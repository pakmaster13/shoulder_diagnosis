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
  {'id': 'sensation', 'label': 'New numbness, loss of feeling, or unusually cold or pale arm'},
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
          colorScheme: ColorScheme.fromSeed(seedColor: _blue, brightness: Brightness.dark, surface: _surface),
          scaffoldBackgroundColor: _bg,
          appBarTheme: const AppBarTheme(backgroundColor: _bg, foregroundColor: _ink, elevation: 0, surfaceTintColor: Colors.transparent),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontSize: 38, height: 1.14, fontWeight: FontWeight.w700, color: _ink, letterSpacing: -0.8),
            headlineMedium: TextStyle(fontSize: 30, height: 1.18, fontWeight: FontWeight.w700, color: _ink),
            titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _ink),
            bodyLarge: TextStyle(fontSize: 17, height: 1.55, color: _muted),
            bodyMedium: TextStyle(fontSize: 15, height: 1.5, color: _muted),
          ),
          cardTheme: CardThemeData(color: _surface, elevation: 0, shape: RoundedRectangleBorder(side: const BorderSide(color: _line), borderRadius: BorderRadius.circular(13)), margin: EdgeInsets.zero),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _surface,
            hintStyle: const TextStyle(color: _muted, fontSize: 17),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _line), borderRadius: BorderRadius.circular(14)),
            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _blue, width: 2), borderRadius: BorderRadius.circular(14)),
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
  final Set<String> _selectedSymptoms = {};
  final Set<String> _selectedStructures = {};
  final Set<String> _urgent = {};
  List<Map<String, dynamic>> _symptoms = [];
  List<Map<String, dynamic>> _conditions = [];
  List<Map<String, dynamic>> _matches = [];
  List<Map<String, dynamic>> _references = [];
  String _page = 'browse';
  String _sort = 'A to Z';
  String? _conditionId;
  bool _filtersOpen = true;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _loadData();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await Future.wait([
        rootBundle.loadString('assets/data/symptoms.json'),
        rootBundle.loadString('assets/data/conditions.json'),
        rootBundle.loadString('assets/data/matches.json'),
        rootBundle.loadString('assets/data/references.json'),
      ]);
      if (!mounted) return;
      setState(() {
        _symptoms = _rows(data[0]);
        _conditions = _rows(data[1]);
        _matches = _rows(data[2]);
        _references = _rows(data[3]);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'The reference data could not be loaded. Please restart the app.';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> _rows(String value) => (jsonDecode(value) as List<dynamic>).cast<Map<String, dynamic>>();

  String _symptomLabel(String id) => _symptoms.firstWhere((item) => item['id'] == id, orElse: () => {'label': id})['label'] as String;

  bool get _hasUrgent => _urgent.isNotEmpty;
  bool get _isEmergency => _urgent.contains('chest') || _urgent.contains('breathing');

  int get _activeFilterCount {
    var count = 0;
    for (final category in _filterCategories.values) {
      if (_selectedSymptoms.any((id) => _symptomById(id)?['category'] == category)) count++;
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
      final result = scores.putIfAbsent(id, () => {'score': 0, 'matched': <String>[]});
      result['score'] = (result['score'] as int) + (row['weight'] as int);
      (result['matched'] as List<String>).add(symptomId);
    }
    return scores;
  }

  List<Map<String, dynamic>> _visibleConditions() {
    final scores = _scores();
    final query = _search.text.trim().toLowerCase();
    final filtered = _conditions.where((condition) {
      final name = (condition['name'] as String).toLowerCase();
      if (query.isNotEmpty && !name.contains(query)) return false;
      if (_selectedStructures.isNotEmpty && !_selectedStructures.contains(condition['structure'])) return false;
      if (_selectedSymptoms.isNotEmpty && !scores.containsKey(condition['id'])) return false;
      return true;
    }).map((condition) => {...condition, ...(scores[condition['id']] ?? {'score': 0, 'matched': <String>[]})}).toList();

    filtered.sort((a, b) {
      if (_sort == 'A to Z' || _selectedSymptoms.isEmpty) return (a['name'] as String).compareTo(b['name'] as String);
      final scoreOrder = (b['score'] as int).compareTo(a['score'] as int);
      return scoreOrder != 0 ? scoreOrder : (a['name'] as String).compareTo(b['name'] as String);
    });
    return filtered;
  }

  Future<void> _showMultiFilter(String title, List<Map<String, String>> choices, Set<String> selected) async {
    final temporary = Set<String>.of(selected);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, setDialogState) => AlertDialog(
            backgroundColor: _surface2,
            title: Text(title),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: choices.map((choice) {
                  final id = choice['id']!;
                  return CheckboxListTile(
                    value: temporary.contains(id),
                    onChanged: (checked) => setDialogState(() => checked == true ? temporary.add(id) : temporary.remove(id)),
                    title: Text(choice['label']!, style: const TextStyle(fontSize: 16)),
                    activeColor: _blue,
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList()),
              ),
            ),
              actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
              TextButton(onPressed: () {
                setState(() {
                  selected..clear()..addAll(temporary);
                  if (identical(selected, _selectedSymptoms)) _sort = temporary.isEmpty ? 'A to Z' : 'Best symptom match';
                });
                Navigator.pop(dialogContext);
              }, child: const Text('Apply')),
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
        children: ['Best symptom match', 'A to Z'].map((item) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: Row(children: [Icon(item == _sort ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: _blue), const SizedBox(width: 10), Text(item)]),
            )).toList(),
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
    final opened = await launchUrl(Uri.parse(value), mode: LaunchMode.externalApplication);
    if (!opened && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the reference link.')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator()));
    if (_loadError != null) return Scaffold(backgroundColor: _bg, body: Center(child: Text(_loadError!)));
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: InkWell(onTap: () => setState(() { _page = 'browse'; _conditionId = null; }), child: const Text('Shoulder Guide', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        actions: [TextButton.icon(onPressed: () => setState(() { _page = 'browse'; _filtersOpen = true; }), icon: const Icon(Icons.grid_view_rounded), label: const Text('Browse')), const SizedBox(width: 14)],
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: _line)),
      ),
      body: SafeArea(
        top: false,
        child: Column(children: [
          Expanded(child: LayoutBuilder(builder: (context, constraints) => Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _page == 'browse' ? 1440 : 900),
              child: _page == 'condition' ? _conditionPage() : _browsePage(constraints.maxWidth),
            ),
          ))),
          _footer(),
        ]),
      ),
    );
  }

  Widget _browsePage(double availableWidth) {
    final items = _visibleConditions();
    final columns = availableWidth >= 1100 ? 3 : (availableWidth >= 680 ? 2 : 1);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(availableWidth < 620 ? 18 : 28, 28, availableWidth < 620 ? 18 : 28, 42),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Browse', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 34)),
        const SizedBox(height: 22),
        LayoutBuilder(builder: (context, constraints) {
          final button = OutlinedButton.icon(
            onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
            icon: const Icon(Icons.tune_rounded, color: _blue),
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('Filters', style: TextStyle(color: _blue, fontSize: 16, fontWeight: FontWeight.w700)),
              if (_activeFilterCount > 0) ...[const SizedBox(width: 10), CircleAvatar(radius: 12, backgroundColor: _blue, foregroundColor: _bg, child: Text('$_activeFilterCount', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)))],
            ]),
            style: OutlinedButton.styleFrom(backgroundColor: const Color(0xFF102A39), side: BorderSide.none, minimumSize: const Size(152, 62), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
          );
          if (constraints.maxWidth < 540) return Column(children: [_searchField(), const SizedBox(height: 10), SizedBox(width: double.infinity, child: button)]);
          return Row(children: [Expanded(child: _searchField()), const SizedBox(width: 14), button]);
        }),
        if (_filtersOpen) ...[
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final count = constraints.maxWidth >= 1200 ? 5 : (constraints.maxWidth >= 780 ? 4 : (constraints.maxWidth >= 540 ? 2 : 1));
            final filterNames = [..._filterCategories.keys, 'Structure', 'Urgent signs', 'Sort'];
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filterNames.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: count, crossAxisSpacing: 14, mainAxisSpacing: 18, mainAxisExtent: 84),
              itemBuilder: (context, index) => _filterField(filterNames[index]),
            );
          }),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: _clearFilters, icon: const Icon(Icons.delete_outline, color: _blue), label: const Text('Reset filters', style: TextStyle(color: _blue, fontSize: 15, fontWeight: FontWeight.w700)))),
        ],
        if (_hasUrgent) ...[const SizedBox(height: 15), _warningCard()],
        const SizedBox(height: 22),
        Row(children: [Text('${items.length} conditions', style: const TextStyle(color: _muted, fontWeight: FontWeight.w600)), const SizedBox(width: 8), if (_selectedSymptoms.isNotEmpty) const Text('· ranked by selected symptom matches', style: TextStyle(color: _muted, fontSize: 13))]),
        const SizedBox(height: 12),
        if (items.isEmpty)
          _emptyResults()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 14, mainAxisSpacing: 14, mainAxisExtent: 235),
            itemBuilder: (context, index) => _conditionCard(items[index], index),
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
          suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Clear search', onPressed: _search.clear, icon: const Icon(Icons.close)),
        ),
      );

  Widget _filterField(String title) {
    final details = _filterCategories[title];
    late final String value;
    late final VoidCallback onTap;
    if (details != null) {
      final options = _symptoms.where((item) => item['category'] == details).toList();
      final active = options.where((item) => _selectedSymptoms.contains(item['id'])).length;
      value = active == 0 ? 'Any' : '$active selected';
      onTap = () => _showMultiFilter(title, options.map((item) => {'id': item['id'] as String, 'label': item['label'] as String}).toList(), _selectedSymptoms);
    } else if (title == 'Structure') {
      final structures = _conditions.map((item) => item['structure'] as String).toSet().toList()..sort();
      value = _selectedStructures.isEmpty ? 'Any' : '${_selectedStructures.length} selected';
      onTap = () => _showMultiFilter(title, structures.map((item) => {'id': item, 'label': item}).toList(), _selectedStructures);
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
          Padding(padding: const EdgeInsets.only(bottom: 7), child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: _muted))),
          Expanded(child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
            child: Row(children: [Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, color: value == 'Any' || value == 'None selected' ? _muted : _ink))), const Icon(Icons.keyboard_arrow_down_rounded, color: _muted)]),
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
        onTap: () => setState(() { _conditionId = condition['id'] as String; _page = 'condition'; }),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(condition['structure'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted))),
              if (hasMatches) Text('#${index + 1}', style: const TextStyle(color: _blue, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Text(condition['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 9),
            Expanded(child: Text(condition['what'] as String, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.45, color: _muted))),
            if (hasMatches) ...[
              Text('Selected symptoms: ${matched.map(_symptomLabel).take(3).join(', ')}${matched.length > 3 ? '…' : ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _muted)),
              const SizedBox(height: 5),
            ],
            Row(children: [Text(hasMatches ? 'Some symptoms match' : 'Browse information', style: const TextStyle(color: _blue, fontWeight: FontWeight.w700, fontSize: 13)), const Spacer(), const Icon(Icons.arrow_forward, color: _blue, size: 18)]),
          ]),
        ),
      ),
    );
  }

  Widget _conditionPage() {
    final found = _conditions.where((item) => item['id'] == _conditionId);
    if (found.isEmpty) return const SizedBox.shrink();
    final condition = found.first;
    final refs = _references.where((ref) => (condition['references'] as List<dynamic>).contains(ref['id'])).toList();
    return SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 26, 24, 48), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton.icon(onPressed: () => setState(() => _page = 'browse'), icon: const Icon(Icons.arrow_back), label: const Text('Back to Browse')),
      const SizedBox(height: 18),
      _eyebrow('CONDITION GUIDE'),
      Text(condition['name'] as String, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 9),
      const Text('General information only. A healthcare professional is needed to assess and diagnose shoulder conditions.'),
      const SizedBox(height: 22),
      _contentSection('What is it?', [Text(condition['what'] as String), const SizedBox(height: 8), Text('Area involved: ${condition['structure']}', style: const TextStyle(fontWeight: FontWeight.w600))]),
      _contentSection('Common symptoms', _bulletList(condition['symptoms'] as List<dynamic>)),
      _contentSection('Common causes', [Text(condition['causes'] as String)]),
      _contentSection('Risk factors', _bulletList(condition['riskFactors'] as List<dynamic>)),
      _contentSection('What may make it worse?', [Text(condition['worse'] as String)]),
      _contentSection('General recovery information', [Text(condition['recovery'] as String)]),
      const SizedBox(height: 16),
      _notice('When should I seek medical care?', (condition['warningSigns'] as List<dynamic>).first as String, alert: true),
      const SizedBox(height: 20),
      _contentSection('Sources', refs.map((ref) => Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${ref['organization']}: ${ref['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('${ref['year'] ?? 'Date not listed'} · ${ref['evidenceType']}'),
        Text(ref['summary'] as String),
        TextButton.icon(onPressed: () => _openReference(ref['url'] as String), icon: const Icon(Icons.open_in_new, size: 16), label: const Text('Open source')),
      ]))).toList()),
      const SizedBox(height: 12),
      const Text('The matching weights are placeholders and have not been clinically validated.', style: TextStyle(fontSize: 13, color: _muted)),
    ]));
  }

  Widget _warningCard() {
    final emergency = _isEmergency;
    final color = emergency ? const Color(0xFFFFD1D1) : const Color(0xFFFFD4A3);
    return Semantics(
      liveRegion: true,
      label: emergency ? 'Emergency warning. Call 911 now. Chest pain or trouble breathing may be an emergency.' : 'Prompt care warning. Contact a healthcare professional or urgent care service now.',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: emergency ? const Color(0xFF351A20) : const Color(0xFF35291A), border: Border.all(color: emergency ? const Color(0xFFB74651) : const Color(0xFFC98337), width: 1.5), borderRadius: BorderRadius.circular(13)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(emergency ? Icons.emergency : Icons.warning_amber_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(emergency ? 'Call 911 now.' : 'Please seek prompt medical assessment.', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 5),
            Text(emergency ? 'Chest pain or trouble breathing can be an emergency. Do not wait for these symptom matches.' : 'One or more signs you selected can need urgent attention, especially after an injury. Contact a healthcare professional or urgent care service now. If symptoms become severe or you feel unsafe, call 911.', style: TextStyle(color: color, height: 1.5)),
          ])),
          IconButton(tooltip: 'Clear urgent signs', onPressed: () => setState(_urgent.clear), icon: Icon(Icons.close, color: color)),
        ]),
      ),
    );
  }

  Widget _emptyResults() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: _surface, border: Border.all(color: _line), borderRadius: BorderRadius.circular(13)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.search_off, color: _blue, size: 27),
          SizedBox(height: 10),
          Text('No conditions found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
          SizedBox(height: 6),
          Text('Try a different search or reset some filters.', style: TextStyle(color: _muted)),
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
      ? [const Text('Known risk factors are not listed in the sources attached to this entry.')]
      : lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('•  ', style: TextStyle(fontWeight: FontWeight.w800)), Expanded(child: Text(line as String))]))).toList();

  Widget _notice(String title, String body, {bool alert = false}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(19),
        decoration: BoxDecoration(color: alert ? const Color(0xFF202735) : _surface, border: Border.all(color: alert ? const Color(0xFF46536A) : _line), borderRadius: BorderRadius.circular(13)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(alert ? Icons.info_outline : Icons.info, color: _blue),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 6), Text(body, style: const TextStyle(color: _muted, height: 1.5))])),
        ]),
      );

  Widget _eyebrow(String text) => Padding(padding: const EdgeInsets.only(bottom: 11), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: _muted)));

  Widget _footer() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        decoration: const BoxDecoration(color: Color(0xFF121721), border: Border(top: BorderSide(color: _line))),
        child: const Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 7, children: [
          Text('Shoulder Guide · General information only', style: TextStyle(fontWeight: FontWeight.w700, color: _ink, fontSize: 12)),
          Text('This tool cannot diagnose or replace professional advice.', style: TextStyle(color: _muted, fontSize: 12)),
        ]),
      );
}
