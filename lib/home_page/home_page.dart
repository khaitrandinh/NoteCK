import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' show join;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../note_editor/note_editor_page.dart';
import 'package:test_note/search_page/search_page.dart';
import 'package:test_note/tags_page/tags_page.dart';

class HomePage extends StatefulWidget {
  const HomePage();

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<Database> _myDatabase;
  bool _isGridView = true;
  bool _isSelecting = false;
  List<bool> _selectedNotes = [];
  List<Map<String, dynamic>> _notes = [];
  int _selectedIndex = 0;
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _myDatabase = _initDatabase();
    _notesFuture = _fetchNotes();
    syncWithFirebase(_myDatabase).then((_) => setState(() {}));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blueGrey[200],
          title: const Text('Home Notes'),
          actions: [
            if (_isSelecting)
              Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      '${_selectedNotes.where((selected) => selected).length} selected', // Hiển thị số lượng ghi chú đã chọn
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      await _deleteSelectedNotes();
                      _refreshNotes(); // Refresh sau khi xóa
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () {
                      setState(() {
                        _isSelecting = false;
                        _selectedNotes = List.filled(_notes.length, false);
                      });
                    },
                  ),
                ],
              ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view_as_list',
                  child: ListTile(
                    leading: Icon(_isGridView ? Icons.list : Icons.grid_view),
                    title: Text(_isGridView ? 'View as List' : 'View as Grid'),
                  ),
                ),
                PopupMenuItem(
                  value: 'select_notes',
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(_isSelecting ? 'Cancel Selection' : 'Select Notes'),
                  ),
                ),
                PopupMenuItem(
                  value: 'sync now',
                  child: ListTile(
                    leading: const Icon(Icons.sync),
                    title: const Text('sync now'),
                    onTap: manualSync,
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'view_as_list') {
                  setState(() {
                    _isGridView = !_isGridView; // Chuyển đổi trạng thái
                  });
                } else if (value == 'select_notes') {
                  setState(() {
                    _isSelecting = !_isSelecting; // Chuyển đổi trạng thái chọn
                  });
                }
              },
            ),

          ],
        ),
        body: FutureBuilder<List<Map<String, dynamic>>>(
          future: _fetchNotes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return _buildEmptyState();
            } else {
              _notes = snapshot.data!;
              if (_selectedNotes.length != _notes.length) {
                _selectedNotes = List.filled(_notes.length, false);
              }
              return _isGridView
                  ? GridView.builder(
                padding: const EdgeInsets.all(5.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8.0,
                  mainAxisSpacing: 8.0,

                ),

                itemCount: _notes.length,
                itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
              )
                  : ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _notes.length,
                itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
              );
            }
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addNewNote,
          backgroundColor: Colors.blueGrey[200],
          shape: const CircleBorder(),
          child: const Icon(Icons.edit_note, color: Colors.black87,size: 30,),

        ),

        bottomNavigationBar: _buildBottomNavigationBar(context)

    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.blueGrey[100],
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.tab_outlined),
          label: 'Tags',
        ),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: Colors.blueGrey, // Đảm bảo rằng màu này hoạt động
      unselectedItemColor: Colors.grey, // Thêm màu cho mục không được chọn
      onTap: (int index) {
        setState(() {
          _selectedIndex = index;
        });

        if (index == 1) {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => const SearchPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        } else if (index == 2) {
          Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => TagsPage(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(1.0, 0.0);
                const end = Offset.zero;
                const curve = Curves.easeInOut;
                var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);
                return SlideTransition(position: offsetAnimation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 300),
            ),
          );
        }
      },
    );
  }



  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.edit_note, size: 100, color: Colors.blueGrey[200]),
          const SizedBox(height: 16),
          const Text(
            'Start taking notes!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the new note button below to take a note',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }


  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    // Xử lý danh sách ảnh
    List<String> imagesList = [];
    if (note['images'] != null && note['images'].toString().isNotEmpty) {
      imagesList = note['images'].toString().split(',');
    }

    // Xử lý ngày tháng
    DateTime? updatedAt = note['updated_at'] != null
        ? DateTime.parse(note['updated_at'])
        : null;
    DateTime? createdAt = note['created_at'] != null
        ? DateTime.parse(note['created_at'])
        : null;

    // Xử lý tags
    List<String> tags = [];
    if (note['tags'] != null && note['tags'].toString().isNotEmpty) {
      tags = note['tags'].toString().split(',');
    }

    String getFormattedDate(DateTime? date) {
      if (date == null) return '';
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }

    return InkWell(
      onLongPress: () {
        setState(() {
          _isSelecting = true;
          _selectedNotes[index] = true;
        });
      },
      onTap: () {
        if (_isSelecting) {
          setState(() {
            _selectedNotes[index] = !_selectedNotes[index];
            if (!_selectedNotes.contains(true)) {
              _isSelecting = false;
            }
          });
        } else {
          _editNote(note);
        }
      },
      child: Card(
        color: Color(note['color'] ?? Colors.white),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              constraints: BoxConstraints(
                minHeight: _isGridView ? 200 : 100,
                maxHeight: _isGridView ? 200 : double.infinity,
              ),
              child: Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image section
                      if (imagesList.isNotEmpty)
                        Container(
                          height: _isGridView ? 50 : 100,
                          child: imagesList.length == 1
                              ? Image.file(
                            File(imagesList[0]),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 50),
                          )
                              : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: imagesList.length,
                            itemBuilder: (context, imgIndex) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Image.file(
                                File(imagesList[imgIndex]),
                                fit: BoxFit.cover,
                                width: _isGridView ? 50 : 150,
                                errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image, size: 50),
                              ),
                            ),
                          ),
                        ),

                      // Content section
                      Flexible(
                        fit: FlexFit.loose,
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row with checkbox
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      note['title'] ?? 'No Title',
                                      style: TextStyle(
                                        fontSize: _isGridView ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (_isSelecting)
                                    SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: Checkbox(
                                        value: _selectedNotes[index],
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _selectedNotes[index] = value ?? false;
                                            if (!_selectedNotes.contains(true)) {
                                              _isSelecting = false;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Description
                              Text(
                                note['description'] ?? 'No Description',
                                maxLines: _isGridView ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: _isGridView ? 12 : 14),
                              ),

                              // Tags section
                              if (tags.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 4,
                                  children: tags.map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '#$tag',
                                      style: TextStyle(
                                        fontSize: _isGridView ? 10 : 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  )).toList(),
                                ),
                              ],

                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Timestamp positioned at bottom right
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Text(
                      updatedAt != null
                          ? 'Updated: ${getFormattedDate(updatedAt)}'
                          : 'Created: ${getFormattedDate(createdAt)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }


  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'note_app.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT,
          description TEXT,
          images TEXT,
          reminder TEXT,
          color INTEGER,
          checklist TEXT,
          tags TEXT,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        )
      ''');
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchNotes() async {
    final db = await _myDatabase;
    final List<Map<String, dynamic>> notes = await db.query('notes');
    try {
      return await db.query('notes');
    } catch (e) {
      print('Error fetching notes: $e');
      return [];
    }
  }

  Future<void> _refreshNotes() async {
    setState(() {
      _notesFuture = _fetchNotes();
    });
  }


  Future<void> _deleteSelectedNotes() async {
    final db = await _myDatabase;

    try {
      // Bắt đầu transaction
      await db.transaction((txn) async {
        for (int i = 0; i < _notes.length; i++) {
          if (_selectedNotes[i]) {
            await txn.delete(
              'notes',
              where: 'id = ?',
              whereArgs: [_notes[i]['id']],
            );
          }
        }
      });

      // Reset selection state
      setState(() {
        _isSelecting = false;
        _selectedNotes = List.filled(_notes.length, false);
      });

      // Refresh notes list
      _refreshNotes();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes deleted successfully')),
      );
    } catch (e) {
      print('Error deleting notes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error deleting notes')),
      );
    }
  }

  Future<void> manualSync() async {
    // Hiển thị dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(
                  'Syncing...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      await syncWithFirebase(_myDatabase);
      Navigator.pop(context); // Đóng dialog loading

      // Hiển thị thông báo thành công
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sync completed successfully'),
          backgroundColor: Colors.green[200],
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {}); // Cập nhật UI
    } catch (e) {
      Navigator.pop(context); // Đóng dialog loading

      // Hiển thị thông báo lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: ${e.toString()}'),
          backgroundColor: Colors.red[400],
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }



  void _addNewNote() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(builder: (context) => NoteEditor(myDatabase: _myDatabase)),
    )
        .then((_) => setState(() {})); // Refresh notes list after returning
  }

  void _editNote(Map<String, dynamic> note) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            NoteEditor(myDatabase: _myDatabase, note: note),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    ).then((_) => setState(() {}));
  }

  Future<List<Map<String, dynamic>>> fetchNotesFromFirebase() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('notes').get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        ...data,
        'color': data['color'],
      };
    }).toList();
  }

// Function to push a single note to Firebase
  Future<void> pushNoteToFirebase(Map<String, dynamic> note) async {
    final firestore = FirebaseFirestore.instance;

    try {
      if (note['id'] != null) {
        await firestore.collection('notes').doc(note['id'].toString()).set(note);
      } else {
        await firestore.collection('notes').add(note);
      }
    } catch (e) {
      print('Error pushing note to Firebase: $e');
    }
  }

// Function to sync SQLite with Firebase
  Future<void> syncWithFirebase(Future<Database> database) async {
    final db = await database;
    final notesFromSQLite = await db.query('notes');
    final notesFromFirebase = await fetchNotesFromFirebase();

    // Sync Firebase -> SQLite
    for (final firebaseNote in notesFromFirebase) {
      final existsInSQLite = notesFromSQLite.any((sqliteNote) =>
      sqliteNote['id'].toString() == firebaseNote['id'].toString());

      if (!existsInSQLite) {
        // Insert into SQLite
        await db.insert(
          'notes',
          {
            'id': int.parse(firebaseNote['id']),
            'title': firebaseNote['title'],
            'description': firebaseNote['description'],
            'images': firebaseNote['images'],
            'reminder': firebaseNote['reminder'],
            'color': firebaseNote['color'],
            'checklist': firebaseNote['checklist'],
            'tags': firebaseNote['tags'],
            'created_at': firebaseNote['created_at'],
            'updated_at': firebaseNote['updated_at'],
          },
        );
      }
    }

    // Sync SQLite -> Firebase
    for (final sqliteNote in notesFromSQLite) {
      final existsInFirebase = notesFromFirebase.any((firebaseNote) =>
      firebaseNote['id'].toString() == sqliteNote['id'].toString());

      if (!existsInFirebase) {
        await pushNoteToFirebase(sqliteNote);
      }
    }
  }
}