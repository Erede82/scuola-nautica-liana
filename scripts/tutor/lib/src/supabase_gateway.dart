import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'eligibility.dart';
import 'image_source.dart';
import 'persistence.dart';
import 'pipeline.dart';
import 'question.dart';
import 'selection.dart';
import 'source_hash.dart';

void assertServiceRoleKey(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError('SUPABASE_SERVICE_ROLE_KEY is empty');
  }
  if (trimmed.startsWith('sb_publishable')) {
    throw ArgumentError(
      'Refusing a publishable Supabase key. The generator requires the service role.',
    );
  }
  if (trimmed.contains(' ') || trimmed.contains('\n')) {
    throw ArgumentError('SUPABASE_SERVICE_ROLE_KEY is malformed');
  }
}

class FileTutorCatalog implements TutorCatalog {
  FileTutorCatalog(this.items);

  final List<TutorCatalogItem> items;
  List<String> _missingSampleSlots = const [];

  @override
  List<String> get missingSampleSlots => _missingSampleSlots;

  static Future<FileTutorCatalog> fromFile(File file) async {
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw FormatException('catalog must be a JSON array');
    }
    final items = <TutorCatalogItem>[];
    for (final row in decoded) {
      if (row is! Map) {
        throw FormatException('catalog row is not an object');
      }
      final json = Map<String, Object?>.from(row);
      final question = TutorQuestion.fromJson(json);
      final supplied = json['source_hash']?.toString();
      final hash = supplied != null && tutorSourceHashPattern.hasMatch(supplied)
          ? supplied
          : tutorSourceHash(question);
      final status = json['existing_status']?.toString();
      TutorExistingRow? existing;
      if (status != null && status.isNotEmpty && status != 'null') {
        existing = TutorExistingRow(
          questionId: question.id,
          sourceHash: json['existing_source_hash']?.toString() ?? hash,
          status: status,
        );
      }
      items.add(
        TutorCatalogItem(
          question: question,
          sourceHash: hash,
          existing: existing,
        ),
      );
    }
    return FileTutorCatalog(items);
  }

  @override
  Future<List<TutorCatalogItem>> load(TutorSelection selection) async {
    final byId = {for (final item in items) item.question.id: item};
    final selected = selectQuestions(
      items.map((item) => item.question).toList(),
      selection,
    );
    _missingSampleSlots = selected.missingSampleSlots;
    return [for (final question in selected.questions) byId[question.id]!];
  }
}

