import 'package:flutter/material.dart';

/// Placeholder — full alert history arrives in Step 7.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: const Center(
        child: Text('Alert history — coming in Step 7',
            style: TextStyle(color: Color(0xFF94A3B8))),
      ),
    );
  }
}
