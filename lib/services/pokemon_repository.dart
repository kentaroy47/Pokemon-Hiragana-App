import 'dart:convert';
import 'package:flutter/services.dart';
import '../data/pokemon_data.dart';
import '../data/pokemon_fallback_data.dart';

/// assets/data/pokemon_all.json から全ポケモンを読み込むリポジトリ。
/// main() で init() を呼ぶことで起動時にロードし、以降は同期アクセス可能。
class PokemonRepository {
  static List<PokemonEntry> _all = pokemonList; // フォールバック: ハードコード200匹

  /// アセットから全ポケモンを読み込む（アプリ起動時に一度だけ呼ぶ）
  static Future<void> init() async {
    try {
      final raw =
          await rootBundle.loadString('assets/data/pokemon_all.json');
      final list = (jsonDecode(raw) as List)
          .map((e) => PokemonEntry.fromJson(e as Map<String, dynamic>))
          .toList();
      if (list.isNotEmpty) _all = list;
    } catch (_) {
      // 読み込み失敗時はハードコードリストを使い続ける
    }
  }

  /// 全ポケモンのリスト（init() 後は JSON 由来の1007匹）
  static List<PokemonEntry> get all => _all;
}
