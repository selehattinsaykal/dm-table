import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Detay sayfalarinin ORTAK "duzenleme modu" parcalari.
///
/// Kural: bir kaydin sayfasi VARSAYILAN OLARAK OKUMA icindir. Masada bir
/// goreve ya da NPC'ye bakmak, onu yanlislikla degistirme riski tasimamali;
/// sayfalar bos form alanlarindan olusan bir duvar yerine okunur bir ozet
/// gostermeli. Degistirmek bilincli bir hamle: DM kalem dugmesine basar.
///
/// Ayni kalip once harita sayfasinda kuruldu (`LocationPage`), buraya
/// tasindi ki gorev/NPC/dukkan sayfalari da ayni davransin.

/// Arac cubugundaki duzenleme modu anahtari.
///
/// Durum yalnizca ikonla anlatilmiyor: acikken dolgu zemin + vurgu rengi
/// birlikte "bu sayfa artik yaziyor" der (UX: aktif mod gorunur olmali).
class EditModeButton extends StatelessWidget {
  const EditModeButton({
    required this.editing,
    required this.onToggle,
    super.key,
  });

  final bool editing;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return IconButton(
      tooltip: editing ? l10n.editModeOn : l10n.editModeOff,
      isSelected: editing,
      icon: const Icon(Icons.edit_outlined),
      selectedIcon: const Icon(Icons.edit),
      style: IconButton.styleFrom(
        backgroundColor: editing
            ? theme.colorScheme.primary.withValues(alpha: 0.16)
            : null,
        foregroundColor: editing ? theme.colorScheme.primary : null,
      ),
      onPressed: onToggle,
    );
  }
}

/// Duzenlenebilir bir alan: modda gore ya form girdisi ya okunur metin.
///
/// Goruntuleme modunda BOS alanlar hic cizilmez. Sebep: 14 alanli bir NPC
/// formunun cogu genelde bostur; hepsini bos etiketlerle gostermek okunur
/// ozeti gurultuye bogar. Duzenleme moduna gecince hepsi geri gelir.
class DetailField extends StatelessWidget {
  const DetailField({
    required this.label,
    required this.controller,
    required this.editing,
    this.lines = 1,
    this.keyboardType,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final bool editing;
  final int lines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    if (editing) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: lines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
    }

    final value = controller.text.trim();
    if (value.isEmpty) return const SizedBox.shrink();
    return ReadOnlyField(label: label, value: value);
  }
}

/// Salt-okunur "etiket + deger" satiri.
///
/// Ayri bir widget: bazi alanlar bir denetleyiciden gelmiyor (hesaplanmis
/// deger, birlestirilmis metin) ama ayni gorsel ritmi paylasmali.
class ReadOnlyField extends StatelessWidget {
  const ReadOnlyField({
    required this.label,
    required this.value,
    this.emphasize = false,
    super.key,
  });

  final String label;
  final String value;

  /// Baslik gibi one cikan alanlar (ad, baslik) icin buyuk govde punto.
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: emphasize
                ? theme.textTheme.titleLarge
                : theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// Goruntuleme modunda, kayitta gosterilecek hicbir sey yoksa cikan not.
///
/// Bos bir sayfa "yuklenmedi mi?" izlenimi verir; bu satir "kayit gercekten
/// bos, doldurmak icin duzenlemeyi ac" der.
class EmptyRecordHint extends StatelessWidget {
  const EmptyRecordHint({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: context.spacing.lg),
      child: Row(
        children: [
          Icon(
            Icons.edit_note_outlined,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(
            child: Text(
              L10n.of(context).editModeEmptyRecord,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
