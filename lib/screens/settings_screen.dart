import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/daily_stats_service.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

const _kAllDrillKeys = ['hiragana', 'math', 'clock', 'katakana_quiz', 'memory', 'sugoroku', 'battle'];
const _kDrillIcons = {
  'hiragana': '📖',
  'math': '🔢',
  'clock': '🕐',
  'katakana_quiz': '🌼',
  'memory': '🃏',
  'sugoroku': '🎲',
  'battle': '⚔️',
};

class _SettingsScreenState extends State<SettingsScreen> {
  bool _limitEnabled = false;
  int _limitCount = 3;
  final Map<String, List<(String, int)>> _weekData = {};

  @override
  void initState() {
    super.initState();
    _limitEnabled = StorageService.loadDailyLimitEnabled();
    _limitCount = StorageService.loadDailyLimitCount();
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
