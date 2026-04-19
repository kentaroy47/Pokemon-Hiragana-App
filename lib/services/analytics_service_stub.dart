/// モバイル・デスクトップ用スタブ（何もしない）
class AnalyticsService {
  static void logScreenView(String screenName) {}
  static void logMathRoundComplete({
    required String level,
    required int score,
    required bool passed,
    required bool isShiny,
    required int roundsCompleted,
  }) {}
  static void logPokemonCaught({
    required String pokemonName,
    required bool isShiny,
    required String source,
  }) {}
  static void logKokugoModeSelected(String mode) {}
  static void logKatakanaRoundComplete({
    required int score,
    required bool passed,
    required bool isShiny,
  }) {}
  static void logClockRoundComplete({
    required String level,
    required int score,
    required bool passed,
    required bool isShiny,
    required int roundsCompleted,
  }) {}
  static void logMemoryRoundComplete({
    required int score,
    required bool isShiny,
  }) {}
  static void logSugorokuRoundComplete({
    required int stepsWalked,
    required bool isShiny,
  }) {}
  static void logPokemonReadingRoundComplete({
    required String mode,
    required int correctCount,
    required bool isShiny,
  }) {}
}
