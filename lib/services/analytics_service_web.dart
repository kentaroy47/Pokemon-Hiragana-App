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
  }) {
    _gtag('event'.toJS, 'math_round_complete'.toJS, <String, Object>{
      'level': level,
      'score': score,
      'passed': passed,
      'is_shiny': isShiny,
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
}
