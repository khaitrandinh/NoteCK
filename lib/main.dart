import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:test_note/home_page/home_page.dart';
import 'package:test_note/search_page/search_page.dart';
import 'package:test_note/tags_page/tags_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(
    initialRoute: '/',
    routes: {
      '/': (context) => const NotesHomePage(),
      '/search': (context) => const SearchPage(),
      '/tags': (context) => const TagsPage(),
    },
    // Thêm hiệu ứng chuyển trang
    theme: ThemeData(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    ),
  ));
}
//
// class HomePage extends StatefulWidget {
//   const HomePage();
//
//   @override
//   State<HomePage> createState() => _HomePageState();
// }
//
// class _HomePageState extends State<HomePage> {
//   late Future<Database> _myDatabase;
//   bool _isGridView = true;
//   bool _isSelecting = false;
//   List<bool> _selectedNotes = [];
//   List<Map<String, dynamic>> _notes = [];
//   int _selectedIndex = 0;
//   late Future<List<Map<String, dynamic>>> _notesFuture;
//
//   @override
//   void initState() {
//     super.initState();
//     _myDatabase = _initDatabase();
//     _notesFuture = _fetchNotes();
//     syncWithFirebase(_myDatabase).then((_) => setState(() {}));
//   }
//   Future<void> _refreshNotes() async {
//     setState(() {
//       _notesFuture = _fetchNotes();
//     });
//   }
//   Future<void> manualSync() async {
//     // Hiển thị dialog loading
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext context) {
//         return Center(
//           child: Container(
//             padding: const EdgeInsets.all(20),
//             decoration: BoxDecoration(
//               color: Colors.white,
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: const Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 CircularProgressIndicator(),
//                 SizedBox(height: 20),
//                 Text(
//                   'Syncing...',
//                   style: TextStyle(fontSize: 16),
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//
//     try {
//       await syncWithFirebase(_myDatabase);
//       Navigator.pop(context); // Đóng dialog loading
//
//       // Hiển thị thông báo thành công
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Sync completed successfully'),
//           backgroundColor: Colors.green,
//           duration: Duration(seconds: 2),
//         ),
//       );
//
//       setState(() {}); // Cập nhật UI
//     } catch (e) {
//       Navigator.pop(context); // Đóng dialog loading
//
//       // Hiển thị thông báo lỗi
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Sync failed: ${e.toString()}'),
//           backgroundColor: Colors.red,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//     }
//   }
//
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//         appBar: AppBar(
//           backgroundColor: Colors.blueGrey[200],
//           title: const Text('Home Notes'),
//           actions: [
//             if (_isSelecting)
//               Row(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.symmetric(horizontal: 8.0),
//                     child: Text(
//                       '${_selectedNotes.where((selected) => selected).length} selected', // Hiển thị số lượng ghi chú đã chọn
//                       style: const TextStyle(fontSize: 16),
//                     ),
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.delete),
//                     onPressed: () async {
//                       await _deleteSelectedNotes();
//                       _refreshNotes(); // Refresh sau khi xóa
//                     },
//                   ),
//                   IconButton(
//                     icon: const Icon(Icons.check),
//                     onPressed: () {
//                       setState(() {
//                         _isSelecting = false;
//                         _selectedNotes = List.filled(_notes.length, false);
//                       });
//                     },
//                   ),
//                 ],
//               ),
//             // IconButton(
//             //   icon: const Icon(Icons.sync),
//             //   onPressed: manualSync, // Manual sync trigger
//             // ),
//             PopupMenuButton<String>(
//               icon: const Icon(Icons.more_vert),
//               itemBuilder: (context) => [
//                 PopupMenuItem(
//                   value: 'view_as_list',
//                   child: ListTile(
//                     leading: Icon(_isGridView ? Icons.list : Icons.grid_view),
//                     title: Text(_isGridView ? 'View as List' : 'View as Grid'),
//                   ),
//                 ),
//                 PopupMenuItem(
//                   value: 'select_notes',
//                   child: ListTile(
//                     leading: const Icon(Icons.check_circle_outline),
//                     title: Text(_isSelecting ? 'Cancel Selection' : 'Select Notes'),
//                   ),
//                 ),
//                 PopupMenuItem(
//                   value: 'sync now',
//                   child: ListTile(
//                     leading: const Icon(Icons.sync),
//                     title: const Text('sync now'),
//                     onTap: manualSync,
//                   ),
//                 ),
//               ],
//               onSelected: (value) {
//                 if (value == 'view_as_list') {
//                   setState(() {
//                     _isGridView = !_isGridView; // Chuyển đổi trạng thái
//                   });
//                 } else if (value == 'select_notes') {
//                   setState(() {
//                     _isSelecting = !_isSelecting; // Chuyển đổi trạng thái chọn
//                   });
//                 }
//               },
//             ),
//
//           ],
//         ),
//         body: FutureBuilder<List<Map<String, dynamic>>>(
//           future: _fetchNotes(),
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting) {
//               return const Center(child: CircularProgressIndicator());
//             } else if (snapshot.hasError) {
//               return Center(child: Text('Error: ${snapshot.error}'));
//             } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
//               return _buildEmptyState();
//             } else {
//               _notes = snapshot.data!;
//               if (_selectedNotes.length != _notes.length) {
//                 _selectedNotes = List.filled(_notes.length, false);
//               }
//               return _isGridView
//                   ? GridView.builder(
//                 padding: const EdgeInsets.all(5.0),
//                 gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//                   crossAxisCount: 2,
//                   crossAxisSpacing: 8.0,
//                   mainAxisSpacing: 8.0,
//
//                 ),
//
//                 itemCount: _notes.length,
//                 itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
//               )
//                   : ListView.builder(
//                 padding: const EdgeInsets.all(8.0),
//                 itemCount: _notes.length,
//                 itemBuilder: (context, index) => _buildNoteCard(_notes[index], index),
//               );
//             }
//           },
//         ),
//         floatingActionButton: FloatingActionButton(
//           onPressed: _addNewNote,
//           backgroundColor: Colors.blueGrey[200],
//           shape: const CircleBorder(),
//           child: const Icon(Icons.edit_note, color: Colors.black87,size: 30,),
//
//         ),
//
//         bottomNavigationBar: _buildBottomNavigationBar(context)
//
//     );
//   }
//
//   Widget _buildBottomNavigationBar(BuildContext context) {
//     return BottomNavigationBar(
//       backgroundColor: Colors.blueGrey[100],
//       items: const <BottomNavigationBarItem>[
//         BottomNavigationBarItem(
//           icon: Icon(Icons.home),
//           label: 'Home',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.search),
//           label: 'Search',
//         ),
//         BottomNavigationBarItem(
//           icon: Icon(Icons.tab_outlined),
//           label: 'Tags',
//         ),
//       ],
//       currentIndex: _selectedIndex,
//       selectedItemColor: Colors.blueGrey, // Đảm bảo rằng màu này hoạt động
//       unselectedItemColor: Colors.grey, // Thêm màu cho mục không được chọn
//       onTap: (int index) {
//         setState(() {
//           _selectedIndex = index;
//         });
//
//         if (index == 1) {
//           Navigator.of(context).push(
//             PageRouteBuilder(
//               pageBuilder: (context, animation, secondaryAnimation) => const SearchPage(),
//               transitionsBuilder: (context, animation, secondaryAnimation, child) {
//                 const begin = Offset(1.0, 0.0);
//                 const end = Offset.zero;
//                 const curve = Curves.easeInOut;
//                 var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
//                 var offsetAnimation = animation.drive(tween);
//                 return SlideTransition(position: offsetAnimation, child: child);
//               },
//               transitionDuration: const Duration(milliseconds: 300),
//             ),
//           );
//         } else if (index == 2) {
//           Navigator.of(context).push(
//             PageRouteBuilder(
//               pageBuilder: (context, animation, secondaryAnimation) => TagsPage(),
//               transitionsBuilder: (context, animation, secondaryAnimation, child) {
//                 const begin = Offset(1.0, 0.0);
//                 const end = Offset.zero;
//                 const curve = Curves.easeInOut;
//                 var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
//                 var offsetAnimation = animation.drive(tween);
//                 return SlideTransition(position: offsetAnimation, child: child);
//               },
//               transitionDuration: const Duration(milliseconds: 300),
//             ),
//           );
//         }
//       },
//     );
//   }
//   Future<void> _deleteSelectedNotes() async {
//     final db = await _myDatabase;
//
//     try {
//       // Bắt đầu transaction
//       await db.transaction((txn) async {
//         for (int i = 0; i < _notes.length; i++) {
//           if (_selectedNotes[i]) {
//             await txn.delete(
//               'notes',
//               where: 'id = ?',
//               whereArgs: [_notes[i]['id']],
//             );
//           }
//         }
//       });
//
//       // Reset selection state
//       setState(() {
//         _isSelecting = false;
//         _selectedNotes = List.filled(_notes.length, false);
//       });
//
//       // Refresh notes list
//       _refreshNotes();
//
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Notes deleted successfully')),
//       );
//     } catch (e) {
//       print('Error deleting notes: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Error deleting notes')),
//       );
//     }
//   }
//
//
//   Widget _buildEmptyState() {
//     return Center(
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Icon(Icons.edit_note, size: 100, color: Colors.blueGrey[200]),
//           const SizedBox(height: 16),
//           const Text(
//             'Start taking notes!',
//             style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Tap the new note button below to take a note',
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 16, color: Colors.grey),
//           ),
//         ],
//       ),
//     );
//   }
//
//
//   Widget _buildNoteCard(Map<String, dynamic> note, int index) {
//     // Xử lý danh sách ảnh
//     List<String> imagesList = [];
//     if (note['images'] != null && note['images'].toString().isNotEmpty) {
//       imagesList = note['images'].toString().split(',');
//     }
//
//     // Xử lý ngày tháng
//     DateTime? updatedAt = note['updated_at'] != null
//         ? DateTime.parse(note['updated_at'])
//         : null;
//     DateTime? createdAt = note['created_at'] != null
//         ? DateTime.parse(note['created_at'])
//         : null;
//
//     // Xử lý tags
//     List<String> tags = [];
//     if (note['tags'] != null && note['tags'].toString().isNotEmpty) {
//       tags = note['tags'].toString().split(',');
//     }
//
//     String getFormattedDate(DateTime? date) {
//       if (date == null) return '';
//       return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
//     }
//
//     return InkWell(
//       onLongPress: () {
//         setState(() {
//           _isSelecting = true;
//           _selectedNotes[index] = true;
//         });
//       },
//       onTap: () {
//         if (_isSelecting) {
//           setState(() {
//             _selectedNotes[index] = !_selectedNotes[index];
//             if (!_selectedNotes.contains(true)) {
//               _isSelecting = false;
//             }
//           });
//         } else {
//           _editNote(note);
//         }
//       },
//       child: Card(
//         color: Color(note['color'] ?? Colors.white.value),
//         child: LayoutBuilder(
//           builder: (context, constraints) {
//             return Container(
//               constraints: BoxConstraints(
//                 minHeight: _isGridView ? 200 : 100,
//                 maxHeight: _isGridView ? 200 : double.infinity,
//               ),
//               child: Stack(
//                 children: [
//                   Column(
//                     mainAxisSize: MainAxisSize.min,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       // Image section
//                       if (imagesList.isNotEmpty)
//                         Container(
//                           height: _isGridView ? 50 : 100,
//                           child: imagesList.length == 1
//                               ? Image.file(
//                             File(imagesList[0]),
//                             fit: BoxFit.cover,
//                             width: double.infinity,
//                             errorBuilder: (context, error, stackTrace) =>
//                             const Icon(Icons.broken_image, size: 50),
//                           )
//                               : ListView.builder(
//                             scrollDirection: Axis.horizontal,
//                             itemCount: imagesList.length,
//                             itemBuilder: (context, imgIndex) => Padding(
//                               padding: const EdgeInsets.only(right: 8.0),
//                               child: Image.file(
//                                 File(imagesList[imgIndex]),
//                                 fit: BoxFit.cover,
//                                 width: _isGridView ? 50 : 150,
//                                 errorBuilder: (context, error, stackTrace) =>
//                                 const Icon(Icons.broken_image, size: 50),
//                               ),
//                             ),
//                           ),
//                         ),
//
//                       // Content section
//                       Flexible(
//                         fit: FlexFit.loose,
//                         child: Padding(
//                           padding: const EdgeInsets.all(8.0),
//                           child: Column(
//                             mainAxisSize: MainAxisSize.min,
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               // Title row with checkbox
//                               Row(
//                                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Expanded(
//                                     child: Text(
//                                       note['title'] ?? 'No Title',
//                                       style: TextStyle(
//                                         fontSize: _isGridView ? 14 : 16,
//                                         fontWeight: FontWeight.bold,
//                                       ),
//                                       maxLines: 1,
//                                       overflow: TextOverflow.ellipsis,
//                                     ),
//                                   ),
//                                   if (_isSelecting)
//                                     SizedBox(
//                                       height: 24,
//                                       width: 24,
//                                       child: Checkbox(
//                                         value: _selectedNotes[index],
//                                         onChanged: (bool? value) {
//                                           setState(() {
//                                             _selectedNotes[index] = value ?? false;
//                                             if (!_selectedNotes.contains(true)) {
//                                               _isSelecting = false;
//                                             }
//                                           });
//                                         },
//                                       ),
//                                     ),
//                                 ],
//                               ),
//                               const SizedBox(height: 4),
//
//                               // Description
//                               Text(
//                                 note['description'] ?? 'No Description',
//                                 maxLines: _isGridView ? 2 : 3,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: TextStyle(fontSize: _isGridView ? 12 : 14),
//                               ),
//
//                               // Tags section
//                               if (tags.isNotEmpty) ...[
//                                 const SizedBox(height: 8),
//                                 Wrap(
//                                   spacing: 4,
//                                   runSpacing: 4,
//                                   children: tags.map((tag) => Container(
//                                     padding: const EdgeInsets.symmetric(
//                                       horizontal: 8,
//                                       vertical: 2,
//                                     ),
//                                     decoration: BoxDecoration(
//                                       color: Colors.black.withOpacity(0.1),
//                                       borderRadius: BorderRadius.circular(12),
//                                     ),
//                                     child: Text(
//                                       '#$tag',
//                                       style: TextStyle(
//                                         fontSize: _isGridView ? 10 : 12,
//                                         color: Colors.black54,
//                                       ),
//                                     ),
//                                   )).toList(),
//                                 ),
//                               ],
//
//                               const SizedBox(height: 24),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//
//                   // Timestamp positioned at bottom right
//                   Positioned(
//                     right: 8,
//                     bottom: 8,
//                     child: Text(
//                       updatedAt != null
//                           ? 'Updated: ${getFormattedDate(updatedAt)}'
//                           : 'Created: ${getFormattedDate(createdAt)}',
//                       style: TextStyle(
//                         fontSize: 10,
//                         color: Colors.grey[600],
//                         fontStyle: FontStyle.italic,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//
//   Future<Database> _initDatabase() async {
//     Directory documentsDirectory = await getApplicationDocumentsDirectory();
//     String path = join(documentsDirectory.path, 'note_app.db');
//     return openDatabase(
//       path,
//       version: 1,
//       onCreate: (db, version) {
//         db.execute('''
//         CREATE TABLE notes (
//           id INTEGER PRIMARY KEY AUTOINCREMENT,
//           title TEXT,
//           description TEXT,
//           images TEXT,
//           reminder TEXT,
//           color INTEGER,
//           checklist TEXT,
//           tags TEXT,
//           created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
//           updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
//         )
//       ''');
//       },
//     );
//   }
//   // Future<void> resetDatabase() async {
//   //   Directory documentsDirectory = await getApplicationDocumentsDirectory();
//   //   String path = join(documentsDirectory.path, 'notes.db');
//   //   if (await File(path).exists()) {
//   //     await File(path).delete();
//   //     setState(() {
//   //       _myDatabase = _initDatabase();
//   //     });
//   //   }
//   // }
//   Future<List<Map<String, dynamic>>> _fetchNotes() async {
//     final db = await _myDatabase;
//     final List<Map<String, dynamic>> notes = await db.query('notes');
//     try {
//       return await db.query('notes');
//     } catch (e) {
//       print('Error fetching notes: $e');
//       return [];
//     }
//   }
//
//
//
//   void _addNewNote() {
//     Navigator.of(context)
//         .push(
//       MaterialPageRoute(builder: (context) => NoteEditor(myDatabase: _myDatabase)),
//     )
//         .then((_) => setState(() {})); // Refresh notes list after returning
//   }
//
//   void _editNote(Map<String, dynamic> note) {
//     Navigator.of(context).push(
//       PageRouteBuilder(
//         pageBuilder: (context, animation, secondaryAnimation) =>
//             NoteEditor(myDatabase: _myDatabase, note: note),
//         transitionsBuilder: (context, animation, secondaryAnimation, child) {
//           const begin = Offset(0.0, 1.0);
//           const end = Offset.zero;
//           const curve = Curves.easeInOut;
//           var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
//           var offsetAnimation = animation.drive(tween);
//           return SlideTransition(position: offsetAnimation, child: child);
//         },
//         transitionDuration: const Duration(milliseconds: 300),
//       ),
//     ).then((_) => setState(() {}));
//   }
//
//   Future<List<Map<String, dynamic>>> fetchNotesFromFirebase() async {
//     final firestore = FirebaseFirestore.instance;
//     final snapshot = await firestore.collection('notes').get();
//
//     return snapshot.docs.map((doc) {
//       final data = doc.data();
//       return {
//         'id': doc.id,
//         ...data,
//         'color': data['color'],
//       };
//     }).toList();
//   }
//
// // Function to push a single note to Firebase
//   Future<void> pushNoteToFirebase(Map<String, dynamic> note) async {
//     final firestore = FirebaseFirestore.instance;
//
//     try {
//       if (note['id'] != null) {
//         await firestore.collection('notes').doc(note['id'].toString()).set(note);
//       } else {
//         await firestore.collection('notes').add(note);
//       }
//     } catch (e) {
//       print('Error pushing note to Firebase: $e');
//     }
//   }
//
// // Function to sync SQLite with Firebase
//   Future<void> syncWithFirebase(Future<Database> database) async {
//     final db = await database;
//     final notesFromSQLite = await db.query('notes');
//     final notesFromFirebase = await fetchNotesFromFirebase();
//
//     // Sync Firebase -> SQLite
//     for (final firebaseNote in notesFromFirebase) {
//       final existsInSQLite = notesFromSQLite.any((sqliteNote) =>
//       sqliteNote['id'].toString() == firebaseNote['id'].toString());
//
//       if (!existsInSQLite) {
//         // Insert into SQLite
//         await db.insert(
//           'notes',
//           {
//             'id': int.parse(firebaseNote['id']),
//             'title': firebaseNote['title'],
//             'description': firebaseNote['description'],
//             'images': firebaseNote['images'],
//             'reminder': firebaseNote['reminder'],
//             'color': firebaseNote['color'],
//             'checklist': firebaseNote['checklist'],
//             'tags': firebaseNote['tags'],
//             'created_at': firebaseNote['created_at'],
//             'updated_at': firebaseNote['updated_at'],
//           },
//         );
//       }
//     }
//
//     // Sync SQLite -> Firebase
//     for (final sqliteNote in notesFromSQLite) {
//       final existsInFirebase = notesFromFirebase.any((firebaseNote) =>
//       firebaseNote['id'].toString() == sqliteNote['id'].toString());
//
//       if (!existsInFirebase) {
//         await pushNoteToFirebase(sqliteNote);
//       }
//     }
//   }
// }
//
// class NoteEditor extends StatefulWidget {
//   final Future<Database> myDatabase;
//   final Map<String, dynamic>? note;
//
//   const NoteEditor({required this.myDatabase, this.note});
//
//   @override
//   State<NoteEditor> createState() => _NoteEditorState();
// }
//
// class _NoteEditorState extends State<NoteEditor> {
//   final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//   final _titleController = TextEditingController();
//   final _descriptionController = TextEditingController();
//   final _tagsController = TextEditingController();
//   List<File> _images = [];
//   List<ChecklistItem> _checklistItems = [];
//   Color _color = Colors.white;
//   DateTime? _reminder;
//   TextStyle _currentTextStyle = const TextStyle();
//   bool _isBold = false;
//   bool _isItalic = false;
//   bool _isUnderlined = false;
//   Timer? _autoSaveTimer;
//   bool _hasChanges = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _initTimeZone();
//     _initializeNotifications();
//     _loadExistingNote();
//     _setupAutoSave();
//     _setupTextControllerListeners();
//     _requestNotificationPermission();
//   }
//
//   Future<void> _initTimeZone() async {
//     tz.initializeTimeZones();
//     const String timeZoneName = 'Asia/Ho_Chi_Minh'; // Hoặc lấy timezone của thiết bị
//     tz.setLocalLocation(tz.getLocation(timeZoneName));
//   }
//
//   void _loadExistingNote() {
//     if (widget.note != null) {
//       // Sử dụng operator [] để truy cập Map an toàn hơn
//       _titleController.text = widget.note!.containsKey('title') ? widget.note!['title'] as String : '';
//       _descriptionController.text = widget.note!.containsKey('description') ? widget.note!['description'] as String : '';
//       _tagsController.text = widget.note!.containsKey('tags') ? widget.note!['tags'] as String : '';
//       _color = Color(widget.note!.containsKey('color') ? widget.note!['color'] as int : Colors.white.value);
//
//       if (widget.note!.containsKey('reminder') && widget.note!['reminder'] != null) {
//         _reminder = DateTime.tryParse(widget.note!['reminder'] as String);
//       }
//
//       // Load images
//       if (widget.note!.containsKey('images') && widget.note!['images'] != null) {
//         final String imagesStr = widget.note!['images'] as String;
//         if (imagesStr.isNotEmpty) {
//           _images = imagesStr
//               .split(',')
//               .map((path) => File(path))
//               .where((file) => file.existsSync())
//               .toList();
//         }
//       }
//
//       // Load checklist items
//       if (widget.note!.containsKey('checklist') && widget.note!['checklist'] != null) {
//         final String checklistStr = widget.note!['checklist'] as String;
//         if (checklistStr.isNotEmpty) {
//           final List<dynamic> checklistData = json.decode(checklistStr);
//           _checklistItems = checklistData.map((item) {
//             final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
//             return ChecklistItem(
//               text: itemMap['text'] as String? ?? '',
//               isChecked: itemMap['isChecked'] as bool? ?? false,
//             );
//           }).toList();
//         }
//       }
//
//       // Schedule notification if reminder exists
//       if (_reminder != null) {
//         _scheduleNotification();
//       }
//     }
//   }
//
//   void _setupAutoSave() {
//     // Auto save every 30 seconds if there are changes
//     _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
//       if (_hasChanges) {
//         _saveNote();
//       }
//     });
//   }
//
//   void _setupTextControllerListeners() {
//     _titleController.addListener(() => _hasChanges = true);
//     _descriptionController.addListener(() => _hasChanges = true);
//     _tagsController.addListener(() => _hasChanges = true);
//   }
//
//   @override
//   void dispose() {
//     _autoSaveTimer?.cancel();
//     if (_hasChanges) {
//       _saveNote(); // Save on dispose if there are changes
//     }
//     _titleController.dispose();
//     _descriptionController.dispose();
//     _tagsController.dispose();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return WillPopScope(
//       onWillPop: () async {
//         if (_hasChanges) {
//           await _saveNote();
//         }
//         return true;
//       },
//       child: Scaffold(
//         backgroundColor: _color,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
//             onPressed: () async {
//               if (_hasChanges) {
//                 await _saveNote();
//               }
//               Navigator.of(context).pop();
//             },
//           ),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.alarm, color: Colors.black),
//               onPressed: _setReminder,
//             ),
//             IconButton(
//               icon: const Icon(Icons.local_offer_outlined, color: Colors.black),
//               onPressed: _showTagsDialog,
//             ),
//           ],
//         ),
//         body: Column(
//           children: [
//             Expanded(
//               child: SingleChildScrollView(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     TextField(
//                       controller: _titleController,
//                       style: const TextStyle(
//                         fontSize: 28,
//                         fontWeight: FontWeight.bold,
//                       ),
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         hintText: 'Title',
//                       ),
//                     ),
//                     if (_reminder != null)
//                       Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 8.0),
//                         child: Chip(
//                           label: Text(
//                             'Reminder: ${_formatDateTime(_reminder!)}',
//                             style: const TextStyle(fontSize: 12),
//                           ),
//                           deleteIcon: const Icon(Icons.close, size: 16),
//                           onDeleted: () => setState(() => _reminder = null),
//                         ),
//                       ),
//                     if (_tagsController.text.isNotEmpty)
//                       Wrap(
//                         spacing: 8.0,
//                         children: _tagsController.text.split(',').map((tag) {
//                           return Chip(
//                             label: Text(tag.trim()),
//                             backgroundColor: Colors.grey[200],
//                           );
//                         }).toList(),
//                       ),
//                     if (_images.isNotEmpty)
//                       Container(
//                         height: 200,
//                         child: ListView.builder(
//                           scrollDirection: Axis.horizontal,
//                           itemCount: _images.length,
//                           itemBuilder: (context, index) {
//                             return Padding(
//                               padding: const EdgeInsets.only(right: 8.0),
//                               child: Stack(
//                                 children: [
//                                   Image.file(_images[index], height: 200),
//                                   Positioned(
//                                     right: 4,
//                                     top: 4,
//                                     child: IconButton(
//                                       icon: const Icon(Icons.close, color: Colors.white),
//                                       onPressed: () {
//                                         setState(() {
//                                           _images.removeAt(index);
//                                           _hasChanges = true;
//                                         });
//                                       },
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             );
//                           },
//                         ),
//                       ),
//                     TextField(
//                       controller: _descriptionController,
//                       maxLines: null,
//                       style: _currentTextStyle,
//                       decoration: const InputDecoration(
//                         border: InputBorder.none,
//                         hintText: 'Start typing...',
//                       ),
//                     ),
//                     ..._checklistItems.map((item) => ChecklistItemWidget(
//                       item: item,
//                       onChanged: (bool? value) {
//                         setState(() {
//                           item.isChecked = value ?? false;
//                           _hasChanges = true;
//                         });
//                       },
//                       onDelete: () {
//                         setState(() {
//                           _checklistItems.remove(item);
//                           _hasChanges = true;
//                         });
//                       },
//                     )),
//                   ],
//                 ),
//               ),
//             ),
//             _buildBottomToolbar(),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildBottomToolbar() {
//     return Container(
//       padding: const EdgeInsets.all(8.0),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         boxShadow: [
//           BoxShadow(
//             color: Colors.grey.withOpacity(0.2),
//             spreadRadius: 1,
//             blurRadius: 3,
//           ),
//         ],
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceAround,
//         children: [
//           IconButton(
//             icon: const Icon(Icons.check_box_outlined),
//             onPressed: _addChecklistItem,
//           ),
//           IconButton(
//             icon: const Icon(Icons.camera_alt_outlined),
//             onPressed: _pickImage,
//           ),
//           IconButton(
//             icon: Icon(Icons.format_bold,
//                 color: _isBold ? Colors.blue : Colors.black
//             ),
//             onPressed: _toggleBold,
//           ),
//           IconButton(
//             icon: Icon(Icons.format_italic,
//                 color: _isItalic ? Colors.blue : Colors.black
//             ),
//             onPressed: _toggleItalic,
//           ),
//           IconButton(
//             icon: Icon(Icons.format_underline,
//                 color: _isUnderlined ? Colors.blue : Colors.black
//             ),
//             onPressed: _toggleUnderline,
//           ),
//           IconButton(
//             icon: const Icon(Icons.color_lens),
//             onPressed: _showColorPicker,
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showColorPicker() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Pick a color'),
//         content: SingleChildScrollView(
//           child: ColorPicker(
//             pickerColor: _color,
//             onColorChanged: (color) {
//               setState(() {
//                 _color = color;
//                 _hasChanges = true;
//               });
//             },
//             pickerAreaHeightPercent: 0.8,
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).pop(),
//             child: const Text('Done'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _setReminder() async {
//     final DateTime? pickedDate = await showDatePicker(
//       context: context,
//       initialDate: _reminder ?? DateTime.now(),
//       firstDate: DateTime.now(),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//     );
//
//     if (pickedDate != null) {
//       final TimeOfDay? pickedTime = await showTimePicker(
//         context: context,
//         initialTime: TimeOfDay.now(),
//       );
//
//       if (pickedTime != null) {
//         setState(() {
//           _reminder = DateTime(
//             pickedDate.year,
//             pickedDate.month,
//             pickedDate.day,
//             pickedTime.hour,
//             pickedTime.minute,
//           );
//           _hasChanges = true;
//         });
//
//         // Schedule notification when reminder is set
//         await _scheduleNotification();
//       }
//     }
//   }
//   Future<void> _initializeNotifications() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     final DarwinInitializationSettings initializationSettingsIOS =
//     DarwinInitializationSettings(
//       requestSoundPermission: true,
//       requestBadgePermission: true,
//       requestAlertPermission: true,
//
//     );
//
//     final InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(
//       initializationSettings,
//       onDidReceiveNotificationResponse: (NotificationResponse response) {
//         // Xử lý khi người dùng nhấn vào thông báo
//         if (response.payload != null) {
//           print('notification payload: ${response.payload}');
//         }
//       },
//     );
//
//     // Yêu cầu quyền cho Android
//     if (Platform.isAndroid) {
//       final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
//       flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
//           AndroidFlutterLocalNotificationsPlugin>();
//       // Yêu cầu quyền đặt báo thức chính xác
//       await androidImplementation?.requestExactAlarmsPermission();
//     }
//
//     // Yêu cầu quyền cho iOS
//     if (Platform.isIOS) {
//       await flutterLocalNotificationsPlugin
//           .resolvePlatformSpecificImplementation<
//           IOSFlutterLocalNotificationsPlugin>()
//           ?.requestPermissions(
//         alert: true,
//         badge: true,
//         sound: true,
//       );
//     }
//   }
//
//
//   Future<void> _requestNotificationPermission() async {
//     final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//     FlutterLocalNotificationsPlugin();
//
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const DarwinInitializationSettings initializationSettingsIOS =
//     DarwinInitializationSettings(
//       requestSoundPermission: false,
//       requestBadgePermission: false,
//       requestAlertPermission: true,
//     );
//
//     const InitializationSettings initializationSettings = InitializationSettings(
//       android: initializationSettingsAndroid,
//       iOS: initializationSettingsIOS,
//     );
//
//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//   }
//   // Thêm hàm để lên lịch thông báo
//   Future<void> _scheduleNotification() async {
//     if (_reminder == null) return;
//
//     final int notificationId = widget.note != null ? (widget.note!['id'] as int) : DateTime.now().millisecondsSinceEpoch;
//
//     // Hủy thông báo cũ nếu có
//     await flutterLocalNotificationsPlugin.cancel(notificationId);
//
//     // Cấu hình cho Android
//     final AndroidNotificationDetails androidPlatformChannelSpecifics =
//     AndroidNotificationDetails(
//       'note_reminders', // channel id
//       'Note Reminders', // channel name
//       channelDescription: 'Notifications for note reminders ',
//       importance: Importance.max,
//       priority: Priority.high,
//       enableVibration: true,
//       playSound: true,
//       styleInformation: BigTextStyleInformation(''),
//       category: AndroidNotificationCategory.reminder,
//     );
//
//     // Cấu hình cho iOS
//     const DarwinNotificationDetails iOSPlatformChannelSpecifics =
//     DarwinNotificationDetails(
//       presentAlert: true,
//       presentBadge: true,
//       presentSound: true,
//       interruptionLevel: InterruptionLevel.active,
//     );
//
//     final NotificationDetails platformChannelSpecifics = NotificationDetails(
//       android: androidPlatformChannelSpecifics,
//       iOS: iOSPlatformChannelSpecifics,
//     );
//
//     final String title = _titleController.text.isNotEmpty
//         ? _titleController.text
//         : 'Note Reminder';
//     final String body = _descriptionController.text.isNotEmpty
//         ? _descriptionController.text
//         : 'Time to check your note!';
//
//     try {
//       // Chuyển đổi DateTime sang TZDateTime
//       tz.TZDateTime scheduledDate = tz.TZDateTime.from(_reminder!, tz.local);
//
//       // Đảm bảo thời gian thông báo là trong tương lai
//       if (scheduledDate.isBefore(DateTime.now())) {
//         print('Warning: Scheduled time is in the past');
//         return;
//       }
//
//       await flutterLocalNotificationsPlugin.zonedSchedule(
//         notificationId,
//         title,
//         body,
//         scheduledDate,
//         platformChannelSpecifics,
//         androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
//         uiLocalNotificationDateInterpretation:
//         UILocalNotificationDateInterpretation.absoluteTime,
//       );
//
//       print('Notification scheduled successfully for: $scheduledDate');
//
//       // Hiển thị thông báo xác nhận
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Reminder set for ${_formatDateTime(_reminder!)}')),
//         );
//       }
//     } catch (e) {
//       print('Error scheduling notification: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Failed to set reminder: $e')),
//         );
//       }
//     }
//   }
//
//
//   void _showTagsDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Add Tags'),
//         content: TextField(
//           controller: _tagsController,
//           decoration: const InputDecoration(
//             hintText: 'Enter tags separated by commas',
//           ),
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               setState(() => _hasChanges = true);
//             },
//             child: const Text('Done'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showMoreOptions() {
//     // Implement additional options menu
//   }
//
//   String _formatDateTime(DateTime dateTime) {
//     return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
//   }
//
//   Future<void> _saveNote() async {
//     final db = await widget.myDatabase;
//     final now = DateTime.now().toIso8601String();
//
//     final checklistJson = json.encode(_checklistItems.map((item) => {
//       'text': item.text,
//       'isChecked': item.isChecked,
//     }).toList());
//
//     final Map<String, dynamic> note = {
//       'title': _titleController.text,
//       'description': _descriptionController.text,
//       'images': _images.map((image) => image.path).join(','),
//       'reminder': _reminder?.toIso8601String(),
//       'color': _color.value,
//       'tags': _tagsController.text,
//       'checklist': checklistJson,
//       'updated_at': now,
//     };
//
//     try {
//       if (widget.note != null && widget.note!.containsKey('id')) {
//         await db.update(
//           'notes',
//           note,
//           where: 'id = ?',
//           whereArgs: [widget.note!['id']],
//         );
//       } else {
//         note['created_at'] = now;
//         await db.insert('notes', note);
//       }
//       _hasChanges = false;
//     } catch (e) {
//       print('Error saving note: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Error saving note')),
//         );
//       }
//     }
//   }
//
//
//   void _toggleBold() {
//     setState(() {
//       _isBold = !_isBold;
//       _updateTextStyle();
//     });
//   }
//
//   void _toggleItalic() {
//     setState(() {
//       _isItalic = !_isItalic;
//       _updateTextStyle();
//     });
//   }
//
//   void _toggleUnderline() {
//     setState(() {
//       _isUnderlined = !_isUnderlined;
//       _updateTextStyle();
//     });
//   }
//
//   void _updateTextStyle() {
//     _currentTextStyle = TextStyle(
//       fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
//       fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
//       decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none,
//     );
//   }
//
//   Future<void> _pickImage() async {
//     final picker = ImagePicker();
//     final pickedFile = await picker.pickImage(source: ImageSource.gallery);
//     if (pickedFile != null) {
//       setState(() {
//         _images.add(File(pickedFile.path));
//       });
//     }
//   }
//
//   void _addChecklistItem() {
//     setState(() {
//       _checklistItems.add(ChecklistItem(text: '', isChecked: false));
//     });
//   }
// }
//
// class ChecklistItem {
//   String text;
//   bool isChecked;
//
//   ChecklistItem({required this.text, required this.isChecked});
// }
//
// class ChecklistItemWidget extends StatelessWidget {
//   final ChecklistItem item;
//   final ValueChanged<bool?> onChanged;
//   final VoidCallback onDelete;
//
//   const ChecklistItemWidget({
//     required this.item,
//     required this.onChanged,
//     required this.onDelete,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return Row(
//       children: [
//         Checkbox(
//           value: item.isChecked,
//           onChanged: onChanged,
//         ),
//         Expanded(
//           child: TextField(
//             onChanged: (value) => item.text = value,
//             decoration: const InputDecoration(
//               border: InputBorder.none,
//               hintText: 'List item',
//             ),
//           ),
//         ),
//         IconButton(
//           icon: const Icon(Icons.close),
//           onPressed: onDelete,
//         ),
//       ],
//     );
//   }
// }