class SupabaseTutorGateway
    implements TutorCatalog, TutorExplanationStore, TutorImageSource {
  SupabaseTutorGateway({
    required String supabaseUrl,
    required String serviceRoleKey,
    HttpClient? httpClient,
  }) : supabaseUrl = supabaseUrl.endsWith('/')
           ? supabaseUrl.substring(0, supabaseUrl.length - 1)
           : supabaseUrl,
       serviceRoleKey = serviceRoleKey.trim(),
       _http = httpClient ?? HttpClient() {
    assertServiceRoleKey(this.serviceRoleKey);
    _http.connectionTimeout = const Duration(seconds: 20);
  }

  final String supabaseUrl;
  final String serviceRoleKey;
  final HttpClient _http;
  List<String> _missingSampleSlots = const [];

  @override
  List<String> get missingSampleSlots => _missingSampleSlots;

  void close() => _http.close(force: true);

  @override
  Future<List<TutorCatalogItem>> load(TutorSelection selection) async {
    final questions = await _fetchQuestions(selection);
    final selectedResult = selectQuestions(questions, selection);
    _missingSampleSlots = selectedResult.missingSampleSlots;
    final selected = selectedResult.questions;
    if (selected.isEmpty) return const [];
    final existing = await _fetchExisting(selected.map((q) => q.id).toList());
    final items = <TutorCatalogItem>[];
    for (final question in selected) {
      final hash = await _sourceHash(question.id);
      items.add(
        TutorCatalogItem(
          question: question,
          sourceHash: hash,
          existing: existing[question.id],
        ),
      );
    }
    return items;
  }

  Future<List<TutorQuestion>> _fetchQuestions(TutorSelection selection) async {
    final rows = <TutorQuestion>[];
    const pageSize = 1000;
    var offset = 0;
    while (true) {
      final query = <String, String>{
        'select':
            'id,license_category,lesson_number,exam_topic_code,source_topic_text,'
            'prompt,option_a,option_b,option_c,correct_option,explanation,image_path',
        'order': 'id.asc',
      };
      if (selection.questionIds.isNotEmpty) {
        query['id'] = 'in.(${selection.questionIds.join(',')})';
      }
      if (selection.category != null) {
        query['license_category'] = 'eq.${selection.category}';
      }
      if (selection.lesson != null) {
        query['lesson_number'] = 'eq.${selection.lesson}';
      }
      final uri = Uri.parse(
        '$supabaseUrl/rest/v1/questions',
      ).replace(queryParameters: query);
      final page = await _json(
        'GET',
        uri,
        range: '$offset-${offset + pageSize - 1}',
      );
      if (page is! List) {
        throw TutorGatewayException('questions response is not a list');
      }
      rows.addAll(
        page.map(
          (row) =>
              TutorQuestion.fromJson(Map<String, Object?>.from(row as Map)),
        ),
      );
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return rows;
  }

  Future<String> _sourceHash(String questionId) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/rpc/compute_quiz_question_tutor_source_hash',
    );
    final body = await _json('POST', uri, body: {'p_question_id': questionId});
    if (body is! String || !tutorSourceHashPattern.hasMatch(body)) {
      throw TutorGatewayException(
        'Trusted source hash missing for question $questionId',
      );
    }
    return body;
  }

  Future<Map<String, TutorExistingRow>> _fetchExisting(List<String> ids) async {
    final found = <String, TutorExistingRow>{};
    const chunk = 80;
    for (var i = 0; i < ids.length; i += chunk) {
      final slice = ids.skip(i).take(chunk).join(',');
      final uri = Uri.parse('$supabaseUrl/rest/v1/quiz_question_explanations')
          .replace(
            queryParameters: {
              'select': 'question_id,source_hash,status',
              'question_id': 'in.($slice)',
            },
          );
      final page = await _json('GET', uri);
      if (page is! List) {
        throw TutorGatewayException('tutor rows response is not a list');
      }
      for (final row in page) {
        final map = Map<String, Object?>.from(row as Map);
        final id = map['question_id']?.toString() ?? '';
        found[id] = TutorExistingRow(
          questionId: id,
          sourceHash: map['source_hash']?.toString() ?? '',
          status: map['status']?.toString() ?? '',
        );
      }
    }
    return found;
  }

  @override
  Future<void> insert(TutorWritePayload payload) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/quiz_question_explanations');
    await _json(
      'POST',
      uri,
      body: payload.toJson(),
      prefer: 'return=representation',
    );
  }

  @override
  Future<void> update({
    required TutorWritePayload payload,
    required String filter,
  }) async {
    final uri = Uri.parse(
      '$supabaseUrl/rest/v1/quiz_question_explanations?$filter',
    );
    final updated = await _json(
      'PATCH',
      uri,
      body: payload.toJson(),
      prefer: 'return=representation',
    );
    if (updated is! List || updated.isEmpty) {
      throw TutorGatewayException(
        'Tutor update matched no row for ${payload.questionId}. '
        'An approved current-hash row is left unchanged.',
      );
    }
  }

  @override
  Future<TutorImageAsset> fetch(String imagePath) async {
    if (mediaTypeForImagePath(imagePath) == null) {
      throw TutorImageException('unsupported image type for $imagePath');
    }
    final uri = quizImagePublicUri(
      supabaseUrl: supabaseUrl,
      imagePath: imagePath,
    );
    final request = await _http.getUrl(uri);
    request.followRedirects = false;
    final response = await request.close().timeout(const Duration(seconds: 20));
    final bytes = await _readLimited(response);
    return validateFetchedQuizImage(
      path: imagePath,
      statusCode: response.statusCode,
      contentType: response.headers.value(HttpHeaders.contentTypeHeader),
      bytes: bytes,
    );
  }

  Future<Object?> _json(
    String method,
    Uri uri, {
    Object? body,
    String? prefer,
    String? range,
  }) async {
    final request = await _http.openUrl(method, uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set('apikey', serviceRoleKey);
    request.headers.set(
      HttpHeaders.authorizationHeader,
      'Bearer $serviceRoleKey',
    );
    if (prefer != null) request.headers.set('Prefer', prefer);
    if (range != null) request.headers.set('Range', range);
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.add(utf8.encode(jsonEncode(body)));
    }
    final response = await request.close().timeout(const Duration(seconds: 30));
    final text = await utf8.decodeStream(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TutorGatewayException(
        'Supabase $method ${uri.path} HTTP ${response.statusCode}: '
        '${_redact(text)}',
      );
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  Future<Uint8List> _readLimited(HttpClientResponse response) async {
    final builder = BytesBuilder(copy: false);
    var total = 0;
    await for (final chunk in response) {
      total += chunk.length;
      if (total > 8 * 1024 * 1024) {
        throw TutorImageException('image exceeds 8 MB');
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  String _redact(String text) => text.replaceAll(serviceRoleKey, '[redacted]');
}

class TutorGatewayException implements Exception {
  TutorGatewayException(this.message);
  final String message;
  @override
  String toString() => message;
}

class UnavailableImageSource implements TutorImageSource {
  @override
  Future<TutorImageAsset> fetch(String imagePath) {
    throw TutorImageException(
      'Image loading is disabled in this run ($imagePath).',
    );
  }
}

class MemoryTutorStore implements TutorExplanationStore {
  final List<TutorWritePayload> inserts = [];
  final List<({TutorWritePayload payload, String filter})> updates = [];

  @override
  Future<void> insert(TutorWritePayload payload) async {
    inserts.add(payload);
  }

  @override
  Future<void> update({
    required TutorWritePayload payload,
    required String filter,
  }) async {
    updates.add((payload: payload, filter: filter));
  }
}
