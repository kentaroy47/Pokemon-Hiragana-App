# Project Overview

子ども向け（6歳）ひらがな・カタカナ・さんすう・時計練習アプリ。Flutter製、**ランドスケープ固定**、**Web（GitHub Pages）がメインターゲット**。ポケモンをゲットする報酬システムで学習意欲を維持する。

# Common Commands

```bash
# ローカルでWeb起動
flutter run -d chrome

# GitHub Pages へビルド
flutter build web --release --base-href "/hiragana/"

# 静的解析
flutter analyze
```

CI: `.github/workflows/deploy.yml` — Flutter 3.29.0 / Dart 3.7.0 で自動デプロイ。

# Architecture

## 主要ファイル構成

```
lib/
  main.dart                    # エントリポイント、ランドスケープ固定
  app_theme.dart               # カラー定数（blueAccent, pinkAccent, levelGold 等）
  app_palette.dart             # テーマパレット切替（ValueNotifier）
  screens/
    home_screen.dart           # ホーム画面（左パネル＋右パネル、ドリル選択）
    practice_screen.dart       # ひらがな1文字練習
    pokemon_screen.dart        # ポケモン名なぞりゲーム（こくごドリル）
    map_screen.dart            # 50音マップ
    math_screen.dart           # さんすうドリル（4択、5問制）
    clock_screen.dart          # 時計をよもう（4択、5正解制）
    katakana_quiz_screen.dart  # カタカナをよもう（4択、5正解制）
    settings_screen.dart       # 設定画面（日次回数制限のON/OFF・上限数）
  widgets/
    drawing_canvas.dart        # お絵かきキャンバス
    pokemon_widgets.dart       # PokemonImage, Pokeball, ConfettiOverlay 等
    drill_suggestion_dialog.dart
  data/
    hiragana_data.dart
    katakana_data.dart
    pokemon_data.dart          # 200匹（PokemonEntry: katakana/hiragana/color/pokedexId）
    math_data.dart
  models/
    character_model.dart       # HiraganaChar, HiraganaRow
  services/
    storage_service.dart       # 条件付きexport（dart.library.js_interop で切替）
    storage_service_web.dart   # localStorage 実装
    storage_service_stub.dart  # モバイル用 no-op スタブ
    analytics_service.dart     # 同じく条件付きexport
    analytics_service_web.dart # GA4 gtag 実装
    analytics_service_stub.dart
    sound_service.dart         # 同じく条件付きexport
    sound_service_web.dart     # Web Audio API（BGM＋効果音）
    sound_service_stub.dart
    daily_stats_service.dart   # 今日の統計（ValueNotifier でホームへ反映）
    pokemon_repository.dart    # PokemonRepository.all（全ポケモンリスト）
```

## 条件付きexport パターン

```dart
// storage_service.dart
export 'storage_service_stub.dart'
    if (dart.library.js_interop) 'storage_service_web.dart';
```

Web ビルド時は `_web.dart`、それ以外は `_stub.dart` が使われる。analytics・sound も同様。

## ドリル画面の共通設計（clock / math / katakana_quiz）

- **左パネル**（260px固定）：もどるボタン、レベル選択ボタン、進捗星、報酬ポケモンプレビュー、ゲット数
- **右パネル**（Expanded）：問題表示 または ラウンド結果オーバーレイ（Stack）
- `_pendingRewardPokemon` をラウンド開始時に事前決定 → レベル切替しても**ポケモンは変わらない**
- `_selectLevel` でレベル変更時は問題状態のみリセット（ポケモンはそのまま）
- `_nextRound` でラウンド完了後に新しいポケモンを選ぶ
- **5正解で1ラウンド終了**（math のみ5問固定で3/5以上合格）

## ポケモン報酬システム

- ラウンド開始時に `PokemonRepository.all` からランダムに1匹を `_pendingRewardPokemon` に設定
- 20%の確率で色違い（`isShiny = true`）
- ラウンドクリアで `StorageService.saveCaughtNames` に保存（複数画面で共有）
- ゲット演出：ポケボール回転アニメーション ＋ `ConfettiOverlay`

## 日次回数制限機能

- **デフォルト: OFF**（`StorageService.loadDailyLimitEnabled()` → false）
- 設定画面でON/OFFと最大回数（1〜10）を変更
- localStorage キー: `dp_{mode}_{YYYY-MM-DD}` 形式（日付をキーに含めて自動リセット）
- mode キー例: `clock_exact`, `clock_half`, `clock_quarter`, `math_addSimple`, `katakana_quiz`
- 制限に達したレベルは左パネルで灰色表示 ＋ 鍵アイコン
- `_isExhausted(level)` で判定、`StorageService.incrementDailyPlays(mode)` で `_endRound` 時に加算

## StorageService（localStorage）キー一覧

| キー | 内容 |
|------|------|
| `pokemon_caught` | ゲット済みポケモン（カタカナ名カンマ区切り、重複あり） |
| `pokemon_caught_shiny` | 色違いゲット済み（カタカナ名カンマ区切り） |
| `app_palette` | 選択中テーマパレットID |
| `math_rounds_completed` | さんすう累計ラウンド数 |
| `clock_rounds_completed` | 時計累計ラウンド数 |
| `daily_limit_enabled` | 日次制限ON/OFF |
| `daily_limit_count` | 日次制限の上限回数 |
| `today_date_jst` | 今日の日付（JST）、日替わりリセット用 |
| `today_caught_count` | 今日ゲットしたポケモン数 |
| `today_sessions_{drill}` | 今日のドリルセッション数 |
| `dp_{mode}_{YYYY-MM-DD}` | 日次プレイ回数（制限機能用） |

## IDE の Dart 解析エラーについて

VS Code の Dart 拡張が連続編集後に一時的に `BuildContext`, `Text`, `StatelessWidget` 等を「未定義」と誤報することがある。これは **false positive**。`flutter analyze` や `flutter build web` は正常に通る。ファイルを保存し直すか、しばらく待てば解消する。

# ホーム画面のボタン構成

| ボタン | 画面 | 色 |
|--------|------|-----|
| 📖 こくご | `_KokugoModeDialog` → `PokemonScreen` | パレット依存 |
| 🔢 さんすう | `MathScreen` | パレット依存 |
| 🌼 カタカナをよもう！ | `KatakanaQuizScreen` | `0xFFFF9F43` |
| 🕐 とけいをよもう！ | `ClockScreen` | `0xFF48BEFF` |
| ⚙️（アイコン） | `SettingsScreen` | グレー |
