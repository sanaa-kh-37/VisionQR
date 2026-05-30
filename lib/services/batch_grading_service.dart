// lib/services/batch_grading_service.dart
//
// Task 5: Batch processing & report generation.
// For each image it runs the full pipeline:
//   1. decode the answer-key QR  (Task 1)
//   2. OCR name / reg / class / subject  (Task 2)
//   3. read the OMR bubbles  (Task 3)
//   4. grade against the key  (Task 4)
// then aggregates everything into a CSV with a summary row.

import 'dart:io';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import '../models/answer_key.dart';
import '../models/student_answers.dart';
import '../models/grade_report.dart';
import 'gemini_omr_service.dart';
import 'quiz_grader.dart';

class BatchRowResult {
  final String fileName;
  final bool ok;
  final String? error;

  final String quizTitle;
  final String setInfo;
  final String className;
  final String subject;
  final String name;
  final String regNo;
  final Map<String, String?> part1; // normalised Q01..Q08
  final Map<String, String?> part2;
  final GradeReport? report;

  BatchRowResult({
    required this.fileName,
    required this.ok,
    this.error,
    this.quizTitle = '',
    this.setInfo = '',
    this.className = '',
    this.subject = '',
    this.name = '',
    this.regNo = '',
    this.part1 = const {},
    this.part2 = const {},
    this.report,
  });

  factory BatchRowResult.fail(String fileName, String error) =>
      BatchRowResult(fileName: fileName, ok: false, error: error);
}

class BatchSummary {
  final int processed; // successfully graded
  final int failed;
  final double averageMarks;
  final double averagePercentage;
  final double highest;
  final double lowest;

  const BatchSummary({
    required this.processed,
    required this.failed,
    required this.averageMarks,
    required this.averagePercentage,
    required this.highest,
    required this.lowest,
  });
}

class BatchGradingService {
  final GeminiOmrService _gemini = GeminiOmrService();
  final MobileScannerController _scanner = MobileScannerController();

  /// Runs the pipeline over every image. [onProgress] fires after each sheet.
  Future<List<BatchRowResult>> processAll(
      List<File> images, {
        void Function(int done, int total)? onProgress,
      }) async {
    final out = <BatchRowResult>[];
    for (var i = 0; i < images.length; i++) {
      out.add(await _processOne(images[i]));
      onProgress?.call(i + 1, images.length);
    }
    return out;
  }

  Future<BatchRowResult> _processOne(File img) async {
    final fileName = img.path.split(Platform.pathSeparator).last;
    try {
      // 1. Decode the answer-key QR from the image.
      final BarcodeCapture? capture = await _scanner.analyzeImage(img.path);
      final String? raw = (capture != null && capture.barcodes.isNotEmpty)
          ? capture.barcodes.first.rawValue
          : null;

      if (raw == null ||
          !(raw.contains('Part-I:') && raw.contains('Part-II:'))) {
        return BatchRowResult.fail(fileName, 'No answer-key QR found in image');
      }
      final key = AnswerKey.fromPayload(raw);

      // 2 + 3. One Gemini call: name, reg, class, subject AND bubbles.
      final sheet = await _gemini.processSheet(img);

      // 4. Grade.
      final report = grade_quiz(
        StudentAnswers(part1: sheet.part1, part2: sheet.part2),
        key,
      );

      return BatchRowResult(
        fileName: fileName,
        ok: true,
        quizTitle: key.quizTitle,
        setInfo: key.setInfo,
        className: sheet.className,
        subject: sheet.subject,
        name: sheet.name,
        regNo: sheet.regNo,
        part1: _normalize8(sheet.part1),
        part2: _normalize8(sheet.part2),
        report: report,
      );
    } catch (e) {
      return BatchRowResult.fail(fileName, e.toString());
    }
  }

  // ---------------------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------------------

