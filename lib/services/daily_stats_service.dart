import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// 今日（JST）の学習統計を管理する。
/// todayCaughtNotifier はホーム画面のポケモン取得数バッジに使用する。
class DailyStatsService {
  static final todayCaughtNotifier = ValueNotifier<int>(0);

  /// アプリ起動時にストレージから値を復元する
  static void init() {
    todayCaughtNotifier.value = StorageService.loadTodayCaughtCount();
  }

  /// ポケモンをゲットしたときに呼ぶ（ストレージ保存 + 通知）
  static void incrementCaught() {
    StorageService.incrementTodayCaughtCount();
    todayCaughtNotifier.value = todayCaughtNotifier.value + 1;
  }

  /// ドリルのセッションを1増やし、新しいセッション数を返す
  static int incrementDrillSessions(String drillKey) {
    return StorageService.incrementTodayDrillSessions(drillKey);
  }

  /// 今日のセッション数を読み込む
  static int loadDrillSessions(String drillKey) {
    return StorageService.loadTodayDrillSessions(drillKey);
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
    };
    return names[drillKey] ?? drillKey;
  }
}
