import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/character_model.dart';
import '../data/hiragana_data.dart';
import '../widgets/drawing_canvas.dart';

class PracticeScreen extends StatefulWidget {
  final List<HiraganaRow> rows;
  final String title;
  final int initialRowIndex;
  final int initialCharIndex;

  const PracticeScreen({
    super.key,
    this.rows = hiraganaRows,
    this.title = 'ひらがな',
    this.initialRowIndex = 0,
    this.initialCharIndex = 0,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late int _rowIndex;
  late int _charIndex;
  bool _showCompletion = false;
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _rowIndex = widget.initialRowIndex;
    _charIndex = widget.initialCharIndex;
  }

  List<HiraganaRow> get _rows => widget.rows;
  HiraganaChar get _currentChar => _rows[_rowIndex].chars[_charIndex];

  void _goToPrev() {
    setState(() {
      _showCompletion = false;
      if (_charIndex > 0) {
        _charIndex--;
      } else if (_rowIndex > 0) {
        _rowIndex--;
        _charIndex = _rows[_rowIndex].chars.length - 1;
      }
      _canvasKey.currentState?.reset();
    });
  }

  void _goToNext() {
    setState(() {
      _showCompletion = false;
      if (_charIndex < _rows[_rowIndex].chars.length - 1) {
        _charIndex++;
      } else if (_rowIndex < _rows.length - 1) {
        _rowIndex++;
        _charIndex = 0;
      }
      _canvasKey.currentState?.reset();
    });
  }

  bool get _hasPrev => _rowIndex > 0 || _charIndex > 0;
  bool get _hasNext =>
      _rowIndex < _rows.length - 1 ||
      _charIndex < _rows[_rowIndex].chars.length - 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Left panel
          SizedBox(
            width: 300,
            child: _LeftPanel(
              rows: _rows,
              currentChar: _currentChar,
              rowIndex: _rowIndex,
              charIndex: _charIndex,
              onPrev: _hasPrev ? _goToPrev : null,
              onNext: _hasNext ? _goToNext : null,
              onRowSelected: (ri, ci) {
                setState(() {
                  _showCompletion = false;
                  _rowIndex = ri;
                  _charIndex = ci;
                  _canvasKey.currentState?.reset();
                });
              },
              onBack: () => Navigator.pop(context),
            ),
          ),
          // Right panel: drawing canvas + completion overlay
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: DrawingCanvas(
                    key: _canvasKey,
                    character: _currentChar.char,
                    totalStrokes: _currentChar.strokeCount,
                    onComplete: () => setState(() => _showCompletion = true),
                  ),
                ),
                if (_showCompletion)
                  _CompletionOverlay(
                    character: _currentChar.char,
                    onNext: _hasNext
                        ? () {
                            setState(() => _showCompletion = false);
                            _goToNext();
                          }
                        : null,
                    onRetry: () {
                      setState(() => _showCompletion = false);
                      _canvasKey.currentState?.reset();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Completion Overlay ───────────────────────────────────────────────────────

class _CompletionOverlay extends StatefulWidget {
  final String character;
  final VoidCallback? onNext;
  final VoidCallback onRetry;

  const _CompletionOverlay({
    required this.character,
    this.onNext,
    required this.onRetry,
  });

  @override
  State<_CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<_CompletionOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();
    _scale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.4, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Opacity(
          opacity: _fade.value,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Confetti emoji row
                    const Text(
                      '🎉  ⭐  🎊',
                      style: TextStyle(fontSize: 40),
                    ),
                    const SizedBox(height: 16),

                    // "やったね！" title
                    Text(
                      'やったね！',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.pinkAccent,
                        shadows: [
                          Shadow(
                            color: AppTheme.pinkAccent.withValues(alpha: 0.25),
                            offset: const Offset(0, 6),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      'じょうずにかけたね！',
                      style: TextStyle(
                        fontSize: 18,
                        color: AppTheme.textGray,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Large character display
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: AppTheme.blueAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppTheme.blueAccent.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.character,
                        style: const TextStyle(
                          fontSize: 120,
                          color: AppTheme.blueAccent,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onRetry,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text(
                            'もういちど',
                            style: TextStyle(fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.darkText,
                            side: const BorderSide(color: Color(0xFFCCCCCC)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                        ),
                        if (widget.onNext != null) ...[
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: widget.onNext,
                            icon: const Text('つぎへ',
                                style: TextStyle(fontSize: 16)),
                            label: const Icon(Icons.arrow_forward, size: 18),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.pinkAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Left Panel ───────────────────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final List<HiraganaRow> rows;
  final HiraganaChar currentChar;
  final int rowIndex;
  final int charIndex;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final void Function(int rowIndex, int charIndex) onRowSelected;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.rows,
    required this.currentChar,
    required this.rowIndex,
    required this.charIndex,
    required this.onPrev,
    required this.onNext,
    required this.onRowSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final rowGridNames = rows.map((r) => r.rowName).toList();

    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: onBack,
                icon: const Icon(Icons.home_outlined, size: 16),
                label: const Text('もどる', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.darkText,
                  side: const BorderSide(color: Color(0xFFCCCCCC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.volume_up_outlined),
                color: AppTheme.textGray,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Character navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  onPressed: onPrev,
                  icon: const Icon(Icons.chevron_left, size: 28),
                  color: onPrev != null ? AppTheme.darkText : AppTheme.lightGray,
                ),
                Text(
                  currentChar.char,
                  style: const TextStyle(
                    fontSize: 56,
                    color: AppTheme.blueAccent,
                    fontWeight: FontWeight.bold,
                    height: 1.0,
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right, size: 28),
                  color: onNext != null ? AppTheme.darkText : AppTheme.lightGray,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Mascot
          Center(
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.yellowPanel,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.levelGold, width: 3),
                  ),
                  child: const Center(
                    child: Text('🧒', style: TextStyle(fontSize: 40)),
                  ),
                ),
                Positioned(
                  top: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.pinkAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'れんしゅうちゅう',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Row selector grid
          _RowSelectorGrid(
            rowIndex: rowIndex,
            rowGridNames: rowGridNames,
            onRowSelected: (ri) => onRowSelected(ri, 0),
          ),
          const SizedBox(height: 12),

          // Char selector within row
          _CharSelector(
            chars: rows[rowIndex].chars,
            selectedIndex: charIndex,
            onSelected: (ci) => onRowSelected(rowIndex, ci),
          ),

          const Spacer(),

          // Mini level card
          _MiniLevelCard(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Row Selector Grid ────────────────────────────────────────────────────────

class _RowSelectorGrid extends StatelessWidget {
  final int rowIndex;
  final List<String> rowGridNames;
  final void Function(int) onRowSelected;

  const _RowSelectorGrid({
    required this.rowIndex,
    required this.rowGridNames,
    required this.onRowSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: 1.4,
      ),
      itemCount: rowGridNames.length,
      itemBuilder: (context, i) {
        final isSelected = i == rowIndex;
        return GestureDetector(
          onTap: () => onRowSelected(i),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.pinkAccent : AppTheme.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.pinkAccent
                    : const Color(0xFFDDDDDD),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              rowGridNames[i],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.darkText,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Char Selector ────────────────────────────────────────────────────────────

class _CharSelector extends StatelessWidget {
  final List<HiraganaChar> chars;
  final int selectedIndex;
  final void Function(int) onSelected;

  const _CharSelector({
    required this.chars,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(chars.length, (i) {
        final isSelected = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.blueAccent.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? AppTheme.blueAccent
                    : const Color(0xFFDDDDDD),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              chars[i].char,
              style: TextStyle(
                fontSize: 18,
                color: isSelected ? AppTheme.blueAccent : AppTheme.darkText,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─── Mini Level Card ──────────────────────────────────────────────────────────

class _MiniLevelCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.levelGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Lv.1',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ひらがなのたまご',
                style: TextStyle(fontSize: 12, color: AppTheme.darkText),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 5,
              backgroundColor: Color(0xFFDDDDDD),
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.levelGold),
            ),
          ),
          const SizedBox(height: 4),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              '0pt / 100pt',
              style: TextStyle(fontSize: 11, color: AppTheme.textGray),
            ),
          ),
        ],
      ),
    );
  }
}
