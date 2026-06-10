import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

enum HomeBonusType {
  nextShiny, // 次の1回が100%色違い
  shinyUp,   // 次の3回が60%色違い
}

class HomeBonusState {
  final HomeBonusType type;
  final int remaining;
  const HomeBonusState(this.type, this.remaining);
}

class HomeBonusService {
  static final bonusNotifier = ValueNotifier<HomeBonusState?>(null);

  static const _rollChance = 0.30; // 30% per home visit

  static void init() {
    final typeStr = StorageService.loadHomeBonusType();
    final remain = StorageService.loadHomeBonusRemaining();
    if (typeStr.isNotEmpty && remain > 0) {
      final type = _fromString(typeStr);
      bonusNotifier.value = HomeBonusState(type, remain);
    }
  }

  /// ホーム画面を訪れたときに呼ぶ。ボーナス未設定なら30%で付与。
  static void rollBonus() {
    if (bonusNotifier.value != null) return;
    if (math.Random().nextDouble() > _rollChance) return;
    final types = HomeBonusType.values;
    final type = types[math.Random().nextInt(types.length)];
    final remain = _initialUses(type);
    bonusNotifier.value = HomeBonusState(type, remain);
    StorageService.saveHomeBonusType(type.name);
    StorageService.saveHomeBonusRemaining(remain);
  }

  /// ドリルのシャイニー抽選時に呼ぶ。
  /// ボーナス中なら消費してそのボーナスレートを返す。なければ null。
  static double? tryConsumeRate() {
    final state = bonusNotifier.value;
    if (state == null) return null;
    final rate = _shinyRate(state.type);
    final newRemain = state.remaining - 1;
    if (newRemain <= 0) {
      bonusNotifier.value = null;
      StorageService.saveHomeBonusType('');
      StorageService.saveHomeBonusRemaining(0);
    } else {
      bonusNotifier.value = HomeBonusState(state.type, newRemain);
      StorageService.saveHomeBonusRemaining(newRemain);
    }
    return rate;
  }

  static HomeBonusType _fromString(String s) =>
      HomeBonusType.values.firstWhere((t) => t.name == s,
          orElse: () => HomeBonusType.nextShiny);

  static int _initialUses(HomeBonusType type) => switch (type) {
        HomeBonusType.nextShiny => 1,
        HomeBonusType.shinyUp => 3,
      };

  static double _shinyRate(HomeBonusType type) => switch (type) {
        HomeBonusType.nextShiny => 1.0,
        HomeBonusType.shinyUp => 0.6,
      };
}
