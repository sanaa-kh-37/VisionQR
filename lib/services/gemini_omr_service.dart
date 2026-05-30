import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiSheetResult {
  final String name;
  final String regNo;
  final Map<String, String?> part1;
  final Map<String, String?> part2;
  GeminiSheetResult({
    required this.name,
    required this.regNo,
    required this.part1,
    required this.part2,
  });
}

class GeminiOmrService {
  late final GenerativeModel _model;

  GeminiOmrService() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("GEMINI_API_KEY not found!");
    }
    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // 2.0-flash is retired (shutdown June 1, 2026)
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // forces clean JSON, no ``` fences
        temperature: 0.0,                     // deterministic reading
      ),
    );
  }

  Future<GeminiSheetResult> processSheet(File imageFile) async {
    final bytes = await imageFile.readAsBytes();

    final prompt = """
You are an expert exam-sheet reader. The image is a student's quiz answer sheet.

Do TWO things:

1. Read the HANDWRITTEN student details at the top:
   - "name": the student's full name. If genuinely unreadable, use null.
   - "regNo": the registration / roll number. If genuinely unreadable, use null.

2. Read the OMR bubbles. Two parts (Part-I left, Part-II right),
   each with 8 questions Q01..Q08, each with options A, B, C, D.
   - Exactly one bubble filled -> that letter.
   - None filled -> null.
   - More than one filled -> "INVALID".

Return ONLY valid JSON in EXACTLY this shape, nothing else:
{
  "name": "John Doe",
  "regNo": "FA24-BSE-037",
  "part1": {"Q01":"A","Q02":"B","Q03":null,"Q04":"C","Q05":"D","Q06":"A","Q07":"INVALID","Q08":"B"},
  "part2": {"Q01":"C","Q02":"D","Q03":"D","Q04":"A","Q05":"C","Q06":"B","Q07":"C","Q08":"B"}
}
""";

    final response = await _model.generateContent([
      Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])
    ]);

    final text = response.text?.trim() ?? '';
    print("🔍 Gemini Raw Response: $text");

    if (text.isEmpty) {
      throw Exception("Gemini returned an empty response");
    }

    // responseMimeType=json means this is already pure JSON;
    // keep a brace-extraction fallback just in case.
    final jsonStr = text.startsWith('{')
        ? text
        : (RegExp(r'\{[\s\S]*\}').firstMatch(text)?.group(0) ?? '');
    if (jsonStr.isEmpty) throw Exception("No JSON found in Gemini response");

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    Map<String, String?> toAnswers(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) => MapEntry(k.toString(), v?.toString()));
    }

    String clean(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? 'Not Detected' : s;
    }

    return GeminiSheetResult(
      name: clean(data['name']),
      regNo: clean(data['regNo']),
      part1: toAnswers(data['part1']),
      part2: toAnswers(data['part2']),
    );
  }
}