import 'dart:js_interop';

extension type _JSStorage(JSObject _) implements JSObject {
  external JSString? getItem(String key);
  external void setItem(String key, String value);
}

@JS('localStorage')
external _JSStorage get _localStorage;

const _key = 'pokemon_caught';
const _shinyKey = 'pokemon_caught_shiny';
const _paletteKey = 'app_palette';
const _mathRoundsKey = 'math_rounds_completed';
const _clockRoundsKey = 'clock_rounds_completed';
const _dailyLimitEnabledKey = 'daily_limit_enabled';
const _dailyLimitCountKey = 'daily_limit_count';
const _todayDateKey = 'today_date_jst';
const _todayCaughtKey = 'today_caught_count';
const _drillSessionPrefix = 'today_sessions_';

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

  /// 選択中のパレットIDを読み込む
  static String? loadPaletteId() {
    try {
      final raw = _localStorage.getItem(_paletteKey)?.toDart ?? '';
      return raw.isEmpty ? null : raw;
    } catch (_) {
      return null;
    }
  }

  /// 選択中のパレットIDを保存する
  static void savePaletteId(String id) {
    try {
      _localStorage.setItem(_paletteKey, id);
    } catch (_) {}
  }

  // ─── 今日（JST）の統計 ─────────────────────────────────────────────────────

  static String _jstDateString() {
    final jst = DateTime.now().toUtc().add(const Duration(hours: 9));
    return '${jst.year}-${jst.month.toString().padLeft(2, '0')}-${jst.day.toString().padLeft(2, '0')}';
  }

  /// 日付が変わっていたら今日の統計をリセットする
  static void _resetTodayIfNeeded() {
    final today = _jstDateString();
    final stored = _localStorage.getItem(_todayDateKey)?.toDart ?? '';
    if (stored == today) return;
    _localStorage.setItem(_todayDateKey, today);
    _localStorage.setItem(_todayCaughtKey, '0');
    for (final drill in ['hiragana', 'math', 'clock', 'katakana_quiz', 'memory', 'sugoroku', 'battle']) {
      _localStorage.setItem('$_drillSessionPrefix$drill', '0');
    }
  }

  /// 今日ゲットしたポケモンの数を読み込む（日付リセットあり）
  static int loadTodayCaughtCount() {
    try {
      _resetTodayIfNeeded();
      final raw = _localStorage.getItem(_todayCaughtKey)?.toDart ?? '';
      return int.tryParse(raw) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 今日ゲットしたポケモン数を1増やす
  static void incrementTodayCaughtCount() {
    try {
      _resetTodayIfNeeded();
      final current =
          int.tryParse(_localStorage.getItem(_todayCaughtKey)?.toDart ?? '') ??
              0;
      _localStorage.setItem(_todayCaughtKey, '${current + 1}');
    } catch (_) {}
  }

  /// 今日の指定ドリルのセッション数を読み込む
  static int loadTodayDrillSessions(String drillKey) {
    try {
      _resetTodayIfNeeded();
      final raw =
          _localStorage.getItem('$_drillSessionPrefix$drillKey')?.toDart ?? '';
      return int.tryParse(raw) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 今日の指定ドリルのセッション数を1増やし、新しい値を返す
  static int incrementTodayDrillSessions(String drillKey) {
    try {
      _resetTodayIfNeeded();
      final current = int.tryParse(
              _localStorage
                  .getItem('$_drillSessionPrefix$drillKey')
                  ?.toDart ??
                  '') ??
          0;
      final next = current + 1;
      _localStorage.setItem('$_drillSessionPrefix$drillKey', '$next');
      // 週間サマリ用キーにも書く（日付付きなので翌日以降もデータが残る）
      final today = _jstDateString();
      _localStorage.setItem('ws_${drillKey}_$today', '$next');
      return next;
    } catch (_) {
      return 0;
    }
  }

  /// 過去7日分のドリルセッション数を返す（古い順、最後が今日）
  static List<(String, int)> loadWeekSummary(String drillKey) {
    try {
      final result = <(String, int)>[];
      final now = DateTime.now().toUtc().add(const Duration(hours: 9));
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final dateStr =
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        final label = '${day.month}/${day.day}';
        final raw =
            _localStorage.getItem('ws_${drillKey}_$dateStr')?.toDart ?? '';
        final count = int.tryParse(raw) ?? 0;
        result.add((label, count));
      }
      return result;
    } catch (_) {
      return [];
    }
  }

  // ─── さんすう・時計の累計 ──────────────────────────────────────────────────

  /// さんすうの累計完了ラウンド数を読み込む
  static int loadMathRoundsCompleted() {
    try {
      final raw = _localStorage.getItem(_mathRoundsKey)?.toDart ?? '';
      return int.tryParse(raw) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// さんすうの累計完了ラウンド数を保存する
  static void saveMathRoundsCompleted(int count) {
    try {
      _localStorage.setItem(_mathRoundsKey, '$count');
    } catch (_) {}
  }

  /// 時計の累計完了ラウンド数を読み込む
  static int loadClockRoundsCompleted() {
    try {
      final raw = _localStorage.getItem(_clockRoundsKey)?.toDart ?? '';
      return int.tryParse(raw) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 時計の累計完了ラウンド数を保存する
  static void saveClockRoundsCompleted(int count) {
    try {
      _localStorage.setItem(_clockRoundsKey, '$count');
    } catch (_) {}
  }

  // ─── 日次回数制限 ──────────────────────────────────────────────────────────

  static String _dailyKey(String mode) {
    final now = DateTime.now();
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'dp_${mode}_$date';
  }

  static bool loadDailyLimitEnabled() {
    try {
      final raw = _localStorage.getItem(_dailyLimitEnabledKey)?.toDart ?? '';
      return raw == 'true';
    } catch (_) {
      return false;
    }
  }

  static void saveDailyLimitEnabled(bool value) {
    try {
      _localStorage.setItem(_dailyLimitEnabledKey, value ? 'true' : 'false');
    } catch (_) {}
  }

  static int loadDailyLimitCount() {
    try {
      final raw = _localStorage.getItem(_dailyLimitCountKey)?.toDart ?? '';
      return int.tryParse(raw) ?? 3;
    } catch (_) {
      return 3;
    }
  }

  static void saveDailyLimitCount(int count) {
    try {
      _localStorage.setItem(_dailyLimitCountKey, '$count');
    } catch (_) {}
  }

  /// 今日の指定モードのプレイ回数を取得
  static int loadDailyPlays(String mode) {
    try {
      final raw = _localStorage.getItem(_dailyKey(mode))?.toDart ?? '';
      return int.tryParse(raw) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// 今日の指定モードのプレイ回数を1増やす
  static void incrementDailyPlays(String mode) {
    try {
      final current = loadDailyPlays(mode);
      _localStorage.setItem(_dailyKey(mode), '${current + 1}');
    } catch (_) {}
  }
}
