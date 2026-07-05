import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import '../services/pokemon_repository.dart';
import '../services/storage_service.dart';
import '../services/analytics_service.dart';
import '../services/daily_stats_service.dart';
import '../services/sound_service.dart';
import '../widgets/pokemon_widgets.dart';
import 'drill_round_mixin.dart';

// ─── クイズデータ ─────────────────────────────────────────────────────────────

typedef _KanaPair = (String hira, String kata);

const List<_KanaPair> _kanaPairs = [
  ('あ', 'ア'), ('い', 'イ'), ('う', 'ウ'), ('え', 'エ'), ('お', 'オ'),
  ('か', 'カ'), ('き', 'キ'), ('く', 'ク'), ('け', 'ケ'), ('こ', 'コ'),
  ('さ', 'サ'), ('し', 'シ'), ('す', 'ス'), ('せ', 'セ'), ('そ', 'ソ'),
  ('た', 'タ'), ('ち', 'チ'), ('つ', 'ツ'), ('て', 'テ'), ('と', 'ト'),
  ('な', 'ナ'), ('に', 'ニ'), ('ぬ', 'ヌ'), ('ね', 'ネ'), ('の', 'ノ'),
  ('は', 'ハ'), ('ひ', 'ヒ'), ('ふ', 'フ'), ('へ', 'ヘ'), ('ほ', 'ホ'),
  ('ま', 'マ'), ('み', 'ミ'), ('む', 'ム'), ('め', 'メ'), ('も', 'モ'),
  ('や', 'ヤ'), ('ゆ', 'ユ'), ('よ', 'ヨ'),
  ('ら', 'ラ'), ('り', 'リ'), ('る', 'ル'), ('れ', 'レ'), ('ろ', 'ロ'),
  ('わ', 'ワ'), ('を', 'ヲ'), ('ん', 'ン'),
];

// ─── こくごデータ ─────────────────────────────────────────────────────────────

const List<(String, String)> _hantaigoData = [
  ('おおきい', 'ちいさい'), ('ながい', 'みじかい'), ('はやい', 'おそい'),
  ('あかるい', 'くらい'),  ('あつい', 'さむい'),   ('あたらしい', 'ふるい'),
  ('たかい', 'ひくい'),   ('かるい', 'おもい'),   ('おおい', 'すくない'),
  ('うえ', 'した'),       ('みぎ', 'ひだり'),     ('まえ', 'うしろ'),
  ('すき', 'きらい'),     ('いい', 'わるい'),     ('ひろい', 'せまい'),
];

const List<(List<String>, String)> _nakamahazureData = [
  (['りんご', 'みかん', 'もも'], 'いぬ'),
  (['いぬ', 'ねこ', 'うし'], 'もも'),
  (['あか', 'あお', 'きいろ'], 'ねこ'),
  (['はる', 'なつ', 'あき'], 'いぬ'),
  (['ぱん', 'すし', 'うどん'], 'いぬ'),
  (['て', 'あし', 'め'], 'りんご'),
  (['でんしゃ', 'バス', 'くるま'], 'もも'),
  (['まる', 'さんかく', 'しかく'], 'いぬ'),
  (['いち', 'に', 'さん'], 'いぬ'),
  (['えんぴつ', 'けしゴム', 'ノート'], 'いぬ'),
  (['ぞう', 'きりん', 'らいおん'], 'りんご'),
  (['つくえ', 'いす', 'たな'], 'ねこ'),
];

const List<(String, String, List<String>)> _gotouMojiData = [
  ('か', 'かえる', ['いぬ', 'ねこ', 'うさぎ']),
  ('い', 'いぬ',   ['りんご', 'ねこ', 'もも']),
  ('は', 'はな',   ['ねこ', 'りんご', 'うし']),
  ('さ', 'さかな', ['いぬ', 'ねこ', 'うし']),
  ('み', 'みかん', ['いぬ', 'りんご', 'ねこ']),
  ('り', 'りんご', ['みかん', 'いぬ', 'ねこ']),
  ('つ', 'つき',   ['はな', 'うみ', 'やま']),
  ('く', 'くも',   ['はな', 'つき', 'やま']),
  ('ね', 'ねこ',   ['いぬ', 'はな', 'うし']),
  ('や', 'やま',   ['うみ', 'かわ', 'そら']),
  ('う', 'うみ',   ['やま', 'かわ', 'そら']),
  ('た', 'たこ',   ['いか', 'かに', 'えび']),
  ('わ', 'わに',   ['へび', 'かえる', 'ねこ']),
  ('ひ', 'ひよこ', ['いぬ', 'ねこ', 'うし']),
  ('ほ', 'ほし',   ['つき', 'くも', 'やま']),
];

