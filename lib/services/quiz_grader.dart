// lib/services/quiz_grader.dart
//
// Task 4 deliverable:  grade_quiz(student_answers, answer_key) -> GradeReport
//
// Compares the student's bubbles against the decoded answer key, bubble by
// bubble, and computes counts + marks + percentage + letter grade. Negative
// marking is honoured automatically when it is encoded in the QR (see AnswerKey).

import '../models/answer_key.dart';
import '../models/student_answers.dart';
import '../models/grade_report.dart';

/// Normalises "Q1", "q01", "Question 1" etc. -> "Q01" so key and student maps
/// always line up regardless of how each side wrote the question number.
String _normKey(String k) {
  final digits = k.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? k.toUpperCase() : 'Q${digits.padLeft(2, '0')}';
}

Map<String, V> _normMap<V>(Map<String, V> m) =>
    {for (final e in m.entries) _normKey(e.key): e.value};

// ignore: non_constant_identifier_names  (named to match the rubric exactly)
GradeReport grade_quiz(StudentAnswers studentAnswers, AnswerKey answerKey) {
  final double mpc = answerKey.marksPerCorrect;
  final double neg = answerKey.negativePerWrong;

  int correct = 0, incorrect = 0, unattempted = 0;
  double earned = 0;

  List<QuestionResult> gradePart(
      String label,
      Map<String, String> key,
      Map<String, String?> student,
      ) {
    final nk = _normMap(key);
    final ns = _normMap(student);
    final out = <QuestionResult>[];

    final questions = nk.keys.toList()..sort();
    for (final q in questions) {
      final correctAns = (nk[q] ?? '').toUpperCase();
      final raw = ns[q];
      final ans = (raw == null || raw.trim().isEmpty)
          ? null
          : raw.trim().toUpperCase();

      QStatus status;
      double marks;
      bool invalid = false;

      if (ans == null) {
        status = QStatus.unattempted;
        marks = 0;
        unattempted++;
      } else if (ans == 'INVALID') {
        status = QStatus.incorrect; // multi-filled counts as incorrect
        marks = -neg;
        invalid = true;
        incorrect++;
      } else if (ans == correctAns) {
        status = QStatus.correct;
        marks = mpc;
        correct++;
      } else {
        status = QStatus.incorrect;
        marks = -neg;
        incorrect++;
      }

      earned += marks;
      out.add(QuestionResult(
        part: label,
        question: q,
        correctAnswer: correctAns,
        studentAnswer: ans,
        status: status,
        marks: marks,
        wasInvalid: invalid,
      ));
    }
    return out;
  }

  final p1 = gradePart('Part-I', answerKey.part1, studentAnswers.part1);
  final p2 = gradePart('Part-II', answerKey.part2, studentAnswers.part2);

  final int totalQ = answerKey.part1.length + answerKey.part2.length;
  final double maxMarks = totalQ * mpc;
  final double clamped = earned < 0 ? 0.0 : earned; // a quiz score can't go below 0
  final double pct = maxMarks > 0 ? (clamped / maxMarks * 100) : 0.0;

  return GradeReport(
    part1: p1,
    part2: p2,
    correct: correct,
    incorrect: incorrect,
    unattempted: unattempted,
    totalMarks: clamped,
    maxMarks: maxMarks,
    percentage: pct,
    grade: letterGrade(pct),
    marksPerCorrect: mpc,
    negativePerWrong: neg,
  );
}