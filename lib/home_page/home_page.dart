import 'dart:async';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../note_editor/note_editor_page.dart';
import 'package:test_note/search_page/search_page.dart';
import 'package:test_note/tags_page/tags_page.dart';
import 'package:test_note/utils/sync_utils.dart';

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
  List<Map<String, dynamic>> _favoriteNotes = [];
  List<Map<String, dynamic>> _regularNotes = [];

  @override
  void initState() {
    super.initState();
    _myDatabase = _initDatabase();
    _notesFuture = _loadNotes();
    _initializeData();
  }

  Future<List<Map<String, dynamic>>> _loadNotes() async {
    final db = await _myDatabase;
    final notes = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    if (mounted) {
      setState(() {
        _notes = notes;
        _favoriteNotes = notes.where((note) => note['is_favorite'] == 1).toList();
        _regularNotes = notes.where((note) => note['is_favorite'] != 1).toList();
        _selectedNotes = List.filled(notes.length, false);
      });
    }
    return notes;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueGrey[200],
        title: const Text('NoteCK'),
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
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (_favoriteNotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Favorites',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _favoriteNotes.length,
            itemBuilder: (context, index) {
              final globalIndex = _notes.indexWhere((note) => note['id'] == _favoriteNotes[index]['id']);
              return _buildNoteCard(_favoriteNotes[index], globalIndex);
            },
          ),
        ],
        if (_regularNotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.85,
            ),
            itemCount: _regularNotes.length,
            itemBuilder: (context, index) {
              final globalIndex = _notes.indexWhere((note) => note['id'] == _regularNotes[index]['id']);
              return _buildNoteCard(_regularNotes[index], globalIndex);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildListView() {
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        if (_favoriteNotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Favorites',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ..._favoriteNotes.map((note) {
            final globalIndex = _notes.indexWhere((n) => n['id'] == note['id']);
            return _buildNoteCard(note, globalIndex);
          }),
        ],
        if (_regularNotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Text(
              'Notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ..._regularNotes.map((note) {
            final globalIndex = _notes.indexWhere((n) => n['id'] == note['id']);
            return _buildNoteCard(note, globalIndex);
          }),
        ],
      ],
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
                          _buildTitleRow(note['title'], index, note),
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

  Widget _buildTitleRow(String? title, int index, Map<String, dynamic> note) {
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
            child: Transform.scale(
              scale: 0.9,
              child: Checkbox(
                activeColor: Colors.blueGrey[300],
                value: _selectedNotes[index],
                onChanged: (bool? value) {
                  setState(() {
                    _selectedNotes[index] = value ?? false;
                    if (!_selectedNotes.contains(true)) {
                      _isSelecting = false;
                    }
                  });
                },
                shape: const CircleBorder(),
              ),
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

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      // 1. Đợi đồng bộ hoàn tất trước
      await SyncUtils.syncWithFirebase(_myDatabase);

      // 2. Sau đó mới load notes
      _notes = await _loadNotes();
      _selectedNotes = List.filled(_notes.length, false);
    } catch (e) {
      print('Error initializing data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String dbPath = path.join(documentsDirectory.path, 'noteCK.db');
    return openDatabase(
      dbPath,
      version: 2, // Increment version number
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
          is_favorite INTEGER DEFAULT 0,
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
        builder: (context) => AlertDialog(
          title: const Text('Delete Notes'),
          content: const Text('Are you sure you want to delete the selected notes?'),
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

      // Keep track of deleted note IDs
      List<String> deletedNoteIds = [];

      // Start a database transaction
      await db.transaction((txn) async {
        for (int i = 0; i < _selectedNotes.length; i++) {
          if (_selectedNotes[i] && i < _notes.length) {
            // Delete associated images
            if (_notes[i]['images'] != null && _notes[i]['images'].toString().isNotEmpty) {
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

            // Delete from local database
            await txn.delete(
              'notes',
              where: 'id = ?',
              whereArgs: [_notes[i]['id']],
            );

            // Add to list of deleted note IDs
            deletedNoteIds.add(_notes[i]['id'].toString());
          }
        }
      });

      // Delete from Firebase if connected
      if (await SyncUtils.checkInternetConnection()) {
        try {
          final firestore = FirebaseFirestore.instance;
          for (String noteId in deletedNoteIds) {
            await firestore.collection('notes').doc(noteId).delete();
          }
        } catch (e) {
          print('Error deleting notes from Firebase: $e');
          // Don't throw here - we want to continue even if Firebase sync fails
        }
      }

      // Update local state
      setState(() {
        // Remove deleted notes from the list
        _notes = _notes.where((note) => !deletedNoteIds.contains(note['id'].toString())).toList();
        // Reset selection state
        _selectedNotes = List.filled(_notes.length, false);
        _isSelecting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notes deleted successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Refresh notes list
      _notes = await _loadNotes();
      setState(() {
        _selectedNotes = List.filled(_notes.length, false);
      });

    } catch (e) {
      print('Error deleting notes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting notes: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }



  // Firebase sync functionality
  Future<void> manualSync() async {
    // Kiểm tra kết nối internet
    bool isConnected = await SyncUtils.checkInternetConnection();

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blueGrey)),
                  const SizedBox(height: 20),
                  Text(
                    'Syncing...',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.w600, // Semi-bold
                      color: Colors.blueGrey,
                      letterSpacing: 1.5,
                    ),
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
      bool isFirebaseAvailable = await SyncUtils.checkFirebaseConnection();
      if (!isFirebaseAvailable) {
        throw Exception('Cannot connect to Firebase. Please try again later.');
      }

      await SyncUtils.syncWithFirebase(_myDatabase);

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