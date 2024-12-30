import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sqflite/sqflite.dart';


class SyncUtils {

  static Future<bool> checkInternetConnection() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  static Future<bool> checkFirebaseConnection() async {
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

  static Future<void> syncWithFirebase(Future<Database> database) async {
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
          final sqliteNote = notesFromSQLite.firstWhere(
                (note) => note['id'].toString() == firebaseNote['id'].toString(),
            orElse: () => {},
          );

          // Convert dates to String and handle null cases
          final firebaseUpdatedAt = firebaseNote['updated_at']?.toString() ?? DateTime.now().toIso8601String();
          final sqliteUpdatedAt = sqliteNote['updated_at']?.toString() ?? '';

          // Nếu note không tồn tại hoặc Firebase version mới hơn
          if (sqliteNote.isEmpty ||
              DateTime.parse(firebaseUpdatedAt).isAfter(
                  DateTime.parse(sqliteUpdatedAt)
              )) {
            int? color;
            if (firebaseNote['color'] != null) {
              color = int.tryParse(firebaseNote['color'].toString());
            }

            await db.insert(
              'notes',
              {
                'id': int.parse(firebaseNote['id']),
                'title': firebaseNote['title']?.toString() ?? '',
                'description': firebaseNote['description']?.toString() ?? '',
                'elements': firebaseNote['elements']?.toString() ?? '',
                'images': firebaseNote['images']?.toString() ?? '',
                'reminder': firebaseNote['reminder']?.toString() ?? '',
                'color': color,
                'checklist': firebaseNote['checklist']?.toString() ?? '',
                'tags': firebaseNote['tags']?.toString() ?? '',
                'is_favorite': firebaseNote['is_favorite']?.toString() ?? '',
                'created_at': firebaseNote['created_at']?.toString() ?? DateTime.now().toIso8601String(),
                'updated_at': firebaseUpdatedAt,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
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
          final firebaseNote = notesFromFirebase.firstWhere(
                (note) => note['id'].toString() == sqliteNote['id'].toString(),
            orElse: () => {},
          );

          // Convert dates to String and handle null cases
          final sqliteUpdatedAt = sqliteNote['updated_at']?.toString() ?? DateTime.now().toIso8601String();
          final firebaseUpdatedAt = firebaseNote['updated_at']?.toString() ?? '';

          // Nếu note không tồn tại trên Firebase hoặc SQLite version mới hơn
          if (firebaseNote.isEmpty ||
              DateTime.parse(sqliteUpdatedAt).isAfter(
                  DateTime.parse(firebaseUpdatedAt)
              )) {
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

  static Future<List<Map<String, dynamic>>> fetchNotesFromFirebase() async {
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

  static Future<void> pushNoteToFirebase(Map<String, dynamic> note) async {
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

}