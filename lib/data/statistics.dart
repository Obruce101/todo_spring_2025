import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Statistics {
  final int totalTasks;
  final int completedTasks;
  final int overdueTasks;
  final double completionRate;
  final double avgTasksCreatedPerWeek;
  final double avgTasksCompletedPerWeek;

  Statistics({
    required this.totalTasks,
    required this.completedTasks,
    required this.overdueTasks,
    required this.completionRate,
    required this.avgTasksCreatedPerWeek,
    required this.avgTasksCompletedPerWeek,
  });
}
