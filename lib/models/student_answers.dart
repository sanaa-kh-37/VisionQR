// lib/models/student_answers.dart
//
// Structured result of an OMR bubble read (the rubric's `StudentAnswers`).
//
// Each answer value is one of:
//   "A" | "B" | "C" | "D"  -> exactly one bubble clearly filled
//   "INVALID"              -> more than one bubble filled (flagged)
//   null                   -> no bubble filled (unattempted)

class StudentAnswers {
  /// Q01..Q08 -> answer value (see class doc for the allowed values).
  final Map<String, String?> part1;
  final Map<String, String?> part2;

  const StudentAnswers({required this.part1, required this.part2});

  static const String invalidFlag = "INVALID";

  /// Combined view with part-prefixed keys so Q01 in both parts don't clash.
  Iterable<MapEntry<String, String?>> get _all => [
    ...part1.entries.map((e) => MapEntry('P1-${e.key}', e.value)),
    ...part2.entries.map((e) => MapEntry('P2-${e.key}', e.value)),
  ];

  /// Questions where more than one bubble was filled.
  List<String> get invalidQuestions =>
      [for (final e in _all) if (e.value == invalidFlag) e.key];

  /// Questions left blank (unattempted).
  List<String> get unattemptedQuestions =>
      [for (final e in _all) if (e.value == null) e.key];

  /// Questions with exactly one valid letter answer.
  int get answeredCount =>
      _all.where((e) => e.value != null && e.value != invalidFlag).length;

  int get totalCount => part1.length + part2.length;

  /// Matches the exact structure required by the deliverable.
  Map<String, dynamic> toJson() => {'part1': part1, 'part2': part2};

  @override
  String toString() => 'StudentAnswers(part1: $part1, part2: $part2)';
}