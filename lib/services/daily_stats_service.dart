import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// 今日（JST）の学習統計を管理する。
/// Notifier 系はホーム画面でリアルタイム表示に使用する。
class DailyStatsService {
  static final todayCaughtNotifier = ValueNotifier<int>(0);

  /// れんぞくプレイ日数（ホームの👑バッジ用）
  static final streakNotifier = ValueNotifier<int>(0);

  /// 今日残っている色違いボーナス枠（ホームの✨バッジ用）
  static final shinyBonusNotifier = ValueNotifier<int>(0);

  static const _drillKeys = ['hiragana', 'math', 'clock', 'katakana_quiz', 'memory', 'sugoroku', 'battle', 'kanji_write', 'kanji_read', 'pokemon_catch'];

  static final _drillNotifiers = <String, ValueNotifier<int>>{
    for (final k in _drillKeys) k: ValueNotifier(0),
  };

  /// 指定ドリルの今日のセッション数 Notifier を返す
  static ValueNotifier<int> drillNotifier(String drillKey) =>
      _drillNotifiers[drillKey] ?? ValueNotifier(0);

  /// アプリ起動時にストレージから値を復元する
  static void init() {
    todayCaughtNotifier.value = StorageService.loadTodayCaughtCount();
    streakNotifier.value = StorageService.loadStreakCount();
    shinyBonusNotifier.value = StorageService.shinyBonusRemaining();
    for (final k in _drillKeys) {
      _drillNotifiers[k]!.value = StorageService.loadTodayDrillSessions(k);
    }
  }

  /// プレイ完了時に呼ぶ。ストリークを更新し、ホームのバッジへ反映する。
  static void recordStreak() {
    streakNotifier.value = StorageService.recordPlayStreak();
  }

  /// 報酬抽選1回分。今日がボーナスデーなら true（色違い率アップ）を返す。
  /// バッジは消費せず、一日中表示されたまま。
  static bool consumeShinyBonus() => StorageService.useShinyBonusDraw();

  /// ポケモンをゲットしたときに呼ぶ（ストレージ保存 + 通知）
  static void incrementCaught() {
    StorageService.incrementTodayCaughtCount();
    todayCaughtNotifier.value = todayCaughtNotifier.value + 1;
  }

  /// ドリルのセッションを1増やし、新しいセッション数を返す
  static int incrementDrillSessions(String drillKey) {
    final next = StorageService.incrementTodayDrillSessions(drillKey);
    _drillNotifiers[drillKey]?.value = next;
    return next;
  }

  /// 指定ドリル以外のドリル名をランダムに1つ返す
  static String pickSuggestion(String drillKey) {
    const others = {
      'hiragana': ['さんすう', '時計（とけい）', 'カタカナ'],
      'math': ['ひらがな', '時計（とけい）', 'カタカナ'],
      'clock': ['さんすう', 'ひらがな', 'カタカナ'],
      'katakana_quiz': ['さんすう', '時計（とけい）', 'ひらがな'],
    };
    final list = others[drillKey] ?? ['さんすう'];
    return list[math.Random().nextInt(list.length)];
  }

  /// ドリルキーを表示名に変換する
  static String displayName(String drillKey) {
    const names = {
      'hiragana': 'ひらがな',
      'math': 'さんすう',
      'clock': '時計（とけい）',
      'katakana_quiz': 'カタカナ',
      'memory': 'カードあわせ',
      'sugoroku': 'スゴロク',
      'battle': 'バトル',
    };
    return names[drillKey] ?? drillKey;
  }
}
