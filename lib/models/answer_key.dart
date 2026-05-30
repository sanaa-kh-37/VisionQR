class AnswerKey {
  final String quizTitle;
  final String setInfo;
  final Map<String, String> part1; // Q01 -> "D", etc.
  final Map<String, String> part2;

  /// Marks awarded per correct answer (default 1).
  final double marksPerCorrect;

  /// Penalty subtracted per wrong answer (default 0 = no negative marking).
  final double negativePerWrong;

  AnswerKey({
    required this.quizTitle,
    required this.setInfo,
    required this.part1,
    required this.part2,
    this.marksPerCorrect = 1.0,
    this.negativePerWrong = 0.0,
  });

  bool get hasNegativeMarking => negativePerWrong > 0;

  /// Expected QR payload (negative-marking / marks segments are OPTIONAL):
  ///   "AI Quiz SP2026 Set-C | Part-I: Q1=D Q2=A ... | Part-II: ... | Neg: 0.25 | Marks per: 1"
  factory AnswerKey.fromPayload(String payload) {
    try {
      final parts = payload.split('|').map((e) => e.trim()).toList();

      String quizTitle = parts[0];
      String setInfo = "";

      if (quizTitle.contains("Set-")) {
        setInfo = quizTitle.split("Set-").last.split(" ").first;
        quizTitle = quizTitle.split("|")[0].trim();
      }

      Map<String, String> part1 = {};
      Map<String, String> part2 = {};
      double marksPerCorrect = 1.0;
      double negativePerWrong = 0.0;

      for (var part in parts) {
        final lower = part.toLowerCase();

        if (lower.contains("part-i:") && !lower.contains("part-ii:")) {
          part1 = _parseAnswers(
              part.replaceAll(RegExp('part-i:', caseSensitive: false), "").trim());
        } else if (lower.contains("part-ii:")) {
          part2 = _parseAnswers(
              part.replaceAll(RegExp('part-ii:', caseSensitive: false), "").trim());
        } else if (lower.contains("neg")) {
          // e.g. "Neg: 0.25" or "Negative -0.25"
          final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(part);
          if (m != null) negativePerWrong = double.tryParse(m.group(1)!) ?? 0.0;
        } else if (lower.contains("mark") &&
            (lower.contains("per") || lower.contains("each") || lower.contains("/q"))) {
          // e.g. "Marks per: 2"  (NOT "Total Marks: 16")
          final m = RegExp(r'(\d+(\.\d+)?)').firstMatch(part);
          if (m != null) marksPerCorrect = double.tryParse(m.group(1)!) ?? 1.0;
        }
      }

      return AnswerKey(
        quizTitle: quizTitle,
        setInfo: setInfo,
        part1: part1,
        part2: part2,
        marksPerCorrect: marksPerCorrect,
        negativePerWrong: negativePerWrong,
      );
    } catch (e) {
      return AnswerKey(
        quizTitle: "Unknown Quiz",
        setInfo: "",
        part1: {},
        part2: {},
      );
    }
  }

  static Map<String, String> _parseAnswers(String text) {
    final map = <String, String>{};
    final answers = text.split(' ');
    for (var ans in answers) {
      if (ans.contains('=')) {
        final kv = ans.split('=');
        if (kv.length == 2) {
          map[kv[0].trim()] = kv[1].trim();
        }
      }
    }
    return map;
  }
}