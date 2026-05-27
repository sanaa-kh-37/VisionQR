import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StudentInfo {
  final String name;
  final String regNo;

  StudentInfo({required this.name, required this.regNo});

  @override
  String toString() => 'Name: $name\nReg No: $regNo';
}

class OcrService {
  // ── PASTE YOUR API KEY HERE ──────────────────────────────────────────────
  static String get _apiKey => dotenv.env['CLOUD_VISION_API_KEY'] ?? '';
  static final String _endpoint =
      'https://vision.googleapis.com/v1/images:annotate?key=$_apiKey';

  Future<StudentInfo> extractStudentInfo(File imageFile) async {
    // 1. Convert image to base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    // 2. Call Cloud Vision API
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "requests": [
          {
            "image": {"content": base64Image},
            "features": [
              {"type": "DOCUMENT_TEXT_DETECTION"} // best for handwriting
            ],
            "imageContext": {
              "languageHints": ["en"] // add "ur" if Urdu names appear
            }
          }
        ]
      }),
    );

    if (response.statusCode != 200) {
      return StudentInfo(name: 'OCR Error', regNo: 'OCR Error');
    }

    final data = jsonDecode(response.body);

    // 3. Extract full text
    final String fullText = data['responses']?[0]?['fullTextAnnotation']?['text'] ?? '';

    if (fullText.isEmpty) {
      return StudentInfo(name: 'Not found', regNo: 'Not found');
    }

    // 4. Parse name and reg number from the text
    return _parseStudentInfo(fullText);
  }

  StudentInfo _parseStudentInfo(String fullText) {
    String name = 'Not found';
    String regNo = 'Not found';

    // Split into lines for processing
    final lines = fullText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lower = line.toLowerCase();

      // ── NAME extraction ──────────────────────────────────────────────────
      if (_isNameLabel(lower) && name == 'Not found') {
        // Try after colon on same line: "Name: Noor-ul Ain Jadoon"
        final afterColon = _extractAfterSeparator(line);
        if (afterColon.length > 2 && !_isLabel(afterColon.toLowerCase())) {
          name = afterColon;
        }
        // Try next line
        else if (i + 1 < lines.length) {
          final next = lines[i + 1];
          if (!_isLabel(next.toLowerCase()) && next.length > 2) {
            name = next;
          }
        }
      }

      // ── REGISTRATION extraction ──────────────────────────────────────────
      if (_isRegLabel(lower) && regNo == 'Not found') {
        // Try after # or colon: "Registration # BSE-FA24-047"
        final afterSep = _extractAfterSeparator(line);
        if (afterSep.length > 2 && !_isLabel(afterSep.toLowerCase())) {
          regNo = afterSep;
        }
        // Try next line
        else if (i + 1 < lines.length) {
          final next = lines[i + 1];
          if (!_isLabel(next.toLowerCase()) && next.length > 2) {
            regNo = next;
          }
        }
      }
    }

    // ── Regex fallback for reg number ────────────────────────────────────
    // Catches BSE-FA24-047 / 2023-CS-01 / FA21-BCE-123 formats
    if (regNo == 'Not found' || !_looksLikeRegNo(regNo)) {
      final match = RegExp(
        r'\b([A-Z]{2,4}-[A-Z]{2,4}\d{2,4}-\d{2,4}|[A-Z]{2,4}\d{2,4}-[A-Z]{2,4}-\d{2,4}|\d{4}-[A-Z]{2,4}-\d{2,4})\b',
        caseSensitive: false,
      ).firstMatch(fullText);
      if (match != null) regNo = match.group(0)!;
    }

    return StudentInfo(
      name: _sanitizeName(name),
      regNo: _sanitizeReg(regNo),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isNameLabel(String lower) =>
      lower.contains('name') &&
          !lower.contains('registr') &&
          !lower.contains('subject') &&
          !lower.contains('quiz') &&
          !lower.contains('class');

  bool _isRegLabel(String lower) =>
      lower.contains('reg') ||
          lower.contains('registration') ||
          lower.contains('roll') ||
          lower.contains('reg#') ||
          lower.contains('reg #');

  bool _isLabel(String lower) =>
      lower.contains('name') ||
          lower.contains('reg') ||
          lower.contains('roll') ||
          lower.contains('class') ||
          lower.contains('subject') ||
          lower.contains('quiz') ||
          lower.contains('time') ||
          lower.contains('total') ||
          lower.contains('marks') ||
          lower.contains('part') ||
          lower.contains('answer');

  bool _looksLikeRegNo(String text) =>
      RegExp(r'[A-Z]{2,}-?\d{2,}', caseSensitive: false).hasMatch(text) ||
          RegExp(r'\d{4}-[A-Z]{2,}', caseSensitive: false).hasMatch(text);

  // Handles both ":" and "#" as separators
  String _extractAfterSeparator(String line) {
    for (final sep in [':', '#']) {
      final idx = line.indexOf(sep);
      if (idx != -1 && idx < line.length - 1) {
        return line.substring(idx + 1).trim();
      }
    }
    return '';
  }

  String _sanitizeName(String name) {
    if (name == 'Not found') return name;
    return name
        .replaceAll(RegExp(r'[^a-zA-Z\s\.\-]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  String _sanitizeReg(String reg) {
    if (reg == 'Not found') return reg;
    // Collapse spaces OCR may insert: "B S E" → "BSE"
    String collapsed = reg.replaceAll(
        RegExp(r'(?<=[A-Za-z0-9])\s(?=[A-Za-z0-9])'), '');
    return collapsed
        .replaceAll(RegExp(r'[^a-zA-Z0-9\-]'), '')
        .toUpperCase()
        .trim();
  }

  void dispose() {
    // Nothing to close — HTTP client is stateless
  }
}