//
// class SearchPage extends StatefulWidget {
//   const SearchPage();
//
//   @override
//   State<SearchPage> createState() => _SearchPageState();
// }
//
// class _SearchPageState extends State<SearchPage> {
//   final TextEditingController _searchController = TextEditingController();
//   String _selectedTag = '';
//   List<Map<String, dynamic>> _notes = [];
//   List<String> _availableTags = [];
//   late Future<Database> _myDatabase;
//
//   @override
//   void initState() {
//     super.initState();
//     _myDatabase = _initDatabase();
//     _fetchAvailableTags();
//     _fetchNotes();
//   }
//
//   Future<Database> _initDatabase() async {
//     Directory documentsDirectory = await getApplicationDocumentsDirectory();
//     String path = join(documentsDirectory.path, 'note_app.db');
//     return openDatabase(path, version: 1);
//   }
//
//   Future<void> _fetchAvailableTags() async {
//     final db = await _myDatabase;
//     final result = await db.rawQuery('SELECT DISTINCT tags FROM notes');
//     setState(() {
//       _availableTags = result
//           .expand((row) {
//         // Kiểm tra nếu `row['tags']` là String, nếu không trả về danh sách rỗng
//         if (row['tags'] is String) {
//           return (row['tags'] as String).split(',');
//         } else {
//           return [];
//         }
//       })
//           .where((tag) => tag.isNotEmpty) // Lọc các tag rỗng
//           .map((tag) => tag.toString()) // Đảm bảo tất cả là String
//           .toSet()
//           .toList(); // Loại bỏ các phần tử trùng lặp
//     });
//   }
//
//
//   Future<void> _fetchNotes() async {
//     final db = await _myDatabase;
//     final keyword = _searchController.text.trim();
//     final tag = _selectedTag;
//
//     String whereClause = '';
//     List<String> whereArgs = [];
//
//     if (keyword.isNotEmpty) {
//       whereClause += '(title LIKE ? OR description LIKE ?)';
//       whereArgs.addAll(['%$keyword%', '%$keyword%']);
//     }
//
//     if (tag.isNotEmpty) {
//       if (whereClause.isNotEmpty) {
//         whereClause += ' AND ';
//       }
//       whereClause += 'tags LIKE ?';
//       whereArgs.add('%$tag%');
//     }
//
//     final result = await db.query(
//       'notes',
//       where: whereClause.isNotEmpty ? whereClause : null,
//       whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
//     );
//
//     setState(() {
//       _notes = result;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Search Notes')),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           children: [
//             TextField(
//               controller: _searchController,
//               decoration: const InputDecoration(
//                 labelText: 'Search by keyword',
//                 prefixIcon: Icon(Icons.search),
//               ),
//               onChanged: (_) => _fetchNotes(),
//             ),
//             const SizedBox(height: 10),
//             DropdownButton<String>(
//               value: _selectedTag.isEmpty ? null : _selectedTag,
//               hint: const Text('Filter by tag'),
//               items: _availableTags
//                   .map((tag) => DropdownMenuItem(
//                 value: tag,
//                 child: Text(tag),
//               ))
//                   .toList(),
//               onChanged: (value) {
//                 setState(() {
//                   _selectedTag = value ?? '';
//                 });
//                 _fetchNotes();
//               },
//             ),
//             const SizedBox(height: 10),
//             Expanded(
//               child: _notes.isEmpty
//                   ? const Center(child: Text('No notes found'))
//                   : ListView.builder(
//                 itemCount: _notes.length,
//                 itemBuilder: (context, index) {
//                   final note = _notes[index];
//                   return Card(
//                     color: Color(note['color'] ?? Colors.white.value),
//                     child: ListTile(
//                       title: Text(note['title'] ?? 'No Title'),
//                       subtitle: Text(note['created_at'] ?? 'No created_at'),
//                       onTap: () {
//                         Navigator.of(context).push(
//                           MaterialPageRoute(
//                             builder: (context) => NoteEditor(
//                               myDatabase: _myDatabase,
//                               note: note,
//                             ),
//                           ),
//                         );
//                       },
//                     ),
//                   );
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

