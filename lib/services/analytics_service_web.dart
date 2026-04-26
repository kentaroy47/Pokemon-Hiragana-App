import 'dart:js_interop';

@JS('gtag')
external void _gtag(JSString command, JSString eventName, JSAny? params);

/// GA4 カスタムイベント送信サービス（Web専用）
class AnalyticsService {
  static void logScreenView(String screenName) {
    _gtag('event'.toJS, 'screen_view'.toJS, <String, Object>{
      'screen_name': screenName,
    }.jsify());
  }

  static void logMathRoundComplete({
    required String level,
    required int score,
    required bool passed,
    required bool isShiny,
    required int roundsCompleted,
  }) {
    _gtag('event'.toJS, 'math_round_complete'.toJS, <String, Object>{
      'level': level,
      'score': score,
      'passed': passed,
      'is_shiny': isShiny,
      'rounds_completed': roundsCompleted,
    }.jsify());
  }

  static void logPokemonCaught({
    required String pokemonName,
    required bool isShiny,
    required String source, // 'math' or 'pokemon'
  }) {
    _gtag('event'.toJS, 'pokemon_caught'.toJS, <String, Object>{
      'pokemon_name': pokemonName,
      'is_shiny': isShiny,
      'source': source,
    }.jsify());
  }

  static void logKokugoModeSelected(String mode) {
    _gtag('event'.toJS, 'kokugo_mode_selected'.toJS, <String, Object>{
      'mode': mode,
    }.jsify());
  }

  static void logKatakanaRoundComplete({
    required int score,
    required bool passed,
    required bool isShiny,
  }) {
    _gtag('event'.toJS, 'katakana_round_complete'.toJS, <String, Object>{
      'score': score,
      'passed': passed,
      'is_shiny': isShiny,
    }.jsify());
  }

  static void logClockRoundComplete({
    required String level,
    required int score,
    required bool passed,
    required bool isShiny,
    required int roundsCompleted,
  }) {
    _gtag('event'.toJS, 'clock_round_complete'.toJS, <String, Object>{
      'level': level,
      'score': score,
      'passed': passed,
      'is_shiny': isShiny,
      'rounds_completed': roundsCompleted,
    }.jsify());
  }

  static void logMemoryRoundComplete({
    required int score,
    required bool isShiny,
  }) {
    _gtag('event'.toJS, 'memory_round_complete'.toJS, <String, Object>{
      'score': score,
      'is_shiny': isShiny,
    }.jsify());
  }

  static void logSugorokuRoundComplete({
    required int stepsWalked,
    required bool isShiny,
  }) {
    _gtag('event'.toJS, 'sugoroku_round_complete'.toJS, <String, Object>{
      'steps_walked': stepsWalked,
      'is_shiny': isShiny,
    }.jsify());
  }

  static void logBattleRoundComplete({
    required int score,
    required bool isShiny,
  }) {
    _gtag('event'.toJS, 'battle_round_complete'.toJS, <String, Object>{
      'score': score,
      'is_shiny': isShiny,
    }.jsify());
  }

  static void logPokemonReadingRoundComplete({
    required String mode, // 'hiragana' or 'katakana'
    required int correctCount,
    required bool isShiny,
  }) {
    _gtag('event'.toJS, 'pokemon_reading_round_complete'.toJS, <String, Object>{
      'mode': mode,
      'correct_count': correctCount,
      'is_shiny': isShiny,
    }.jsify());
  }
}
