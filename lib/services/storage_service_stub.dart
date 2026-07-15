/// モバイル・デスクトップ用スタブ（何もしない）
class StorageService {
  static List<String> loadCaughtNames() => [];
  static void saveCaughtNames(List<String> names) {}
  static Set<String> loadShinyCaughtNames() => {};
  static void saveShinyCaughtNames(Set<String> names) {}
  static String? loadPaletteId() => null;
  static void savePaletteId(String id) {}
  static int loadMathRoundsCompleted() => 0;
  static void saveMathRoundsCompleted(int count) {}
  static int loadClockRoundsCompleted() => 0;
  static void saveClockRoundsCompleted(int count) {}
  static bool loadDailyLimitEnabled() => false;
  static void saveDailyLimitEnabled(bool value) {}
  static int loadDailyLimitCount() => 3;
  static void saveDailyLimitCount(int count) {}
  static int loadDailyPlays(String mode) => 0;
  static void incrementDailyPlays(String mode) {}
  static int loadTodayCaughtCount() => 0;
  static void incrementTodayCaughtCount() {}
  static int loadTodayDrillSessions(String drillKey) => 0;
  static int incrementTodayDrillSessions(String drillKey) => 0;
  static List<(String, int)> loadWeekSummary(String drillKey) => [];
  static List<String> loadTodayCaughtNamesList() => [];
  static void addTodayCaughtName(String katakana) {}
  static bool loadBattleRewardVisible() => true;
  static void saveBattleRewardVisible(bool value) {}
  static bool loadShowKokugoEasy() => false;
  static void saveShowKokugoEasy(bool value) {}
  static bool loadShowKatakanaYomou() => false;
  static void saveShowKatakanaYomou(bool value) {}
  static bool loadShowMemory() => true;
  static void saveShowMemory(bool value) {}
  static bool loadShowClock() => true;
  static void saveShowClock(bool value) {}
  static int loadKanjiMaxStrokes() => 99;
  static void saveKanjiMaxStrokes(int value) {}
  static bool loadKokugoInBattle() => true;
  static void saveKokugoInBattle(bool value) {}
  static bool loadMathInBattle() => true;
  static void saveMathInBattle(bool value) {}
  static bool loadKokugoInSugoroku() => true;
  static void saveKokugoInSugoroku(bool value) {}
  static bool loadMathInSugoroku() => true;
  static void saveMathInSugoroku(bool value) {}
  static bool loadKanaWritingEnabled() => true;
  static void saveKanaWritingEnabled(bool value) {}
  static int loadStreakCount() => 0;
  static int recordPlayStreak() => 0;
  static int shinyBonusRemaining() => 0;
  static bool useShinyBonusDraw() => false;
  static String loadHomeBonusType() => '';
  static void saveHomeBonusType(String value) {}
  static int loadHomeBonusRemaining() => 0;
  static void saveHomeBonusRemaining(int value) {}
}
