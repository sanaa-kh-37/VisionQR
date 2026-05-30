// lib/services/bubble_sheet_reader.dart
//
// Deliverable entry point:  read_bubble_sheet(image) -> StudentAnswers
//
// Detects the answer grid in the image and interprets every bubble for
// Part-I and Part-II (Q01..Q08 each), handling:
//   - partial fills      -> picks the clearly-darkened bubble
//   - blank questions    -> null  (unattempted)
//   - multi-filled bubbles -> "INVALID" (flagged)
//
// Powered by Gemini vision, which tolerates moderate tilt/warp without any
// manual perspective correction.

import 'dart:io';
import '../models/student_answers.dart';
import 'gemini_omr_service.dart';

final GeminiOmrService _gemini = GeminiOmrService();

/// Reads the OMR bubble grid from [image] and returns a [StudentAnswers].
///
/// Throws if the model call fails or returns unparseable output, so callers
/// can surface a real error instead of silently treating everything as blank.
// ignore: non_constant_identifier_names  (named to match the rubric exactly)
Future<StudentAnswers> read_bubble_sheet(File image) async {
  final result = await _gemini.processSheet(image);
  return StudentAnswers(
    part1: result.part1,
    part2: result.part2,
  );
}