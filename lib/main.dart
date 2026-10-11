import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const _bg = Color(0xFF0E121A);
const _surface = Color(0xFF191F2B);
const _surface2 = Color(0xFF202735);
const _ink = Color(0xFFF0F3FA);
const _muted = Color(0xFFADB6C6);
const _blue = Color(0xFF1AA9E8);
const _line = Color(0xFF2B3444);

const _filterCategories = <String, String>{
  'Location': 'Where do you feel it?',
  'Symptoms': 'What do you notice?',
  'When': 'When do you notice it?',
  'How it started': 'How did it begin?',
};

const _urgentItems = <Map<String, String>>[
  {'id': 'chest', 'label': 'Chest pain, pressure, or tightness'},
  {'id': 'breathing', 'label': 'Trouble breathing'},
  {'id': 'deformity', 'label': 'Shoulder looks out of place after an injury'},
  {'id': 'major-injury', 'label': 'Serious fall, collision, or other injury'},
  {'id': 'severe', 'label': 'Sudden severe pain or cannot move the arm'},
  {
    'id': 'sensation',
    'label': 'New numbness, loss of feeling, or unusually cold or pale arm'
  },
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShoulderGuideApp());
}

class ShoulderGuideApp extends StatelessWidget {
  const ShoulderGuideApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Shoulder Guide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          fontFamily: 'SourceSans3',
          colorScheme: ColorScheme.fromSeed(
              seedColor: _blue, brightness: Brightness.dark, surface: _surface),
          scaffoldBackgroundColor: _bg,
          appBarTheme: const AppBarTheme(
              backgroundColor: _bg,
              foregroundColor: _ink,
              elevation: 0,
              surfaceTintColor: Colors.transparent),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
                fontSize: 38,
                height: 1.14,
                fontWeight: FontWeight.w700,
                color: _ink,
                letterSpacing: -0.8),
            headlineMedium: TextStyle(
                fontSize: 30,
                height: 1.18,
                fontWeight: FontWeight.w700,
                color: _ink),
            titleLarge: TextStyle(
                fontSize: 21, fontWeight: FontWeight.w700, color: _ink),
            bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: _muted),
            bodyMedium: TextStyle(fontSize: 16, height: 1.55, color: _muted),
          ),
          cardTheme: CardThemeData(
              color: _surface,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  side: const BorderSide(color: _line),
                  borderRadius: BorderRadius.circular(13)),
              margin: EdgeInsets.zero),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _surface,
            hintStyle: const TextStyle(color: _muted, fontSize: 17),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _line),
                borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: _blue, width: 2),
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        home: const ShoulderBrowse(),
      );
}

class ShoulderBrowse extends StatefulWidget {
  const ShoulderBrowse({super.key});

  @override
  State<ShoulderBrowse> createState() => _ShoulderBrowseState();
}

