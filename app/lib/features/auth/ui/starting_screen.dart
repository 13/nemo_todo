import 'package:flutter/material.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';

/// The moment between the first frame and knowing whether anyone is signed
/// in. Deliberately still: it is on screen for a keychain read, and a
/// spinner that long reads as a failure rather than as progress.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: NemoLogoTile(size: 72)));
}
