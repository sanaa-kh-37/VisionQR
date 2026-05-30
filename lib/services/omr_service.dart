import 'dart:io';
import 'gemini_omr_service.dart';

class OmrResult {
  final String studentName;
  final String studentRegNo;
  final Map<String, String?> part1;
  final Map<String, String?> part2;
  OmrResult({
    required this.studentName,
    required this.studentRegNo,
    required this.part1,
    required this.part2,
  });
}

class OmrService {
  final GeminiOmrService _gemini = GeminiOmrService();

  Future<OmrResult?> scanSheet(File imageFile) async {
    try {
      final r = await _gemini.processSheet(imageFile);
      return OmrResult(
        studentName: r.name,
        studentRegNo: r.regNo,
        part1: r.part1,
        part2: r.part2,
      );
    } catch (e) {
      print("OMR Service Error: $e");
      return null; // UI will show "grading unavailable"
    }
  }
}