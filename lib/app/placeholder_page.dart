import 'package:flutter/material.dart';

/// Henuz yazilmamis fazlar icin gecici ekran.
///
/// Her biri hangi fazda gelecegini soyler, boylece iskelet uzerinde gezerken
/// neyin eksik oldugu belli olur.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({
    required this.title,
    required this.phase,
    required this.icon,
    super.key,
  });

  final String title;
  final String phase;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text(phase, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }
}
