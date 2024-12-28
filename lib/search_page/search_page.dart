import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:test_note/note_editor/note_editor_page.dart';


class SearchPage extends StatefulWidget {
  const SearchPage();

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedTag = '';
  List<Map<String, dynamic>> _notes = [];
  List<String> _availableTags = [];
  late Future<Database> _myDatabase;

  @override
  void initState() {
    super.initState();
    _myDatabase = _initDatabase();
    _fetchAvailableTags();
    _fetchNotes();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Notes'),backgroundColor: Colors.blueGrey[200]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search by keyword',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => _fetchNotes(),
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: _selectedTag.isEmpty ? null : _selectedTag,
              hint: const Text('Filter by tag'),
              items: _availableTags
                  .map((tag) => DropdownMenuItem(
                value: tag,
                child: Text(tag),
              ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedTag = value ?? '';
                });
                _fetchNotes();
              },
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _notes.isEmpty
                  ? const Center(child: Text('No notes found'))
                  : ListView.builder(
                itemCount: _notes.length,
                itemBuilder: (context, index) {
                  final note = _notes[index];
                  return Card(
                    color: Color(note['color'] ?? Colors.white.value),
                    child: ListTile(
                      title: Text(note['title'] ?? 'No Title'),
                      subtitle: Text(note['created_at'] ?? 'No created_at'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => NoteEditor(
                              myDatabase: _myDatabase,
                              note: note,
                            ),
                          ),
                        );
                      },
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

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'note_app.db');
    return openDatabase(path, version: 1);
  }

  Future<void> _fetchAvailableTags() async {
    final db = await _myDatabase;
    final result = await db.rawQuery('SELECT DISTINCT tags FROM notes');
    setState(() {
      _availableTags = result
          .expand((row) {
        // Kiểm tra nếu `row['tags']` là String, nếu không trả về danh sách rỗng
        if (row['tags'] is String) {
          return (row['tags'] as String).split(',');
        } else {
          return [];
        }
      })
          .where((tag) => tag.isNotEmpty) // Lọc các tag rỗng
          .map((tag) => tag.toString()) // Đảm bảo tất cả là String
          .toSet()
          .toList(); // Loại bỏ các phần tử trùng lặp
    });
  }


  Future<void> _fetchNotes() async {
    final db = await _myDatabase;
    final keyword = _searchController.text.trim();
    final tag = _selectedTag;

    String whereClause = '';
    List<String> whereArgs = [];

    if (keyword.isNotEmpty) {
      whereClause += '(title LIKE ? OR description LIKE ?)';
      whereArgs.addAll(['%$keyword%', '%$keyword%']);
    }

    if (tag.isNotEmpty) {
      if (whereClause.isNotEmpty) {
        whereClause += ' AND ';
      }
      whereClause += 'tags LIKE ?';
      whereArgs.add('%$tag%');
    }

    final result = await db.query(
      'notes',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
    );

    setState(() {
      _notes = result;
    });
  }
}