class _ShoulderBrowseState extends State<ShoulderBrowse> {
  final _search = TextEditingController();
  final _videoSearch = TextEditingController();
  final Set<String> _selectedSymptoms = {};
  final Set<String> _selectedStructures = {};
  final Set<String> _urgent = {};
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _conditions = [];
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _references = [];
  List<Map<String, dynamic>> _recoveryResources = [];
  List<Map<String, dynamic>> _videos = [];
  List<Map<String, dynamic>> _temporaryPainOptions = [];
  String _page = 'browse';
  String _sort = 'A to Z';
  String _videoCategory = 'All categories';
  String _videoCondition = 'All conditions';
  String _videoLanguage = 'All languages';
  String? _conditionId;
  bool _filtersOpen = true;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _videoSearch.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _search.dispose();
    _videoSearch.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await Future.wait([
        rootBundle.loadString('assets/data/symptoms.json'),
        rootBundle.loadString('assets/data/conditions.json'),
        rootBundle.loadString('assets/data/matches.json'),
        rootBundle.loadString('assets/data/references.json'),
        rootBundle.loadString('assets/data/recovery_resources.json'),
        rootBundle.loadString('assets/data/videos.json'),
        rootBundle.loadString('assets/data/temporary_pain_options.json'),
      ]);
      if (!mounted) return;
      setState(() {
        _symptoms = _rows(data[0]);
        _conditions = _rows(data[1]);
        _matches = _rows(data[2]);
        _references = _rows(data[3]);
        _recoveryResources = _rows(data[4]);
        _videos = _rows(data[5]);
        _temporaryPainOptions = _rows(data[6]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError =
            'The reference data could not be loaded. Please restart the app.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _rows(String value) =>
      (jsonDecode(value) as List<dynamic>).cast<Map<String, dynamic>>();

  String _symptomLabel(String id) =>
      _symptoms.firstWhere((item) => item['id'] == id,
          orElse: () => {'label': id})['label'] as String;

  bool get _hasUrgent => _urgent.isNotEmpty;
  bool get _isEmergency =>
      _urgent.contains('chest') || _urgent.contains('breathing');

  int get _activeFilterCount {
    var count = 0;
    for (final category in _filterCategories.values) {
      if (_selectedSymptoms
          .any((id) => _symptomById(id)?['category'] == category)) count++;
    }
    if (_selectedStructures.isNotEmpty) count++;
    if (_urgent.isNotEmpty) count++;
    return count;
  }

  Map<String, dynamic>? _symptomById(String id) {
    for (final item in _symptoms) {
      if (item['id'] == id) return item;
    }
    return null;
  }

  Map<String, Map<String, dynamic>> _scores() {
    final scores = <String, Map<String, dynamic>>{};
    for (final row in _matches) {
      final symptomId = row['symptomId'] as String;
      if (!_selectedSymptoms.contains(symptomId)) continue;
      final id = row['conditionId'] as String;
      final result =
          scores.putIfAbsent(id, () => {'score': 0, 'matched': <String>[]});
      result['score'] = (result['score'] as int) + (row['weight'] as int);
      (result['matched'] as List<String>).add(symptomId);
    }
    return scores;
  }

  List<Map<String, dynamic>> _visibleConditions() {
    final scores = _scores();
    final query = _search.text.trim().toLowerCase();
    final filtered = _conditions
        .where((condition) {
          final name = (condition['name'] as String).toLowerCase();
          if (query.isNotEmpty && !name.contains(query)) return false;
          if (_selectedStructures.isNotEmpty &&
              !_selectedStructures.contains(condition['structure']))
            return false;
          if (_selectedSymptoms.isNotEmpty &&
              !scores.containsKey(condition['id'])) return false;
          return true;
        })
        .map((condition) => {
              ...condition,
              ...(scores[condition['id']] ??
                  {'score': 0, 'matched': <String>[]})
            })
        .toList();

    filtered.sort((a, b) {
      if (_sort == 'A to Z' || _selectedSymptoms.isEmpty)
        return (a['name'] as String).compareTo(b['name'] as String);
      final scoreOrder = (b['score'] as int).compareTo(a['score'] as int);
      return scoreOrder != 0
          ? scoreOrder
          : (a['name'] as String).compareTo(b['name'] as String);
    });
    return filtered;
  }

  Future<void> _showMultiFilter(String title, List<Map<String, String>> choices,
      Set<String> selected) async {
    final temporary = Set<String>.of(selected);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                backgroundColor: _surface2,
                title: Text(title),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: choices.map((choice) {
                          final id = choice['id']!;
                          return CheckboxListTile(
                            value: temporary.contains(id),
                            onChanged: (checked) => setDialogState(() =>
                                checked == true
                                    ? temporary.add(id)
                                    : temporary.remove(id)),
                            title: Text(choice['label']!,
                                style: const TextStyle(fontSize: 16)),
                            activeColor: _blue,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList()),
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () {
                        setState(() {
                          selected
                            ..clear()
                            ..addAll(temporary);
                          if (identical(selected, _selectedSymptoms))
                            _sort = temporary.isEmpty
                                ? 'A to Z'
                                : 'Best symptom match';
                        });
                        Navigator.pop(dialogContext);
                      },
                      child: const Text('Apply')),
                ],
              )),
    );
  }

  Future<void> _showUrgentFilter() async {
    await _showMultiFilter('Urgent signs', _urgentItems, _urgent);
  }

