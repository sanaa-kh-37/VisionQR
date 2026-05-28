// lib/services/omr_service.dart
// =====================================================
// This file is the Flutter side of the OMR system.
// It sends the bubble sheet photo to the Python server
// and returns structured answers back to scanner_screen.dart
//
// HOW IT WORKS:
//   1. Flutter takes a photo (File object)
//   2. We convert the photo to base64 (text)
//   3. We POST that text to our Python server
//   4. Server responds with JSON answers
//   5. We parse the JSON into OmrResult object
//   6. scanner_screen.dart uses OmrResult to grade the quiz

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ─── Data model for the result ────────────────────────────────────────────────
class OmrResult {
  // part1 maps "Q01" → "A" | "B" | "C" | "D" | "INVALID" | null
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

  // Parse the JSON response from Python server into this object
  factory OmrResult.fromJson(Map<String, dynamic> json) {
    // Helper: convert raw JSON map to Map<String, String?>
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

  // How many questions were answered (not null, not INVALID)
  int get totalAnswered =>
      [...part1.values, ...part2.values]
          .where((v) => v != null && v != 'INVALID')
          .length;

  // How many were flagged as invalid (multiple bubbles)
  int get totalInvalid =>
      [...part1.values, ...part2.values]
          .where((v) => v == 'INVALID')
          .length;
}

// ─── The service class ────────────────────────────────────────────────────────
class OmrService {
  // Read server URL from .env file
  // Add this line to your .env:   OMR_SERVER_URL=http://192.168.x.x:5000
  //
  // IMPORTANT: Use your PC's local IP address, NOT localhost
  // On Windows: run "ipconfig" in cmd → look for IPv4 Address
  // On Mac/Linux: run "ifconfig" → look for inet address
  // Example: OMR_SERVER_URL=http://192.168.1.105:5000
  static String get _baseUrl =>
      dotenv.env['OMR_SERVER_URL'] ?? 'http://192.168.1.14:5000';

  // ─── Check if server is reachable ──────────────────────────────────────────
  // Call this before scanning to show a friendly error if server is offline
  Future<bool> isServerAlive() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/ping'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Main method: send photo → get answers ─────────────────────────────────
  Future<OmrResult?> scanSheet(File imageFile) async {
    // Step 1: Read image bytes from disk
    final bytes = await imageFile.readAsBytes();

    // Step 2: Convert bytes to base64 string
    // Base64 turns binary data into safe text that can go in JSON
    // Example: [255, 216, 255] → "/9j/..."
    final base64Image = base64Encode(bytes);

    // Step 3: Send POST request to Python server
    final response = await http
        .post(
      Uri.parse('$_baseUrl/scan-omr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image': base64Image}),
    )
        .timeout(const Duration(seconds: 30));
    // 30 seconds is plenty — OpenCV is fast (~2-3 seconds per image)

    // Step 4: Parse response
    if (response.statusCode != 200) {
      // Server returned an error
      return null;
    }

    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Check if server reported success
      if (data['success'] != true) {
        return null;
      }

      return OmrResult.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
