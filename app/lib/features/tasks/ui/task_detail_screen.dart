import 'package:flutter/material.dart';

/// Placeholder until the real screen lands.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('TaskDetailScreen $taskId')));
}
