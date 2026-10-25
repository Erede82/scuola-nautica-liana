import 'dart:convert';
import 'dart:io';

import 'package:tutor_liana_generator/tutor_generator.dart';

const _usage = '''
Tutor Liana offline generator.

Default is a dry run: no AI call and no database write.

  dart run bin/tutor_generate.dart --sample
  dart run bin/tutor_generate.dart --question-id <uuid> --limit 30
  dart run bin/tutor_generate.dart --category A12 --lesson 4 --with-image

Gates, both required before a production write:
  --generate          call the provider, do not write
  --generate --write  call the provider and upsert review_required rows

Extra:
  --regenerate        replace a current review_required/generated row
  --force-approved    replace an approved row whose hash is still current
  --catalog <file>    JSON question catalog for an offline dry run
  --concurrency <1-4> default 1
  --min-interval-ms   pause after each provider call (default 500 when generating)
  --model <id>        passed to the provider; not used by domain rules
  --provider openai   required together with --generate before any OpenAI call
  --pricing <file>    optional JSON prices, input_usd_per_million / output_usd_per_million

Environment, only when the live database is used:
  SUPABASE_URL
  SUPABASE_SERVICE_ROLE_KEY

Environment, only when --provider openai is combined with --generate:
  OPENAI_API_KEY
''';

Future<void> main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return;
  }
  try {
    final config = _parse(args);
    validateSelection(config.selection);
    if (config.write && !config.generate) {
      throw FormatException('--write requires --generate.');
    }
    if (config.catalogFile != null && config.write) {
      throw FormatException('--catalog cannot be combined with --write.');
    }
    final opened = await _open(config);
    try {
      final pipeline = TutorPipeline(
        catalog: opened.catalog,
        store: opened.gateway ?? MemoryTutorStore(),
        provider: buildTutorProvider(
          providerName: config.providerName,
          generate: config.generate,
          openAIApiKey: config.providerName == 'openai' && config.generate
              ? Platform.environment['OPENAI_API_KEY']
              : null,
        ),
        images: opened.gateway ?? UnavailableImageSource(),
        log: (event) => stdout.writeln(jsonEncode(event)),
      );
      final summary = await pipeline.run(
        TutorRunRequest(
          selection: config.selection,
          generate: config.generate,
          write: config.write,
          regenerate: config.regenerate,
          forceApproved: config.forceApproved,
          concurrency: config.concurrency,
          minInterval: config.generate
              ? Duration(milliseconds: config.minIntervalMs)
              : Duration.zero,
          model: config.model,
          pricing: config.pricing,
        ),
      );
      stdout.writeln(tutorSummaryLine(summary));
      final missing = opened.catalog.missingSampleSlots;
      if (missing.isNotEmpty) {
        stdout.writeln(jsonEncode({'missing_sample_slots': missing}));
      }
      if (summary.failed > 0) exitCode = 1;
    } finally {
      opened.gateway?.close();
    }
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exitCode = 2;
  } on TutorProviderUnavailable catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
  } catch (error) {
    stderr.writeln(error.toString());
    exitCode = 1;
  }
}

class _Config {
  _Config({
    required this.selection,
    required this.generate,
    required this.write,
    required this.regenerate,
    required this.forceApproved,
    required this.concurrency,
    required this.minIntervalMs,
    required this.pricing,
    this.model,
    this.providerName,
    this.catalogFile,
  });

  final TutorSelection selection;
  final bool generate;
  final bool write;
  final bool regenerate;
  final bool forceApproved;
  final int concurrency;
  final int minIntervalMs;
  final PricingCatalog pricing;
  final String? model;
  final String? providerName;
  final String? catalogFile;
}

_Config _parse(List<String> args) {
  final ids = <String>[];
  String? category;
  String? catalog;
  String? model;
  String? providerName;
  String? pricingPath;
  int? limit;
  int? lesson;
  var withImage = false;
  var withoutImage = false;
  var sample = false;
  var generate = false;
  var write = false;
  var regenerate = false;
  var forceApproved = false;
  var concurrency = 1;
  var minIntervalMs = 500;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    String next() {
      if (i + 1 >= args.length) {
        throw FormatException('Missing value for $arg');
      }
      i += 1;
      return args[i];
    }

    switch (arg) {
      case '--generate':
        generate = true;
      case '--write':
        write = true;
      case '--regenerate':
        regenerate = true;
      case '--force-approved':
        forceApproved = true;
      case '--sample':
        sample = true;
      case '--with-image':
        withImage = true;
      case '--without-image':
        withoutImage = true;
      case '--question-id':
        ids.add(next());
      case '--limit':
        limit = int.tryParse(next());
        if (limit == null) throw FormatException('--limit must be an integer');
      case '--lesson':
        lesson = int.tryParse(next());
        if (lesson == null) {
          throw FormatException('--lesson must be an integer');
        }
      case '--category':
        category = next();
      case '--catalog':
        catalog = next();
      case '--model':
        model = next();
      case '--provider':
        final provider = next();
        if (provider.trim().isEmpty) {
          throw FormatException('--provider requires a value');
        }
        providerName = provider;
      case '--pricing':
        pricingPath = next();
      case '--concurrency':
        concurrency = int.tryParse(next()) ?? 0;
        if (concurrency < 1 || concurrency > 4) {
          throw FormatException('--concurrency must be from 1 to 4');
        }
      case '--min-interval-ms':
        minIntervalMs = int.tryParse(next()) ?? -1;
        if (minIntervalMs < 0) {
          throw FormatException('--min-interval-ms must be >= 0');
        }
      default:
        throw FormatException('Unknown argument $arg');
    }
  }

  return _Config(
    selection: TutorSelection(
      questionIds: ids,
      limit: limit,
      category: category,
      lesson: lesson,
      withImage: withImage,
      withoutImage: withoutImage,
      sample: sample,
    ),
    generate: generate,
    write: write,
    regenerate: regenerate,
    forceApproved: forceApproved,
    concurrency: concurrency,
    minIntervalMs: minIntervalMs,
    model: model,
    providerName: providerName,
    catalogFile: catalog,
    pricing: pricingPath == null
        ? const PricingCatalog({})
        : _pricing(File(pricingPath)),
  );
}

PricingCatalog _pricing(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is! Map) {
    throw FormatException('pricing file must be a JSON object');
  }
  final prices = <String, ModelPrice>{};
  decoded.forEach((key, value) {
    if (value is! Map) return;
    final input = value['input_usd_per_million'];
    final output = value['output_usd_per_million'];
    if (input is! num || output is! num) {
      throw FormatException('pricing for $key is incomplete');
    }
    prices[key.toString()] = ModelPrice(
      inputUsdPerMillion: input.toDouble(),
      outputUsdPerMillion: output.toDouble(),
    );
  });
  return PricingCatalog(prices);
}

class _Opened {
  const _Opened({required this.catalog, this.gateway});
  final TutorCatalog catalog;
  final SupabaseTutorGateway? gateway;
}

Future<_Opened> _open(_Config config) async {
  if (config.catalogFile != null) {
    return _Opened(
      catalog: await FileTutorCatalog.fromFile(File(config.catalogFile!)),
    );
  }
  final url = Platform.environment['SUPABASE_URL']?.trim();
  final key = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];
  if (url == null || url.isEmpty || key == null || key.trim().isEmpty) {
    throw FormatException(
      'SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are required '
      'unless --catalog is used.',
    );
  }
  final gateway = SupabaseTutorGateway(supabaseUrl: url, serviceRoleKey: key);
  return _Opened(catalog: gateway, gateway: gateway);
}
