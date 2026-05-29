// lib/services/omr_service.dart
// =====================================================
// FIXES:
//   1. ping timeout: 4s → 60s  (Render cold start takes 30-50s)
//   2. scan timeout: 30s → 120s (Gemini Vision call takes extra time)
//   3. Added wake-up ping BEFORE scanning so server is warm

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Data model for the result ────────────────────────────────────────────────
class OmrResult {
  final Map<String, String?> part1;
  final Map<String, String?> part2;
  final bool perspectiveCorrected;
  final int bubblesFoundPart1;
  final int bubblesFoundPart2;

  OmrResult({
    required this.part1,
    required this.part2,
    this.perspectiveCorrected = false,
    this.bubblesFoundPart1   = 0,
    this.bubblesFoundPart2   = 0,
  });

  factory OmrResult.fromJson(Map<String, dynamic> json) {
    Map<String, String?> parseAnswers(dynamic raw) {
      if (raw == null) return {};
      return (raw as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, value as String?));
    }

    final debug = json['debug_info'] as Map<String, dynamic>? ?? {};

    return OmrResult(
      part1: parseAnswers(json['part1']),
      part2: parseAnswers(json['part2']),
      perspectiveCorrected: debug['perspective_corrected'] as bool? ?? false,
      bubblesFoundPart1:    debug['bubbles_found_part1']   as int?  ?? 0,
      bubblesFoundPart2:    debug['bubbles_found_part2']   as int?  ?? 0,
    );
  }

  int get totalAnswered =>
      [...part1.values, ...part2.values]
          .where((v) => v != null && v != 'INVALID')
          .length;

  int get totalInvalid =>
      [...part1.values, ...part2.values]
          .where((v) => v == 'INVALID')
          .length;
}

// ─── The service class ────────────────────────────────────────────────────────
class OmrService {

  static String get _baseUrl {
    final url = dotenv.env['OMR_SERVER_URL'];
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return 'http://192.168.1.14:5000';
  }

  // ─── Check if server is reachable ─────────────────────────────────────────
  // FIX: timeout raised from 4s → 60s to survive Render cold start (30-50s)
  Future<bool> isServerAlive() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(const Duration(seconds: 60)); // ← was 4, now 60
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Wake up the server silently before the user taps "Capture Sheet" ─────
  // Call this as soon as the answer key QR is scanned, so by the time
  // the user takes the photo the server is already warm.
  Future<void> warmUp() async {
    try {
      await http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(const Duration(seconds: 60));
    } catch (_) {
      // Ignore — this is just a best-effort wake-up call
    }
  }

  // ─── Main method: send photo → get answers ────────────────────────────────
  // FIX: timeout raised from 30s → 120s (Gemini Vision API call takes ~5-15s
  //      on top of the network round-trip to Render)
  Future<OmrResult?> scanSheet(File imageFile) async {
    final bytes       = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    try {
      final response = await http
          .post(
        Uri.parse('$_baseUrl/scan-omr'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'image': base64Image}),
      )
          .timeout(const Duration(seconds: 120)); // ← was 30, now 120

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['success'] != true) return null;

      return OmrResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}