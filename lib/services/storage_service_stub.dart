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
}
