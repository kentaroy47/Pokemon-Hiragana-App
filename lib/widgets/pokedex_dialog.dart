import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../app_theme.dart';
import '../data/pokemon_data.dart';
import 'pokemon_widgets.dart';

// ─── ゲットずかん ダイアログ ──────────────────────────────────────────────────

class PokedexDialog extends StatefulWidget {
  final List<PokemonEntry> caughtPokemon;
  final Set<String> shinyCaughtNames;
  final List<String> todayCaughtNames;

  const PokedexDialog({
    super.key,
    required this.caughtPokemon,
    required this.shinyCaughtNames,
    this.todayCaughtNames = const [],
  });

  @override
  State<PokedexDialog> createState() => _PokedexDialogState();
}

class _PokedexDialogState extends State<PokedexDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  late final Map<String, int> _counts;
  late final List<PokemonEntry> _normal;
  late final List<PokemonEntry> _mega;
  late final List<PokemonEntry> _gmax;
  late final List<PokemonEntry> _today;
  late final List<PokemonEntry> _shiny;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);

    _counts = {};
    final uniqueAll = <PokemonEntry>[];
    for (final p in widget.caughtPokemon) {
      if (!_counts.containsKey(p.katakana)) uniqueAll.add(p);
      _counts[p.katakana] = (_counts[p.katakana] ?? 0) + 1;
    }
    _normal = uniqueAll.where((p) => p.pokedexId < 10000).toList();
    _mega   = uniqueAll.where((p) => p.pokedexId >= 10000 && p.pokedexId < 10195).toList();
    _gmax   = uniqueAll.where((p) => p.pokedexId >= 10195).toList();
    _shiny  = uniqueAll.where((p) => widget.shinyCaughtNames.contains(p.katakana)).toList();

    final todaySet = widget.todayCaughtNames.toSet();
    final todayCounts = <String, int>{};
    for (final n in widget.todayCaughtNames) {
      todayCounts[n] = (todayCounts[n] ?? 0) + 1;
    }
    _today = uniqueAll.where((p) => todaySet.contains(p.katakana)).toList();
    for (final e in todayCounts.entries) {
      _counts[e.key] = e.value;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 720,
        height: 500,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 12),
              child: Row(
                children: [
                  const Text('📖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 8),
                  const Text(
                    'ゲットずかん',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              labelColor: AppTheme.blueAccent,
              unselectedLabelColor: AppTheme.textGray,
              indicatorColor: AppTheme.blueAccent,
              tabs: [
                Tab(text: 'ポケモン  ${_normal.length}ひき'),
                Tab(text: '🌟きょうゲット  ${_today.length}ひき'),
                Tab(text: 'メガシンカ  ${_mega.length}ひき'),
                Tab(text: 'キョダイマックス  ${_gmax.length}ひき'),
                Tab(text: '✨いろちがい  ${_shiny.length}ひき'),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _PokedexGrid(entries: _normal, counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames),
                  _PokedexGrid(entries: _today,  counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames,
                      emptyMessage: 'きょうはまだゲットしていないよ！'),
                  _PokedexGrid(entries: _mega,   counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames),
                  _PokedexGrid(entries: _gmax,   counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames),
                  _PokedexGrid(entries: _shiny,  counts: _counts,
                      shinyCaughtNames: widget.shinyCaughtNames, forceShiny: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ずかんグリッド ───────────────────────────────────────────────────────────

class _PokedexGrid extends StatelessWidget {
  final List<PokemonEntry> entries;
  final Map<String, int> counts;
  final Set<String> shinyCaughtNames;
  final bool forceShiny;
  final String emptyMessage;

  const _PokedexGrid({
    required this.entries,
    required this.counts,
    required this.shinyCaughtNames,
    this.forceShiny = false,
    this.emptyMessage = 'まだゲットしていないよ！',
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, color: AppTheme.textGray),
            ),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final p = entries[i];
        return _PokedexCard(
          pokemon: p,
          count: counts[p.katakana]!,
          isShiny: forceShiny || shinyCaughtNames.contains(p.katakana),
        );
      },
    );
  }
}

// ─── ずかん1枚カード ──────────────────────────────────────────────────────────

class _PokedexCard extends StatelessWidget {
  final PokemonEntry pokemon;
  final int count;
  final bool isShiny;

  const _PokedexCard({
    required this.pokemon,
    required this.count,
    this.isShiny = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showDialog(
        context: context,
        builder: (_) => _PokedexDetailDialog(pokemon: pokemon),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: pokemon.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: pokemon.color.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PokemonImage(pokemon: pokemon, size: 72, isShiny: isShiny),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    pokemon.katakana,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: pokemon.color,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  pokemon.hiragana,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textGray,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isShiny)
            const Positioned(
              top: 4,
              left: 4,
              child: Text('✨', style: TextStyle(fontSize: 12)),
            ),
          if (count > 1)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.pinkAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '×$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── ポケモン詳細ダイアログ ───────────────────────────────────────────────────

const _typeJa = {
  'normal': 'ノーマル', 'fire': 'ほのお',    'water': 'みず',
  'grass': 'くさ',     'electric': 'でんき', 'ice': 'こおり',
  'fighting': 'かくとう', 'poison': 'どく',  'ground': 'じめん',
  'flying': 'ひこう',  'psychic': 'エスパー','bug': 'むし',
  'rock': 'いわ',      'ghost': 'ゴースト',  'dragon': 'ドラゴン',
  'dark': 'あく',      'steel': 'はがね',    'fairy': 'フェアリー',
};

const _typeColors = {
  'normal':   Color(0xFFA8A878), 'fire':     Color(0xFFF08030),
  'water':    Color(0xFF6890F0), 'grass':    Color(0xFF78C850),
  'electric': Color(0xFFF8D030), 'ice':      Color(0xFF98D8D8),
  'fighting': Color(0xFFC03028), 'poison':   Color(0xFFA040A0),
  'ground':   Color(0xFFE0C068), 'flying':   Color(0xFFA890F0),
  'psychic':  Color(0xFFF85888), 'bug':      Color(0xFFA8B820),
  'rock':     Color(0xFFB8A038), 'ghost':    Color(0xFF705898),
  'dragon':   Color(0xFF7038F8), 'dark':     Color(0xFF705848),
  'steel':    Color(0xFFB8B8D0), 'fairy':    Color(0xFFEE99AC),
};

const _statJa = {
  'hp': 'HP', 'attack': 'こうげき', 'defense': 'ぼうぎょ',
  'special-attack': 'とくこう', 'special-defense': 'とくぼう',
  'speed': 'すばやさ',
};

class _PokedexDetailDialog extends StatefulWidget {
  final PokemonEntry pokemon;
  const _PokedexDetailDialog({required this.pokemon});

  @override
  State<_PokedexDetailDialog> createState() => _PokedexDetailDialogState();
}

class _PokedexDetailDialogState extends State<_PokedexDetailDialog> {
  Map<String, dynamic>? _data;
  String? _flavorText;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final pokemonRes = await http.get(
        Uri.parse(
            'https://pokeapi.co/api/v2/pokemon/${widget.pokemon.pokedexId}/'),
      );
      final pokemonData =
          jsonDecode(pokemonRes.body) as Map<String, dynamic>;

      final speciesUrl = (pokemonData['species'] as Map)['url'] as String;
      final speciesRes = await http.get(Uri.parse(speciesUrl));
      final speciesData =
          jsonDecode(speciesRes.body) as Map<String, dynamic>;

      final entries = speciesData['flavor_text_entries'] as List;
      final kanaEntries =
          entries.where((e) => e['language']['name'] == 'ja-Hrkt').toList();
      final jaEntry = kanaEntries.isNotEmpty ? kanaEntries.last : null;

      if (!mounted) return;
      setState(() {
        _data = pokemonData;
        _flavorText = jaEntry != null
            ? (jaEntry['flavor_text'] as String)
                .replaceAll('\n', ' ')
                .replaceAll('\f', ' ')
            : null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.pokemon.color;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(
        width: 700,
        height: 440,
        child: _loading
            ? Center(child: CircularProgressIndicator(color: color))
            : _error
                ? const Center(
                    child: Text('データをよみこめませんでした',
                        style: TextStyle(color: AppTheme.textGray)),
                  )
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final types = (data['types'] as List)
        .map((t) => t['type']['name'] as String)
        .toList();
    final stats = (data['stats'] as List)
        .map((s) =>
            MapEntry(s['stat']['name'] as String, s['base_stat'] as int))
        .toList();
    final height = ((data['height'] as int) / 10).toStringAsFixed(1);
    final weight = ((data['weight'] as int) / 10).toStringAsFixed(1);
    final color = widget.pokemon.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 230,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              PokemonImage(pokemon: widget.pokemon, size: 130),
              const SizedBox(height: 8),
              Text(
                widget.pokemon.katakana,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                widget.pokemon.hiragana,
                style: const TextStyle(fontSize: 12, color: AppTheme.textGray),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: types.map((t) => _TypeChip(type: t)).toList(),
              ),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _InfoItem(label: 'たかさ', value: '${height}m'),
                  _InfoItem(label: 'おもさ', value: '${weight}kg'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_flavorText != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _flavorText!,
                      style: const TextStyle(
                          fontSize: 13, height: 1.8, color: AppTheme.darkText),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                const Text(
                  'きほんステータス',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                ...stats.map((e) =>
                    _StatBar(name: e.key, value: e.value, color: color)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _typeColors[type] ?? Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _typeJa[type] ?? type,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const _InfoItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textGray)),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkText)),
      ],
    );
  }
}

class _StatBar extends StatelessWidget {
  final String name;
  final int value;
  final Color color;
  const _StatBar(
      {required this.name, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              _statJa[name] ?? name,
              style: const TextStyle(fontSize: 12, color: AppTheme.textGray),
            ),
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 255,
                minHeight: 8,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
