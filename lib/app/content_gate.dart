import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../l10n/app_localizations.dart';

/// Kural kutuphanesi veritabanina yazilana kadar uygulamayi bekletir.
///
/// Yalnizca ilk acilista (ya da paketlenmis veri guncellendiginde) gorunur;
/// sonraki aciliislarda [contentReadyProvider] aninda tamamlanir.
class ContentGate extends ConsumerWidget {
  const ContentGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final ready = ref.watch(contentReadyProvider);

    return ready.when(
      data: (_) => child,
      loading: () =>
          _Progress(l10n: l10n, table: ref.watch(importProgressProvider)),
      error: (error, stack) => _Failure(
        l10n: l10n,
        error: error,
        onRetry: () => ref.invalidate(contentReadyProvider),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.l10n, this.table});

  final L10n l10n;
  final String? table;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 24),
              Text(l10n.importTitle, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                table == null
                    ? l10n.importSubtitle
                    : l10n.importStepWriting(table!),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({
    required this.l10n,
    required this.error,
    required this.onRetry,
  });

  final L10n l10n;
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 40,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(l10n.importFailed, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}
