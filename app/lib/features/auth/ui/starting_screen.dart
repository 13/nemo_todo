import 'package:flutter/material.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';

/// The moment between the first frame and knowing whether anyone is signed
/// in. On the web it is what the page's loading screen fades out onto, so
/// it shows the same mark in the same place; see [NemoSplashMark] for why
/// it stands still.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: NemoSplashMark()));
}