const Set<int> _kLegendaryIds = {
  144, 145, 146, 150, 151,
  243, 244, 245, 249, 250, 251,
  377, 378, 379, 380, 381, 382, 383, 384, 385,
  483, 484, 485, 486, 487, 488, 490, 491, 492, 493,
  643, 644, 645, 646,
  716, 717, 718,
  791, 792, 800,
  888, 889, 890, 898,
  1007, 1008, 1024,
};

class _Quiz {
  final String displayBig;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final double choiceFontSize;
  const _Quiz({
    required this.displayBig,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    this.choiceFontSize = 36,
  });
}

// ─── フェーズ ─────────────────────────────────────────────────────────────────

enum _Phase { answering, ballReady, throwing, caught, missed, stageResult, gameOver }

// ─── メイン画面 ───────────────────────────────────────────────────────────────

class PokemonCatchScreen extends StatefulWidget {
  const PokemonCatchScreen({super.key});

  @override
  State<PokemonCatchScreen> createState() => _PokemonCatchScreenState();
}

class _PokemonCatchScreenState extends State<PokemonCatchScreen>
    with DrillRoundMixin, TickerProviderStateMixin {
  static const _questionsPerBall = 3;

  int _stage = 0;
  _Phase _phase = _Phase.answering;
  int _correctInBall = 0;
  int _missCount = 0;

  late _Quiz _currentQuiz;
  String? _selectedAnswer;

  // ── ポケモン ──
  late PokemonEntry _stageA;
  late PokemonEntry _stageB;
  late PokemonEntry _stageC;
  bool _stageCIsShiny = false;
  bool _stageCRevealed = false;
  final List<(PokemonEntry, bool)> _caught = [];

  // ── アニメーション ──
  late AnimationController _throwCtrl;
  late Animation<double> _throwT;

  // ── 投げ方向（外れ時に斜めに飛ばす） ──
  double _throwOffsetX = 0;

  @override
  void initState() {
    super.initState();
    drillInitPokemonState();
    _initPokemon();
    _currentQuiz = _generateQuiz();
    _throwCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _throwT = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _throwCtrl, curve: Curves.easeOut),
    );
    AnalyticsService.logScreenView('pokemon_catch');
  }

  @override
  void dispose() {
    _throwCtrl.dispose();
    super.dispose();
  }

  void _initPokemon() {
    final all = List<PokemonEntry>.from(PokemonRepository.all)..shuffle(drillRandom);
    _stageA = all[0];
    _stageB = all[1];
    final legendaries = PokemonRepository.all
        .where((p) => _kLegendaryIds.contains(p.pokedexId))
        .toList()
      ..shuffle(drillRandom);
    if (legendaries.isNotEmpty && drillRandom.nextBool()) {
      _stageC = legendaries.first;
      _stageCIsShiny = drillRollShiny();
    } else {
      _stageC = all[2];
      _stageCIsShiny = true;
    }
  }

  PokemonEntry get _currentPokemon => [_stageA, _stageB, _stageC][_stage];
  bool get _isSecretStage => _stage == 2;

  double get _catchRate => switch (_missCount) {
        0 => 0.70,
        1 => 0.85,
        _ => 1.00,
      };

  // ── 問題生成（ステージ = ゾーン、バトルと同パラメータ） ──

  // こくご: 0=ひら→カタ, 3=カタ→ひら, 5=反対語, 6=なかまはずれ, 7=語頭文字
  // さんすう: 1=足し算, 2=引き算, 4=応用計算
  static const _kokugoByZone = [
    [0],               // stage 0: ひら→カタのみ
    [0, 3],            // stage 1: +カタ→ひら
    [0, 3, 5, 6, 7],   // stage 2: +反対語, なかまはずれ, 語頭文字
  ];
  static const _mathByZone = [
    [1, 2],            // stage 0: 足し算・引き算
    [1, 2],            // stage 1: 同じ（数値レンジが上がる）
    [1, 2, 4],         // stage 2: +応用計算
  ];

  _Quiz _generateQuiz() {
    final zone = _stage.clamp(0, 2);
    final types = [..._kokugoByZone[zone], ..._mathByZone[zone]];
    final type = types[drillRandom.nextInt(types.length)];
    return switch (type) {
      0 => _generateHiraToKata(),
      1 => _generateAddition(zone),
      2 => _generateSubtraction(zone),
      3 => _generateKataToHira(),
      4 => switch (drillRandom.nextInt(3)) {
          0 => _generateAddTens(),
          1 => _generateSubtractTens(),
          _ => _generateAddTriple(),
        },
      5 => _generateHantaigo(),
      6 => _generateNakamahazure(),
      _ => _generateGotouMoji(),
    };
  }

  _Quiz _generateHiraToKata() {
    final pair = _kanaPairs[drillRandom.nextInt(_kanaPairs.length)];
    final correct = pair.$2;
    final wrongs = (List<_KanaPair>.from(_kanaPairs)
          ..removeWhere((p) => p.$2 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$2)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$1,
      prompt: 'この ひらがなの カタカナは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  _Quiz _generateKataToHira() {
    final pair = _kanaPairs[drillRandom.nextInt(_kanaPairs.length)];
    final correct = pair.$1;
    final wrongs = (List<_KanaPair>.from(_kanaPairs)
          ..removeWhere((p) => p.$1 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$1)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$2,
      prompt: 'この カタカナの ひらがなは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
    );
  }

  _Quiz _generateAddition(int zone) {
    final (int minA, int maxA, int maxSum, int spread) = zone == 0
        ? (5, 19, 20, 5)
        : (10, 29, 30, 8);
    final a = drillRandom.nextInt(maxA - minA + 1) + minA;
    final maxB = maxSum - a;
    final b = maxB >= 1 ? drillRandom.nextInt(maxB) + 1 : 1;
    final answer = a + b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts++ < 50) {
      final w = answer + drillRandom.nextInt(spread * 2 + 1) - spread;
      if (w != answer && w > 0) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString()).toList();
    return _Quiz(
      displayBig: '$a ＋ $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateSubtraction(int zone) {
    final (int minA, int maxA, int spread) = zone == 0
        ? (10, 20, 5)
        : (15, 30, 8);
    final a = drillRandom.nextInt(maxA - minA + 1) + minA;
    final b = drillRandom.nextInt(a - 1) + 1;
    final answer = a - b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts++ < 50) {
      final w = answer + drillRandom.nextInt(spread * 2 + 1) - spread;
      if (w != answer && w >= 0 && w < a) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString()).toList();
    return _Quiz(
      displayBig: '$a － $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateAddTens() {
    int a, b;
    do {
      a = (drillRandom.nextInt(8) + 1) * 10;
      b = (drillRandom.nextInt(8) + 1) * 10;
    } while (a + b > 100);
    final answer = a + b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts++ < 50) {
      final w = answer + (drillRandom.nextInt(5) - 2) * 10;
      if (w != answer && w > 0 && w <= 100) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString()).toList();
    return _Quiz(
      displayBig: '$a ＋ $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateSubtractTens() {
    int a, b;
    do {
      a = (drillRandom.nextInt(8) + 2) * 10;
      b = (drillRandom.nextInt(8) + 1) * 10;
    } while (b >= a);
    final answer = a - b;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts++ < 50) {
      final w = answer + (drillRandom.nextInt(5) - 2) * 10;
      if (w != answer && w > 0 && w < a) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString()).toList();
    return _Quiz(
      displayBig: '$a － $b',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateAddTriple() {
    final a = drillRandom.nextInt(5) + 1;
    final b = drillRandom.nextInt(5) + 1;
    final c = drillRandom.nextInt(5) + 1;
    final answer = a + b + c;
    final wrongs = <int>{};
    var attempts = 0;
    while (wrongs.length < 3 && attempts++ < 50) {
      final w = answer + drillRandom.nextInt(7) - 3;
      if (w != answer && w > 0) wrongs.add(w);
    }
    final choices = ([answer, ...wrongs.take(3)]..shuffle(drillRandom))
        .map((n) => n.toString()).toList();
    return _Quiz(
      displayBig: '$a ＋ $b ＋ $c',
      prompt: 'こたえは いくつ？',
      choices: choices,
      correctIndex: choices.indexOf(answer.toString()),
    );
  }

  _Quiz _generateHantaigo() {
    final pair = _hantaigoData[drillRandom.nextInt(_hantaigoData.length)];
    final correct = pair.$2;
    final wrongs = (_hantaigoData.toList()
          ..removeWhere((p) => p.$2 == correct)
          ..shuffle(drillRandom))
        .take(3)
        .map((p) => p.$2)
        .toList();
    final choices = [correct, ...wrongs]..shuffle(drillRandom);
    return _Quiz(
      displayBig: pair.$1,
      prompt: 'はんたいの ことばは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(correct),
      choiceFontSize: 24,
    );
  }

  _Quiz _generateNakamahazure() {
    final data = _nakamahazureData[drillRandom.nextInt(_nakamahazureData.length)];
    final choices = [...data.$1, data.$2]..shuffle(drillRandom);
    return _Quiz(
      displayBig: '？',
      prompt: 'なかまでは ないのは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(data.$2),
      choiceFontSize: 22,
    );
  }

  _Quiz _generateGotouMoji() {
    final data = _gotouMojiData[drillRandom.nextInt(_gotouMojiData.length)];
    final choices = [data.$2, ...data.$3]..shuffle(drillRandom);
    return _Quiz(
      displayBig: data.$1,
      prompt: 'この もじで はじまる ことばは どれ？',
      choices: choices,
      correctIndex: choices.indexOf(data.$2),
      choiceFontSize: 24,
    );
  }

  // ── 回答処理 ──

  void _onAnswer(String choice) {
    if (_selectedAnswer != null || _phase != _Phase.answering) return;
    final isCorrect = choice == _currentQuiz.choices[_currentQuiz.correctIndex];
    if (isCorrect) SoundService.playStrokeComplete();
    setState(() => _selectedAnswer = choice);
    Future.delayed(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (isCorrect && _correctInBall + 1 >= _questionsPerBall) {
        setState(() {
          _correctInBall = 0;
          _phase = _Phase.ballReady;
          _selectedAnswer = null;
        });
      } else {
        setState(() {
          if (isCorrect) _correctInBall++;
          _selectedAnswer = null;
          _currentQuiz = _generateQuiz();
        });
      }
    });
  }

  // ── ボール投げ ──

  void _onThrow() {
    if (_phase != _Phase.ballReady) return;
    final caught = drillRandom.nextDouble() < _catchRate;
    // 外れた場合はボールが斜めに飛ぶ
    _throwOffsetX = caught ? 0 : (drillRandom.nextBool() ? 0.25 : -0.25);
    setState(() => _phase = _Phase.throwing);
    _throwCtrl.reset();
    _throwCtrl.forward().then((_) {
      if (!mounted) return;
      if (caught) {
        SoundService.playCatch();
        setState(() => _phase = _Phase.caught);
        Future.delayed(const Duration(milliseconds: 1400), _registerCatch);
      } else {
        setState(() {
          _phase = _Phase.missed;
          _missCount++;
        });
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!mounted) return;
          setState(() {
            _phase = _Phase.answering;
            _selectedAnswer = null;
            _currentQuiz = _generateQuiz();
          });
        });
      }
    });
  }

  void _registerCatch() {
    if (!mounted) return;
    final pokemon = _currentPokemon;
    final isShiny = _isSecretStage ? _stageCIsShiny : false;
    _caught.add((pokemon, isShiny));
    drillCaughtPokemon.add(pokemon);
    StorageService.saveCaughtNames(
        drillCaughtPokemon.map((p) => p.katakana).toList());
    StorageService.addTodayCaughtName(pokemon.katakana);
    if (isShiny) {
      drillShinyCaughtNames.add(pokemon.katakana);
      StorageService.saveShinyCaughtNames(drillShinyCaughtNames);
    }
    DailyStatsService.incrementCaught();
    AnalyticsService.logPokemonCaught(
      pokemonName: pokemon.katakana,
      isShiny: isShiny,
      source: 'pokemon_catch',
    );
    if (_isSecretStage) setState(() => _stageCRevealed = true);
    setState(() => _phase = _Phase.stageResult);
  }

  void _nextStage() {
    if (_stage + 1 >= 3) {
      StorageService.incrementDailyPlays('pokemon_catch');
      DailyStatsService.incrementDrillSessions('pokemon_catch');
      DailyStatsService.recordStreak();
      setState(() => _phase = _Phase.gameOver);
    } else {
      setState(() {
        _stage++;
        _phase = _Phase.answering;
        _missCount = 0;
        _correctInBall = 0;
        _selectedAnswer = null;
        _currentQuiz = _generateQuiz();
      });
      _throwCtrl.reset();
    }
  }

  void _restart() {
    setState(() {
      _stage = 0;
      _phase = _Phase.answering;
      _missCount = 0;
      _correctInBall = 0;
      _selectedAnswer = null;
      _caught.clear();
      _stageCRevealed = false;
    });
    _throwCtrl.reset();
    _initPokemon();
    _currentQuiz = _generateQuiz();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 280,
            child: _LeftPanel(
              stage: _stage,
              phase: _phase,
              pokemon: _currentPokemon,
              isSecretStage: _isSecretStage,
              isRevealed: _stageCRevealed,
              isShiny: _isSecretStage ? _stageCIsShiny : false,
              correctInBall: _correctInBall,
              onBack: () => Navigator.pop(context),
            ),
          ),
          Expanded(
            child: _RightPanel(
              phase: _phase,
              quiz: _currentQuiz,
              selectedAnswer: _selectedAnswer,
              onAnswer: _onAnswer,
              throwT: _throwT,
              throwOffsetX: _throwOffsetX,
              onThrow: _onThrow,
              onNextStage: _nextStage,
              isSecretStage: _isSecretStage,
              isRevealed: _stageCRevealed,
              pokemonColor: _currentPokemon.color,
              caught: _caught,
              onRestart: _restart,
              onBack: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── 左パネル（ポケモン表示） ──────────────────────────────────────────────────

class _LeftPanel extends StatelessWidget {
  final int stage;
  final _Phase phase;
  final PokemonEntry pokemon;
  final bool isSecretStage;
  final bool isRevealed;
  final bool isShiny;
  final int correctInBall;
  final VoidCallback onBack;

  const _LeftPanel({
    required this.stage,
    required this.phase,
    required this.pokemon,
    required this.isSecretStage,
    required this.isRevealed,
    required this.isShiny,
    required this.correctInBall,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final showSilhouette = isSecretStage && !isRevealed;
    final isCaught = phase == _Phase.caught || phase == _Phase.stageResult;

    return Container(
      color: AppTheme.white,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 16),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onBack,
                      icon: const Icon(Icons.home_outlined, size: 14),
                      label:
                          const Text('もどる', style: TextStyle(fontSize: 12)),
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
                    const SizedBox(height: 12),
                    _StageIndicator(stage: stage),
                    const SizedBox(height: 16),

                    // ── ポケモン画像 ──
                    Center(
                      child: Column(
                        children: [
                          if (isShiny && !showSilhouette)
                            const Text('✨',
                                style: TextStyle(fontSize: 20, height: 1.2)),
                          SizedBox(
                            width: 190,
                            height: 190,
                            child: showSilhouette
                                ? ColorFiltered(
                                    colorFilter: const ColorFilter.mode(
                                        Color(0xFF1A1A2E), BlendMode.srcATop),
                                    child: PokemonImage(
                                        pokemon: pokemon,
                                        size: 170,
                                        isShiny: false),
                                  )
                                : PokemonImage(
                                    pokemon: pokemon,
                                    size: 170,
                                    isShiny: isShiny),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            showSilhouette ? '？？？？？' : pokemon.hiragana,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: showSilhouette
                                  ? AppTheme.textGray
                                  : AppTheme.darkText,
                              letterSpacing: showSilhouette ? 4 : 0,
                            ),
                          ),
                          if (isCaught && isShiny)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text('いろちがい！',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFFFD700),
                                      fontWeight: FontWeight.bold)),
                            ),
                          if (isCaught)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text('ゲット！',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const Spacer(),

                    if (phase == _Phase.answering || phase == _Phase.missed)
                      _BallProgress(correctInBall: correctInBall),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
          // コンフェッティ（シークレットゲット時）
          if (isCaught && isSecretStage)
            Positioned.fill(
              child: IgnorePointer(
                child: ConfettiOverlay(baseColor: pokemon.color),
              ),
            ),
        ],
      ),
    );
  }
}

