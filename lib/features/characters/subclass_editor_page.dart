import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/custom_content_repository.dart';
import '../../l10n/app_localizations.dart';
import 'character_providers.dart';
import 'creation_wizard.dart' show customContentRepositoryProvider;

/// Alt sinif editoru.
///
/// Girilen alt sinif SRD'dekilerle ayni sekilde saklandigi icin level
/// atlarken yetenekleri kendiliginden geliyor ve sayaclari karakter
/// kagidinda gorunuyor. Masada kullandigin bes-alti alt sinifi bir kez
/// girmen yeterli.
class SubclassEditorPage extends ConsumerStatefulWidget {
  const SubclassEditorPage({
    required this.parentClassKey,
    required this.parentClassName,
    super.key,
  });

  final String parentClassKey;
  final String parentClassName;

  @override
  ConsumerState<SubclassEditorPage> createState() => _SubclassEditorPageState();
}

class _SubclassEditorPageState extends ConsumerState<SubclassEditorPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _features = <SubclassFeature>[];
  final _resources = <SubclassResource>[];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.seSubclassOf(widget.parentClassName))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          TextField(
            controller: _name,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.ccSubclassName,
              hintText: l10n.ccSubclassNameHint,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.seShortDesc,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: l10n.sheetFeatures,
            subtitle: l10n.seFeaturesHint,
            onAdd: _addFeature,
          ),
          if (_features.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.seNoFeatures, style: theme.textTheme.bodySmall),
            )
          else
            for (final (index, feature) in _sortedFeatures.indexed)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text(
                      '${feature.level}',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  title: Text(feature.name),
                  subtitle: feature.description.isEmpty
                      ? null
                      : Text(
                          feature.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () => _features.remove(_sortedFeatures[index]),
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: l10n.seResources,
            subtitle: l10n.seResourcesHint,
            onAdd: _addResource,
          ),
          if (_resources.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(l10n.seNoResources, style: theme.textTheme.bodySmall),
            )
          else
            for (final resource in _resources)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.tag),
                  title: Text(resource.name),
                  subtitle: Text(
                    (resource.valuesByLevel.keys.toList()..sort())
                        .map(
                          (l) => l10n.seLevelArrow(
                            l,
                            '${resource.valuesByLevel[l]}',
                          ),
                        )
                        .join('   '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () =>
                        setState(() => _resources.remove(resource)),
                  ),
                ),
              ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _name.text.trim().isEmpty || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  List<SubclassFeature> get _sortedFeatures =>
      _features.toList()..sort((a, b) => a.level.compareTo(b.level));

  Future<void> _addFeature() async {
    final feature = await showDialog<SubclassFeature>(
      context: context,
      builder: (context) => const _FeatureDialog(),
    );
    if (feature != null) setState(() => _features.add(feature));
  }

  Future<void> _addResource() async {
    final resource = await showDialog<SubclassResource>(
      context: context,
      builder: (context) => const _ResourceDialog(),
    );
    if (resource != null) setState(() => _resources.add(resource));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final key = await ref
          .read(customContentRepositoryProvider)
          .addSubclass(
            name: _name.text.trim(),
            parentClassKey: widget.parentClassKey,
            parentClassName: widget.parentClassName,
            description: _description.text.trim(),
            features: _sortedFeatures,
            resources: _resources,
          );
      ref.invalidate(subclassesProvider(widget.parentClassKey));
      ref.invalidate(allClassDefinitionsProvider);
      if (mounted) Navigator.of(context).pop(key);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: Text(L10n.of(context).add),
            ),
          ],
        ),
        Text(subtitle, style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _FeatureDialog extends StatefulWidget {
  const _FeatureDialog();

  @override
  State<_FeatureDialog> createState() => _FeatureDialogState();
}

class _FeatureDialogState extends State<_FeatureDialog> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  int _level = 3;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return AlertDialog(
      title: Text(l10n.seAddFeature),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(l10n.formLevel),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _level > 1
                        ? () => setState(() => _level--)
                        : null,
                  ),
                  Text(
                    '$_level',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _level < 20
                        ? () => setState(() => _level++)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.seFeatureName,
                  hintText: l10n.seFeatureNameHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: l10n.seFeatureDesc,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () => Navigator.pop(context, (
                  level: _level,
                  name: _name.text.trim(),
                  description: _description.text.trim(),
                )),
          child: Text(l10n.add),
        ),
      ],
    );
  }
}

/// Seviyeye gore degisen sayac tanimlar.
///
/// Kullanici yalnizca degisim noktalarini giriyor (3. seviyede 4, 7'de 5);
/// aradaki seviyeler kaydederken kendiliginden dolduruluyor.
class _ResourceDialog extends StatefulWidget {
  const _ResourceDialog();

  @override
  State<_ResourceDialog> createState() => _ResourceDialogState();
}

class _ResourceDialogState extends State<_ResourceDialog> {
  final _name = TextEditingController();
  final _values = <int, String>{};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final levels = _values.keys.toList()..sort();

    return AlertDialog(
      title: Text(l10n.seAddResource),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.seResourceName,
                  hintText: l10n.seResourceNameHint,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Text(l10n.seResourceHint, style: theme.textTheme.bodySmall),
              const SizedBox(height: 8),
              for (final level in levels)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.seLevelArrow(level, '${_values[level]}')),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _values.remove(level)),
                  ),
                ),
              TextButton.icon(
                onPressed: _addThreshold,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.seAddThreshold),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _name.text.trim().isEmpty || _values.isEmpty
              ? null
              : () => Navigator.pop(context, (
                  name: _name.text.trim(),
                  valuesByLevel: Map<int, String>.from(_values),
                )),
          child: Text(l10n.add),
        ),
      ],
    );
  }

  Future<void> _addThreshold() async {
    var level = _values.isEmpty
        ? 3
        : (_values.keys.reduce((a, b) => a > b ? a : b) + 1);
    final value = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = L10n.of(context);
        return StatefulBuilder(
          builder: (context, setInner) => AlertDialog(
            title: Text(l10n.seThreshold),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(l10n.formLevel),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: level > 1
                          ? () => setInner(() => level--)
                          : null,
                    ),
                    Text('$level'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: level < 20
                          ? () => setInner(() => level++)
                          : null,
                    ),
                  ],
                ),
                TextField(
                  controller: value,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.seValue,
                    hintText: l10n.seValueHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.add),
              ),
            ],
          ),
        );
      },
    );

    if (added == true && value.text.trim().isNotEmpty) {
      setState(() => _values[level] = value.text.trim());
    }
  }
}
