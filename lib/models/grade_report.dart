// lib/models/grade_report.dart
//
// Result of grading one student's sheet against an answer key (Task 4).

/// tick (correct) | cross (incorrect) | dash (unattempted)
enum QStatus { correct, incorrect, unattempted }

class QuestionResult {
  final String part;          // "Part-I" / "Part-II"
  final String question;      // normalised "Q01"
  final String correctAnswer; // "A".."D"
  final String? studentAnswer; // null | "A".."D" | "INVALID"
  final QStatus status;
  final double marks;         // marks awarded for THIS question
  final bool wasInvalid;      // true if student multi-filled (counts as incorrect)

  const QuestionResult({
    required this.part,
    required this.question,
    required this.correctAnswer,
    required this.studentAnswer,
    required this.status,
    required this.marks,
    this.wasInvalid = false,
  });
}

class GradeReport {
  final List<QuestionResult> part1;
  final List<QuestionResult> part2;

  final int correct;
  final int incorrect;     // includes INVALID (multi-filled) rows
  final int unattempted;

  final double totalMarks;  // achieved (clamped at 0)
  final double maxMarks;    // total possible
  final double percentage;  // 0..100
  final String grade;       // A/B/C/D/F

  final double marksPerCorrect;
  final double negativePerWrong;

  const GradeReport({
    required this.part1,
    required this.part2,
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.totalMarks,
    required this.maxMarks,
    required this.percentage,
    required this.grade,
    required this.marksPerCorrect,
    required this.negativePerWrong,
  });

  List<QuestionResult> get all => [...part1, ...part2];

  bool get hasNegativeMarking => negativePerWrong > 0;

  /// e.g. "12 / 16"
  String get scoreText => '${fmtNum(totalMarks)} / ${fmtNum(maxMarks)}';

  String get percentText => '${percentage.toStringAsFixed(1)}%';
}

/// Standard A/B/C/D/F scale. Adjust the thresholds here if your
/// institution uses a different cutoff.
String letterGrade(double percentage) {
  if (percentage >= 80) return 'A';
  if (percentage >= 70) return 'B';
  if (percentage >= 60) return 'C';
  if (percentage >= 50) return 'D';
  return 'F';
}

/// Pretty-prints a double without a trailing ".0" (12.0 -> "12", 11.5 -> "11.5").
String fmtNum(double n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);