import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/daily_stats_service.dart';
import '../services/home_visibility_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const _kAllDrillKeys = ['hiragana', 'math', 'clock', 'katakana_quiz', 'memory', 'sugoroku', 'battle', 'kanji_write', 'kanji_read', 'pokemon_catch'];
const _kDrillIcons = {
  'hiragana': '📖',
  'math': '🔢',
  'clock': '🕐',
  'katakana_quiz': '🌼',
  'memory': '🃏',
  'sugoroku': '🎲',
  'battle': '⚔️',
  'kanji_write': '✏️',
  'kanji_read': '📚',
  'pokemon_catch': '🎯',
};

class _SettingsScreenState extends State<SettingsScreen> {
  bool _limitEnabled = false;
  int _limitCount = 3;
  bool _battleRewardVisible = true;
  bool _showKokugoEasy = false;
  bool _showKatakanaYomou = false;
  bool _showMemory = true;
  bool _showClock = true;
  int _kanjiMaxStrokes = 99;
  bool _kokugoInBattle = true;
  bool _mathInBattle = true;
  bool _kokugoInSugoroku = true;
  bool _mathInSugoroku = true;
  final Map<String, List<(String, int)>> _weekData = {};

  @override
  void initState() {
    super.initState();
    _limitEnabled = StorageService.loadDailyLimitEnabled();
    _limitCount = StorageService.loadDailyLimitCount();
    _battleRewardVisible = StorageService.loadBattleRewardVisible();
    _showKokugoEasy = StorageService.loadShowKokugoEasy();
    _showKatakanaYomou = StorageService.loadShowKatakanaYomou();
    _showMemory = StorageService.loadShowMemory();
    _showClock = StorageService.loadShowClock();
    _kanjiMaxStrokes = StorageService.loadKanjiMaxStrokes();
    _kokugoInBattle = StorageService.loadKokugoInBattle();
    _mathInBattle = StorageService.loadMathInBattle();
    _kokugoInSugoroku = StorageService.loadKokugoInSugoroku();
    _mathInSugoroku = StorageService.loadMathInSugoroku();
    for (final key in _kAllDrillKeys) {
      _weekData[key] = StorageService.loadWeekSummary(key);
    }
  }

  void _toggleLimit(bool value) {
    setState(() => _limitEnabled = value);
    StorageService.saveDailyLimitEnabled(value);
  }

  void _changeCount(int delta) {
    final next = (_limitCount + delta).clamp(1, 10);
    if (next == _limitCount) return;
    setState(() => _limitCount = next);
    StorageService.saveDailyLimitCount(next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── 左パネル ───
          Container(
            width: 200,
            color: AppTheme.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.home_outlined, size: 14),
                  label: const Text('もどる', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.darkText,
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(height: 24),
                const Icon(Icons.settings_rounded,
                    size: 48, color: AppTheme.textGray),
                const SizedBox(height: 8),
                const Text(
                  'せってい',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
              ],
            ),
          ),

          // ─── 右パネル ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'まいにちのかいすうせいげん',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'オンにすると、各レベルを1日にできる回数を制限できます。',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGray),
                  ),
                  const SizedBox(height: 20),

