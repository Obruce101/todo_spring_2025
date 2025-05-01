import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:todo_spring_2025/home/profile_screen.dart';

import '../data/todo.dart';
import 'details/detail_screen.dart';
import 'filter/filter_sheet.dart';
import 'package:intl/intl.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  StreamSubscription<List<Todo>>? _todoSubscription;
  List<Todo> _todos = [];
  List<Todo>? _filteredTodos;
  FilterSheetResult _filters = FilterSheetResult(
    sortBy: 'date',
    order: 'descending',
  );

  int totalTasksDueToday = 0;
  int completedTasksToday = 0;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _todoSubscription = getTodosForUser(user.uid).listen((todos) {
        setState(() {
          _todos = todos;
          _filteredTodos = filterTodos();
        });
      });
      _fetchDailyTasks();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _todoSubscription?.cancel();
    super.dispose();
  }

  List<Todo> filterTodos() {
    List<Todo> filteredTodos = _todos.where((todo) {
      return todo.text.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    if (_filters.sortBy == 'date') {
      filteredTodos.sort((a, b) =>
          _filters.order == 'ascending' ? a.createdAt.compareTo(b.createdAt) : b.createdAt.compareTo(a.createdAt));
    } else if (_filters.sortBy == 'completed') {
      filteredTodos.sort((a, b) => _filters.order == 'ascending'
          ? (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0))
          : (b.completedAt ?? DateTime(0)).compareTo(a.completedAt ?? DateTime(0)));
    }

    return filteredTodos;
  }



  Stream<List<Todo>> getTodosForUser(String userId) {
    return FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) => Todo.fromSnapshot(doc)).toList());
  }

  Future<void> _fetchDailyTasks() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final querySnapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: user.uid)
        .get();

    int total = 0;
    int completed = 0;

    for (var doc in querySnapshot.docs) {
      final dueDate = (doc.data()['dueAt'] as Timestamp?)?.toDate();
      if (dueDate != null) {
        final today = DateTime.now();
        if (dueDate.year == today.year && dueDate.month == today.month && dueDate.day == today.day) {
          total++;
          if (doc.data()['completedAt'] != null) {
            completed++;
          }
        }
      }
    }

    setState(() {
      totalTasksDueToday = total;
      completedTasksToday = completed;
    });
  }

  void _updateTaskCompletion(String taskId, bool isCompleted) async {
    final updateData = {
      'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
    };

    await FirebaseFirestore.instance.collection('todos').doc(taskId).update(updateData);
    _fetchDailyTasks(); // Refresh the progress after updating a task
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          if (FirebaseAuth.instance.currentUser?.photoURL != null)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(FirebaseAuth.instance.currentUser!.photoURL!),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isDesktop = constraints.maxWidth > 600;
          return Center(
            child: SizedBox(
              width: isDesktop ? 600 : double.infinity,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        labelText: 'Search TODOs',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.filter_list),
                          onPressed: () async {
                            final result = await showModalBottomSheet<FilterSheetResult>(
                              context: context,
                              builder: (context) {
                                return FilterSheet(initialFilters: _filters);
                              },
                            );

                            if (result != null) {
                              setState(() {
                                _filters = result;
                                _filteredTodos = filterTodos();
                              });
                            }
                          },
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filteredTodos = filterTodos();
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Display the number of tasks due today
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Tasks due today: $totalTasksDueToday',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: _filteredTodos?.isEmpty ?? true
                        ? const Center(child: Text('No TODOs found'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            itemCount: _filteredTodos?.length ?? 0,
                            itemBuilder: (context, index) {
                              final todo = _filteredTodos?[index];
                              if (todo == null) return const SizedBox.shrink();
                              return ListTile(
                                leading: Checkbox(
                                  value: todo.completedAt != null,
                                  onChanged: (bool? value) {
                                    _updateTaskCompletion(todo.id, value == true);
                                  },
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.arrow_forward_ios),
                                  ],
                                ),
                                title: Text(
                                  todo.text,
                                  style: todo.completedAt != null
                                      ? const TextStyle(decoration: TextDecoration.lineThrough)
                                      : null,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DetailScreen(
                                        todo: todo.copyWith(onDueDateUpdated: _fetchDailyTasks),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                  if (totalTasksDueToday > 0)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Daily Progress: $completedTasksToday / $totalTasksDueToday tasks completed',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: completedTasksToday / totalTasksDueToday,
                            minHeight: 10,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                                completedTasksToday == totalTasksDueToday ? Colors.green : Colors.blue),
                          ),
                        ],
                      ),
                    ),
                  Container(
                    color: Colors.green[100],
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.text,
                            controller: _controller,
                            decoration: const InputDecoration(
                              labelText: 'Enter Task:',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            if (user != null && _controller.text.isNotEmpty) {
                              await FirebaseFirestore.instance.collection('todos').add({
                                'text': _controller.text,
                                'createdAt': FieldValue.serverTimestamp(),
                                'uid': user.uid,
                              });
                              _controller.clear();
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}