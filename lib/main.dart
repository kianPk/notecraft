import 'dart:convert';
import 'package:flutter/material.dart';
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
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD4A574),
          brightness: Brightness.dark,
          surface: const Color(0xFF161310),
        ),
        scaffoldBackgroundColor: const Color(0xFF12100E),
        fontFamily: 'Roboto',
      ),
      home: const NotesHome(),
    );
  }
}

class Note {
  Note({required this.id, required this.title, required this.body, required this.updated});
  final String id;
  String title;
  String body;
  DateTime updated;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'updated': updated.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        updated: DateTime.tryParse(j['updated'] as String? ?? '') ?? DateTime.now(),
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
      _notes.sort((a, b) => b.updated.compareTo(a.updated));
    } else {
      _notes.addAll([
        Note(
          id: '1',
          title: 'Welcome to NoteCraft',
          body: 'A fast Flutter notes app — local-first, offline, no account.\n\nTap + to create.',
          updated: DateTime.now(),
        ),
        Note(
          id: '2',
          title: 'Ship checklist',
          body: '- README\n- Screenshots\n- Web build for Pages',
          updated: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ]);
      await _persist();
    }
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notecraft.notes', jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  List<Note> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _notes;
    return _notes
        .where((n) => n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _edit([Note? existing]) async {
    final note = existing ??
        Note(id: DateTime.now().millisecondsSinceEpoch.toString(), title: '', body: '', updated: DateTime.now());
    final titleCtrl = TextEditingController(text: note.title);
    final bodyCtrl = TextEditingController(text: note.body);
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditor(titleCtrl: titleCtrl, bodyCtrl: bodyCtrl, isNew: existing == null),
      ),
    );
    if (saved == true) {
      setState(() {
        note.title = titleCtrl.text.trim().isEmpty ? 'Untitled' : titleCtrl.text.trim();
        note.body = bodyCtrl.text;
        note.updated = DateTime.now();
        if (existing == null) _notes.insert(0, note);
        _notes.sort((a, b) => b.updated.compareTo(a.updated));
      });
      await _persist();
    }
  }

  Future<void> _delete(Note n) async {
    setState(() => _notes.removeWhere((x) => x.id == n.id));
    await _persist();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NoteCraft', style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.5)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.45),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Note'),
        backgroundColor: const Color(0xFFD4A574),
        foregroundColor: const Color(0xFF1A120C),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filtered.isEmpty
              ? Center(child: Text('No notes yet', style: TextStyle(color: cs.onSurfaceVariant)))
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
                        decoration: BoxDecoration(color: Colors.red.shade800, borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline),
                      ),
                      onDismissed: (_) => _delete(n),
                      child: Material(
                        color: cs.surfaceContainerHighest.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _edit(n),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text(
                                  n.body,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _fmt(n.updated),
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant.withOpacity(0.7)),
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

class NoteEditor extends StatelessWidget {
  const NoteEditor({super.key, required this.titleCtrl, required this.bodyCtrl, required this.isNew});
  final TextEditingController titleCtrl;
  final TextEditingController bodyCtrl;
  final bool isNew;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'New note' : 'Edit'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: 'Title', border: InputBorder.none),
            ),
            const Divider(),
            Expanded(
              child: TextField(
                controller: bodyCtrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(hintText: 'Write…', border: InputBorder.none),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
