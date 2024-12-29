import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../note_editor/note_editor_page.dart';
import 'package:test_note/search_page/search_page.dart';
import 'package:test_note/tags_page/tags_page.dart';

class NotesHomePage extends StatefulWidget {
  const NotesHomePage({Key? key}) : super(key: key);

  @override
  State<NotesHomePage> createState() => _NotesHomePageState();
}

class _NotesHomePageState extends State<NotesHomePage> {
  late Future<Database> _myDatabase;
  bool _isGridView = true;
  bool _isSelecting = false;
  List<bool> _selectedNotes = [];
  List<Map<String, dynamic>> _notes = [];
  bool _isLoading = true;
  int _selectedIndex = 0;
  late Future<List<Map<String, dynamic>>> _notesFuture;

  @override
  void initState() {
    super.initState();
    _myDatabase = _initDatabase();
    _notesFuture = _loadNotes();
    syncWithFirebase(_myDatabase).then((_) => setState(() {}));
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final db = await _myDatabase;
      final List<Map<String, dynamic>> notes = await db.query(
        'notes',
        orderBy: 'updated_at DESC',
      );

      setState(() {
        _notes = notes;
        _selectedNotes = List.filled(notes.length, false);
        _isLoading = false;
      });
      return notes; // Trả về notes thay vì void
    } catch (e) {
      print('Error loading notes: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: $e')),
        );
      }
      return []; // Trả về list rỗng trong trường hợp có lỗi
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[200],
        title: const Text('My Notes'),
        actions: [
          if (_isSelecting)
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    '${_selectedNotes
                        .where((selected) => selected)
                        .length} selected',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    await _deleteSelectedNotes();
                    await _loadNotes();
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
            itemBuilder: (context) =>
            [
              PopupMenuItem(
                value: 'view_toggle',
                child: ListTile(
                  leading: Icon(_isGridView ? Icons.list : Icons.grid_view),
                  title: Text(_isGridView ? 'View as List' : 'View as Grid'),
                ),
              ),
              PopupMenuItem(
                value: 'select_notes',
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(
                      _isSelecting ? 'Cancel Selection' : 'Select Notes'),
                ),
              ),
              const PopupMenuItem(
                value: 'sync_now',
                child: ListTile(
                  leading: Icon(Icons.sync),
                  title: Text('Sync Now'),
                ),
              ),
            ],
            onSelected: (value) async {
              switch (value) {
                case 'view_toggle':
                  setState(() => _isGridView = !_isGridView);
                  break;
                case 'select_notes':
                  setState(() => _isSelecting = !_isSelecting);
                  break;
                case 'sync_now':
                  await manualSync();
                  break;
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
          ? _buildEmptyState()
          : _isGridView
          ? _buildGridView()
          : _buildListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewNote,
        backgroundColor: Colors.blueGrey[200],
        child: const Icon(Icons.edit_note, color: Colors.black87, size: 30),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
      ),
      itemCount: _notes.length,
      itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _notes.length,
      itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
    );
  }

  Widget _buildNoteCard(Map<String, dynamic> note, int index) {
    // Process images
    List<String> imagesList = [];
    if (note['images'] != null && note['images']
        .toString()
        .isNotEmpty) {
      imagesList = note['images'].toString().split(',');
    }

    // Process dates
    DateTime? updatedAt = note['updated_at'] != null
        ? DateTime.parse(note['updated_at'])
        : null;
    DateTime? createdAt = note['created_at'] != null
        ? DateTime.parse(note['created_at'])
        : null;

    // Process tags
    List<String> tagList = [];
    if (note['tags'] != null && note['tags']
        .toString()
        .isNotEmpty) {
      tagList = note['tags'].toString().split(',')
          .where((tag) => tag.isNotEmpty)
          .toList();
    }

    // Process checklist
    List<ChecklistItem> checklistItems = [];
    if (note['checklist'] != null) {
      final List<dynamic> checklistData = json.decode(
          note['checklist'] as String);
      checklistItems = checklistData.map((item) =>
          ChecklistItem(
            text: item['text']?.toString() ?? '',
            isChecked: item['isChecked'] as bool? ?? false,
          )).toList();
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
          _openNote(note);
        }
      },
      child: Card(
        color: Color(note['color'] ?? Colors.white.value),
        child: Container(
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
                  if (imagesList.isNotEmpty)
                    SizedBox(
                      height: _isGridView ? 50 : 100,
                      child: imagesList.length == 1
                          ? _buildSingleImage(imagesList[0])
                          : _buildImageList(imagesList),
                    ),

                  Flexible(
                    fit: FlexFit.loose,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleRow(note['title'], index),
                          const SizedBox(height: 4),
                          _buildDescription(note['description']),
                          if (checklistItems.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${checklistItems
                                  .where((item) => item.isChecked)
                                  .length}/${checklistItems
                                  .length} items completed',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                          if (tagList.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _buildTagsList(tagList),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 8,
                bottom: 8,
                child: Text(
                  updatedAt != null
                      ? 'Updated: ${_getFormattedDate(updatedAt)}'
                      : 'Created: ${_getFormattedDate(createdAt)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widgets and methods for note card
  Widget _buildSingleImage(String imagePath) {
    return Image.file(
      File(imagePath),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (context, error, stackTrace) =>
      const Icon(Icons.broken_image, size: 50),
    );
  }

  Widget _buildImageList(List<String> images) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: images.length,
      itemBuilder: (context, imgIndex) =>
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Image.file(
              File(images[imgIndex]),
              fit: BoxFit.cover,
              width: _isGridView ? 50 : 150,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 50),
            ),
          ),
    );
  }

  Widget _buildTitleRow(String? title, int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title ?? 'Untitled',
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
    );
  }

  Widget _buildDescription(String? description) {
    return Text(
      description ?? 'No Description',
      maxLines: _isGridView ? 2 : 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: _isGridView ? 12 : 14),
    );
  }

  Widget _buildTagsList(List<String> tags) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: tags.map((tag) =>
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
    );
  }

  String _getFormattedDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute
        .toString().padLeft(2, '0')}';
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
      selectedItemColor: Colors.blueGrey,
      unselectedItemColor: Colors.grey,
      onTap: _handleBottomNavigation,
    );
  }

  void _handleBottomNavigation(int index) {
    setState(() => _selectedIndex = index);

    if (index == 1) {
      _navigateWithSlideTransition(SearchPage());
    } else if (index == 2) {
      _navigateWithSlideTransition(const TagsPage());
    }
  }

  void _navigateWithSlideTransition(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbPath = path.join(documentsDirectory.path, 'noteCK.db');
    return openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT,
            description TEXT,
            elements TEXT,
            images TEXT,
            reminder TEXT,
            color INTEGER,
            tags TEXT,
            checklist TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  void _addNewNote() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteEditor(myDatabase: _myDatabase),
      ),
    );
    await _loadNotes();
  }

  Future<void> _openNote(Map<String, dynamic> note) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NoteEditor(
              myDatabase: _myDatabase,
              note: note,
            ),
      ),
    );
    await _loadNotes();
  }

  Future<void> _deleteSelectedNotes() async {
    final db = await _myDatabase;

    try {
      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: const Text('Delete Notes'),
              content: const Text(
                  'Are you sure you want to delete the selected notes?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
      );

      if (confirm != true) return;

      await db.transaction((txn) async {
        for (int i = 0; i < _notes.length; i++) {
          if (_selectedNotes[i]) {
            // Delete associated images
            if (_notes[i]['images'] != null && _notes[i]['images']
                .toString()
                .isNotEmpty) {
              final imagePaths = _notes[i]['images'].toString().split(',');
              for (final imagePath in imagePaths) {
                if (imagePath.isNotEmpty) {
                  final file = File(imagePath);
                  if (await file.exists()) {
                    await file.delete();
                  }
                }
              }
            }

            // Delete note from database
            await txn.delete(
              'notes',
              where: 'id = ?',
              whereArgs: [_notes[i]['id']],
            );
          }
        }
      });

      setState(() {
        _isSelecting = false;
        _selectedNotes = List.filled(_notes.length, false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes deleted successfully')),
      );
    } catch (e) {
      print('Error deleting notes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting notes: $e')),
      );
    }
  }

  Future<bool> checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  // Firebase sync functionality
  Future<void> manualSync() async {
    // Kiểm tra kết nối internet
    bool isConnected = await checkInternetConnection();

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection. Please check your network and try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Hiển thị dialog loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Center(
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
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      // Thử kết nối Firebase
      bool isFirebaseAvailable = await _checkFirebaseConnection();
      if (!isFirebaseAvailable) {
        throw Exception('Cannot connect to Firebase. Please try again later.');
      }

      await syncWithFirebase(_myDatabase);

      // Đóng dialog loading
      if (context.mounted) Navigator.pop(context);

      // Hiển thị thông báo thành công
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      setState(() {}); // Cập nhật UI
    } catch (e) {
      // Đóng dialog loading
      if (context.mounted) Navigator.pop(context);

      // Hiển thị thông báo lỗi
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<bool> _checkFirebaseConnection() async {
    try {
      // Thử thực hiện một truy vấn đơn giản để kiểm tra kết nối
      final firestore = FirebaseFirestore.instance;
      await firestore.collection('notes').limit(1).get();
      return true;
    } catch (e) {
      print('Firebase connection check failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> fetchNotesFromFirebase() async {
    final firestore = FirebaseFirestore.instance;
    final snapshot = await firestore.collection('notes').get();

    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());

      // Chuyển đổi các trường số thành string
      if (data['id'] != null) data['id'] = data['id'].toString();
      if (data['color'] != null) data['color'] = data['color'].toString();

      return data;
    }).toList();
  }

  Future<void> pushNoteToFirebase(Map<String, dynamic> note) async {
    final firestore = FirebaseFirestore.instance;

    try {
      // Create a copy of the note to modify
      final noteToSync = Map<String, dynamic>.from(note);

      // Convert id to string if it exists
      if (noteToSync['id'] != null) {
        noteToSync['id'] = noteToSync['id'].toString();
      }

      // Convert other numeric fields to appropriate types if needed
      if (noteToSync['color'] != null) {
        noteToSync['color'] = noteToSync['color'].toString();
      }

      if (noteToSync['id'] != null) {
        await firestore.collection('notes').doc(noteToSync['id']).set(noteToSync);
      } else {
        await firestore.collection('notes').add(noteToSync);
      }
    } catch (e) {
      print('Error pushing note to Firebase: $e');
      throw e; // Re-throw to handle in UI
    }
  }

  Future<void> syncWithFirebase(Future<Database> database) async {
    if (!await checkInternetConnection()) {
      throw Exception('No internet connection');
    }

    final db = await database;

    try {
      final notesFromSQLite = await db.query('notes');
      final notesFromFirebase = await fetchNotesFromFirebase();

      // Sync Firebase -> SQLite
      for (final firebaseNote in notesFromFirebase) {
        try {
          final existsInSQLite = notesFromSQLite.any((sqliteNote) =>
          sqliteNote['id'].toString() == firebaseNote['id'].toString());

          if (!existsInSQLite) {
            int? color;
            if (firebaseNote['color'] != null) {
              color = int.tryParse(firebaseNote['color'].toString());
            }

            await db.insert(
              'notes',
              {
                'id': int.parse(firebaseNote['id']),
                'title': firebaseNote['title'],
                'description': firebaseNote['description'],
                'elements': firebaseNote['elements'],
                'images': firebaseNote['images'],
                'reminder': firebaseNote['reminder'],
                'color': color,
                'checklist': firebaseNote['checklist'],
                'tags': firebaseNote['tags'],
                'created_at': firebaseNote['created_at'],
                'updated_at': firebaseNote['updated_at'],
              },
            );
          }
        } catch (e) {
          print('Error syncing Firebase note to SQLite: $e');
          continue;
        }
      }

      // Sync SQLite -> Firebase
      for (final sqliteNote in notesFromSQLite) {
        try {
          final existsInFirebase = notesFromFirebase.any((firebaseNote) =>
          firebaseNote['id'].toString() == sqliteNote['id'].toString());

          if (!existsInFirebase) {
            await pushNoteToFirebase(sqliteNote);
          }
        } catch (e) {
          print('Error syncing SQLite note to Firebase: $e');
          continue;
        }
      }
    } catch (e) {
      print('General sync error: $e');
      throw Exception('Sync failed: ${e.toString()}');
    }
  }
}

// Helper class for checklist items
class ChecklistItem {
  final String text;
  final bool isChecked;

  ChecklistItem({
    required this.text,
    required this.isChecked,
  });
}