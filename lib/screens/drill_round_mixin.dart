import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/sound_service.dart';

// ─── ドリル画面 共通ロジック Mixin ────────────────────────────────────────────
/// clock / math / katakana_quiz の3画面で共通するポケモン報酬・状態管理ロジック

mixin DrillRoundMixin<T extends StatefulWidget> on State<T> {
  final drillRandom = math.Random();

  int drillCorrectCount = 0;
  bool drillShowRoundResult = false;
  PokemonEntry? drillRewardPokemon;
  bool drillRewardIsShiny = false;
  PokemonEntry? drillPendingRewardPokemon;
  bool drillPendingIsShiny = false;
  int drillPrevPokemonIndex = -1;
  final List<PokemonEntry> drillCaughtPokemon = [];
  final Set<String> drillShinyCaughtNames = {};

  // ─── 初期化 ──────────────────────────────────────────────────────────────
  /// initState() の先頭で呼ぶ。localStorage からゲット済みポケモンを復元する。
  void drillInitPokemonState() {
    final lookup = {for (final p in PokemonRepository.all) p.katakana: p};
    for (final name in StorageService.loadCaughtNames()) {
      final entry = lookup[name];
      if (entry != null) drillCaughtPokemon.add(entry);
    }
    drillShinyCaughtNames.addAll(StorageService.loadShinyCaughtNames());
  }

  // ─── 報酬ポケモン抽選 ──────────────────────────────────────────────────────
  /// _startRound() の末尾で呼ぶ。前回と重複しないポケモンを選ぶ。
  void drillPickPendingPokemon() {
    final pool = PokemonRepository.all;
    int idx;
    do {
      idx = drillRandom.nextInt(pool.length);
    } while (idx == drillPrevPokemonIndex && pool.length > 1);
    drillPrevPokemonIndex = idx;
    drillPendingRewardPokemon = pool[idx];
    drillPendingIsShiny = drillRandom.nextDouble() < 0.2;
  }

  // ─── ポケモン保存 ─────────────────────────────────────────────────────────
  /// _endRound() の共通部分。保存して効果音を鳴らし、ゲットしたポケモンを返す。
  PokemonEntry? drillSaveRewardPokemon() {
    final reward = drillPendingRewardPokemon;
    final shiny = drillPendingIsShiny;
    if (reward != null) {
      drillCaughtPokemon.add(reward);
      StorageService.saveCaughtNames(
          drillCaughtPokemon.map((p) => p.katakana).toList());
      if (shiny) {
        drillShinyCaughtNames.add(reward.katakana);
        StorageService.saveShinyCaughtNames(drillShinyCaughtNames);
      }
      SoundService.playCatch();
    }
    return reward;
  }

  // ─── 日次制限チェック ─────────────────────────────────────────────────────
  /// modeKey 例: 'clock_exact', 'math_addSimple', 'katakana_quiz'
  bool drillIsExhausted(String modeKey) {
    if (!StorageService.loadDailyLimitEnabled()) return false;
    final limit = StorageService.loadDailyLimitCount();
    return StorageService.loadDailyPlays(modeKey) >= limit;
  }
}
