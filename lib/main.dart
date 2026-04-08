import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_palette.dart';
import 'screens/home_screen.dart';
import 'services/daily_stats_service.dart';
import 'services/pokemon_repository.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await PokemonRepository.init();
  DailyStatsService.init();

  // 保存済みパレットを復元
  final savedId = StorageService.loadPaletteId();
  if (savedId != null) {
    paletteNotifier.value = AppPalettes.findById(savedId);
  }

  runApp(const HiraganaApp());
}

class HiraganaApp extends StatelessWidget {
  const HiraganaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPalette>(
      valueListenable: paletteNotifier,
      builder: (context, palette, _) {
        return MaterialApp(
          title: 'ひらがな れんしゅう',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(palette),
          home: const HomeScreen(),
        );
      },
    );
  }
}
