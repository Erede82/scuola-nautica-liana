import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  test('correct answer text follows A, B, and C', () {
    expect(sampleQuestion(correctOption: 'A').correctAnswerText, 'Uno');
    expect(sampleQuestion(correctOption: 'B').correctAnswerText, 'Due');
    expect(sampleQuestion(correctOption: 'C').correctAnswerText, 'Tre');
    expect(
      () => sampleQuestion(correctOption: 'D').correctAnswerText,
      throwsFormatException,
    );
  });

  test('prompt states the official answer and does not ask for a choice', () {
    final prompt = buildTutorPrompt(
      sampleQuestion(correctOption: 'B'),
      imageAttached: false,
    );
    expect(prompt.version, tutorLianaPromptVersion);
    expect(prompt.version, 'tutor_liana_v2');
    expect(prompt.version, isNot('tutor_liana_v1'));
    expect(prompt.version, isNot('latest'));
    expect(prompt.version, isNot('current'));
    expect(prompt.system, contains('authoritative'));
    expect(prompt.system, contains('Never choose a different option'));
    expect(prompt.system, isNot(contains('which option is correct')));
    expect(prompt.user, contains('OFFICIAL CORRECT OPTION'));
    expect(prompt.user, contains('B'));
    expect(prompt.user, contains('OFFICIAL CORRECT ANSWER'));
    expect(prompt.user, contains('Due'));
    expect(prompt.user, isNot(contains('student_id')));
    expect(prompt.user, isNot(contains('selected_option')));
    expect(prompt.user, isNot(contains('IMAGE')));
    expect(prompt.user, isNot(contains('EXISTING OFFICIAL EXPLANATION')));
  });

  test('prompt requires a silent Italian proofreading pass', () {
    final prompt = buildTutorPrompt(sampleQuestion(), imageAttached: false);
    final system = prompt.system;
    expect(system, contains('Italian spelling'));
    expect(system, contains('spacing between words'));
    expect(system, contains('punctuation'));
    expect(system, contains('accidental word concatenations'));
    expect(system, contains('incomplete sentences'));
    expect(system, contains('Do not mention this check'));
    expect(system, contains('Do not replace valid nautical terms'));
    expect(system, contains('make the text longer'));
    expect(system, contains('The official correct answer is supplied'));
    expect(system, contains('Never say the official answer is incorrect'));
    expect(system, contains('Do not invent law article numbers'));
    expect(system, contains('Do not be childish'));
    expect(system, isNot(contains('be more verbose')));
    expect(
      system,
      contains(
        'explanation, simple_explanation, memory_example, needs_review, review_reason',
      ),
    );
  });

  test('image and official note are included only when present', () {
    final prompt = buildTutorPrompt(
      sampleQuestion(
        imagePath: 'figures/figura_1.png',
        officialExplanation: 'Nota ufficiale',
      ),
      imageAttached: true,
    );
    expect(prompt.imageAttached, isTrue);
    expect(prompt.user, contains('IMAGE'));
    expect(prompt.user, contains('figures/figura_1.png'));
    expect(prompt.user, contains('EXISTING OFFICIAL EXPLANATION'));
    expect(prompt.user, contains('Nota ufficiale'));
    expect(prompt.user, isNot(contains('student_id')));
  });

  test('source hash matches the SQL concat layout', () {
    final plain = tutorSourceHash(
      sampleQuestion(
        prompt: '  Ciao  ',
        optionA: 'Uno',
        optionB: 'Due',
        optionC: 'Tre',
        correctOption: 'B',
      ),
    );
    expect(
      plain,
      'db66e1ee91e4e27fd187966570071190c92242a5aac4f71fcb8a55a3af274b89',
    );

    final withImage = tutorSourceHash(
      sampleQuestion(
        prompt: 'Segnale',
        optionA: 'A1',
        optionB: 'B1',
        optionC: 'C1',
        correctOption: 'A',
        imagePath: 'figures/figura_1.png',
        officialExplanation: 'Nota ufficiale',
      ),
    );
    expect(
      withImage,
      '8b4df485efa0ccbdc4d1d9de2ab8b2171e4f5c3b1afd8e3d06319ffa8c26d1cd',
    );
  });

  test('identical content still belongs to separate question ids', () {
    final left = sampleQuestion(id: '11111111-1111-4111-8111-111111111111');
    final right = sampleQuestion(id: '22222222-2222-4222-8222-222222222222');
    expect(tutorSourceHash(left), tutorSourceHash(right));
    expect(left.id, isNot(right.id));
  });
}
