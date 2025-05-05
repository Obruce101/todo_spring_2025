import 'package:app_settings/app_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../data/todo.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class DetailScreen extends StatefulWidget {
  final Todo todo;

  const DetailScreen({super.key, required this.todo});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Todo? _currentTodo;
  late TextEditingController _textController;
  late TextEditingController _subtaskController; //
  late TextEditingController _locationController;
  //late TextEditingController _currentLocation;

  DateTime? _selectedDueDate;
  //String? _currentLocation;



  void _addSubtask() async {
    if (_subtaskController.text.isEmpty) return;

    final newSubtask = SubTask(
      id: DateTime.now().toString(),
      text: _subtaskController.text,
    );

    await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({
      'subtasks': FieldValue.arrayUnion([newSubtask.toMap()]),
    });

    _subtaskController.clear();
  }

  Future<void> _fetchTodo() async {
    final doc = await FirebaseFirestore.instance
        .collection('todos')
        .doc(widget.todo.id)
        .get();

    setState(() {
      _currentTodo = Todo.fromSnapshot(doc);
      _textController = TextEditingController(text: _currentTodo!.text);
      _locationController = TextEditingController(text: _currentTodo!.location ?? '');
      _subtaskController = TextEditingController();
      _selectedDueDate = _currentTodo!.dueAt;
    });
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.todo.text);
    _locationController = TextEditingController(text: widget.todo.location ?? '');
    _subtaskController = TextEditingController();
    _selectedDueDate = widget.todo.dueAt;
    _fetchTodo();
    //_locationController = TextEditingController(text: widget.todo.location ?? '');/_currentLocation = widget.todo.location;


  }

  Future<void> _delete() async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).delete();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Todo deleted!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete todo: $e')),
        );
      }
    }
  }

  Future<void> _updateText(String newText) async {
    try {
      await FirebaseFirestore.instance.collection('todos').doc(widget.todo.id).update({'text': newText});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todo updated!')),
        );
      }


    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<void> _updateDueDate(DateTime? newDueDate) async {
    try {
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'dueAt': newDueDate == null ? null : Timestamp.fromDate(newDueDate)});

      if (mounted) {
        widget.todo.onDueDateUpdated?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update todo: $e')),
        );
      }
    }
  }

  Future<bool> _requestNotificationPermission() async {
    if (kIsWeb) return true;
    final isGranted = await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission() ??
        false;
    return isGranted;
  }

  void _showPermissionDeniedSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'You need to enable notifications to set due date.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 10),
        action: SnackBarAction(
          label: 'Open Settings',
          textColor: Colors.white,
          onPressed: () {
            AppSettings.openAppSettings(
              type: AppSettingsType.notification,
            );
          },
        ),
      ),
    );
  }

  Future<void> _initializeNotifications() async {
    final initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
    );
  }

  Future<void> _scheduleNotification(
    String todoId,
    DateTime dueDate,
    String text,
  ) async {
    final tzDateTime = tz.TZDateTime.from(dueDate, tz.local);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      todoId.hashCode,
      'Task due',
      text,
      tzDateTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'general_channel',
          'General Notifications',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexact,
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
  }

  Future<void> _updateLocation(String newLocation) async {
    try {
      // Update the 'location' field in Firestore for the specific todo
      await FirebaseFirestore.instance
          .collection('todos')
          .doc(widget.todo.id)
          .update({'location': newLocation});

      // Update the local TextController with the new location
      setState(() {
       // _currentLocation = newLocation;
        _locationController.text = newLocation;
        // Now updating the TextField locally
      });

      // Show success message if the widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated!')),
        );
      }
    } catch (e) {
      // Show error message if the update failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update location: $e')),
        );
      }
    }
  }


  @override
  void dispose() {
    _textController.dispose();
    _subtaskController.dispose();
    super.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Todo'),
                  content: const Text('Are you sure you want to delete this todo?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _delete();
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (newText) async {
                if (newText.isNotEmpty && newText != _currentTodo!.text) {
                  await _updateText(newText);
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location',
                border: UnderlineInputBorder(),
              ),
              onSubmitted: (newLocation) async {
                if (newLocation.isNotEmpty && newLocation != _currentTodo!.location) {
                  await _updateLocation(newLocation);
                  setState(() {
                    _locationController.text = newLocation;
                  });
                }
              },
            ),
            Container(
              margin: const EdgeInsets.only(top: 8.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.redAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationController.text.isEmpty
                          ? 'No location entered'
                          : _locationController.text,
                      style: const TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Due Date'),
              subtitle: Text(
                _selectedDueDate?.toLocal().toString().split('.')[0] ?? 'No due date',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedDueDate != null)
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () async {
                        _updateDueDate(null);
                        setState(() {
                          _selectedDueDate = null;
                        });
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final isGranted = await _requestNotificationPermission();
                      if (!context.mounted) return;

                      if (!isGranted) {
                        _showPermissionDeniedSnackbar(context);
                        return;
                      }

                      await _initializeNotifications();
                      if (!context.mounted) return;

                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDueDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2050),
                      );
                      if (!context.mounted) return;
                      if (selectedDate == null) return;

                      final selectedTime = await showTimePicker(
                        context: context,
                        initialTime: _selectedDueDate != null
                            ? TimeOfDay.fromDateTime(_selectedDueDate!)
                            : TimeOfDay.now(),
                      );
                      if (selectedTime == null) return;

                      final DateTime dueDate = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );

                      setState(() {
                        _selectedDueDate = dueDate;
                      });

                      await _updateDueDate(dueDate);
                      await _scheduleNotification(
                        _currentTodo!.id,
                        dueDate,
                        _currentTodo!.text,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }}
