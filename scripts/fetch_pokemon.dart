/// PokeAPI から全ポケモン（species）の日本語名・色を取得して
/// assets/data/pokemon_all.json を生成するワンショットスクリプト。
///
/// 実行方法（プロジェクトルートから）:
///   dart run scripts/fetch_pokemon.dart
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

// PokeAPI の color 文字列 → Flutter Color の hex 値マッピング
const _colorHex = {
  'black':  0xFF212121,
  'blue':   0xFF1565C0,
  'brown':  0xFF795548,
  'gray':   0xFF9E9E9E,
  'green':  0xFF4CAF50,
  'pink':   0xFFF48FB1,
  'purple': 0xFF7B1FA2,
  'red':    0xFFE53935,
  'white':  0xFFEEEEEE,
  'yellow': 0xFFFFD54F,
};

Future<String?> _get(String url) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'hiragana-app-fetch-script/1.0');
    final res = await req.close();
    if (res.statusCode != 200) {
      stderr.writeln('HTTP ${res.statusCode}: $url');
      return null;
    }
    return await res.transform(utf8.decoder).join();
  } catch (e) {
    stderr.writeln('Error fetching $url: $e');
    return null;
  } finally {
    client.close();
  }
}

/// カタカナ → ひらがな変換（ァ〜ヶ のみ、それ以外はそのまま）
String _toHiragana(String text) {
  return String.fromCharCodes(text.runes.map((r) {
    if (r >= 0x30A1 && r <= 0x30F6) return r - 0x60;
    return r;
  }));
}

Future<Map<String, dynamic>?> _fetchSpecies(String url) async {
  final raw = await _get(url);
  if (raw == null) return null;

  final data = jsonDecode(raw) as Map<String, dynamic>;
  final id = data['id'] as int;

  final names = (data['names'] as List);
  final jaEntry = names.cast<Map>().firstWhere(
    (n) => n['language']['name'] == 'ja-hrkt',
    orElse: () => <String, dynamic>{},
  );
  if (jaEntry.isEmpty) {
    stderr.writeln('No ja-Hrkt name for species $id');
    return null;
  }

  final katakana = jaEntry['name'] as String;
  final hiragana = _toHiragana(katakana);
  final colorName = (data['color'] as Map)['name'] as String;
  final colorValue = _colorHex[colorName] ?? 0xFF9E9E9E;

  return {
    'id': id,
    'katakana': katakana,
    'hiragana': hiragana,
    'color': colorValue,
  };
}

void main() async {
  // 1. 全 species リストを取得
  stdout.writeln('Fetching species list from PokeAPI...');
  final listRaw = await _get(
      'https://pokeapi.co/api/v2/pokemon-species?limit=2000');
  if (listRaw == null) {
    stderr.writeln('Failed to fetch species list.');
    exit(1);
  }

  final listData = jsonDecode(listRaw) as Map<String, dynamic>;
  final speciesList = (listData['results'] as List)
      .cast<Map<String, dynamic>>();
  stdout.writeln('Total species: ${speciesList.length}');

  // 2. 各 species を並列バッチ（20件ずつ）でフェッチ
  final results = <Map<String, dynamic>>[];
  const batchSize = 20;

  for (var i = 0; i < speciesList.length; i += batchSize) {
    final batch = speciesList.sublist(
        i, min(i + batchSize, speciesList.length));

    final futures = batch
        .map((s) => _fetchSpecies(s['url'] as String))
        .toList();
    final batchResults = await Future.wait(futures);

    for (final r in batchResults) {
      if (r != null) results.add(r);
    }

    // IDでソート
    results.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    stdout.writeln(
        '  ${min(i + batchSize, speciesList.length)}/${speciesList.length} done');

    // API への負荷軽減
    if (i + batchSize < speciesList.length) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  // 3. JSON ファイルに保存
  final outDir = Directory('assets/data');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);

  final encoder = JsonEncoder.withIndent(null); // compact JSON
  await File('assets/data/pokemon_all.json')
      .writeAsString(encoder.convert(results));

  stdout.writeln('');
  stdout.writeln('Done! ${results.length} pokemon saved to assets/data/pokemon_all.json');
}
