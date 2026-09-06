import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ai_settings_provider.dart';
import '../../data/ai/ai_service.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../ai/session_recap.dart';

/// Oturum gunlugunden "gecen bolumde" ozeti.
///
/// AI KAPALIYSA dugme calismiyor ve kendi anahtarini kullaniyor; gunluk
/// metni cihazdan disari yalnizca kullanici bu dugmeye bastiginda cikiyor.
class SessionRecapSheet extends ConsumerStatefulWidget {
  const SessionRecapSheet({super.key});

  @override
  ConsumerState<SessionRecapSheet> createState() => _SessionRecapSheetState();
}

class _SessionRecapSheetState extends ConsumerState<SessionRecapSheet> {
  String? _recap;
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final ai = ref.watch(aiSettingsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.sessionRecap,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (_recap != null)
                  IconButton(
                    tooltip: l10n.nameCopy,
                    icon: const Icon(Icons.copy_all_outlined),
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: _recap!)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            if (_recap != null)
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    _recap!,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: ai.enabled && !_busy ? _generate : null,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(l10n.sessionRecapGenerate),
            ),
            if (!ai.enabled) ...[
              const SizedBox(height: 8),
              Text(
                l10n.settingsAiInactive,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    final l10n = L10n.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final recap = await SessionRecap(
        ref.read(databaseProvider),
        AiService(ref.read(aiSettingsProvider)),
      ).generate(language: l10n.localeName);
      if (!mounted) return;
      setState(() {
        // Gunluk bossa ozet de yok; hata degil, bilgi.
        _recap = recap;
        _error = recap == null ? l10n.sessionRecapEmpty : null;
      });
    } on AiException catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
