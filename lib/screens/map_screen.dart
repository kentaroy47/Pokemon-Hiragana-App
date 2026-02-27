import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/character_model.dart';
import '../data/hiragana_data.dart';
import 'practice_screen.dart';

class MapScreen extends StatelessWidget {
  final List<HiraganaRow> rows;
  final String title;

  const MapScreen({
    super.key,
    this.rows = hiraganaRows,
    this.title = 'ひらがな',
  });

  static const _vowels = ['あ/ア', 'い/イ', 'う/ウ', 'え/エ', 'お/オ'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.darkText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '50おんマップ（$title）',
          style: const TextStyle(
            color: AppTheme.darkText,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                const SizedBox(width: 60),
                ..._vowels.map(
                  (v) => Expanded(
                    child: Center(
                      child: Text(
                        v,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.blueAccent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: rows.length,
                itemBuilder: (context, rowIndex) {
                  final row = rows[rowIndex];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            row.rowName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textGray,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        ...List.generate(5, (colIndex) {
                          final char = colIndex < row.chars.length
                              ? row.chars[colIndex]
                              : null;
                          return Expanded(
                            child: Center(
                              child: char != null
                                  ? _CharCell(
                                      character: char.char,
                                      romaji: char.romaji,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => PracticeScreen(
                                              rows: rows,
                                              title: title,
                                              initialRowIndex: rowIndex,
                                              initialCharIndex: colIndex,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharCell extends StatelessWidget {
  final String character;
  final String romaji;
  final VoidCallback onTap;

  const _CharCell({
    required this.character,
    required this.romaji,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              character,
              style: const TextStyle(
                fontSize: 24,
                color: AppTheme.darkText,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              romaji,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.textGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
