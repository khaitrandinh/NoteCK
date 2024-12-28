import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';


class NoteEditor extends StatefulWidget {
  final Future<Database> myDatabase;
  final Map<String, dynamic>? note;

  const NoteEditor({required this.myDatabase, this.note});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  List<File> _images = [];
  List<ChecklistItem> _checklistItems = [];
  Color _color = Colors.white;
  DateTime? _reminder;
  TextStyle _currentTextStyle = const TextStyle();
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _initTimeZone();
    _initializeNotifications();
    _loadExistingNote();
    _setupAutoSave();
    _setupTextControllerListeners();
    _requestNotificationPermission();
  }



  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_hasChanges) {
      _saveNote(); // Save on dispose if there are changes
    }
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          await _saveNote();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: _color,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () async {
              if (_hasChanges) {
                await _saveNote();
              }
              Navigator.of(context).pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.alarm, color: Colors.black),
              onPressed: _setReminder,
            ),
            IconButton(
              icon: const Icon(Icons.local_offer_outlined, color: Colors.black),
              onPressed: _showTagsDialog,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Title',
                      ),
                    ),
                    if (_reminder != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Chip(
                          label: Text(
                            'Reminder: ${_formatDateTime(_reminder!)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => _reminder = null),
                        ),
                      ),
                    if (_tagsController.text.isNotEmpty)
                      Wrap(
                        spacing: 8.0,
                        children: _tagsController.text.split(',').map((tag) {
                          return Chip(
                            label: Text(tag.trim()),
                            backgroundColor: Colors.grey[200],
                          );
                        }).toList(),
                      ),
                    if (_images.isNotEmpty)
                      Container(
                        height: 200,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  Image.file(_images[index], height: 200),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        setState(() {
                                          _images.removeAt(index);
                                          _hasChanges = true;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    TextField(
                      controller: _descriptionController,
                      maxLines: null,
                      style: _currentTextStyle,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Start typing...',
                      ),
                    ),
                    ..._checklistItems.map((item) => ChecklistItemWidget(
                      item: item,
                      onChanged: (bool? value) {
                        setState(() {
                          item.isChecked = value ?? false;
                          _hasChanges = true;
                        });
                      },
                      onDelete: () {
                        setState(() {
                          _checklistItems.remove(item);
                          _hasChanges = true;
                        });
                      },
                    )),
                  ],
                ),
              ),
            ),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.check_box_outlined),
            onPressed: _addChecklistItem,
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _pickImage,
          ),
          IconButton(
            icon: Icon(Icons.format_bold,
                color: _isBold ? Colors.blue : Colors.black
            ),
            onPressed: _toggleBold,
          ),
          IconButton(
            icon: Icon(Icons.format_italic,
                color: _isItalic ? Colors.blue : Colors.black
            ),
            onPressed: _toggleItalic,
          ),
          IconButton(
            icon: Icon(Icons.format_underline,
                color: _isUnderlined ? Colors.blue : Colors.black
            ),
            onPressed: _toggleUnderline,
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: _showColorPicker,
          ),
        ],
      ),
    );
  }

  void _showColorPicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _color,
            onColorChanged: (color) {
              setState(() {
                _color = color;
                _hasChanges = true;
              });
            },
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _setReminder() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _reminder ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (pickedTime != null) {
        setState(() {
          _reminder = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
          _hasChanges = true;
        });

        // Schedule notification when reminder is set
        await _scheduleNotification();
      }
    }
  }
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,

    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Xử lý khi người dùng nhấn vào thông báo
        if (response.payload != null) {
          print('notification payload: ${response.payload}');
        }
      },
    );

    // Yêu cầu quyền cho Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Yêu cầu quyền đặt báo thức chính xác
      await androidImplementation?.requestExactAlarmsPermission();
    }

    // Yêu cầu quyền cho iOS
    if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }


  Future<void> _requestNotificationPermission() async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> _initTimeZone() async {
    tz.initializeTimeZones();
    const String timeZoneName = 'Asia/Ho_Chi_Minh'; // Hoặc lấy timezone của thiết bị
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  }

  // Thêm hàm để lên lịch thông báo
  Future<void> _scheduleNotification() async {
    if (_reminder == null) return;

    final int notificationId = widget.note != null ? (widget.note!['id'] as int) : DateTime.now().millisecondsSinceEpoch;

    // Hủy thông báo cũ nếu có
    await flutterLocalNotificationsPlugin.cancel(notificationId);

    // Cấu hình cho Android
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'note_reminders', // channel id
      'Note Reminders', // channel name
      channelDescription: 'Notifications for note reminders ',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
      category: AndroidNotificationCategory.reminder,
    );

    // Cấu hình cho iOS
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final String title = _titleController.text.isNotEmpty
        ? _titleController.text
        : 'Note Reminder';
    final String body = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : 'Time to check your note!';

    try {
      // Chuyển đổi DateTime sang TZDateTime
      tz.TZDateTime scheduledDate = tz.TZDateTime.from(_reminder!, tz.local);

      // Đảm bảo thời gian thông báo là trong tương lai
      if (scheduledDate.isBefore(DateTime.now())) {
        print('Warning: Scheduled time is in the past');
        return;
      }

      await flutterLocalNotificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledDate,
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('Notification scheduled successfully for: $scheduledDate');

      // Hiển thị thông báo xác nhận
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set for ${_formatDateTime(_reminder!)}')),
        );
      }
    } catch (e) {
      print('Error scheduling notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to set reminder: $e')),
        );
      }
    }
  }


  void _showTagsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tags'),
        content: TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            hintText: 'Enter tags separated by commas',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() => _hasChanges = true);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }


  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
  }

  Future<void> _saveNote() async {
    final db = await widget.myDatabase;
    final now = DateTime.now().toIso8601String();

    final checklistJson = json.encode(_checklistItems.map((item) => {
      'text': item.text,
      'isChecked': item.isChecked,
    }).toList());

    final Map<String, dynamic> note = {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'images': _images.map((image) => image.path).join(','),
      'reminder': _reminder?.toIso8601String(),
      'color': _color.value,
      'tags': _tagsController.text,
      'checklist': checklistJson,
      'updated_at': now,
    };

    try {
      if (widget.note != null && widget.note!.containsKey('id')) {
        await db.update(
          'notes',
          note,
          where: 'id = ?',
          whereArgs: [widget.note!['id']],
        );
      } else {
        note['created_at'] = now;
        await db.insert('notes', note);
      }
      _hasChanges = false;
    } catch (e) {
      print('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving note')),
        );
      }
    }
  }


  void _loadExistingNote() {
    if (widget.note != null) {
      // Sử dụng operator [] để truy cập Map an toàn hơn
      _titleController.text = widget.note!.containsKey('title') ? widget.note!['title'] as String : '';
      _descriptionController.text = widget.note!.containsKey('description') ? widget.note!['description'] as String : '';
      _tagsController.text = widget.note!.containsKey('tags') ? widget.note!['tags'] as String : '';
      _color = Color(widget.note!.containsKey('color') ? widget.note!['color'] as int : Colors.white.value);

      if (widget.note!.containsKey('reminder') && widget.note!['reminder'] != null) {
        _reminder = DateTime.tryParse(widget.note!['reminder'] as String);
      }

      // Load images
      if (widget.note!.containsKey('images') && widget.note!['images'] != null) {
        final String imagesStr = widget.note!['images'] as String;
        if (imagesStr.isNotEmpty) {
          _images = imagesStr
              .split(',')
              .map((path) => File(path))
              .where((file) => file.existsSync())
              .toList();
        }
      }

      // Load checklist items
      if (widget.note!.containsKey('checklist') && widget.note!['checklist'] != null) {
        final String checklistStr = widget.note!['checklist'] as String;
        if (checklistStr.isNotEmpty) {
          final List<dynamic> checklistData = json.decode(checklistStr);
          _checklistItems = checklistData.map((item) {
            final Map<String, dynamic> itemMap = item as Map<String, dynamic>;
            return ChecklistItem(
              text: itemMap['text'] as String? ?? '',
              isChecked: itemMap['isChecked'] as bool? ?? false,
            );
          }).toList();
        }
      }

      // Schedule notification if reminder exists
      if (_reminder != null) {
        _scheduleNotification();
      }
    }
  }

  void _setupAutoSave() {
    // Auto save every 30 seconds if there are changes
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasChanges) {
        _saveNote();
      }
    });
  }

  void _setupTextControllerListeners() {
    _titleController.addListener(() => _hasChanges = true);
    _descriptionController.addListener(() => _hasChanges = true);
    _tagsController.addListener(() => _hasChanges = true);
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
      _updateTextStyle();
    });
  }

  void _toggleItalic() {
    setState(() {
      _isItalic = !_isItalic;
      _updateTextStyle();
    });
  }

  void _toggleUnderline() {
    setState(() {
      _isUnderlined = !_isUnderlined;
      _updateTextStyle();
    });
  }

  void _updateTextStyle() {
    _currentTextStyle = TextStyle(
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none,
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  void _addChecklistItem() {
    setState(() {
      _checklistItems.add(ChecklistItem(text: '', isChecked: false));
    });
  }
}

class ChecklistItem {
  String text;
  bool isChecked;

  ChecklistItem({required this.text, required this.isChecked});
}

class ChecklistItemWidget extends StatelessWidget {
  final ChecklistItem item;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  const ChecklistItemWidget({
    required this.item,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(
          value: item.isChecked,
          onChanged: onChanged,
        ),
        Expanded(
          child: TextField(
            onChanged: (value) => item.text = value,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'List item',
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: onDelete,
        ),
      ],
    );
  }
}