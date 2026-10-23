import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoteCraftApp());
}

class NoteCraftApp extends StatelessWidget {
  const NoteCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NoteCraft',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF5A6B5C),
          onPrimary: Color(0xFFF4F6F8),
          surface: Color(0xFFF4F6F8),
          onSurface: Color(0xFF12161C),
          surfaceContainerHighest: Color(0xFFE8EBEE),
        ),
        scaffoldBackgroundColor: const Color(0xFFE8EBEE),
        fontFamily: 'Roboto',
      ),
      home: const NotesHome(),
    );
  }
}

class Note {
  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updated,
    this.pinned = false,
    this.archived = false,
    this.tags = const [],
  });

  final String id;
  String title;
  String body;
  DateTime updated;
  bool pinned;
  bool archived;
  List<String> tags;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updated': updated.toIso8601String(),
        'pinned': pinned,
        'archived': archived,
        'tags': tags,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        updated: DateTime.tryParse(j['updated'] as String? ?? '') ?? DateTime.now(),
        pinned: j['pinned'] as bool? ?? false,
        archived: j['archived'] as bool? ?? false,
        tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

class NotesHome extends StatefulWidget {
  const NotesHome({super.key});
  @override
  State<NotesHome> createState() => _NotesHomeState();
}

class _NotesHomeState extends State<NotesHome> {
  final List<Note> _notes = [];
  String _query = '';
  String? _tagFilter;
  bool _showArchived = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('notecraft.notes');
    if (raw != null) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _notes
        ..clear()
        ..addAll(list.map(Note.fromJson));
    } else {
      _notes.addAll([
        Note(
          id: '1',
          title: 'Welcome to NoteCraft',
          body:
              'Local-first notes with tags, pins, archive, and JSON export.\n\n#ship #flutter',
          updated: DateTime.now(),
          pinned: true,
          tags: ['ship', 'flutter'],
        ),
        Note(
          id: '2',
          title: 'Ship checklist',
          body: '- README\n- Screenshots\n- Web build for Pages\n\n#ops',
          updated: DateTime.now().subtract(const Duration(hours: 2)),
          tags: ['ops'],
        ),
      ]);
      await _persist();
    }
    _sort();
    setState(() => _loading = false);
  }

  void _sort() {
    _notes.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updated.compareTo(a.updated);
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notecraft.notes', jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  List<String> get _allTags {
    final set = <String>{};
    for (final n in _notes) {
      set.addAll(n.tags);
    }
    final list = set.toList()..sort();
    return list;
  }

  List<Note> get _filtered {
    final q = _query.trim().toLowerCase();
    return _notes.where((n) {
      if (n.archived != _showArchived) return false;
      if (_tagFilter != null && !n.tags.contains(_tagFilter)) return false;
      if (q.isEmpty) return true;
      return n.title.toLowerCase().contains(q) ||
          n.body.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  List<String> _extractTags(String body) {
    final re = RegExp(r'#([A-Za-z0-9_-]+)');
    return re.allMatches(body).map((m) => m.group(1)!.toLowerCase()).toSet().toList();
  }

  Future<void> _edit([Note? existing]) async {
    final note = existing ??
        Note(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: '',
          body: '',
          updated: DateTime.now(),
        );
    final titleCtrl = TextEditingController(text: note.title);
    final bodyCtrl = TextEditingController(text: note.body);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditor(
          titleCtrl: titleCtrl,
          bodyCtrl: bodyCtrl,
          isNew: existing == null,
          pinned: note.pinned,
          onTogglePin: (v) => note.pinned = v,
        ),
      ),
    );
    if (saved == true) {
      setState(() {
        note.title = titleCtrl.text.trim().isEmpty ? 'Untitled' : titleCtrl.text.trim();
        note.body = bodyCtrl.text;
        note.tags = _extractTags(note.body);
        note.updated = DateTime.now();
        if (existing == null) _notes.insert(0, note);
        _sort();
      });
      await _persist();
    }
  }

  Future<void> _delete(Note n) async {
    setState(() => _notes.removeWhere((x) => x.id == n.id));
    await _persist();
  }

  Future<void> _archive(Note n) async {
    setState(() {
      n.archived = !n.archived;
      n.updated = DateTime.now();
      _sort();
    });
    await _persist();
  }

  Future<void> _togglePin(Note n) async {
    setState(() {
      n.pinned = !n.pinned;
      _sort();
    });
    await _persist();
  }

  Future<void> _export() async {
    final payload = const JsonEncoder.withIndent('  ').convert(_notes.map((n) => n.toJson()).toList());
    await Clipboard.setData(ClipboardData(text: payload));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notes JSON copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NoteCraft', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Active notes' : 'Archive',
            onPressed: () => setState(() => _showArchived = !_showArchived),
            icon: Icon(_showArchived ? Icons.inbox_outlined : Icons.archive_outlined),
          ),
          IconButton(tooltip: 'Export JSON', onPressed: _export, icon: const Icon(Icons.ios_share_outlined)),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_allTags.isEmpty ? 56 : 104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search notes or #tags…',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.75),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ),
              if (_allTags.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('all'),
                          selected: _tagFilter == null,
                          onSelected: (_) => setState(() => _tagFilter = null),
                        ),
                      ),
                      ..._allTags.map(
                        (t) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text('#$t'),
                            selected: _tagFilter == t,
                            onSelected: (_) => setState(() => _tagFilter = t),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Note'),
        backgroundColor: const Color(0xFF12161C),
        foregroundColor: const Color(0xFFF4F6F8),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(child: Text(_showArchived ? 'Archive empty' : 'No notes yet', style: TextStyle(color: cs.onSurface.withOpacity(0.5))))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: _filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final n = _filtered[i];
                    return Dismissible(
                      key: ValueKey(n.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(color: const Color(0xFF8B3A3A), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      onDismissed: (_) => _delete(n),
                      child: Material(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _edit(n),
                          onLongPress: () => _togglePin(n),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (n.pinned)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.push_pin, size: 16, color: Color(0xFF5A6B5C)),
                                      ),
                                    Expanded(
                                      child: Text(n.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _archive(n),
                                      icon: Icon(n.archived ? Icons.unarchive_outlined : Icons.archive_outlined, size: 20),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  n.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurface.withOpacity(0.62), height: 1.35),
                                ),
                                if (n.tags.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 6,
                                    children: n.tags
                                        .map((t) => Text('#$t', style: const TextStyle(fontSize: 12, color: Color(0xFF5A6B5C), fontFamily: 'monospace')))
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Text(
                                  _fmt(n.updated),
                                  style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.45)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  String _fmt(DateTime d) {
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class NoteEditor extends StatefulWidget {
  const NoteEditor({
    super.key,
    required this.titleCtrl,
    required this.bodyCtrl,
    required this.isNew,
    required this.pinned,
    required this.onTogglePin,
  });
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final bool isNew;
  final bool pinned;
  final ValueChanged<bool> onTogglePin;

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  late bool pinned;
  bool preview = false;

  @override
  void initState() {
    super.initState();
    pinned = widget.pinned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New note' : 'Edit'),
        actions: [
          IconButton(
            tooltip: pinned ? 'Unpin' : 'Pin',
            onPressed: () {
              setState(() => pinned = !pinned);
              widget.onTogglePin(pinned);
            },
            icon: Icon(pinned ? Icons.push_pin : Icons.push_pin_outlined),
          ),
          IconButton(
            tooltip: preview ? 'Edit' : 'Preview',
            onPressed: () => setState(() => preview = !preview),
            icon: Icon(preview ? Icons.edit_outlined : Icons.visibility_outlined),
          ),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: widget.titleCtrl,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
            ),
            const Divider(),
            Expanded(
              child: preview
                  ? SingleChildScrollView(
                      child: Text(
                        widget.bodyCtrl.text.isEmpty ? 'Nothing to preview' : widget.bodyCtrl.text,
                        style: const TextStyle(height: 1.5, fontSize: 16),
                      ),
                    )
                  : TextField(
                      controller: widget.bodyCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: 'Write… use #tags in the body',
                        border: InputBorder.none,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
