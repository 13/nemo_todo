import 'package:flutter/material.dart';

/// Centres [child] and caps its width so wide screens keep phone-like lines.
class MaxWidth extends StatelessWidget {
  const MaxWidth({required this.child, this.maxWidth = 720, super.key});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
