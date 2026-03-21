/// モバイル・デスクトップ用スタブ（何もしない）
class AnalyticsService {
  static void logScreenView(String screenName) {}
  static void logMathRoundComplete({
    required String level,
    required int score,
    required bool passed,
    required bool isShiny,
  }) {}
  static void logPokemonCaught({
    required String pokemonName,
    required bool isShiny,
    required String source,
  }) {}
  static void logKokugoModeSelected(String mode) {}
}
