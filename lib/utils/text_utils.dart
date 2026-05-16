String normalizeTurkish(String text) {
  return text
      .toLowerCase()
      .replaceAll('i̇', 'i') // İ → Dart lowercases to i̇ (i + combining dot above)
      .replaceAll('â', 'a')
      .replaceAll('î', 'i')
      .replaceAll('û', 'u')
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c');
}

// Hyphens and apostrophes stripped (e.g. "Âl-i İmrân" → "ali imran",
// "En'âm" → "enam"). Filter is split into tokens so "al imran" still
// matches "Âl-i İmrân".
bool turkishContains(String item, String filter) {
  if (filter.isEmpty) return true;
  final sep = RegExp(r"[-'’‘ʼ]");
  String prep(String t) => normalizeTurkish(t).replaceAll(sep, '');
  final normItem = prep(item);
  final tokens = filter.trim().split(RegExp(r'\s+')).map(prep).where((t) => t.isNotEmpty);
  return tokens.every((token) => normItem.contains(token));
}
