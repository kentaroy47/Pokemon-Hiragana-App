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
const _todayCaughtNamesKey = 'today_caught_names_list';
const _battleRewardVisibleKey = 'battle_reward_visible';
const _showKokugoEasyKey = 'show_kokugo_easy';
const _showKatakanaYomouKey = 'show_katakana_yomou';
const _streakCountKey = 'streak_count';
const _streakLastDateKey = 'streak_last_date';

/// 1日の色違いボーナス枠（最初のN回だけ色違い率アップ）
const _shinyBonusCap = 2;

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

  static String _jstDateString() => _jstDateOffset(0);

  /// 今日（JST）から days 日ずらした日付文字列を返す（days=-1 で昨日）
  static String _jstDateOffset(int days) {
    final jst = DateTime.now()
        .toUtc()
        .add(const Duration(hours: 9))
        .add(Duration(days: days));
    return '${jst.year}-${jst.month.toString().padLeft(2, '0')}-${jst.day.toString().padLeft(2, '0')}';
  }

  /// 日付が変わっていたら今日の統計をリセットする
  static void _resetTodayIfNeeded() {
    final today = _jstDateString();
    final stored = _localStorage.getItem(_todayDateKey)?.toDart ?? '';
    if (stored == today) return;
    _localStorage.setItem(_todayDateKey, today);
    _localStorage.setItem(_todayCaughtKey, '0');
    _localStorage.setItem(_todayCaughtNamesKey, '');
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

  /// 今日ゲットしたポケモンのカタカナ名リストを読み込む
  static List<String> loadTodayCaughtNamesList() {
    try {
      _resetTodayIfNeeded();
      final raw = _localStorage.getItem(_todayCaughtNamesKey)?.toDart ?? '';
      if (raw.isEmpty) return [];
      return raw.split(',').where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  /// 今日ゲットしたポケモン名を追加する
  static void addTodayCaughtName(String katakana) {
    try {
      _resetTodayIfNeeded();
      final existing = _localStorage.getItem(_todayCaughtNamesKey)?.toDart ?? '';
      final next = existing.isEmpty ? katakana : '$existing,$katakana';
      _localStorage.setItem(_todayCaughtNamesKey, next);
    } catch (_) {}
  }

  // ─── バトル設定 ───────────────────────────────────────────────────────────────

  static bool loadBattleRewardVisible() {
    try {
      final raw = _localStorage.getItem(_battleRewardVisibleKey)?.toDart;
      if (raw == null) return true;
      return raw == 'true';
    } catch (_) { return true; }
  }

  static void saveBattleRewardVisible(bool value) {
    try {
      _localStorage.setItem(_battleRewardVisibleKey, '$value');
    } catch (_) {}
  }

  // ─── ホーム画面表示設定 ───────────────────────────────────────────────────────

  static bool loadShowKokugoEasy() {
    try {
      final raw = _localStorage.getItem(_showKokugoEasyKey)?.toDart;
      if (raw == null) return false;
      return raw == 'true';
    } catch (_) { return false; }
  }

  static void saveShowKokugoEasy(bool value) {
    try { _localStorage.setItem(_showKokugoEasyKey, '$value'); } catch (_) {}
  }

  static bool loadShowKatakanaYomou() {
    try {
      final raw = _localStorage.getItem(_showKatakanaYomouKey)?.toDart;
      if (raw == null) return false;
      return raw == 'true';
    } catch (_) { return false; }
  }

  static void saveShowKatakanaYomou(bool value) {
    try { _localStorage.setItem(_showKatakanaYomouKey, '$value'); } catch (_) {}
  }

  /// 今日の指定モードのプレイ回数を1増やす
  static void incrementDailyPlays(String mode) {
    try {
      final current = loadDailyPlays(mode);
      _localStorage.setItem(_dailyKey(mode), '${current + 1}');
    } catch (_) {}
  }

  // ─── れんぞくプレイ（ストリーク） ─────────────────────────────────────────────

  /// 現在のストリーク日数を読み込む（表示用）。
  /// 最後のプレイが今日か昨日なら継続中、それより前なら途切れたとみなし0を返す。
  static int loadStreakCount() {
    try {
      final last = _localStorage.getItem(_streakLastDateKey)?.toDart ?? '';
      if (last.isEmpty) return 0;
      final count =
          int.tryParse(_localStorage.getItem(_streakCountKey)?.toDart ?? '') ??
              0;
      if (last == _jstDateString() || last == _jstDateOffset(-1)) return count;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// プレイ完了時に呼ぶ。ストリークを更新して新しい日数を返す。
  /// 同日2回目以降は据え置き、昨日プレイ済みなら+1、途切れていたら1にリセット。
  static int recordPlayStreak() {
    try {
      final today = _jstDateString();
      final last = _localStorage.getItem(_streakLastDateKey)?.toDart ?? '';
      int count =
          int.tryParse(_localStorage.getItem(_streakCountKey)?.toDart ?? '') ??
              0;
      if (last == today) return count;
      count = (last == _jstDateOffset(-1)) ? count + 1 : 1;
      _localStorage.setItem(_streakCountKey, '$count');
      _localStorage.setItem(_streakLastDateKey, today);
      return count;
    } catch (_) {
      return 0;
    }
  }

  // ─── 色違いデイリーボーナス ───────────────────────────────────────────────────

  /// 今日まだ残っている色違いボーナス枠の数（バッジ表示用）
  static int shinyBonusRemaining() {
    try {
      final used =
          int.tryParse(_localStorage.getItem('sb_used_${_jstDateString()}')?.toDart ?? '') ??
              0;
      final remain = _shinyBonusCap - used;
      return remain < 0 ? 0 : remain;
    } catch (_) {
      return 0;
    }
  }

  /// ボーナス枠が残っていれば1消費して true（=色違い率アップ対象）を返す。
  static bool useShinyBonusDraw() {
    try {
      final key = 'sb_used_${_jstDateString()}';
      final used = int.tryParse(_localStorage.getItem(key)?.toDart ?? '') ?? 0;
      if (used >= _shinyBonusCap) return false;
      _localStorage.setItem(key, '${used + 1}');
      return true;
    } catch (_) {
      return false;
    }
  }
}