//
// class TagsPage extends StatefulWidget {
//   const TagsPage({Key? key}) : super(key: key);
//
//   @override
//   _TagsPageState createState() => _TagsPageState();
// }
//
// class _TagsPageState extends State<TagsPage> {
//   late Future<Database> _myDatabase;
//   List<String> _availableTags = [];
//   List<Map<String, dynamic>> _notes = [];
//
//   @override
//   void initState() {
//     super.initState();
//     _myDatabase = _initDatabase();
//     _fetchAvailableTags();
//   }
//
//   // Initialize database
//   Future<Database> _initDatabase() async {
//     Directory documentsDirectory = await getApplicationDocumentsDirectory();
//     String path = join(documentsDirectory.path, 'note_app.db');
//     return openDatabase(path, version: 1);
//   }
//
//   // Fetch available tags from the database
//   Future<void> _fetchAvailableTags() async {
//     final db = await _myDatabase;
//     final result = await db.rawQuery('SELECT DISTINCT tags FROM notes');
//
//     setState(() {
//       _availableTags = result
//           .expand((row) {
//         // Kiểm tra nếu row['tags'] là String và tách nó thành danh sách
//         if (row['tags'] is String) {
//           return (row['tags'] as String).split(',');
//         } else {
//           return [];
//         }
//       })
//           .where((tag) => tag.isNotEmpty) // Lọc các tag rỗng
//           .map((tag) => tag.toString()) // Đảm bảo rằng tất cả là String
//           .toSet()
//           .toList(); // Chuyển về List<String>
//     });
//   }
//
//
//   // Fetch notes based on the selected tag
//   Future<void> _fetchNotesByTag(String tag) async {
//     final db = await _myDatabase;
//     final result = await db.query(
//       'notes',
//       where: 'tags LIKE ?',
//       whereArgs: ['%$tag%'],
//     );
//     setState(() {
//       _notes = result;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tags'),
//         backgroundColor: Colors.transparent,
//         elevation: 0,
//       ),
//       body: _availableTags.isEmpty
//           ? const Center(child: CircularProgressIndicator())
//           : ListView.builder(
//         itemCount: _availableTags.length,
//         itemBuilder: (context, index) {
//           final tag = _availableTags[index];
//           return ListTile(
//             leading: const Icon(Icons.label_outline, color: Colors.grey),
//             title: Text(tag),
//             trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
//             onTap: () async {
//               // Fetch notes when tag is tapped
//               await _fetchNotesByTag(tag);
//               Navigator.of(context).push(
//                 MaterialPageRoute(
//                   builder: (context) => NotesListPage(
//                     notes: _notes,
//                     tag: tag,
//                     myDatabase: _myDatabase,
//                   ),
//                 ),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }
//
// // Cập nhật constructor của NotesListPage để nhận _myDatabase
// class NotesListPage extends StatelessWidget {
//   final List<Map<String, dynamic>> notes;
//   final String tag;
//   final Future<Database> myDatabase; // Thêm _myDatabase vào đây
//
//   const NotesListPage({
//     Key? key,
//     required this.notes,
//     required this.tag,
//     required this.myDatabase, // Truyền myDatabase vào constructor
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: Text('Notes for Tag: $tag')),
//       body: notes.isEmpty
//           ? const Center(child: Text('No notes found for this tag'))
//           : ListView.builder(
//         itemCount: notes.length,
//         itemBuilder: (context, index) {
//           final note = notes[index];
//           return Card(
//             color: Color(note['color'] ?? Colors.white.value),
//             child: ListTile(
//               title: Text(note['title'] ?? 'No Title'),
//               subtitle: Text(note['created_at'] ?? 'No created_at'),
//               onTap: () {
//                 Navigator.of(context).push(
//                   MaterialPageRoute(
//                     builder: (context) => NoteEditor(
//                       myDatabase: myDatabase, // Truyền myDatabase vào NoteEditor
//                       note: note,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           );
//         },
//       ),
//     );
//   }
// }


