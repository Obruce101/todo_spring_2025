import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';

class SubTask {
  final String id;
  final String text;

  final bool isCompleted;

  SubTask({
    required this.id,
    required this.text,
    this.isCompleted = false,
  });

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      isCompleted: map['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isCompleted': isCompleted,
    };
  }
}




class Todo {
  final String id;
  final String text;
  final String uid;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? dueAt;
  final VoidCallback? onDueDateUpdated;
  final String? location;

  Todo({
    required this.id,
    required this.text,
    required this.uid,
    required this.createdAt,
    required this.completedAt,
    required this.dueAt,
    this.onDueDateUpdated,
    this.location,
  });

  Todo copyWith({VoidCallback? onDueDateUpdated}) {
    return Todo(
      id: id,
      text: text,
      uid: uid,
      createdAt: createdAt,
      dueAt: dueAt,
      completedAt: completedAt,
      onDueDateUpdated: onDueDateUpdated ?? this.onDueDateUpdated,


    );
  }

  Map<String, dynamic> toSnapshot() {
    return {
      'text': text,
      'uid': uid,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'location': location,
    };
  }

  factory Todo.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
     // Log the entire document

    return Todo(
      id: snapshot.id,
      text: data['text'],
      uid: data['uid'],
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      dueAt: data['dueAt'] != null ? (data['dueAt'] as Timestamp).toDate() : null,
      location: data['location'],
    );
  }
}
