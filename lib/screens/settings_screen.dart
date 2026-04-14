import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _limitEnabled = false;
  int _limitCount = 3;

  @override
  void initState() {
    super.initState();
    _limitEnabled = StorageService.loadDailyLimitEnabled();
    _limitCount = StorageService.loadDailyLimitCount();
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
            child: Padding(
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
                ],
              ),
            ),
          ),
        ],
      ),
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
