// lib/models/scanned_code.dart
// =====================================================
// CHANGES FROM ORIGINAL:
//   Added omrPart1 and omrPart2 fields to store
//   the detected bubble answers alongside the scan record.
//   These are saved in SharedPreferences as JSON strings.

import 'dart:convert';

class ScannedCode {
  final String id;
  final String type;
  final String value;
  final String title;
  final String dateTime;
  bool isFavorite;
  final String? studentName;
  final String? studentRegNo;

  // ── NEW: OMR bubble answers ──────────────────────────────────────────────
  // Map of "Q01" → "A" | "B" | "C" | "D" | "INVALID" | null
  final Map<String, String?>? omrPart1;
  final Map<String, String?>? omrPart2;

  ScannedCode({
    required this.id,
    required this.type,
    required this.value,
    required this.title,
    required this.dateTime,
    this.isFavorite = false,
    this.studentName,
    this.studentRegNo,
    this.omrPart1,   // new
    this.omrPart2,   // new
  });

  // Serialize to map for SharedPreferences storage
  Map<String, dynamic> toMap() => {
    'id'         : id,
    'type'       : type,
    'value'      : value,
    'title'      : title,
    'dateTime'   : dateTime,
    'isFavorite' : isFavorite ? 1 : 0,
    'studentName': studentName,
    'studentRegNo': studentRegNo,
    // Convert Map<String, String?> to JSON string for storage
    'omrPart1'   : omrPart1 != null ? jsonEncode(omrPart1) : null,
    'omrPart2'   : omrPart2 != null ? jsonEncode(omrPart2) : null,
  };

  // Deserialize from SharedPreferences map
  factory ScannedCode.fromMap(Map<String, dynamic> map) {
    // Helper to parse stored JSON string back to Map<String, String?>
    Map<String, String?>? parseOmr(dynamic raw) {
      if (raw == null) return null;
      try {
        final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
        return decoded.map((k, v) => MapEntry(k, v as String?));
      } catch (_) {
        return null;
      }
    }

    return ScannedCode(
      id          : map['id'],
      type        : map['type'],
      value       : map['value'],
      title       : map['title'],
      dateTime    : map['dateTime'],
      isFavorite  : map['isFavorite'] == 1,
      studentName : map['studentName'],
      studentRegNo: map['studentRegNo'],
      omrPart1    : parseOmr(map['omrPart1']),  // new
      omrPart2    : parseOmr(map['omrPart2']),  // new
    );
  }
}
