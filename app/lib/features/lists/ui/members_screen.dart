import 'package:flutter/material.dart';

/// Placeholder until the real screen lands.
class MembersScreen extends StatelessWidget {
  const MembersScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('MembersScreen $listId')));
}
