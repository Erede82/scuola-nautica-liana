import 'package:test/test.dart';
import 'package:tutor_liana_generator/tutor_generator.dart';

import 'support.dart';

void main() {
  const hash =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const other =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  TutorExistingRow row(String status, String sourceHash) {
    return TutorExistingRow(
      questionId: '11111111-1111-4111-8111-111111111111',
      sourceHash: sourceHash,
      status: status,
    );
  }

  test('no existing row is a generate candidate', () {
    expect(
      planTutorAction(
        existing: null,
        currentHash: hash,
        regenerate: false,
        forceApproved: false,
      ),
      TutorPlanAction.generate,
    );
  });

  test('approved current hash is skipped unless force is set', () {
    expect(
      planTutorAction(
        existing: row('approved', hash),
        currentHash: hash,
        regenerate: true,
        forceApproved: false,
      ),
      TutorPlanAction.skipApprovedCurrent,
    );
    expect(
      planTutorAction(
        existing: row('approved', hash),
        currentHash: hash,
        regenerate: false,
        forceApproved: true,
      ),
      TutorPlanAction.forceApproved,
    );
  });

  test('review_required current hash is skipped unless regenerate is set', () {
    expect(
      planTutorAction(
        existing: row('review_required', hash),
        currentHash: hash,
        regenerate: false,
        forceApproved: false,
      ),
      TutorPlanAction.skipReviewCurrent,
    );
    expect(
      planTutorAction(
        existing: row('review_required', hash),
        currentHash: hash,
        regenerate: true,
        forceApproved: false,
      ),
      TutorPlanAction.regenerateCurrent,
    );
  });

  test('generated current hash is skipped unless regenerate is set', () {
    expect(
      planTutorAction(
        existing: row('generated', hash),
        currentHash: hash,
        regenerate: false,
        forceApproved: false,
      ),
      TutorPlanAction.skipReviewCurrent,
    );
    expect(TutorPlanAction.skipReviewCurrent.callsProvider, isFalse);
    expect(TutorPlanAction.skipReviewCurrent.writesRow, isFalse);
    expect(
      planTutorAction(
        existing: row('generated', hash),
        currentHash: hash,
        regenerate: true,
        forceApproved: false,
      ),
      TutorPlanAction.regenerateCurrent,
    );
  });

  test('same-hash stale is regenerated without the regenerate flag', () {
    final action = planTutorAction(
      existing: row('stale', hash),
      currentHash: hash,
      regenerate: false,
      forceApproved: false,
    );
    expect(action, TutorPlanAction.regenerateMarkedStale);
    expect(action.callsProvider, isTrue);
  });

  test('a different hash is stale even when the stored row is approved', () {
    expect(
      planTutorAction(
        existing: row('approved', other),
        currentHash: hash,
        regenerate: false,
        forceApproved: false,
      ),
      TutorPlanAction.regenerateStale,
    );
    expect(
      planTutorAction(
        existing: row('review_required', other),
        currentHash: hash,
        regenerate: false,
        forceApproved: false,
      ),
      TutorPlanAction.regenerateStale,
    );
  });

  test('representative sample covers both categories, topics, and figures', () {
    final questions = <TutorQuestion>[];
    var n = 0;
    final seen = <String>{};
    for (final slot in representativeSampleSlots) {
      final key = '${slot.category}|${slot.topic}|${slot.image}';
      if (!seen.add(key)) continue;
      for (final length in [12, 90]) {
        n += 1;
        final id = '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
        questions.add(
          sampleQuestion(
            id: id,
            licenseCategory: slot.category,
            examTopicCode: slot.topic,
            prompt: 'p' * length,
            imagePath: slot.image ? 'figures/figura_$n.png' : null,
          ),
        );
      }
    }

    final sample = selectRepresentativeSample(questions);
    expect(representativeSampleSlots, hasLength(25));
    expect(sample, hasLength(25));
    expect(sample.where((q) => q.licenseCategory == 'A12'), isNotEmpty);
    expect(sample.where((q) => q.licenseCategory == 'D1'), isNotEmpty);
    expect(
      sample.map((q) => q.topicCode).toSet(),
      containsAll(representativeTopics),
    );
    expect(sample.where((q) => q.hasImage), hasLength(7));
    expect(
      selectRepresentativeSample(questions).map((q) => q.id),
      sample.map((q) => q.id),
    );
    expect(buildRepresentativeSample(questions).missingSlots, isEmpty);
  });

  test('an empty sample reports every missing slot and does not throw', () {
    final report = buildRepresentativeSample(<TutorQuestion>[]);
    expect(report.questions, isEmpty);
    expect(report.missingSlots, hasLength(25));
    expect(report.missingSlots.first, 'A12 SCAFO text shortest');
    expect(report.missingSlots, contains('D1 MANOVRE image shortest'));
  });
}