  Future<void> _showSort() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: _surface2,
        title: const Text('Sort conditions'),
        children: ['Best symptom match', 'A to Z']
            .map((item) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, item),
                  child: Row(children: [
                    Icon(
                        item == _sort
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: _blue),
                    const SizedBox(width: 10),
                    Text(item)
                  ]),
                ))
            .toList(),
      ),
    );
    if (selected != null) setState(() => _sort = selected);
  }

  void _clearFilters() {
    setState(() {
      _search.clear();
      _selectedSymptoms.clear();
      _selectedStructures.clear();
      _urgent.clear();
      _sort = 'A to Z';
    });
  }

  Future<void> _openReference(String value) async {
    final opened =
        await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    if (!opened && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the reference link.')));
  }

  List<String> _videoConditionIdsForDisplay(Map<String, dynamic> video) {
    final conditionIds =
        (video['relevantConditionIds'] as List<dynamic>).cast<String>();
    if (video['category'] != 'exercise_rehabilitation') return conditionIds;
    if (_hasUrgent) return const [];

    final safety = video['exerciseSafety'] as Map<String, dynamic>? ?? const {};
    if (safety['reviewStatus'] != 'clinician_approved') return const [];
    final approvedIds =
        (safety['approvedConditionIds'] as List<dynamic>? ?? const [])
            .cast<String>();
    final assessmentRequiredIds =
        (safety['assessmentRequiredConditionIds'] as List<dynamic>? ?? const [])
            .cast<String>();
    return conditionIds
        .where((id) =>
            approvedIds.contains(id) && !assessmentRequiredIds.contains(id))
        .toList();
  }

  List<Map<String, dynamic>> _visibleVideos({String? conditionId}) {
    final query = _videoSearch.text.trim().toLowerCase();
    return _videos.where((video) {
      final verification =
          video['verification'] as Map<String, dynamic>? ?? const {};
      if (verification['sourceVerified'] != true ||
          verification['relevanceChecked'] != true) return false;
      final visibleConditionIds = _videoConditionIdsForDisplay(video);
      if (visibleConditionIds.isEmpty) return false;
      if (conditionId != null && !visibleConditionIds.contains(conditionId))
        return false;
      if (conditionId == null &&
          _videoCondition != 'All conditions' &&
          !visibleConditionIds.contains(_videoCondition)) return false;
      if (conditionId == null &&
          _videoCategory != 'All categories' &&
          video['category'] != _videoCategory) return false;
      if (conditionId == null &&
          _videoLanguage != 'All languages' &&
          video['language'] != _videoLanguage) return false;
      final searchable =
          '${video['title']} ${video['description']} ${video['publisher']} ${video['category']} ${visibleConditionIds.join(' ')}'
              .toLowerCase();
      return conditionId != null || query.isEmpty || searchable.contains(query);
    }).toList()
      ..sort((a, b) => (a['title'] as String).compareTo(b['title'] as String));
  }

  List<Map<String, dynamic>> _painReliefOptions({String? conditionId}) {
    if (_hasUrgent) return const [];
    return _temporaryPainOptions.where((option) {
      final verification = option['verification'] as Map<String, dynamic>;
      if (verification['sourceVerified'] != true ||
          verification['contentChecked'] != true) return false;
      final conditions =
          (option['applicableConditionIds'] as List<dynamic>).cast<String>();
      return conditionId == null || conditions.contains(conditionId);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator()));
    if (_loadError != null)
      return Scaffold(
          backgroundColor: _bg, body: Center(child: Text(_loadError!)));
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: InkWell(
            onTap: () => setState(() {
                  _page = 'browse';
                  _conditionId = null;
                }),
            child: const Text('Shoulder Guide',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        actions: MediaQuery.sizeOf(context).width < 720
            ? [
                IconButton(
                    tooltip: 'Browse conditions',
                    onPressed: () => setState(() {
                          _page = 'browse';
                          _filtersOpen = true;
                        }),
                    icon: const Icon(Icons.grid_view_rounded)),
                IconButton(
                    tooltip: 'Temporary pain relief',
                    onPressed: () => setState(() => _page = 'relief'),
                    icon: const Icon(Icons.healing_outlined)),
                IconButton(
                    tooltip: 'Videos and visual guides',
                    onPressed: () => setState(() => _page = 'videos'),
                    icon: const Icon(Icons.ondemand_video_outlined)),
              ]
            : [
                TextButton.icon(
                    onPressed: () => setState(() {
                          _page = 'browse';
                          _filtersOpen = true;
                        }),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Browse')),
                TextButton.icon(
                    onPressed: () => setState(() => _page = 'relief'),
                    icon: const Icon(Icons.healing_outlined),
                    label: const Text('Pain relief')),
                TextButton.icon(
                    onPressed: () => setState(() => _page = 'videos'),
                    icon: const Icon(Icons.ondemand_video_outlined),
                    label: const Text('Videos')),
                const SizedBox(width: 14),
              ],
        bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: _line)),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(
              child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: _page == 'browse'
                                  ? 1440
                                  : (_page == 'videos' || _page == 'relief'
                                      ? 1080
                                      : 900)),
                          child: _page == 'condition'
                              ? _conditionPage()
                              : (_page == 'videos'
                                  ? _videoLibraryPage()
                                  : (_page == 'relief'
                                      ? _temporaryPainReliefPage()
                                      : _browsePage(constraints.maxWidth))),
                        ),
                      ))),
          _footer(),
        ]),
      ),
    );
  }

  Widget _browsePage(double availableWidth) {
    final items = _visibleConditions();
    final columns =
        availableWidth >= 1100 ? 3 : (availableWidth >= 680 ? 2 : 1);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(availableWidth < 620 ? 18 : 28, 28,
          availableWidth < 620 ? 18 : 28, 42),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Browse',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontSize: 34)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final button = OutlinedButton.icon(
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            icon: const Icon(Icons.tune_rounded, color: _blue),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Filters',
                  style: TextStyle(
                      color: _blue, fontSize: 16, fontWeight: FontWeight.w700)),
              if (_activeFilterCount > 0) ...[
                const SizedBox(width: 10),
                CircleAvatar(
                    radius: 12,
                    backgroundColor: _blue,
                    foregroundColor: _bg,
                    child: Text('$_activeFilterCount',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 12)))
              ],
            ]),
            style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF102A39),
                side: BorderSide.none,
                minimumSize: const Size(152, 62),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13))),
          );
          if (constraints.maxWidth < 540)
            return Column(children: [
              _searchField(),
              const SizedBox(height: 10),
              SizedBox(width: double.infinity, child: button)
            ]);
          return Row(children: [
            Expanded(child: _searchField()),
            const SizedBox(width: 14),
            button
          ]);
        }),
        if (_filtersOpen) ...[
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth >= 1200
                ? 5
                : (constraints.maxWidth >= 780
                    ? 4
                    : (constraints.maxWidth >= 540 ? 2 : 1));
            final filterNames = [
              ..._filterCategories.keys,
              'Structure',
              'Urgent signs',
              'Sort'
            ];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filterNames.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: count,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  mainAxisExtent: 84),
              itemBuilder: (context, index) => _filterField(filterNames[index]),
            );
          }),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.delete_outline, color: _blue),
                  label: const Text('Reset filters',
                      style: TextStyle(
                          color: _blue,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)))),
        ],
        if (_hasUrgent) ...[const SizedBox(height: 15), _warningCard()],
        const SizedBox(height: 22),
        Row(children: [
          Text('${items.length} conditions',
              style:
                  const TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          if (_selectedSymptoms.isNotEmpty)
            const Text('· ranked by selected symptom matches',
                style: TextStyle(color: _muted, fontSize: 13))
        ]),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _emptyResults()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 235),
            itemBuilder: (context, index) =>
                _conditionCard(items[index], index),
          ),
      ]),
    );
  }

  Widget _searchField() => TextField(
        controller: _search,
        style: const TextStyle(fontSize: 18, color: _ink),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search condition names…',
          prefixIcon: const Icon(Icons.search, size: 25, color: _muted),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: _search.clear,
                  icon: const Icon(Icons.close)),
        ),
      );

  Widget _filterField(String title) {
    final details = _filterCategories[title];
    late final String value;
    late final VoidCallback onTap;
    if (details != null) {
      final options =
          _symptoms.where((item) => item['category'] == details).toList();
      final active = options
          .where((item) => _selectedSymptoms.contains(item['id']))
          .length;
      value = active == 0 ? 'Any' : '$active selected';
      onTap = () => _showMultiFilter(
          title,
          options
              .map((item) => {
                    'id': item['id'] as String,
                    'label': item['label'] as String
                  })
              .toList(),
          _selectedSymptoms);
    } else if (title == 'Structure') {
      final structures = _conditions
          .map((item) => item['structure'] as String)
          .toSet()
          .toList()
        ..sort();
      value = _selectedStructures.isEmpty
          ? 'Any'
          : '${_selectedStructures.length} selected';
      onTap = () => _showMultiFilter(
          title,
          structures.map((item) => {'id': item, 'label': item}).toList(),
          _selectedStructures);
    } else if (title == 'Urgent signs') {
      value = _urgent.isEmpty ? 'None selected' : '${_urgent.length} selected';
      onTap = _showUrgentFilter;
    } else {
      value = _sort;
      onTap = _showSort;
    }

    return Semantics(
      button: true,
      label: '$title. $value. Double tap to filter.',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Text(title.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: _muted))),
          Expanded(
              child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _line)),
            child: Row(children: [
              Expanded(
                  child: Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          color: value == 'Any' || value == 'None selected'
                              ? _muted
                              : _ink))),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _muted)
            ]),
          )),
        ]),
      ),
    );
  }

  Widget _conditionCard(Map<String, dynamic> condition, int index) {
    final matched = (condition['matched'] as List<String>);
    final hasMatches = matched.isNotEmpty;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() {
          _conditionId = condition['id'] as String;
          _page = 'condition';
        }),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(condition['structure'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: _muted))),
              if (hasMatches)
                Text('#${index + 1}',
                    style: const TextStyle(
                        color: _blue, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Text(condition['name'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 9),
            Expanded(
                child: Text(condition['what'] as String,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, height: 1.45, color: _muted))),
            if (hasMatches) ...[
              Text(
                  'Selected symptoms: ${matched.map(_symptomLabel).take(3).join(', ')}${matched.length > 3 ? '…' : ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 5),
            ],
            Row(children: [
              Text(hasMatches ? 'Some symptoms match' : 'Browse information',
                  style: const TextStyle(
                      color: _blue, fontWeight: FontWeight.w700, fontSize: 13)),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: _blue, size: 18)
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _conditionPage() {
    final found = _conditions.where((item) => item['id'] == _conditionId);
    if (found.isEmpty) return const SizedBox.shrink();
    final condition = found.first;
    final refs = _references
        .where((ref) =>
            (condition['references'] as List<dynamic>).contains(ref['id']))
        .toList();
    final resourceIds =
        (condition['recoveryResourceIds'] as List<dynamic>? ?? const [])
            .cast<String>();
    final recoveryResources = _recoveryResources
        .where((resource) => resourceIds.contains(resource['id']))
        .toList();
    final videos = _visibleVideos(conditionId: _conditionId);
    final reliefOptions = _painReliefOptions(conditionId: _conditionId);
    return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 48),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextButton.icon(
              onPressed: () => setState(() => _page = 'browse'),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Browse')),
          const SizedBox(height: 18),
          _eyebrow('CONDITION GUIDE'),
          Text(condition['name'] as String,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 9),
          const Text(
              'General information only. A healthcare professional is needed to assess and diagnose shoulder conditions.'),
          const SizedBox(height: 22),
          _contentSection('What is it?', [
            Text(condition['what'] as String),
            const SizedBox(height: 8),
            Text('Area involved: ${condition['structure']}',
                style: const TextStyle(fontWeight: FontWeight.w600))
          ]),
          _contentSection('Common symptoms',
              _bulletList(condition['symptoms'] as List<dynamic>)),
          _contentSection(
              'Common causes', [Text(condition['causes'] as String)]),
          _contentSection('Risk factors',
              _bulletList(condition['riskFactors'] as List<dynamic>)),
          _contentSection(
              'What may make it worse?', [Text(condition['worse'] as String)]),
          _contentSection(
              'General recovery information',
              recoveryResources.isEmpty
                  ? [
                      const Text(
                          'Recovery information is not currently available for this entry.')
                    ]
                  : recoveryResources
                      .map((resource) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(resource['summary'] as String)))
                      .toList()),
          const SizedBox(height: 16),
          _notice('When should I seek medical care?',
              (condition['warningSigns'] as List<dynamic>).first as String,
              alert: true),
          if (_hasUrgent) ...[
            const SizedBox(height: 12),
            _warningCard(),
          ],
          const SizedBox(height: 18),
          _conditionTemporaryReliefSection(reliefOptions, urgent: _hasUrgent),
          const SizedBox(height: 20),
          _conditionVideosSection(videos),
          const SizedBox(height: 12),
          _contentSection(
              'Sources',
              refs
                  .map((ref) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${ref['organization']}: ${ref['title']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(
                                '${ref['year'] ?? 'Date not listed'} · ${ref['evidenceType']}'),
                            Text(ref['summary'] as String),
                            TextButton.icon(
                                onPressed: () =>
                                    _openReference(ref['url'] as String),
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Open source')),
                          ])))
                  .toList()),
          const SizedBox(height: 12),
          const Text(
              'The matching weights are placeholders and have not been clinically validated.',
              style: TextStyle(fontSize: 13, color: _muted)),
        ]));
  }

  Widget _temporaryPainReliefPage() {
    final options = _painReliefOptions();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
            onPressed: () => setState(() => _page = 'browse'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Browse')),
        const SizedBox(height: 18),
        _eyebrow('GENERAL INFORMATION'),
        Text('Temporary Pain Relief',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        const Text(
            'These general options may offer short-term comfort while you arrange appropriate care. They do not diagnose or treat the cause of shoulder pain, and they may not suit every injury.'),
        const SizedBox(height: 18),
        if (_hasUrgent) ...[
          _warningCard(),
          const SizedBox(height: 14),
          _notice('Routine options are hidden',
              'Please follow the urgent-care guidance above. This page is not a substitute for prompt assessment.'),
        ] else ...[
          _notice('Use care with shoulder pain',
              'If you have had a significant injury, severe or worsening pain, a visible change in shoulder shape, or major difficulty moving your arm, follow the medical guidance on the condition page or seek professional assessment.'),
          const SizedBox(height: 18),
          ...options.map(_temporaryReliefOptionCard),
        ],
      ]),
    );
  }

  Widget _conditionTemporaryReliefSection(List<Map<String, dynamic>> options,
          {required bool urgent}) =>
      _contentSection('Temporary Pain Relief', [
        const Text(
            'These are general short-term comfort options, not a personal treatment plan. They do not diagnose or treat the cause of shoulder pain.'),
        const SizedBox(height: 12),
        if (urgent)
          const Text(
              'Routine options are hidden while urgent signs are selected. Follow the urgent-care guidance above.')
        else if (options.isEmpty)
          const Text(
              'Routine relief options are not listed for this condition because it may need professional assessment. Please follow the medical guidance above.')
        else
          ...options.map(_temporaryReliefOptionCard),
      ]);

  Widget _temporaryReliefOptionCard(Map<String, dynamic> option) {
    final referenceIds =
        (option['referenceIds'] as List<dynamic>).cast<String>();
    final references = _references
        .where((reference) => referenceIds.contains(reference['id']))
        .toList();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(option['title'] as String,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(option['description'] as String),
          const SizedBox(height: 13),
          const Text('When it may be relevant',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(option['whenItMayHelp'] as String),
          const SizedBox(height: 13),
          const Text('Precautions',
              style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(option['precautions'] as String),
          const SizedBox(height: 12),
          const Text(
              'Source and content checked · Not medically reviewed for this app',
              style: TextStyle(fontSize: 13, color: _muted)),
          if (references.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Sources',
                style: TextStyle(color: _ink, fontWeight: FontWeight.w700)),
            ...references.map((reference) => Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text('${reference['organization']}: ${reference['title']}'),
                    TextButton.icon(
                        onPressed: () =>
                            _openReference(reference['url'] as String),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open source')),
                  ],
                )),
          ],
        ]),
      ),
    );
  }

  Widget _conditionVideosSection(List<Map<String, dynamic>> videos) =>
      _contentSection('Videos and Visual Guides', [
        const Text(
            'These videos provide general educational information. They cannot determine whether an exercise is suitable for you. Stop if an activity causes significant or worsening pain, and seek appropriate medical guidance.'),
        const SizedBox(height: 14),
        if (videos.isEmpty)
          const Text(
              'A verified video is not currently available for this condition.')
        else
          ...videos.map(_videoCard),
      ]);

  Widget _videoLibraryPage() {
    final availableVideos = _visibleVideos();
    final categories = _videos
        .where((video) => _videoConditionIdsForDisplay(video).isNotEmpty)
        .map((video) => video['category'] as String)
        .toSet()
        .toList()
      ..sort();
    final conditionIds = _videos
        .where((video) => _videoConditionIdsForDisplay(video).isNotEmpty)
        .expand(_videoConditionIdsForDisplay)
        .toSet()
        .toList()
      ..sort((a, b) => _conditionName(a).compareTo(_conditionName(b)));
    final languages = _videos
        .where((video) => _videoConditionIdsForDisplay(video).isNotEmpty)
        .map((video) => video['language'] as String)
        .toSet()
        .toList()
      ..sort();
    final categoryOptions = ['All categories', ...categories];
    final conditionOptions = ['All conditions', ...conditionIds];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 48),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextButton.icon(
            onPressed: () => setState(() => _page = 'browse'),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Browse')),
        const SizedBox(height: 18),
        _eyebrow('LEARN AT YOUR OWN PACE'),
        Text('Videos and Visual Guides',
            style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 9),
        const Text(
            'Browse educational videos from health organizations. They supplement the written guide and cannot diagnose an injury or replace personal medical advice.'),
        const SizedBox(height: 18),
        _notice('About these resources',
            'The source and topic have been checked for each listing. This app has not medically reviewed the videos. Videos open on the publisher’s website when you choose to watch.'),
        if (_hasUrgent) ...[
          const SizedBox(height: 14),
          _warningCard(),
          const SizedBox(height: 8),
          const Text(
              'Routine exercise demonstrations are hidden while urgent signs are selected.',
              style: TextStyle(color: _muted)),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _videoSearch,
          style: const TextStyle(fontSize: 17, color: _ink),
          decoration: const InputDecoration(
              hintText: 'Search video topics or publishers',
              prefixIcon: Icon(Icons.search, color: _muted)),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final fields = [
            _videoDropdown(
                label: 'Video category',
                value: _videoCategory,
                options: categoryOptions,
                labelFor: _videoCategoryLabel,
                onChanged: (value) => setState(() => _videoCategory = value)),
            _videoDropdown(
                label: 'Condition',
                value: _videoCondition,
                options: conditionOptions,
                labelFor: (value) =>
                    value == 'All conditions' ? value : _conditionName(value),
                onChanged: (value) => setState(() => _videoCondition = value)),
            if (languages.length > 1)
              _videoDropdown(
                  label: 'Language',
                  value: _videoLanguage,
                  options: ['All languages', ...languages],
                  labelFor: _videoLanguageLabel,
                  onChanged: (value) => setState(() => _videoLanguage = value)),
          ];
          if (constraints.maxWidth < 620)
            return Column(
                children: fields
                    .expand((field) => [field, const SizedBox(height: 10)])
                    .toList());
          return Row(
              children: fields
                  .map((field) => Expanded(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: field)))
                  .toList());
        }),
        const SizedBox(height: 18),
        Text(
            '${availableVideos.length} ${availableVideos.length == 1 ? 'video' : 'videos'}',
            style: const TextStyle(color: _muted, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (availableVideos.isEmpty)
          _notice('No verified videos found',
              'Try a different search or filter. If no suitable source has been checked for a topic, the guide leaves that video unavailable.')
        else
          ...availableVideos.map(_videoCard),
      ]),
    );
  }

  Widget _videoDropdown(
          {required String label,
          required String value,
          required List<String> options,
          required String Function(String) labelFor,
          required ValueChanged<String> onChanged}) =>
      DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : options.first,
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 15)),
        items: options
            .map((option) => DropdownMenuItem(
                value: option,
                child: Text(labelFor(option), overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
      );

  Widget _videoCard(Map<String, dynamic> video) {
    final category = _videoCategoryLabel(video['category'] as String);
    final seconds = video['durationSeconds'] as int?;
    final duration = seconds == null
        ? null
        : '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
    final conditionIds = _videoConditionIdsForDisplay(video);
    final conditionNames = conditionIds.map(_conditionName).toList();
    final verification = video['verification'] as Map<String, dynamic>;
    final presenter = video['presenterName'] as String?;
    final credentials = video['presenterCredentials'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.play_circle_outline, color: _blue, size: 30),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(category.toUpperCase(),
                      style: const TextStyle(
                          color: _blue,
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 5),
                  Text(video['title'] as String,
                      style: const TextStyle(
                          color: _ink,
                          fontSize: 19,
                          height: 1.3,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
          const SizedBox(height: 10),
          Text(video['description'] as String),
          const SizedBox(height: 10),
          Text(
              [
                video['publisher'] as String,
                (video['language'] as String).toUpperCase(),
                if (duration != null) duration,
              ].join(' · '),
              style: const TextStyle(
                  fontSize: 14, color: _ink, fontWeight: FontWeight.w600)),
          if (presenter != null) ...[
            const SizedBox(height: 4),
            Text(
                'Presenter: $presenter${credentials == null ? '' : ' · $credentials'}',
                style: const TextStyle(fontSize: 14)),
          ],
          if (conditionNames.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Related topics: ${conditionNames.join(', ')}',
                style: const TextStyle(fontSize: 14)),
          ],
          const SizedBox(height: 10),
          Text(video['prerequisitesOrPrecautions'] as String,
              style: const TextStyle(fontSize: 14, height: 1.45)),
          const SizedBox(height: 8),
          Text(
              verification['medicalReviewStatus'] == 'medically_reviewed'
                  ? 'Source verified · Topic checked · Medically reviewed'
                  : 'Source verified · Topic checked · Not medically reviewed for this app',
              style: const TextStyle(fontSize: 13, color: _muted)),
          const SizedBox(height: 10),
          Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _openReference(video['videoUrl'] as String),
                icon: const Icon(Icons.open_in_new),
                label: Text('Open video from ${video['publisher']}'),
                style:
                    OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
              )),
          if (video['transcriptUrl'] is String) ...[
            const SizedBox(height: 4),
            TextButton.icon(
                onPressed: () =>
                    _openReference(video['transcriptUrl'] as String),
                icon: const Icon(Icons.article_outlined),
                label: const Text('Read the video transcript')),
          ],
        ]),
      ),
    );
  }

  String _conditionName(String id) =>
      _conditions.firstWhere((condition) => condition['id'] == id,
          orElse: () => {'name': id})['name'] as String;

  String _videoLanguageLabel(String language) => switch (language) {
        'All languages' => language,
        'en' => 'English',
        'fr' => 'French',
        'es' => 'Spanish',
        _ => language,
      };

  String _videoCategoryLabel(String category) => switch (category) {
        'understanding_condition' => 'Understanding the condition',
        'general_pain_management' => 'General pain management',
        'exercise_rehabilitation' => 'Exercise and rehabilitation',
        'recovery_education' => 'Recovery education',
        _ => 'Educational video',
      };

  Widget _warningCard() {
    final emergency = _isEmergency;
    final color = emergency ? const Color(0xFFFFD1D1) : const Color(0xFFFFD4A3);
    return Semantics(
      liveRegion: true,
      label: emergency
          ? 'Emergency warning. Call 911 now. Chest pain or trouble breathing may be an emergency.'
          : 'Prompt care warning. Contact a healthcare professional or urgent care service now.',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
            color:
                emergency ? const Color(0xFF351A20) : const Color(0xFF35291A),
            border: Border.all(
                color: emergency
                    ? const Color(0xFFB74651)
                    : const Color(0xFFC98337),
                width: 1.5),
            borderRadius: BorderRadius.circular(13)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(emergency ? Icons.emergency : Icons.warning_amber_rounded,
              color: color),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    emergency
                        ? 'Call 911 now.'
                        : 'Please seek prompt medical assessment.',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                const SizedBox(height: 5),
                Text(
                    emergency
                        ? 'Chest pain or trouble breathing can be an emergency. Do not wait for these symptom matches.'
                        : 'One or more signs you selected can need urgent attention, especially after an injury. Contact a healthcare professional or urgent care service now. If symptoms become severe or you feel unsafe, call 911.',
                    style: TextStyle(color: color, height: 1.5)),
              ])),
          IconButton(
              tooltip: 'Clear urgent signs',
              onPressed: () => setState(_urgent.clear),
              icon: Icon(Icons.close, color: color)),
        ]),
      ),
    );
  }

  Widget _emptyResults() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _line),
            borderRadius: BorderRadius.circular(13)),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.search_off, color: _blue, size: 27),
              SizedBox(height: 10),
              Text('No conditions found',
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
              SizedBox(height: 6),
              Text('Try a different search or reset some filters.',
                  style: TextStyle(color: _muted)),
            ]),
      );

  Widget _contentSection(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...children,
          const SizedBox(height: 16),
          const Divider(color: _line, height: 1),
        ]),
      );

  List<Widget> _bulletList(List<dynamic> lines) => lines.isEmpty
      ? [
          const Text(
              'Known risk factors are not listed in the sources attached to this entry.')
        ]
      : lines
          .map((line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  ',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Expanded(child: Text(line as String))
              ])))
          .toList();

  Widget _notice(String title, String body, {bool alert = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(
            color: alert ? const Color(0xFF202735) : _surface,
            border: Border.all(color: alert ? const Color(0xFF46536A) : _line),
            borderRadius: BorderRadius.circular(13)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(alert ? Icons.info_outline : Icons.info, color: _blue),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 17)),
                const SizedBox(height: 6),
                Text(body, style: const TextStyle(color: _muted, height: 1.5))
              ])),
        ]),
      );

  Widget _eyebrow(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w800,
              color: _muted)));

  Widget _footer() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: const BoxDecoration(
            color: Color(0xFF121721),
            border: Border(top: BorderSide(color: _line))),
        child: const Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 7,
            children: [
              Text('Shoulder Guide · General information only',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: _ink, fontSize: 12)),
              Text('This tool cannot diagnose or replace professional advice.',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ]),
      );
}
