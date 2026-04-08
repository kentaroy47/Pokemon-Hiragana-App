import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pokemon_data.dart';
import '../services/daily_stats_service.dart';
import '../services/pokemon_repository.dart';
import 'pokemon_widgets.dart';

/// 同じドリルを5回こなしたときにポケモンが別ドリルを提案するダイアログを表示する。
/// [drillKey] : 'hiragana' | 'math' | 'clock' | 'katakana_quiz'
/// [sessions] : 今日の完了セッション数（5の倍数のときだけ表示すること）
void showDrillSuggestionDialog(
    BuildContext context, String drillKey, int sessions) {
  final rng = math.Random();
  final pokemon = PokemonRepository.all[rng.nextInt(PokemonRepository.all.length)];
  final suggestion = DailyStatsService.pickSuggestion(drillKey);
  final drillName = DailyStatsService.displayName(drillKey);

  showDialog(
    context: context,
    builder: (_) => _DrillSuggestionDialog(
      pokemon: pokemon,
      drillName: drillName,
      suggestion: suggestion,
      sessions: sessions,
    ),
  );
}

class _DrillSuggestionDialog extends StatelessWidget {
  final PokemonEntry pokemon;
  final String drillName;
  final String suggestion;
  final int sessions;

  const _DrillSuggestionDialog({
    required this.pokemon,
    required this.drillName,
    required this.suggestion,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PokemonImage(pokemon: pokemon, size: 90),
          const SizedBox(height: 12),
          Text(
            '$drillNameを$sessionsかい\nやったよ！すごい！✨',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFFCC02), width: 1.5),
            ),
            child: Text(
              'こんどは$suggestionも\nやってみよう！',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFF555500),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1565C0),
              textStyle: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold),
            ),
            child: const Text('わかった！'),
          ),
        ),
      ],
    );
  }
}
