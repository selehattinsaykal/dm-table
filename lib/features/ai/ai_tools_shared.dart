import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/ai_settings_provider.dart';
import '../../app/theme.dart';
import '../../data/ai/ai_service.dart';
import '../../data/db/database.dart';
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

  /// [maxTokens] varsayilani cogu arac icin yeterli; cok bolumlu ciktisi olan
  /// araclar (bkz. gorev ureteci: asamalar + kancalar + komplikasyonlar)
  /// bunu yukseltir, aksi halde JSON ORTASINDA kesilir ve ayristirilamaz.
  Future<void> generate(
    BuildContext context,
    WidgetRef ref,
    String system,
    String user,
    VoidCallback refresh, {
    int maxTokens = 2048,
  }) async {
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
      ).generate(systemPrompt: system, userPrompt: user, maxTokens: maxTokens);
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

/// Etiketli tek-secimli chip satiri. Gorev ureteci dort ayri enum'u ayni
/// bicimde sordugu icin ortak; her biri icin Wrap kopyalamak yerine.
class AiEnumChips<T> extends StatelessWidget {
  const AiEnumChips({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.enabled,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> values;
  final T selected;
  final bool enabled;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(labelOf(v)),
                selected: selected == v,
                onSelected: enabled ? (_) => onSelected(v) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class AiOptionalPicker extends StatelessWidget {
  const AiOptionalPicker({
    super.key,
    required this.label,
    required this.noneLabel,
    required this.hint,
    required this.entries,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String noneLabel;
  final String hint;

  /// (id, görünen ad) çiftleri.
  final List<(String, String)> entries;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safe = entries.any((e) => e.$1 == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: safe,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            DropdownMenuItem(value: null, child: Text(noneLabel)),
            for (final e in entries)
              DropdownMenuItem(
                value: e.$1,
                child: Text(e.$2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: enabled ? onChanged : null,
        ),
        SizedBox(height: context.spacing.xs),
        Text(
          hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Hiyerarşik lokasyon seçici.
///
/// Kök ("temel") lokasyonlar liste hâlinde durur; alt lokasyonu olanların
/// yanında küçük bir ok bulunur ve ona basılınca alt lokasyonlar **girintili
/// olarak altında** açılır. Böylece derin bir dünya ağacı, düz bir açılır
/// listede yüzlerce satır olmadan gezilebiliyor.
///
/// Seçim her kademeden yapılabilir: bir bölgeyi de, onun içindeki tek bir
/// hanı da seçmek serbest.
class AiLocationTreePicker extends StatefulWidget {
  const AiLocationTreePicker({
    super.key,
    required this.label,
    required this.noneLabel,
    required this.hint,
    required this.nodes,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String noneLabel;
  final String hint;

  /// TÜM lokasyonlar (düz liste); ağaç [LocationNode.parentId]'den kuruluyor.
  final List<LocationNode> nodes;

  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  State<AiLocationTreePicker> createState() => _AiLocationTreePickerState();
}

class _AiLocationTreePickerState extends State<AiLocationTreePicker> {
  final _open = <String>{};

  @override
  void initState() {
    super.initState();
    // Seçili olan derinlerdeyse ona giden yolu açık başlat; aksi hâlde
    // kutu açıldığında seçili öğe görünmezdi.
    var cursor = widget.nodes
        .where((n) => n.id == widget.value)
        .firstOrNull
        ?.parentId;
    while (cursor != null) {
      _open.add(cursor);
      cursor = widget.nodes.where((n) => n.id == cursor).firstOrNull?.parentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roots = widget.nodes.where((n) => n.parentId == null).toList();
    final selected = widget.nodes
        .where((n) => n.id == widget.value)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            enabled: widget.enabled,
          ),
          child: ConstrainedBox(
            // Dünya ağacı büyüyünce form sayfasını yutmasın diye sınırlı;
            // içeride kaydırılıyor.
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _row(
                    context,
                    id: null,
                    name: widget.noneLabel,
                    depth: 0,
                    hasChildren: false,
                  ),
                  for (final root in roots) ..._branch(context, root, 0),
                ],
              ),
            ),
          ),
        ),
        if (selected != null) ...[
          SizedBox(height: context.spacing.xs),
          Text(
            _path(selected),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
        SizedBox(height: context.spacing.xs),
        Text(
          widget.hint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// [node] ve (açıksa) tüm alt dalları.
  List<Widget> _branch(BuildContext context, LocationNode node, int depth) {
    final children = widget.nodes.where((n) => n.parentId == node.id).toList();
    return [
      _row(
        context,
        id: node.id,
        name: node.name,
        depth: depth,
        hasChildren: children.isNotEmpty,
      ),
      if (_open.contains(node.id))
        for (final child in children) ..._branch(context, child, depth + 1),
    ];
  }

  Widget _row(
    BuildContext context, {
    required String? id,
    required String name,
    required int depth,
    required bool hasChildren,
  }) {
    final theme = Theme.of(context);
    final isSelected = widget.value == id;
    final isOpen = id != null && _open.contains(id);

    return InkWell(
      onTap: widget.enabled ? () => widget.onChanged(id) : null,
      child: Padding(
        padding: EdgeInsets.fromLTRB(depth * 16.0, 4, 4, 4),
        child: Row(
          children: [
            // Ok SEÇİMDEN ayrı: dalı açmak onu seçmek anlamına gelmiyor.
            SizedBox(
              width: 28,
              child: hasChildren
                  ? InkWell(
                      onTap: widget.enabled
                          ? () => setState(
                              () => isOpen ? _open.remove(id) : _open.add(id!),
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                      child: Icon(
                        isOpen ? Icons.expand_more : Icons.chevron_right,
                        size: 20,
                      ),
                    )
                  : null,
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                size: 16,
                color: theme.colorScheme.primary,
              ),
            if (isSelected) const SizedBox(width: 6),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : null,
                  color: isSelected ? theme.colorScheme.primary : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Bölge > Şehir > Han" — seçilenin nerede olduğunu tek bakışta verir.
  String _path(LocationNode node) {
    final parts = <String>[node.name];
    var cursor = node.parentId;
    while (cursor != null) {
      final parent = widget.nodes.where((n) => n.id == cursor).firstOrNull;
      if (parent == null) break;
      parts.insert(0, parent.name);
      cursor = parent.parentId;
    }
    return parts.join(' › ');
  }
}

/// [AiLocationTreePicker]'ın ihtiyaç duyduğu asgari lokasyon bilgisi.
///
/// Drift'in `Location` tipine bağlanmamak için ayrı: seçici böylece test
/// edilebiliyor ve ileride başka bir kaynaktan da beslenebilir.
class LocationNode {
  const LocationNode({
    required this.id,
    required this.name,
    required this.parentId,
  });

  final String id;
  final String name;
  final String? parentId;
}

/// Drift `Location` listesini seçicinin anladığı düğümlere çevirir.
extension LocationNodes on List<Location> {
  List<LocationNode> toNodes() => [
    for (final l in this)
      LocationNode(id: l.id, name: l.name, parentId: l.parentId),
  ];
}
