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
