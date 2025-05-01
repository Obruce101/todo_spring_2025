import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:todo_spring_2025/data/statistics.dart';




class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int milestoneTarget = 1; // Initial milestone target

  Stream<Map<String, int>> _getTodoStatsStream(String userId) {
    return FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: userId)
        .snapshots()
        .map((querySnapshot) {
      int completedCount = 0;
      int pendingCount = 0;

      for (var doc in querySnapshot.docs) {
        if (doc.data()['completedAt'] != null) {
          completedCount++;
        } else {
          pendingCount++;
        }
      }

      return {
        'completed': completedCount,
        'pending': pendingCount,
      };
    });
  }

  void _checkAndUpdateMilestone(int completedTasks) {
    if (completedTasks >= milestoneTarget) {
      Future.microtask(() {
        setState(() {
          milestoneTarget = (milestoneTarget * 1.5).ceil(); // Increase target by 1.5x
        });
      });
    }
  }


  Future<Statistics> _fetchStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));

    final querySnapshot = await FirebaseFirestore.instance
        .collection('todos')
        .where('uid', isEqualTo: user.uid)
        .get();

    int totalTasks = querySnapshot.size;
    int completedTasks = 0;
    int overdueTasks = 0;
    int deletedTasks = 0;
    int tasksLastWeek = 0;
    int completedLastWeek = 0;

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final completedAt = data['completedAt'] as Timestamp?;
      final dueAt = data['dueAt'] as Timestamp?;
      final createdAt = data['createdAt'] as Timestamp;
      final isDeleted = data['isDeleted'] == true;

      if (completedAt != null) completedTasks++;
      if (isDeleted) deletedTasks++;

      if (dueAt != null && dueAt.toDate().isBefore(now) && completedAt == null) {
        overdueTasks++;
      }

      if (createdAt.toDate().isAfter(oneWeekAgo)) {
        tasksLastWeek++;
        if (completedAt != null) completedLastWeek++;
      }
    }

    final completionRate = totalTasks > 0
        ? (completedTasks / totalTasks * 100)
        : 0.0;

    final avgTasksCreatedPerWeek = tasksLastWeek / 7;
    final avgTasksCompletedPerWeek = completedLastWeek / 7;

    return Statistics(
      totalTasks: totalTasks,
      completedTasks: completedTasks,
      overdueTasks: overdueTasks,
      completionRate: completionRate,
      avgTasksCreatedPerWeek: avgTasksCreatedPerWeek,
      avgTasksCompletedPerWeek: avgTasksCompletedPerWeek,
    );
  }

  Widget _buildStatisticsSection(Statistics stats) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Statistics', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildStatRow('Total Tasks Created', stats.totalTasks.toString()),
            _buildStatRow('Total Tasks Completed', stats.completedTasks.toString()),
            _buildStatRow('Completion Rate', '${stats.completionRate.toStringAsFixed(1)}%'),
            _buildStatRow('Tasks Overdue', stats.overdueTasks.toString()),
            _buildStatRow('Avg Tasks Created/Week', stats.avgTasksCreatedPerWeek.toStringAsFixed(1)),
            _buildStatRow('Avg Tasks Completed/Week', stats.avgTasksCompletedPerWeek.toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: const Center(
          child: Text('No user is signed in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: StreamBuilder<Map<String, int>>(
        stream: _getTodoStatsStream(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text('Error loading statistics.'));
          }

          final stats = snapshot.data ?? {'completed': 0, 'pending': 0};
          final completedTasks = stats['completed']!;
          final progress = (completedTasks / milestoneTarget).clamp(0.0, 1.0);

          // Check and update milestone safely
          _checkAndUpdateMilestone(completedTasks);

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: user.photoURL != null
                      ? NetworkImage(user.photoURL!)
                      : const AssetImage('assets/images/default_avatar.png')
                          as ImageProvider,
                ),
                const SizedBox(height: 16),
                Text(
                  user.displayName ?? 'No Name',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email ?? 'No Email',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 32),

                // Future builder
                FutureBuilder<Statistics>(
                  future: _fetchStatistics(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: Text('No statistics available'));
                    }
                    return _buildStatisticsSection(snapshot.data!);
                  },
                ),

                const SizedBox(height: 32),
                  Column(
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Current Milestone :  ⭐ ${(milestoneTarget / 1.5).floor()} tasks ⭐',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                Text(
                  'Next Milestone: 🏔 $milestoneTarget tasks 🏔',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                      progress == 1.0 ? Colors.green : Colors.blue),
                ),
                const SizedBox(height: 16),
                if (progress == 1.0)
                  const Text(
                    '🎯 New Milestone Reached!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),

                const SizedBox(height: 32),


              ],
            ),
          );
        },
      ),
    );
  }
}