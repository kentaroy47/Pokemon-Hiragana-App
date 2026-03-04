import 'dart:js_interop';

extension type _JSStorage(JSObject _) implements JSObject {
  external JSString? getItem(String key);
  external void setItem(String key, String value);
}

@JS('localStorage')
external _JSStorage get _localStorage;

const _key = 'pokemon_caught';
const _shinyKey = 'pokemon_caught_shiny';

/// ブラウザの localStorage を使ったデータ永続化サービス
class StorageService {
  /// ゲット済みポケモンのカタカナ名リスト（重複あり）を読み込む
  static List<String> loadCaughtNames() {
    try {
      final raw = _localStorage.getItem(_key)?.toDart ?? '';
      if (raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// ゲット済みポケモンのカタカナ名リストを保存する
  static void saveCaughtNames(List<String> names) {
    try {
      _localStorage.setItem(_key, names.join(','));
    } catch (_) {}
  }

  /// 色違いをゲット済みのカタカナ名セットを読み込む
  static Set<String> loadShinyCaughtNames() {
    try {
      final raw = _localStorage.getItem(_shinyKey)?.toDart ?? '';
      if (raw.isEmpty) return {};
      return raw.split(',').where((s) => s.isNotEmpty).toSet();
    } catch (_) {
      return {};
    }
  }

  /// 色違いをゲット済みのカタカナ名セットを保存する
  static void saveShinyCaughtNames(Set<String> names) {
    try {
      _localStorage.setItem(_shinyKey, names.join(','));
    } catch (_) {}
  }
}