  BatchSummary summarize(List<BatchRowResult> rows) {
    final graded = rows.where((r) => r.ok && r.report != null).toList();
    if (graded.isEmpty) {
      return BatchSummary(
        processed: 0,
        failed: rows.length,
        averageMarks: 0,
        averagePercentage: 0,
        highest: 0,
        lowest: 0,
      );
    }
    final marks = graded.map((r) => r.report!.totalMarks).toList();
    final pcts = graded.map((r) => r.report!.percentage).toList();
    final avgMarks = marks.reduce((a, b) => a + b) / marks.length;
    final avgPct = pcts.reduce((a, b) => a + b) / pcts.length;
    return BatchSummary(
      processed: graded.length,
      failed: rows.length - graded.length,
      averageMarks: avgMarks,
      averagePercentage: avgPct,
      highest: marks.reduce((a, b) => a > b ? a : b),
      lowest: marks.reduce((a, b) => a < b ? a : b),
    );
  }

  /// Builds the CSV text with all required columns + a summary block.
  String buildCsv(List<BatchRowResult> rows) {
    const qs = ['Q01', 'Q02', 'Q03', 'Q04', 'Q05', 'Q06', 'Q07', 'Q08'];

    final header = <String>[
      'Quiz', 'Set', 'Class', 'Subject', 'Name', 'Reg No',
      ...qs.map((q) => 'Part1_$q'),
      ...qs.map((q) => 'Part2_$q'),
      'Correct', 'Incorrect', 'Unattempted', 'Total Marks', 'Percentage', 'Grade',
    ];

    final lines = <String>[header.map(_csv).join(',')];

    for (final r in rows) {
      if (!r.ok || r.report == null) {
        // Keep failed sheets visible so nothing is silently dropped.
        lines.add([
          'ERROR', '', '', '', r.fileName, '',
          ...List.filled(16, ''),
          '', '', '', '', '', r.error ?? 'failed',
        ].map(_csv).join(','));
        continue;
      }
      final rep = r.report!;
      lines.add([
        r.quizTitle, r.setInfo, r.className, r.subject, r.name, r.regNo,
        ...qs.map((q) => _ans(r.part1[q])),
        ...qs.map((q) => _ans(r.part2[q])),
        rep.correct, rep.incorrect, rep.unattempted,
        fmtNum(rep.totalMarks), '${rep.percentage.toStringAsFixed(1)}%', rep.grade,
      ].map(_csv).join(','));
    }

    // ---- summary block ----
    final s = summarize(rows);
    lines.add(''); // blank separator
    lines.add(['CLASS SUMMARY'].map(_csv).join(','));
    lines.add(['Sheets graded', s.processed, 'Failed', s.failed].map(_csv).join(','));
    lines.add(['Class Average (marks)', fmtNum(s.averageMarks),
      'Average %', '${s.averagePercentage.toStringAsFixed(1)}%'].map(_csv).join(','));
    lines.add(['Highest Score', fmtNum(s.highest),
      'Lowest Score', fmtNum(s.lowest)].map(_csv).join(','));

    return lines.join('\n');
  }

  /// Writes the CSV to a temp file, auto-named "<quizTitle>_<timestamp>.csv".
  Future<File> saveCsv(List<BatchRowResult> rows) async {
    final csv = buildCsv(rows);
    final quiz = rows.firstWhere((r) => r.ok, orElse: () => rows.first).quizTitle;
    final safeQuiz = (quiz.isEmpty ? 'Quiz' : quiz)
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final ts = _timestamp(DateTime.now());
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${safeQuiz}_$ts.csv');
    return file.writeAsString(csv);
  }

  void dispose() => _scanner.dispose();

  // ---- helpers ----

  Map<String, String?> _normalize8(Map<String, String?> m) {
    String nk(String k) {
      final d = k.replaceAll(RegExp(r'[^0-9]'), '');
      return d.isEmpty ? k.toUpperCase() : 'Q${d.padLeft(2, '0')}';
    }
    final out = <String, String?>{};
    m.forEach((k, v) => out[nk(k)] = v);
    return out;
  }

  String _ans(String? v) {
    if (v == null) return '-';      // unattempted
    return v;                        // "A".."D" or "INVALID"
  }

  String _csv(Object? v) {
    final s = (v ?? '').toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String _timestamp(DateTime n) =>
      '${n.year}${_2(n.month)}${_2(n.day)}_${_2(n.hour)}${_2(n.minute)}${_2(n.second)}';
  String _2(int x) => x.toString().padLeft(2, '0');
}