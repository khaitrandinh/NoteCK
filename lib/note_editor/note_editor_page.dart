import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:test_note/utils/sync_utils.dart';

enum NoteElementType { text, checklist, image }

class NoteElement {
  NoteElementType type;
  String content;
  bool isChecked;
  File? image;
  TextEditingController? textController;
  FocusNode? focusNode;


  NoteElement({
    required this.type,
    this.content = '',
    this.isChecked = false,
    this.image,
  }) {
    if (type == NoteElementType.text || type == NoteElementType.checklist) {
      textController = TextEditingController(text: content);
      focusNode = FocusNode(); // Khởi tạo focusNode
      textController!.addListener(() {
        content = textController!.text;
      });
    }
  }

  void dispose() {
    textController?.dispose();
    focusNode?.dispose(); // Dispose focusNode
  }
}

class ChecklistItem {
  String text;
  bool isChecked;

  ChecklistItem({required this.text, required this.isChecked});
}

class NoteEditor extends StatefulWidget {
  final Future<Database> myDatabase;
  final Map<String, dynamic>? note;
  final String? serializedNote;

  const NoteEditor({
    Key? key,
    required this.myDatabase,
    this.note,
    this.serializedNote,
  }) : super(key: key);

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final List<NoteElement> _noteElements = [];
  List<ChecklistItem> _checklistItems = [];
  List<File> _images = [];
  Color _color = Colors.white;
  DateTime? _reminder;
  TextStyle _currentTextStyle = const TextStyle();
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  int _currentFocusIndex = -1;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initTimeZone();
    _initializeNotifications();
    if (widget.serializedNote != null) {
      _loadElements(widget.serializedNote!);
    } else {
      // Thêm text element mặc định nếu là note mới
      _noteElements.add(NoteElement(type: NoteElementType.text));
    }
    _loadExistingNote();
    _setupAutoSave();
    _setupTextControllerListeners();
    _requestNotificationPermission();
    if (widget.note != null) {
      _isFavorite = widget.note!['is_favorite'] == 1;
    }
  }

  @override
  void dispose() {
    if (_hasChanges) {
      _saveNote();
    }
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    for (var element in _noteElements) {
      element.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        try {
          if (_hasChanges) {
            // Lưu note và đợi kết quả
            final saved = await _saveNote();
            if (!saved) {
              // Nếu lưu thất bại, show thông báo và không thoát
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Error saving note')),
                );
              }
              return false;
            }
          }

          if (mounted && Navigator.canPop(context)) {
            // Chỉ pop khi widget vẫn mounted và có thể pop
            Navigator.pop(context);
            return false; // Trả về false vì đã xử lý pop thủ công
          }
          return true; // Cho phép pop tự động nếu không thể xử lý
        } catch (e) {
          print('Error handling back press: $e');
          return false;
        }
      },
      child: GestureDetector(
        onTapDown: (details) => _handleTapOutside(),
        child: Scaffold(
          backgroundColor: _color,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  backgroundColor: Colors.blueGrey[200],
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
                      icon: Icon(
                        _isFavorite ? Icons.star : Icons.star_border,
                        color: _isFavorite ? Colors.amber : Colors.black,
                      ),
                      onPressed: () {
                        setState(() {
                          _isFavorite = !_isFavorite;
                          _hasChanges = true;
                        });
                      },
                    ),
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
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: TextField(
                          controller: _titleController,
                          style: const TextStyle(
                            fontSize: 24.0,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: TextField(
                          controller: _descriptionController,
                          style: const TextStyle(
                            fontSize: 16.0,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Add description...',
                            border: InputBorder.none,
                          ),
                          maxLines: 1,
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

                      const Divider(height: 1),
                    ],
                  ),
                ),
              ];
            },
            body: Column(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.zero,
                    child: ReorderableListView(
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final element = _noteElements.removeAt(oldIndex);
                          _noteElements.insert(newIndex, element);
                          _hasChanges = true;
                        });
                      },
                      children: [
                        for (int index = 0; index < _noteElements.length; index++)
                          Padding(
                            key: ValueKey(_noteElements[index]),
                            padding: const EdgeInsets.symmetric(vertical: 0), // Sát nhất có thể
                            child: _buildElementWidget(_noteElements[index], index),
                          ),
                      ],
                    ),
                  ),
                ),

                _buildBottomToolbar(),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildElementWidget(NoteElement element, int index) {
    switch (element.type) {
      case NoteElementType.text:
        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() {
                _currentFocusIndex = index;
              });
            }
          },
          child: TextField(
            controller: element.textController,
            focusNode: element.focusNode,
            style: _currentTextStyle,
            onChanged: (value) {
              setState(() {
                element.content = value;
                _hasChanges = true;

                // Nếu text trống, xóa phần tử
                if (value.isEmpty) {
                  _noteElements.removeAt(index);
                }
              });
            },
            onSubmitted: (value) {
              // Khi nhấn Enter, thêm text mới
              if (value.isNotEmpty) {
                setState(() {
                  _noteElements.insert(index + 1, NoteElement(type: NoteElementType.text));
                  _hasChanges = true;

                  // Focus vào phần tử mới
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _noteElements[index + 1].focusNode?.requestFocus();
                  });
                });
              }
            },
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '',
            ),
          ),
        );
      case NoteElementType.checklist:
        return Focus(
          onFocusChange: (hasFocus) {
            if (hasFocus) {
              setState(() {
                _currentFocusIndex = index;
              });
            }
          },
          child: Row(
            children: [
              Checkbox(
                value: element.isChecked,
                onChanged: (value) {
                  setState(() {
                    element.isChecked = value ?? false;
                    _hasChanges = true;
                  });
                },
              ),
              Expanded(
                child: TextField(
                  controller: element.textController,
                  focusNode: element.focusNode, // Thêm focusNode vào đây
                  onChanged: (value) {
                    setState(() {
                      element.content = value;
                      _hasChanges = true;
                    });
                  },
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Checklist item',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _noteElements.removeAt(index);
                    _hasChanges = true;
                  });
                },
              ),
            ],
          ),
        );
      case NoteElementType.image:
        return Stack(
          children: [
            Image.file(element.image!),
            Positioned(
              right: 4,
              top: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _noteElements.removeAt(index);
                    _hasChanges = true;
                  });
                },
              ),
            ),
          ],
        );
    }
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
          // Bỏ nút text đi
          IconButton(
            icon: const Icon(Icons.checklist),
            onPressed: () => _addElement(NoteElementType.checklist),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: () => _addElement(NoteElementType.image),
          ),
          IconButton(
            icon: Icon(
              Icons.format_bold,
              color: _isBold ? Colors.blueGrey : Colors.black,
            ),
            onPressed: _toggleBold,
          ),
          IconButton(
            icon: Icon(
              Icons.format_italic,
              color: _isItalic ? Colors.blueGrey : Colors.black,
            ),
            onPressed: _toggleItalic,
          ),
          IconButton(
            icon: Icon(
              Icons.format_underline,
              color: _isUnderlined ? Colors.blueGrey : Colors.black,
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

  void _addElement(NoteElementType type) async {
    int insertIndex = _currentFocusIndex;

    if (insertIndex < 0 || insertIndex >= _noteElements.length) {
      insertIndex = _noteElements.length;
    } else {
      insertIndex += 1;
    }

    if (type == NoteElementType.image) {
      final file = await _pickImage();
      if (file != null) {
        setState(() {
          // Thêm image element
          _noteElements.insert(insertIndex, NoteElement(type: type, image: file));
          // Thêm text element mới phía dưới
          _noteElements.insert(insertIndex + 1, NoteElement(type: NoteElementType.text));
          _hasChanges = true;
        });
      }
    } else if (type == NoteElementType.checklist) {
      setState(() {
        // Thêm checklist element
        NoteElement newElement = NoteElement(type: type);
        _noteElements.insert(insertIndex, newElement);
        // Thêm text element mới phía dưới
        _noteElements.insert(insertIndex + 1, NoteElement(type: NoteElementType.text));
        _hasChanges = true;

        // Focus vào checklist mới
        WidgetsBinding.instance.addPostFrameCallback((_) {
          newElement.focusNode?.requestFocus();
        });
      });
    }
  }
  void _handleTapOutside() {
    setState(() {
      _currentFocusIndex = -1; // Reset vị trí focus
    });
  }

  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    return pickedFile != null ? File(pickedFile.path) : null;
  }

  // Additional methods for notifications, reminders, and database operations
  Future<void> _initTimeZone() async {
    tz.initializeTimeZones();
    const String timeZoneName = 'Asia/Ho_Chi_Minh';
    tz.setLocalLocation(tz.getLocation(timeZoneName));
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
        if (response.payload != null) {
          print('notification payload: ${response.payload}');
        }
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestExactAlarmsPermission();
    }
  }

  Future<void> _requestNotificationPermission() async {
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

        await _scheduleNotification();
      }
    }
  }

  Future<void> _scheduleNotification() async {
    if (_reminder == null) return;

    final int notificationId = widget.note != null
        ? (widget.note!['id'] as int)
        : DateTime.now().millisecondsSinceEpoch;

    await flutterLocalNotificationsPlugin.cancel(notificationId);

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'note_reminders',
      'Note Reminders',
      channelDescription: 'Notifications for note reminders',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
    DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final String title =
    _titleController.text.isNotEmpty ? _titleController.text : 'Note Reminder';
    final String body = _descriptionController.text.isNotEmpty
        ? _descriptionController.text
        : 'Time to check your note!';

    try {
      tz.TZDateTime scheduledDate = tz.TZDateTime.from(_reminder!, tz.local);

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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Reminder set for ${_formatDateTime(_reminder!)}')),
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

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute}';
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

  Future<bool> _saveNote() async {
    if (!_hasChanges) {
      return true; // Trả về true nếu không có thay đổi cần lưu
    }

    final db = await widget.myDatabase;
    final now = DateTime.now().toIso8601String();

    try {
      // Convert noteElements to JSON format
      final List<Map<String, dynamic>> serializedElements = _noteElements.map((e) {
        return {
          'type': e.type.index,
          'content': e.content,
          'isChecked': e.isChecked,
          'imagePath': e.image?.path,
        };
      }).toList();

      // Validate images
      final List<String> imagePaths = [];
      for (var element in _noteElements) {
        if (element.type == NoteElementType.image && element.image != null) {
          if (element.image!.existsSync()) {
            imagePaths.add(element.image!.path);
          }
        }
      }

      // Prepare note data
      final Map<String, dynamic> note = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'elements': json.encode(serializedElements),
        'images': imagePaths.join(','),
        'reminder': _reminder?.toIso8601String(),
        'color': _color.value,
        'is_favorite': _isFavorite ? 1 : 0,
        'tags': _tagsController.text.trim(),
        'checklist': json.encode(_checklistItems
            .where((item) => item.text.isNotEmpty)
            .map((item) => {
          'text': item.text,
          'isChecked': item.isChecked,
        })
            .toList()),
        'updated_at': now,
      };

      int? noteId;
      await db.transaction((txn) async {
        if (widget.note != null && widget.note!.containsKey('id')) {
          // Handle update
          final oldNote = await txn.query(
            'notes',
            where: 'id = ?',
            whereArgs: [widget.note!['id']],
          );

          if (oldNote.isNotEmpty) {
            // Clean up old images
            final oldImagesStr = oldNote.first['images'] as String?;
            if (oldImagesStr != null && oldImagesStr.isNotEmpty) {
              final oldImagePaths = oldImagesStr.split(',');
              for (final oldPath in oldImagePaths) {
                if (oldPath.isNotEmpty && !imagePaths.contains(oldPath)) {
                  final oldFile = File(oldPath);
                  if (await oldFile.exists()) {
                    await oldFile.delete();
                  }
                }
              }
            }
          }

          await txn.update(
            'notes',
            note,
            where: 'id = ?',
            whereArgs: [widget.note!['id']],
          );
          noteId = widget.note!['id'];
        } else {
          // Handle insert
          note['created_at'] = now;
          noteId = await txn.insert('notes', note);
        }
      });

      setState(() => _hasChanges = false);

      // Try to sync with Firebase if connected
      try {
        if (await SyncUtils.checkInternetConnection()) {
          await SyncUtils.syncWithFirebase(widget.myDatabase);
        }
      } catch (e) {
        print('Error syncing with Firebase: $e');
        // Don't throw here as the note is already saved locally
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved successfully')),
        );
      }
      return true;
    } catch (e) {
      print('Error saving note: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving note: ${e.toString()}')),
        );
      }
      return false;
    }
  }

  void _loadElements(String serializedData) {
    try {
      final data = jsonDecode(serializedData) as List<dynamic>;
      setState(() {
        _noteElements.clear();
        _noteElements.addAll(data.map((item) {
          return NoteElement(
            type: NoteElementType.values[item['type']],
            content: item['content'] ?? '',
            isChecked: item['isChecked'] ?? false,
            image: item['imagePath'] != null ? File(item['imagePath']) : null,
          );
        }));
      });
    } catch (e) {
      print('Error loading elements: $e');
    }
  }

  void _loadExistingNote() {
    if (widget.note != null) {
      try {
        _titleController.text = widget.note!['title']?.toString() ?? '';
        _descriptionController.text = widget.note!['description']?.toString() ?? '';
        _tagsController.text = widget.note!['tags']?.toString() ?? '';
        _color = Color(widget.note!['color'] as int? ?? Colors.white.value);

        if (widget.note!['reminder'] != null) {
          _reminder = DateTime.tryParse(widget.note!['reminder'] as String);
        }

        // Load elements
        if (widget.note!['elements'] != null) {
          _loadElements(widget.note!['elements'] as String);
        }

        // Đảm bảo luôn có một text element nếu note trống
        if (_noteElements.isEmpty) {
          _noteElements.add(NoteElement(type: NoteElementType.text));
        }

        // Load checklist items
        if (widget.note!['checklist'] != null) {
          final List<dynamic> checklistData =
          json.decode(widget.note!['checklist'] as String);
          _checklistItems = checklistData.map((item) {
            return ChecklistItem(
              text: item['text']?.toString() ?? '',
              isChecked: item['isChecked'] as bool? ?? false,
            );
          }).toList();
        }

        _hasChanges = false;
      } catch (e) {
        print('Error loading note: $e');
      }
    }
  }

  void _setupAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_hasChanges) {
        _saveNote();
      }
    });
  }

  void _setupTextControllerListeners() {
    void onChanged() {
      if (!_hasChanges) {
        setState(() => _hasChanges = true);
      }
    }

    _titleController.addListener(onChanged);
    _descriptionController.addListener(onChanged);
    _tagsController.addListener(onChanged);
  }

  void _toggleBold() {
    setState(() {
      _isBold = !_isBold;
      _updateTextStyle();
      _hasChanges = true;
    });
  }

  void _toggleItalic() {
    setState(() {
      _isItalic = !_isItalic;
      _updateTextStyle();
      _hasChanges = true;
    });
  }

  void _toggleUnderline() {
    setState(() {
      _isUnderlined = !_isUnderlined;
      _updateTextStyle();
      _hasChanges = true;
    });
  }

  void _updateTextStyle() {
    setState(() {
      _currentTextStyle = TextStyle(
        fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
        decoration: _isUnderlined ? TextDecoration.underline : TextDecoration.none,
      );
    });
  }
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
            controller: TextEditingController(text: item.text),
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