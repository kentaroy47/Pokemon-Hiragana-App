import 'package:flutter/material.dart';

class PokemonEntry {
  final String katakana; // フシギダネ
  final String hiragana; // ふしぎだね
  final Color color;
  final int pokedexId; // 全国図鑑ナンバー

  const PokemonEntry({
    required this.katakana,
    required this.hiragana,
    required this.color,
    required this.pokedexId,
  });

  factory PokemonEntry.fromJson(Map<String, dynamic> json) {
    return PokemonEntry(
      katakana: json['katakana'] as String,
      hiragana: json['hiragana'] as String,
      color: Color(json['color'] as int),
      pokedexId: json['id'] as int,
    );
  }

  List<String> get chars => katakana.split('');
  List<String> get hiraganaChars => hiragana.split('');

  /// PokeAPI 公式アートワーク URL
  String get imageUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master'
      '/sprites/pokemon/other/official-artwork/$pokedexId.png';

  /// 色違いアートワーク URL
  String get shinyImageUrl =>
      'https://raw.githubusercontent.com/PokeAPI/sprites/master'
      '/sprites/pokemon/other/official-artwork/shiny/$pokedexId.png';
}

/// カタカナ1文字あたりのストローク数（濁音・半濁音・小文字・長音符含む）
const Map<String, int> _strokeCounts = {
  // ア行
  'ア': 2, 'イ': 2, 'ウ': 3, 'エ': 3, 'オ': 3,
  // カ行（清音）
  'カ': 2, 'キ': 3, 'ク': 2, 'ケ': 3, 'コ': 2,
  // カ行（濁音）゛=2画
  'ガ': 4, 'ギ': 5, 'グ': 4, 'ゲ': 5, 'ゴ': 4,
  // サ行（清音）
  'サ': 3, 'シ': 3, 'ス': 2, 'セ': 2, 'ソ': 2,
  // サ行（濁音）゛=2画
  'ザ': 5, 'ジ': 5, 'ズ': 4, 'ゼ': 4, 'ゾ': 4,
  // タ行（清音）
  'タ': 3, 'チ': 3, 'ツ': 3, 'テ': 3, 'ト': 2,
  // タ行（濁音）゛=2画
  'ダ': 5, 'ヂ': 5, 'ヅ': 5, 'デ': 5, 'ド': 4,
  // ナ行
  'ナ': 2, 'ニ': 2, 'ヌ': 2, 'ネ': 4, 'ノ': 1,
  // ハ行（清音）
  'ハ': 3, 'ヒ': 2, 'フ': 1, 'ヘ': 1, 'ホ': 4,
  // ハ行（濁音）゛=2画
  'バ': 5, 'ビ': 4, 'ブ': 3, 'ベ': 3, 'ボ': 6,
  // ハ行（半濁音）
  'パ': 4, 'ピ': 3, 'プ': 2, 'ペ': 2, 'ポ': 5,
  // マ行
  'マ': 2, 'ミ': 3, 'ム': 2, 'メ': 2, 'モ': 3,
  // ヤ行
  'ヤ': 3, 'ユ': 2, 'ヨ': 3,
  // ラ行
  'ラ': 2, 'リ': 2, 'ル': 2, 'レ': 1, 'ロ': 1,
  // ワ行
  'ワ': 2, 'ヲ': 3, 'ン': 2,
  // 小文字
  'ァ': 2, 'ィ': 2, 'ゥ': 3, 'ェ': 3, 'ォ': 3,
  'ャ': 3, 'ュ': 2, 'ョ': 3, 'ッ': 3,
  // 長音符
  'ー': 1,
};

int strokeCountFor(String char) => _strokeCounts[char] ?? 2;

/// ひらがな1文字あたりのストローク数
const Map<String, int> _hiraganaStrokeCounts = {
  // あ行
  'あ': 3, 'い': 2, 'う': 2, 'え': 2, 'お': 3,
  // か行（清音）
  'か': 3, 'き': 3, 'く': 1, 'け': 3, 'こ': 2,
  // か行（濁音）
  'が': 5, 'ぎ': 5, 'ぐ': 3, 'げ': 5, 'ご': 4,
  // さ行（清音）
  'さ': 3, 'し': 1, 'す': 2, 'せ': 3, 'そ': 2,
  // さ行（濁音）
  'ざ': 5, 'じ': 3, 'ず': 4, 'ぜ': 5, 'ぞ': 4,
  // た行（清音）
  'た': 4, 'ち': 2, 'つ': 1, 'て': 1, 'と': 2,
  // た行（濁音）
  'だ': 6, 'ぢ': 4, 'づ': 3, 'で': 3, 'ど': 4,
  // な行
  'な': 4, 'に': 3, 'ぬ': 2, 'ね': 2, 'の': 1,
  // は行（清音）
  'は': 3, 'ひ': 2, 'ふ': 4, 'へ': 1, 'ほ': 4,
  // は行（濁音）
  'ば': 5, 'び': 4, 'ぶ': 6, 'べ': 3, 'ぼ': 6,
  // は行（半濁音）
  'ぱ': 4, 'ぴ': 3, 'ぷ': 5, 'ぺ': 2, 'ぽ': 5,
  // ま行
  'ま': 3, 'み': 2, 'む': 3, 'め': 2, 'も': 3,
  // や行
  'や': 3, 'ゆ': 2, 'よ': 3,
  // ら行
  'ら': 2, 'り': 2, 'る': 2, 'れ': 2, 'ろ': 1,
  // わ行
  'わ': 2, 'を': 3, 'ん': 1,
  // 小文字
  'ぁ': 3, 'ぃ': 2, 'ぅ': 2, 'ぇ': 2, 'ぉ': 3,
  'ゃ': 3, 'ゅ': 2, 'ょ': 3, 'っ': 1,
  // 長音符
  'ー': 1,
};

int hiraganaStrokeCountFor(String char) => _hiraganaStrokeCounts[char] ?? 2;

