class KanjiEntry {
  final String kanji;
  final String reading;
  final int strokeCount;

  const KanjiEntry({
    required this.kanji,
    required this.reading,
    required this.strokeCount,
  });
}

// 小学1年生で学ぶ漢字（79字）
const List<KanjiEntry> kanjiList1 = [
  // 数
  KanjiEntry(kanji: '一', reading: 'いち', strokeCount: 1),
  KanjiEntry(kanji: '二', reading: 'に', strokeCount: 2),
  KanjiEntry(kanji: '三', reading: 'さん', strokeCount: 3),
  KanjiEntry(kanji: '四', reading: 'し', strokeCount: 5),
  KanjiEntry(kanji: '五', reading: 'ご', strokeCount: 4),
  KanjiEntry(kanji: '六', reading: 'ろく', strokeCount: 4),
  KanjiEntry(kanji: '七', reading: 'しち', strokeCount: 2),
  KanjiEntry(kanji: '八', reading: 'はち', strokeCount: 2),
  KanjiEntry(kanji: '九', reading: 'きゅう', strokeCount: 2),
  KanjiEntry(kanji: '十', reading: 'じゅう', strokeCount: 2),
  KanjiEntry(kanji: '百', reading: 'ひゃく', strokeCount: 6),
  KanjiEntry(kanji: '千', reading: 'せん', strokeCount: 3),
  // 自然・天体
  KanjiEntry(kanji: '山', reading: 'やま', strokeCount: 3),
  KanjiEntry(kanji: '川', reading: 'かわ', strokeCount: 3),
  KanjiEntry(kanji: '田', reading: 'た', strokeCount: 5),
  KanjiEntry(kanji: '土', reading: 'つち', strokeCount: 3),
  KanjiEntry(kanji: '日', reading: 'にち', strokeCount: 4),
  KanjiEntry(kanji: '月', reading: 'つき', strokeCount: 4),
  KanjiEntry(kanji: '火', reading: 'ひ', strokeCount: 4),
  KanjiEntry(kanji: '水', reading: 'みず', strokeCount: 4),
  KanjiEntry(kanji: '木', reading: 'き', strokeCount: 4),
  KanjiEntry(kanji: '金', reading: 'きん', strokeCount: 8),
  KanjiEntry(kanji: '空', reading: 'そら', strokeCount: 8),
  KanjiEntry(kanji: '雨', reading: 'あめ', strokeCount: 8),
  KanjiEntry(kanji: '石', reading: 'いし', strokeCount: 5),
  // 植物
  KanjiEntry(kanji: '花', reading: 'はな', strokeCount: 7),
  KanjiEntry(kanji: '草', reading: 'くさ', strokeCount: 9),
  KanjiEntry(kanji: '竹', reading: 'たけ', strokeCount: 6),
  KanjiEntry(kanji: '林', reading: 'はやし', strokeCount: 8),
  KanjiEntry(kanji: '森', reading: 'もり', strokeCount: 12),
  // 動物・生き物
  KanjiEntry(kanji: '犬', reading: 'いぬ', strokeCount: 4),
  KanjiEntry(kanji: '虫', reading: 'むし', strokeCount: 6),
  KanjiEntry(kanji: '貝', reading: 'かい', strokeCount: 7),
  // からだ
  KanjiEntry(kanji: '手', reading: 'て', strokeCount: 4),
  KanjiEntry(kanji: '足', reading: 'あし', strokeCount: 7),
  KanjiEntry(kanji: '目', reading: 'め', strokeCount: 5),
  KanjiEntry(kanji: '耳', reading: 'みみ', strokeCount: 6),
  KanjiEntry(kanji: '口', reading: 'くち', strokeCount: 3),
  // 人
  KanjiEntry(kanji: '人', reading: 'ひと', strokeCount: 2),
  KanjiEntry(kanji: '女', reading: 'おんな', strokeCount: 3),
  KanjiEntry(kanji: '子', reading: 'こ', strokeCount: 3),
  KanjiEntry(kanji: '男', reading: 'おとこ', strokeCount: 7),
  // 方向・場所
  KanjiEntry(kanji: '上', reading: 'うえ', strokeCount: 3),
  KanjiEntry(kanji: '下', reading: 'した', strokeCount: 3),
  KanjiEntry(kanji: '左', reading: 'ひだり', strokeCount: 5),
  KanjiEntry(kanji: '右', reading: 'みぎ', strokeCount: 5),
  KanjiEntry(kanji: '中', reading: 'なか', strokeCount: 4),
  // 色
  KanjiEntry(kanji: '赤', reading: 'あか', strokeCount: 7),
  KanjiEntry(kanji: '青', reading: 'あお', strokeCount: 8),
  KanjiEntry(kanji: '白', reading: 'しろ', strokeCount: 5),
  // 学校
  KanjiEntry(kanji: '学', reading: 'がく', strokeCount: 8),
  KanjiEntry(kanji: '校', reading: 'こう', strokeCount: 10),
  KanjiEntry(kanji: '字', reading: 'じ', strokeCount: 6),
  KanjiEntry(kanji: '文', reading: 'ぶん', strokeCount: 4),
  KanjiEntry(kanji: '本', reading: 'ほん', strokeCount: 5),
  // その他
  KanjiEntry(kanji: '円', reading: 'えん', strokeCount: 4),
  KanjiEntry(kanji: '王', reading: 'おう', strokeCount: 4),
  KanjiEntry(kanji: '音', reading: 'おと', strokeCount: 9),
  KanjiEntry(kanji: '気', reading: 'き', strokeCount: 6),
  KanjiEntry(kanji: '休', reading: 'やすむ', strokeCount: 6),
  KanjiEntry(kanji: '玉', reading: 'たま', strokeCount: 5),
  KanjiEntry(kanji: '見', reading: 'みる', strokeCount: 7),
  KanjiEntry(kanji: '糸', reading: 'いと', strokeCount: 6),
  KanjiEntry(kanji: '車', reading: 'くるま', strokeCount: 7),
  KanjiEntry(kanji: '出', reading: 'でる', strokeCount: 5),
  KanjiEntry(kanji: '小', reading: 'ちいさい', strokeCount: 3),
  KanjiEntry(kanji: '正', reading: 'ただしい', strokeCount: 5),
  KanjiEntry(kanji: '生', reading: 'いきる', strokeCount: 5),
  KanjiEntry(kanji: '先', reading: 'さき', strokeCount: 6),
  KanjiEntry(kanji: '早', reading: 'はやい', strokeCount: 6),
  KanjiEntry(kanji: '大', reading: 'だい', strokeCount: 3),
  KanjiEntry(kanji: '天', reading: 'てん', strokeCount: 4),
  KanjiEntry(kanji: '入', reading: 'はいる', strokeCount: 2),
  KanjiEntry(kanji: '年', reading: 'とし', strokeCount: 6),
  KanjiEntry(kanji: '名', reading: 'なまえ', strokeCount: 6),
  KanjiEntry(kanji: '立', reading: 'たつ', strokeCount: 5),
  KanjiEntry(kanji: '力', reading: 'ちから', strokeCount: 2),
  KanjiEntry(kanji: '町', reading: 'まち', strokeCount: 7),
  KanjiEntry(kanji: '村', reading: 'むら', strokeCount: 7),
];
