class AnswerKey {
  final String quizTitle;
  final String setInfo;
  final Map<String, String> part1; // Q01 -> "D", etc.
  final Map<String, String> part2;

  AnswerKey({
    required this.quizTitle,
    required this.setInfo,
    required this.part1,
    required this.part2,
  });

  factory AnswerKey.fromPayload(String payload) {
    try {
      // Example: "AI Quiz SP2026 Set-C | Part-I: Q1=D Q2=A ... | Part-II: ..."
      final parts = payload.split('|').map((e) => e.trim()).toList();

      String quizTitle = parts[0];
      String setInfo = "";

      if (quizTitle.contains("Set-")) {
        setInfo = quizTitle.split("Set-").last.split(" ").first;
        quizTitle = quizTitle.split("|")[0].trim();
      }

      Map<String, String> part1 = {};
      Map<String, String> part2 = {};

      for (var part in parts) {
        if (part.contains("Part-I:")) {
          part1 = _parseAnswers(part.replaceAll("Part-I:", "").trim());
        } else if (part.contains("Part-II:")) {
          part2 = _parseAnswers(part.replaceAll("Part-II:", "").trim());
        }
      }

      return AnswerKey(
        quizTitle: quizTitle,
        setInfo: setInfo,
        part1: part1,
        part2: part2,
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