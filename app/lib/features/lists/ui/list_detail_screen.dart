import 'package:flutter/material.dart';

/// Placeholder until the real screen lands.
class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('ListDetailScreen $listId')));
}
