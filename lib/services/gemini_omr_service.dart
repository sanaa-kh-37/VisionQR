import 'dart:convert';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiSheetResult {
  final String name;
  final String regNo;
  final String className; // printed header, e.g. "BSE-4A"
  final String subject;   // printed header, e.g. "Artificial Intelligence"
  final Map<String, String?> part1;
  final Map<String, String?> part2;
  GeminiSheetResult({
    required this.name,
    required this.regNo,
    required this.className,
    required this.subject,
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
      model: 'gemini-2.5-flash', // 2.0-flash retired (shutdown June 1, 2026)
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
You are a meticulous OMR (Optical Mark Recognition) and form-reading engine.
The image is ONE student's printed quiz answer sheet. Do THREE things and return
the result as STRICT JSON only (no commentary, no markdown).

==================== 1. PRINTED HEADER (typed text) ====================
Read these printed/typed fields from the top of the sheet:
  - "class":   the class/section, e.g. "BSE-4A". Use null only if absent.
  - "subject": the subject, e.g. "Artificial Intelligence". Use null only if absent.

==================== 2. HANDWRITTEN STUDENT DETAILS ====================
These are filled in BY HAND (often cursive). Transcribe them as best you can.
  - "name":  the student's full name written on the "Name" line.
  - "regNo": the registration / roll number on the "Registration #" line.
Rules for these two fields:
  - ALWAYS attempt a transcription, even if the handwriting is messy or cursive.
    Give your single best reading rather than refusing.
  - Use null ONLY if the line is genuinely EMPTY (nothing written at all).
  - For regNo keep the exact format including dashes, e.g. "FA24-BSE-037".
  - Never invent a value; transcribe only what is actually written.

==================== 3. OMR BUBBLES ====================
There are TWO answer blocks: Part-I (left) and Part-II (right).
Each block has 8 questions Q01..Q08, each with four option bubbles A, B, C, D.

Decide each question INDEPENDENTLY using this strict definition of "filled":
  - A bubble is FILLED only if its circle is clearly shaded/darkened by hand
    (the inside of the circle is mostly covered with dark ink or pencil).
  - A bubble that is an empty outline, or that only shows the printed letter
    (A / B / C / D), is NOT filled.
  - Faint smudges, stray dots, ticks outside the circle, or the printed letter
    itself do NOT count as filled.

Then map each question to EXACTLY one of:
  - "A" | "B" | "C" | "D"  -> if exactly ONE bubble in that row is clearly filled.
  - null                    -> if NO bubble in that row is clearly filled.
  - "INVALID"               -> if TWO OR MORE bubbles in that row are clearly filled.

CRITICAL RULE: Never guess a letter for a row that has no clearly darkened bubble.
If you are not confident a bubble is darkened, the row MUST be null. An empty /
unattempted row is null, NOT a letter. Do not pattern-match or assume a sequence.

==================== OUTPUT FORMAT (return EXACTLY this shape) ====================
{
  "class": "BSE-4A",
  "subject": "Artificial Intelligence",
  "name": "John Doe",
  "regNo": "FA24-BSE-037",
  "part1": {"Q01":"A","Q02":"B","Q03":null,"Q04":"C","Q05":"D","Q06":"A","Q07":"INVALID","Q08":"B"},
  "part2": {"Q01":"C","Q02":"D","Q03":null,"Q04":"A","Q05":"C","Q06":"B","Q07":"C","Q08":"B"}
}
""";

    final response = await _model.generateContent([
      Content.multi([TextPart(prompt), DataPart('image/jpeg', bytes)])
    ]);

    final text = response.text?.trim() ?? '';
    // ignore: avoid_print
    print("🔍 Gemini Raw Response: $text");

    if (text.isEmpty) {
      throw Exception("Gemini returned an empty response");
    }

    final jsonStr = text.startsWith('{')
        ? text
        : (RegExp(r'\{[\s\S]*\}').firstMatch(text)?.group(0) ?? '');
    if (jsonStr.isEmpty) throw Exception("No JSON found in Gemini response");

    final data = jsonDecode(jsonStr) as Map<String, dynamic>;

    // Bubbles: keep blanks as a real null. Normalise letters to uppercase and
    // convert any stray "null"/"-"/"" the model emits back into null so a blank
    // row can NEVER show up as a phantom letter.
    Map<String, String?> toAnswers(dynamic raw) {
      if (raw is! Map) return {};
      return raw.map((k, v) {
        final s = v?.toString().trim().toUpperCase();
        if (s == null || s.isEmpty || s == 'NULL' || s == '-' || s == '—') {
          return MapEntry(k.toString(), null);
        }
        return MapEntry(k.toString(), s); // "A".."D" or "INVALID"
      });
    }

    String clean(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return (s.isEmpty || s.toLowerCase() == 'null') ? 'Not Detected' : s;
    }

    return GeminiSheetResult(
      name: clean(data['name']),
      regNo: clean(data['regNo']),
      className: clean(data['class']),
      subject: clean(data['subject']),
      part1: toAnswers(data['part1']),
      part2: toAnswers(data['part2']),
    );
  }
}