class _StageIndicator extends StatelessWidget {
  final int stage;
  const _StageIndicator({required this.stage});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final done = i < stage;
        final current = i == stage;
        final isSecret = i == 2;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? const Color(0xFF4CAF50)
                      : current
                          ? const Color(0xFFE84B4B)
                          : const Color(0xFFEEEEEE),
                ),
                child: Center(
                  child: Text(
                    done ? '✓' : isSecret && !current ? '？' : '${i + 1}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: (done || current) ? Colors.white : AppTheme.textGray,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSecret ? 'ひみつ' : 'ステージ${i + 1}',
                style: TextStyle(
                  fontSize: 9,
                  color: current ? const Color(0xFFE84B4B) : AppTheme.textGray,
                  fontWeight: current ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _QuizContent extends StatelessWidget {
  final _Quiz quiz;
  final String? selectedAnswer;
  final void Function(String) onAnswer;

  const _QuizContent({
    required this.quiz,
    required this.selectedAnswer,
    required this.onAnswer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 80,
          alignment: Alignment.center,
          child: Text(
            quiz.displayBig,
            style: const TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkText,
              height: 1.0,
            ),
          ),
        ),
        Text(
          quiz.prompt,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppTheme.textGray),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 2.2,
          children: quiz.choices.map((choice) {
            final answered = selectedAnswer != null;
            final isSelected = selectedAnswer == choice;
            final isCorrectChoice =
                choice == quiz.choices[quiz.correctIndex];
            Color? bg;
            Color textColor = AppTheme.darkText;
            if (answered) {
              if (isSelected && isCorrectChoice) {
                bg = const Color(0xFF4CAF50);
                textColor = Colors.white;
              } else if (isSelected) {
                bg = const Color(0xFFE84B4B);
                textColor = Colors.white;
              } else if (isCorrectChoice) {
                bg = const Color(0xFF4CAF50);
                textColor = Colors.white;
              }
            }
            return GestureDetector(
              onTap: () => onAnswer(choice),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: bg ?? AppTheme.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        bg != null ? Colors.transparent : const Color(0xFFCCCCCC),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    choice,
                    style: TextStyle(
                      fontSize: quiz.choiceFontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BallProgress extends StatelessWidget {
  final int correctInBall;
  const _BallProgress({required this.correctInBall});

  @override
  Widget build(BuildContext context) {
    final remaining = 3 - correctInBall;
    return Column(
      children: [
        Text(
          'あと $remaining もん とくと ボールがもらえる',
          style: const TextStyle(fontSize: 10, color: AppTheme.textGray),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final filled = i < correctInBall;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: filled ? 1.0 : 0.25,
                child: const Pokeball(
                  color: Color(0xFFCC2222),
                  size: 20,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ─── 右パネル（問題表示・ボール投げ） ─────────────────────────────────────────

class _RightPanel extends StatelessWidget {
  final _Phase phase;
  final _Quiz quiz;
  final String? selectedAnswer;
  final void Function(String) onAnswer;
  final Animation<double> throwT;
  final double throwOffsetX;
  final VoidCallback onThrow;
  final VoidCallback onNextStage;
  final bool isSecretStage;
  final bool isRevealed;
  final Color pokemonColor;
  final List<(PokemonEntry, bool)> caught;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _RightPanel({
    required this.phase,
    required this.quiz,
    required this.selectedAnswer,
    required this.onAnswer,
    required this.throwT,
    required this.throwOffsetX,
    required this.onThrow,
    required this.onNextStage,
    required this.isSecretStage,
    required this.isRevealed,
    required this.pokemonColor,
    required this.caught,
    required this.onRestart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    if (phase == _Phase.gameOver) {
      return _GameOverPanel(
          caught: caught, onRestart: onRestart, onBack: onBack);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanEnd: (details) {
        if (details.velocity.pixelsPerSecond.dy < -250 &&
            phase == _Phase.ballReady) {
          onThrow();
        }
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return Stack(
          children: [
            // ── メインコンテンツ ──
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
                child: _buildPhaseContent(),
              ),
            ),

            // ── ボール飛翔アニメーション ──
            if (phase == _Phase.throwing)
              AnimatedBuilder(
                animation: throwT,
                builder: (context, _) {
                  final t = throwT.value;
                  const ballSize = 52.0;
                  final startY = h * 0.8 - ballSize / 2;
                  final endY = h * 0.05 - ballSize / 2;
                  final startX = w / 2 - ballSize / 2;
                  final endX = startX + throwOffsetX * w;
                  final currentY = startY + (endY - startY) * t;
                  final currentX = startX + (endX - startX) * t;
                  final currentSize = ballSize - (ballSize * 0.45 * t);
                  return Positioned(
                    left: currentX + (ballSize - currentSize) / 2,
                    top: currentY + (ballSize - currentSize) / 2,
                    child: Pokeball(
                      color: const Color(0xFFCC2222),
                      size: currentSize,
                    ),
                  );
                },
              ),
          ],
        );
      }),
    );
  }

  Widget _buildPhaseContent() {
    if (phase == _Phase.answering || phase == _Phase.missed) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (phase == _Phase.missed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9900).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'おしい！もう一かいチャレンジ！',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9900)),
                    ),
                  ),
                ),
              _QuizContent(
                quiz: quiz,
                selectedAnswer: selectedAnswer,
                onAnswer: onAnswer,
              ),
            ],
          ),
        ),
      );
    }

    if (phase == _Phase.ballReady) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '↑ スワイプして なげよう！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE84B4B),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: onThrow,
              child: const Pokeball(color: Color(0xFFCC2222), size: 80),
            ),
            const SizedBox(height: 12),
            const Text(
              '（タップでもなげられるよ）',
              style: TextStyle(fontSize: 12, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }

    if (phase == _Phase.caught || phase == _Phase.stageResult) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✨', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            const Text(
              'ゲットできた！',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF4CAF50)),
            ),
            if (phase == _Phase.stageResult) ...[
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: onNextStage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE84B4B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 3,
                ),
                child: const Text('つぎへ →',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

// ─── ゲームオーバー（全ステージ完了） ─────────────────────────────────────────

class _GameOverPanel extends StatelessWidget {
  final List<(PokemonEntry, bool)> caught;
  final VoidCallback onRestart;
  final VoidCallback onBack;

  const _GameOverPanel({
    required this.caught,
    required this.onRestart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'ぜんぶ ゲットできた！',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkText,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: caught.map(((PokemonEntry, bool) e) {
                  final (pokemon, isShiny) = e;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        if (isShiny)
                          const Text('✨',
                              style: TextStyle(fontSize: 20, height: 1.2)),
                        PokemonImage(
                            pokemon: pokemon, size: 110, isShiny: isShiny),
                        const SizedBox(height: 4),
                        Text(pokemon.hiragana,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        if (isShiny)
                          const Text('いろちがい',
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFFFFD700))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE84B4B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('もう一度',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: onBack,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.darkText,
                      side: const BorderSide(color: Color(0xFFCCCCCC)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                    child: const Text('もどる', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (caught.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: ConfettiOverlay(
                  baseColor: caught.last.$1.color),
            ),
          ),
      ],
    );
  }
}
