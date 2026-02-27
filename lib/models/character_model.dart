class HiraganaChar {
  final String char;
  final String romaji;
  final int strokeCount;

  const HiraganaChar({
    required this.char,
    required this.romaji,
    required this.strokeCount,
  });
}

class HiraganaRow {
  final String rowName;   // "あ", "か", etc.
  final String rowRomaji; // "a", "ka", etc.
  final List<HiraganaChar> chars;

  const HiraganaRow({
    required this.rowName,
    required this.rowRomaji,
    required this.chars,
  });
}
