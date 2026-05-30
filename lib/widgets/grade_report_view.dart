// lib/widgets/grade_report_view.dart
//
// Task 4 UI: shows the per-question breakdown (tick / cross / dash), the
// correct / incorrect / unattempted counts, and the final score + grade.
//
// Usage:
//   final report = grade_quiz(StudentAnswers(part1: ..., part2: ...), answerKey);
//   GradeReportView(report: report);

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/grade_report.dart';

class GradeReportView extends StatelessWidget {
  final GradeReport report;
  const GradeReportView({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.auto_awesome, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          Text("Auto-Graded Results",
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                  fontSize: 15)),
        ]),
        if (report.hasNegativeMarking) ...[
          const SizedBox(height: 6),
          Text(
            "Negative marking: −${fmtNum(report.negativePerWrong)} per wrong answer",
            style: const TextStyle(color: Colors.orangeAccent, fontSize: 11),
          ),
        ],
        const SizedBox(height: 16),
        _partBlock("Part - I", report.part1),
        const SizedBox(height: 16),
        _partBlock("Part - II", report.part2),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _chip("${report.correct}", "Correct", Colors.greenAccent),
            _chip("${report.incorrect}", "Wrong", Colors.redAccent),
            _chip("${report.unattempted}", "Blank", Colors.white24),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Text("Score: ${report.scoreText}",
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 4),
              Text("${report.percentText}   •   Grade ${report.grade}",
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partBlock(String title, List<QuestionResult> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent)),
        const SizedBox(height: 8),
        ...rows.map(_row),
      ],
    );
  }

  Widget _row(QuestionResult r) {
    late Color color;
    late IconData icon;
    late String got;

    switch (r.status) {
      case QStatus.unattempted:
        color = Colors.white24;
        icon = Icons.remove; // dash
        got = "—";
        break;
      case QStatus.correct:
        color = Colors.greenAccent;
        icon = Icons.check_circle_rounded; // tick
        got = r.studentAnswer ?? "—";
        break;
      case QStatus.incorrect:
        color = Colors.redAccent;
        icon = Icons.cancel_rounded; // cross
        got = r.wasInvalid ? "INVALID" : (r.studentAnswer ?? "—");
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        SizedBox(
            width: 40,
            child: Text(r.question,
                style: const TextStyle(color: Colors.white54, fontSize: 12))),
        Text("Key: ${r.correctAnswer}  ",
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text("Got: $got",
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const Spacer(),
        Icon(icon, color: color, size: 16),
      ]),
    );
  }

  Widget _chip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(count,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    );
  }
}