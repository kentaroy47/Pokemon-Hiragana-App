import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// ホーム画面のボタン表示/非表示を管理するサービス。
/// ValueNotifier により SettingsScreen の変更がホーム画面にリアルタイム反映される。
class HomeVisibilityService {
  static final showKokugoEasyNotifier =
      ValueNotifier<bool>(StorageService.loadShowKokugoEasy());
  static final showKatakanaYomouNotifier =
      ValueNotifier<bool>(StorageService.loadShowKatakanaYomou());
  static final showMemoryNotifier =
      ValueNotifier<bool>(StorageService.loadShowMemory());
  static final showClockNotifier =
      ValueNotifier<bool>(StorageService.loadShowClock());

  static void setShowKokugoEasy(bool value) {
    StorageService.saveShowKokugoEasy(value);
    showKokugoEasyNotifier.value = value;
  }

  static void setShowKatakanaYomou(bool value) {
    StorageService.saveShowKatakanaYomou(value);
    showKatakanaYomouNotifier.value = value;
  }

  static void setShowMemory(bool value) {
    StorageService.saveShowMemory(value);
    showMemoryNotifier.value = value;
  }

  static void setShowClock(bool value) {
    StorageService.saveShowClock(value);
    showClockNotifier.value = value;
  }
}
