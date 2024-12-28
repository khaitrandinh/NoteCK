import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:test_note/note_editor/note_editor_page.dart';


class TagsPage extends StatefulWidget {
  const TagsPage({Key? key}) : super(key: key);

  @override
  _TagsPageState createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  late Future<Database> _myDatabase;
  List<String> _availableTags = [];
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    _myDatabase = _initDatabase();
    _fetchAvailableTags();
  }

  // Initialize database


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
        backgroundColor: Colors.blueGrey[200],
        elevation: 0,
      ),
      body: _availableTags.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _availableTags.length,
        itemBuilder: (context, index) {
          final tag = _availableTags[index];
          return ListTile(
            leading: const Icon(Icons.label_outline, color: Colors.grey),
            title: Text(tag),
            trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
            onTap: () async {
              // Fetch notes when tag is tapped
              await _fetchNotesByTag(tag);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => NotesListPage(
                    notes: _notes,
                    tag: tag,
                    myDatabase: _myDatabase,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'note_app.db');
    return openDatabase(path, version: 1);
  }

  // Fetch available tags from the database
  Future<void> _fetchAvailableTags() async {
    final db = await _myDatabase;
    final result = await db.rawQuery('SELECT DISTINCT tags FROM notes');

    setState(() {
      _availableTags = result
          .expand((row) {
        // Kiểm tra nếu row['tags'] là String và tách nó thành danh sách
        if (row['tags'] is String) {
          return (row['tags'] as String).split(',');
        } else {
          return [];
        }
      })
          .where((tag) => tag.isNotEmpty) // Lọc các tag rỗng
          .map((tag) => tag.toString()) // Đảm bảo rằng tất cả là String
          .toSet()
          .toList(); // Chuyển về List<String>
    });
  }


  // Fetch notes based on the selected tag
  Future<void> _fetchNotesByTag(String tag) async {
    final db = await _myDatabase;
    final result = await db.query(
      'notes',
      where: 'tags LIKE ?',
      whereArgs: ['%$tag%'],
    );
    setState(() {
      _notes = result;
    });
  }
}

// Cập nhật constructor của NotesListPage để nhận _myDatabase
class NotesListPage extends StatelessWidget {
  final List<Map<String, dynamic>> notes;
  final String tag;
  final Future<Database> myDatabase; // Thêm _myDatabase vào đây

  const NotesListPage({
    Key? key,
    required this.notes,
    required this.tag,
    required this.myDatabase, // Truyền myDatabase vào constructor
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Notes for Tag: $tag')),
      body: notes.isEmpty
          ? const Center(child: Text('No notes found for this tag'))
          : ListView.builder(
        itemCount: notes.length,
        itemBuilder: (context, index) {
          final note = notes[index];
          return Card(
            color: Color(note['color'] ?? Colors.white.value),
            child: ListTile(
              title: Text(note['title'] ?? 'No Title'),
              subtitle: Text(note['created_at'] ?? 'No created_at'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => NoteEditor(
                      myDatabase: myDatabase, // Truyền myDatabase vào NoteEditor
                      note: note,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}