                  // ON/OFF トグル
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_clock_rounded,
                            size: 24, color: AppTheme.blueAccent),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'かいすうせいげん',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.darkText,
                            ),
                          ),
                        ),
                        Switch(
                          value: _limitEnabled,
                          onChanged: _toggleLimit,
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),

                  // 回数ピッカー（ON の時だけ表示）
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    child: _limitEnabled
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppTheme.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: const Color(0xFFEEEEEE)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.repeat_rounded,
                                        size: 24,
                                        color: AppTheme.pinkAccent),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        '1日の最大回数',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.darkText,
                                        ),
                                      ),
                                    ),
                                    _CountPicker(
                                      count: _limitCount,
                                      onDecrement: () => _changeCount(-1),
                                      onIncrement: () => _changeCount(1),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  '各レベルを1日 $_limitCount 回まで練習できます',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textGray,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),

                  // ─── バトル設定 ───
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'バトル設定',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('⚔️', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ゲットできるポケモンを表示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'OFFにするとバトル中にわからない',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _battleRewardVisible,
                          onChanged: (v) {
                            setState(() => _battleRewardVisible = v);
                            StorageService.saveBattleRewardVisible(v);
                          },
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),

                  // ─── バトル・スゴロク 問題ジャンル ───
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'バトル・スゴロクの問題ジャンル',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'バトルとスゴロクで出す問題の種類を選べます',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGray),
                  ),
                  const SizedBox(height: 16),
                  _GenreToggleRow(
                    label: 'バトル',
                    kokugoValue: _kokugoInBattle,
                    mathValue: _mathInBattle,
                    onKokugoChanged: (v) {
                      if (!v && !_mathInBattle) return; // 両方OFFは禁止
                      setState(() => _kokugoInBattle = v);
                      StorageService.saveKokugoInBattle(v);
                    },
                    onMathChanged: (v) {
                      if (!v && !_kokugoInBattle) return;
                      setState(() => _mathInBattle = v);
                      StorageService.saveMathInBattle(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  _GenreToggleRow(
                    label: 'スゴロク',
                    kokugoValue: _kokugoInSugoroku,
                    mathValue: _mathInSugoroku,
                    onKokugoChanged: (v) {
                      if (!v && !_mathInSugoroku) return;
                      setState(() => _kokugoInSugoroku = v);
                      StorageService.saveKokugoInSugoroku(v);
                    },
                    onMathChanged: (v) {
                      if (!v && !_kokugoInSugoroku) return;
                      setState(() => _mathInSugoroku = v);
                      StorageService.saveMathInSugoroku(v);
                    },
                  ),

                  // ─── ホーム画面設定 ───
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'ホーム画面のボタン',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'かんたんモードや読むドリルを表示するか選べます',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGray),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'こくご（かんたん）を表示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'かんたんなひらがな・カタカナかきモード',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showKokugoEasy,
                          onChanged: (v) {
                            setState(() => _showKokugoEasy = v);
                            HomeVisibilityService.setShowKokugoEasy(v);
                          },
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('🌼', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'カタカナをよもう！を表示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'カタカナの読みクイズモード',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showKatakanaYomou,
                          onChanged: (v) {
                            setState(() => _showKatakanaYomou = v);
                            HomeVisibilityService.setShowKatakanaYomou(v);
                          },
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('🕐', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'とけいをよもう！を表示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'じかんをよむドリル',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showClock,
                          onChanged: (v) {
                            setState(() => _showClock = v);
                            HomeVisibilityService.setShowClock(v);
                          },
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('🃏', style: TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'カードあわせを表示',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.darkText,
                                ),
                              ),
                              Text(
                                'おぼえてめくるカードゲーム',
                                style: TextStyle(
                                    fontSize: 12, color: AppTheme.textGray),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _showMemory,
                          onChanged: (v) {
                            setState(() => _showMemory = v);
                            HomeVisibilityService.setShowMemory(v);
                          },
                          activeColor: AppTheme.blueAccent,
                        ),
                      ],
                    ),
                  ),

                  // ─── かんじのレベル ───
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text(
                    'かんじのむずかしさ',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '出てくる漢字の画数で難しさを選べます',
                    style: TextStyle(fontSize: 13, color: AppTheme.textGray),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _KanjiLevelButton(
                        label: 'はじめ',
                        sub: '（4画以下）',
                        maxStrokes: 4,
                        selected: _kanjiMaxStrokes == 4,
                        onTap: () {
                          setState(() => _kanjiMaxStrokes = 4);
                          StorageService.saveKanjiMaxStrokes(4);
                        },
                      ),
                      const SizedBox(width: 10),
                      _KanjiLevelButton(
                        label: 'ふつう',
                        sub: '（7画以下）',
                        maxStrokes: 7,
                        selected: _kanjiMaxStrokes == 7,
                        onTap: () {
                          setState(() => _kanjiMaxStrokes = 7);
                          StorageService.saveKanjiMaxStrokes(7);
                        },
                      ),
                      const SizedBox(width: 10),
                      _KanjiLevelButton(
                        label: 'ぜんぶ',
                        sub: '（79字）',
                        maxStrokes: 99,
                        selected: _kanjiMaxStrokes == 99,
                        onTap: () {
                          setState(() => _kanjiMaxStrokes = 99);
                          StorageService.saveKanjiMaxStrokes(99);
                        },
                      ),
                    ],
                  ),

                  // ─── 週間サマリ ───
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  _WeeklySummary(weekData: _weekData),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  final Map<String, List<(String, int)>> weekData;

  const _WeeklySummary({required this.weekData});

  @override
  Widget build(BuildContext context) {
    final dateLabels =
        (weekData[_kAllDrillKeys.first] ?? []).map((e) => e.$1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1週間のれんしゅうきろく',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkText,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ここ7日間のドリルの回数です',
          style: TextStyle(fontSize: 13, color: AppTheme.textGray),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ヘッダー行（日付）
              Row(
                children: [
                  const SizedBox(width: 110),
                  ...dateLabels.asMap().entries.map((entry) {
                    final isToday = entry.key == dateLabels.length - 1;
                    return Expanded(
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isToday ? FontWeight.bold : FontWeight.normal,
                          color: isToday
                              ? AppTheme.blueAccent
                              : AppTheme.textGray,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 8),
              // ドリルごとの行
              ..._kAllDrillKeys.map((key) {
                final data = weekData[key] ?? [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: Row(
                          children: [
                            Text(
                              _kDrillIcons[key] ?? '',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                DailyStatsService.displayName(key),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.darkText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...data.asMap().entries.map((entry) {
                        final isToday = entry.key == data.length - 1;
                        final count = entry.value.$2;
                        return Expanded(
                          child: Container(
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? AppTheme.blueAccent.withValues(
                                      alpha: isToday ? 0.22 : 0.10)
                                  : const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                count > 0 ? '$count' : '−',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: count > 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: count > 0
                                      ? AppTheme.blueAccent
                                      : AppTheme.textGray,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountPicker extends StatelessWidget {
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CountPicker({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconBtn(Icons.remove_rounded, count > 1 ? onDecrement : null),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
            ),
          ),
        ),
        _iconBtn(Icons.add_rounded, count < 10 ? onIncrement : null),
      ],
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppTheme.blueAccent.withValues(alpha: 0.1)
              : const Color(0xFFEEEEEE),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppTheme.blueAccent : AppTheme.textGray,
        ),
      ),
    );
  }
}

class _KanjiLevelButton extends StatelessWidget {
  final String label;
  final String sub;
  final int maxStrokes;
  final bool selected;
  final VoidCallback onTap;

  const _KanjiLevelButton({
    required this.label,
    required this.sub,
    required this.maxStrokes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF1565C0);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? activeColor : AppTheme.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? activeColor : const Color(0xFFCCCCCC),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  fontSize: 11,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.textGray,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenreToggleRow extends StatelessWidget {
  final String label;
  final bool kokugoValue;
  final bool mathValue;
  final ValueChanged<bool> onKokugoChanged;
  final ValueChanged<bool> onMathChanged;

  const _GenreToggleRow({
    required this.label,
    required this.kokugoValue,
    required this.mathValue,
    required this.onKokugoChanged,
    required this.onMathChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText,
              ),
            ),
          ),
          _chip('📖 こくご', kokugoValue, onKokugoChanged),
          const SizedBox(width: 8),
          _chip('🔢 さんすう', mathValue, onMathChanged),
        ],
      ),
    );
  }

  Widget _chip(String text, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: value ? AppTheme.blueAccent : const Color(0xFFEEEEEE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: value ? Colors.white : AppTheme.textGray,
          ),
        ),
      ),
    );
  }
}
