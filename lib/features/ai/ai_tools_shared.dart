import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ai_settings_provider.dart';
import '../../app/theme.dart';
import '../../data/ai/ai_service.dart';
import '../../l10n/app_localizations.dart';

/// AI araclarinin ORTAK parcalari.
///
/// Ucu de (NPC / Gorev / Karsilasma) ayni iskeleti kuruyor: calisma durumu,
/// hata kutusu, "AI ayarlanmadi" ekrani, kaydirici ve sonuc bolumu. Ucuncu
/// arac eklenirken bunlar `ai_tools_page.dart` icinden buraya cikarildi;
/// oyle olmasa her arac kendi kopyasini tasiyacakti.

class AiRunState {
  bool loading = false;
  String? result;
  String? error;

  /// Saglayicinin ham hata metni. Cevrilmis mesaj cogu zaman yetmiyor —
  /// hangi kotanin doldugunu ya da modelin planda olup olmadigini yalnizca
  /// bu satir soyluyor.
  String? errorDetail;

  Future<void> generate(
    BuildContext context,
    WidgetRef ref,
    String system,
    String user,
    VoidCallback refresh,
  ) async {
    final l10n = L10n.of(context);
    final ai = ref.read(aiSettingsProvider);
    loading = true;
    error = null;
    errorDetail = null;
    result = null;
    refresh();
    try {
      final text = await AiService(
        ai,
      ).generate(systemPrompt: system, userPrompt: user);
      result = text;
    } on AiException catch (e) {
      error = aiErrorMessage(l10n, e.message);
      errorDetail = e.detail;
    } finally {
      loading = false;
      refresh();
    }
  }
}

/// Hata mesaji + (varsa) saglayicinin ham yaniti.
class AiErrorBox extends StatelessWidget {
  const AiErrorBox({super.key, required this.message, this.detail});

  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Container(
      margin: EdgeInsets.only(top: context.spacing.md),
      padding: EdgeInsets.all(context.spacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(context.radii.lg),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: theme.colorScheme.error,
              ),
              SizedBox(width: context.spacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            SizedBox(height: context.spacing.sm),
            Text(
              l10n.aiErrorDetail,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: context.spacing.xs),
            // Secilebilir: DM hatayi arama motoruna/bize yapistirabilmeli.
            SelectableText(
              detail!,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// AI kapalıyken gösterilir: Ayarlar'a yönlendirir.
class AiNotConfigured extends StatelessWidget {
  const AiNotConfigured({super.key});
  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.key_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l10n.codexAiNotConfigured, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.settings, size: 18),
              label: Text(l10n.aiOpenSettings),
            ),
          ],
        ),
      ),
    );
  }
}

class AiSliderRow extends StatelessWidget {
  const AiSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value',
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ),
        SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.end)),
      ],
    );
  }
}

String aiErrorMessage(L10n l10n, String code) => switch (code) {
  'no-key' => l10n.codexAiNotConfigured,
  'auth' => l10n.codexAiErrAuth,
  'rate' => l10n.codexAiErrRate,
  'network' => l10n.codexAiErrNetwork,
  'refused' => l10n.codexAiErrRefused,
  'empty' => l10n.codexAiErrEmpty,
  'no-image' => l10n.codexAiErrNoImage,
  _ => l10n.codexAiErrGeneric,
};

/// Bir görev bölümü kartı. [dmOnly] ise DM'e özel stil + "sadece sen görüyorsun"
/// notu (oyunculara paylaşılan kopyaya girmez).
/// Üreticinin verdiği ödülün MAKİNE OKUNUR hâli: "Görevlere gönder" dendiğinde
/// bu para + eşyalar görevin gerçek ödülü olarak kaydedilir ve görev bitince
/// oyunculara ortak ganimet havuzu olarak açılır.
class AiSection extends StatelessWidget {
  const AiSection({
    super.key,
    required this.title,
    required this.body,
    this.dmOnly = false,
    this.note,
  });

  final String title;
  final String body;
  final bool dmOnly;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = dmOnly
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = dmOnly
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSurface;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: dmOnly
            ? Border.all(color: theme.colorScheme.tertiary, width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (dmOnly) ...[
                Icon(Icons.visibility_off, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(color: fg),
              ),
            ],
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: fg.withValues(alpha: 0.8),
                ),
              ),
            ),
          const SizedBox(height: 6),
          SelectableText(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

/// Kullanıcıya bir Kayıtlar sayfası seçtirir; sayfa yoksa uyarı + null.
