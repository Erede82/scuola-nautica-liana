import 'question.dart';

enum LengthBias { shortest, longest }

class SampleSlot {
  const SampleSlot({
    required this.category,
    required this.topic,
    required this.image,
    required this.bias,
  });

  final String category;
  final String topic;
  final bool image;
  final LengthBias bias;
}

const List<String> representativeTopics = [
  'SCAFO',
  'MOTORE',
  'SICUREZZA',
  'MANOVRE',
  'COLREG',
  'METEO',
  'NAV',
  'NORM',
];

/// 16 text slots (both categories, all eight topics) + 7 figures + 2 long texts.
const List<SampleSlot> representativeSampleSlots = [
  SampleSlot(
    category: 'A12',
    topic: 'SCAFO',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'SCAFO',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'MOTORE',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'MOTORE',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'SICUREZZA',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'SICUREZZA',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'MANOVRE',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'MANOVRE',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'COLREG',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'COLREG',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'METEO',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'METEO',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'NAV',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'NAV',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'NORM',
    image: false,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'NORM',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'SCAFO',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'MOTORE',
    image: true,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'MANOVRE',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'NAV',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'METEO',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'COLREG',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'D1',
    topic: 'MANOVRE',
    image: true,
    bias: LengthBias.shortest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'COLREG',
    image: false,
    bias: LengthBias.longest,
  ),
  SampleSlot(
    category: 'A12',
    topic: 'NAV',
    image: false,
    bias: LengthBias.longest,
  ),
];

class RepresentativeSample {
  const RepresentativeSample({
    required this.questions,
    required this.missingSlots,
  });

  final List<TutorQuestion> questions;
  final List<String> missingSlots;
}

String sampleSlotLabel(SampleSlot slot) {
  final kind = slot.image ? 'image' : 'text';
  final bias = slot.bias == LengthBias.shortest ? 'shortest' : 'longest';
  return '${slot.category} ${slot.topic} $kind $bias';
}

/// Deterministic sample. Same bank and same slots always return the same ids.
///
/// An empty pool is reported in [RepresentativeSample.missingSlots] and skipped.
/// It does not fail the run.
RepresentativeSample buildRepresentativeSample(List<TutorQuestion> questions) {
  final used = <String>{};
  final chosen = <TutorQuestion>[];
  final missing = <String>[];
  for (final slot in representativeSampleSlots) {
    final pool = questions
        .where(
          (question) =>
              question.licenseCategory == slot.category &&
              question.topicCode == slot.topic &&
              question.hasImage == slot.image &&
              !used.contains(question.id),
        )
        .toList();
    pool.sort((a, b) {
      final byLength = slot.bias == LengthBias.shortest
          ? a.promptLength.compareTo(b.promptLength)
          : b.promptLength.compareTo(a.promptLength);
      if (byLength != 0) return byLength;
      return a.id.compareTo(b.id);
    });
    if (pool.isEmpty) {
      missing.add(sampleSlotLabel(slot));
      continue;
    }
    chosen.add(pool.first);
    used.add(pool.first.id);
  }
  return RepresentativeSample(questions: chosen, missingSlots: missing);
}

List<TutorQuestion> selectRepresentativeSample(List<TutorQuestion> questions) {
  return buildRepresentativeSample(questions).questions;
}
