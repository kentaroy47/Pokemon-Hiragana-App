import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_theme.dart';
import 'screens/home_screen.dart';
import 'services/pokemon_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await PokemonRepository.init();
  runApp(const HiraganaApp());
}

class HiraganaApp extends StatelessWidget {
  const HiraganaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ひらがな れんしゅう',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const HomeScreen(),
    );
  }
}
