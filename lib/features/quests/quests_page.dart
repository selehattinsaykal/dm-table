import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/clock_tables.dart';
import '../../data/db/database.dart';
import '../../data/loot_repository.dart';
import '../../data/quest_repository.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../app/undo.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../clocks/clocks_card.dart';
import '../loot/loot_page.dart';
import 'quest_providers.dart';

/// Görevler sekmesi: görevleri kart olarak listeler, elle oluştur/düzenle,
/// üstlenen karakterleri işaretle, tamamla, sil.
class QuestsPage extends ConsumerWidget {
  const QuestsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final quests = ref.watch(questsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navQuests)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(questRepositoryProvider);
          final id = await repo.create();
          if (context.mounted) {
            await Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => QuestEditPage(questId: id)),
            );
          }
        },
        icon: const Icon(Icons.add),
        label: Text(l10n.questsNew),
      ),
      body: asyncView(
        context,
        quests,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(questsProvider),
        data: (list) => list.isEmpty
            ? Center(
                child: Text(
                  l10n.questsEmpty,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _QuestCard(quest: list[i]),
              ),
      ),
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.quest});
  final Quest quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final repo = ref.read(questRepositoryProvider);
    final characters = ref.watch(charactersProvider).value ?? const [];
    String nameOf(String id) =>
        characters.where((c) => c.id == id).firstOrNull?.name ?? id;

    final owners = [
      for (final id in QuestRepository.targetsOf(quest)) nameOf(id),
    ];

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => QuestEditPage(questId: quest.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (quest.done)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      quest.title.isEmpty ? l10n.questUntitled : quest.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: quest.done
                            ? TextDecoration.lineThrough
                            : null,
                        color: quest.done ? theme.colorScheme.outline : null,
                      ),
                    ),
                  ),
                  _menu(context, ref, repo, l10n),
                ],
              ),
              if (quest.questText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    quest.questText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              if (owners.isNotEmpty) ...[
                const SizedBox(height: 6),
                _statusChip(
                  theme,
                  Icons.person_outline,
                  theme.colorScheme.secondary,
                  '${l10n.questOwners}: ${owners.join(', ')}',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChip(
    ThemeData theme,
    IconData icon,
    Color color,
    String text,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: color),
      const SizedBox(width: 4),
      Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
    ],
  );

  Widget _menu(
    BuildContext context,
    WidgetRef ref,
    QuestRepository repo,
    L10n l10n,
  ) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) async {
        switch (v) {
          case 'complete':
            await repo.setDone(quest.id, !quest.done);
          case 'delete':
            await _deleteDialog(context, ref, repo, l10n);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'complete',
          child: Row(
            children: [
              Icon(
                quest.done ? Icons.undo : Icons.check_circle_outline,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(quest.done ? l10n.questReopen : l10n.questComplete),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 18),
              const SizedBox(width: 8),
              Text(l10n.delete),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _deleteDialog(
    BuildContext context,
    WidgetRef ref,
    QuestRepository repo,
    L10n l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.questDelete),
        content: Text(l10n.questDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true) {
      // Gorev tek bir satir; kaskadi yok, o yuzden satirin kendisi yeterli.
      await repo.delete(quest.id);
      final db = ref.read(databaseProvider);
      ref
          .read(undoControllerProvider.notifier)
          .push(
            quest.title,
            () => db
                .into(db.quests)
                .insertOnConflictUpdate(quest.toCompanion(false)),
          );
    }
  }
}

/// Görev düzenleme (elle oluşturma da buradan): başlık, oyuncu metni, ödül,
/// DM notu.
class QuestEditPage extends ConsumerStatefulWidget {
  const QuestEditPage({required this.questId, super.key});
  final String questId;
  @override
  ConsumerState<QuestEditPage> createState() => _QuestEditPageState();
}

class _QuestEditPageState extends ConsumerState<QuestEditPage> {
  final _title = TextEditingController();
  final _quest = TextEditingController();
  final _reward = TextEditingController();
  final _dm = TextEditingController();

  // Ödül parası (pp/gp/sp/cp) — ganimet seti editörüyle aynı düzen.
  final _pp = TextEditingController();
  final _gp = TextEditingController();
  final _sp = TextEditingController();
  final _cp = TextEditingController();
  final _newItem = TextEditingController();
  final _rewardItems = <LootItemData>[];
  bool _newItemMagic = false;

  /// Görevi üstlenen karakterler; işaretlenince doğrudan yazılır.
  final _selectedTargets = <String>{};

  bool _loaded = false;

  /// Duzenleme modu; KAPALI baslar (bkz. `app/ui/edit_mode.dart`). Bir goreve
  /// bakmak — masada en sik yapilan sey — artik bos bir form duvari degil,
  /// okunur bir ozet.
  ///
  /// USTLENENLER bolumu bu modun DISINDA: "bu is kimin uzerinde" masada
  /// degisen bir sey, hazirlik degil.
  bool _editing = false;

  static const _units = [1000, 100, 10, 1];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final q = await ref.read(questRepositoryProvider).find(widget.questId);
    if (q != null) {
      _title.text = q.title;
      _quest.text = q.questText;
      _reward.text = q.reward;
      _dm.text = q.dmNotes;
      var rest = q.rewardCoinsCp;
      final controllers = [_pp, _gp, _sp, _cp];
      for (var i = 0; i < _units.length; i++) {
        controllers[i].text = '${rest ~/ _units[i]}';
        rest %= _units[i];
      }
      _rewardItems
        ..clear()
        ..addAll(QuestRepository.rewardItemsOf(q));
      _selectedTargets.addAll(QuestRepository.targetsOf(q));
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _quest,
      _reward,
      _dm,
      _pp,
      _gp,
      _sp,
      _cp,
      _newItem,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int _coinTotal() {
    int v(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
    return v(_pp) * 1000 + v(_gp) * 100 + v(_sp) * 10 + v(_cp);
  }

  /// Formu DB'ye yazar (sayfayı KAPATMAZ).
  Future<void> _persist() => ref
      .read(questRepositoryProvider)
      .update(
        widget.questId,
        title: _title.text.trim(),
        questText: _quest.text.trim(),
        reward: _reward.text.trim(),
        dmNotes: _dm.text.trim(),
        rewardCoinsCp: _coinTotal(),
        rewardItems: _rewardItems,
      );

  /// Kaydedince sayfayi KAPATMIYORUZ, okuma moduna donuyoruz: DM yazdiginin
  /// sonucunu gorsun.
  Future<void> _save() async {
    await _persist();
    if (mounted) setState(() => _editing = false);
  }

  /// Vazgec: diskteki hâli geri yükler, okuma moduna doner.
  Future<void> _cancel() async {
    setState(() {
      _editing = false;
      _loaded = false;
      _rewardItems.clear();
      _selectedTargets.clear();
    });
    await _load();
  }

  void _addItem() {
    final name = _newItem.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _rewardItems.add((name: name, magic: _newItemMagic));
      _newItem.clear();
      _newItemMagic = false;
    });
  }

  Future<void> _openCompendiumPicker() async {
    await showDialog<void>(
      context: context,
      builder: (context) => CompendiumLootPickerDialog(
        // Gorev odul havuzu ada gore calisir; katalog anahtari kullanilmaz.
        onAdd: (_, name, magic) {
          if (!mounted) return;
          setState(() => _rewardItems.add((name: name, magic: magic)));
        },
      ),
    );
  }

  /// Görevi üstlenen karakter listesini yazar.
  ///
  /// Formun geri kalanindan FARKLI olarak aninda kaydedilir: bu bir metin
  /// alani degil, tek dokunusluk bir isaret ve "kaydet"e basmayi beklemek
  /// masada unutuluyordu.
  Future<void> _persistOwners() => ref
      .read(questRepositoryProvider)
      .setTargets(widget.questId, _selectedTargets.toList());

  Widget _coinField(TextEditingController c, String label) => Expanded(
    child: TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        // Okuma modunda gorevin BASLIGI ustte: hangi goreve baktigin belli olsun.
        title: Text(
          _editing || _title.text.trim().isEmpty
              ? l10n.questEditTitle
              : _title.text.trim(),
        ),
        actions: [
          if (_editing) ...[
            TextButton.icon(
              onPressed: _loaded ? _save : null,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(l10n.save),
            ),
            IconButton(
              tooltip: l10n.editModeDiscard,
              icon: const Icon(Icons.close),
              onPressed: _loaded ? _cancel : null,
            ),
          ] else
            EditModeButton(
              editing: false,
              onToggle: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: !_loaded
          ? const AppLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_editing) ...[
                  TextField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: l10n.questTitleLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _quest,
                    minLines: 3,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.questTextLabel,
                      helperText: l10n.questTextHelper,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _reward,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: l10n.questRewardLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _rewardSection(theme, l10n),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _dm,
                    minLines: 2,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: l10n.questDmLabel,
                      helperText: l10n.questDmHelper,
                      helperStyle: TextStyle(color: theme.colorScheme.tertiary),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ] else
                  ..._readSections(theme, l10n),
                const SizedBox(height: 20),
                // Ustlenenler her iki modda da acik: masada degisen bir
                // sey, hazirlik degil.
                _ownersSection(theme, l10n),
                const SizedBox(height: 20),
                // Goreve bagli saatler: "kervan uc gunde varmazsa" gibi
                // sureli baskilar gorevin yaninda dursun.
                ClocksCard(
                  link: (kind: ClockLinkKind.quest, id: widget.questId),
                ),
              ],
            ),
    );
  }

  /// Okuma modu: doldurulmus alanlar okunur metin olarak, bos olanlar hiç.
  List<Widget> _readSections(ThemeData theme, L10n l10n) {
    final quest = _quest.text.trim();
    final reward = _reward.text.trim();
    final dm = _dm.text.trim();
    final coins = _coinTotal();
    final hasRealReward = coins > 0 || _rewardItems.isNotEmpty;

    return [
      if (quest.isNotEmpty)
        ReadOnlyField(label: l10n.questTextLabel, value: quest),
      if (reward.isNotEmpty)
        ReadOnlyField(label: l10n.questRewardLabel, value: reward),
      if (hasRealReward) _rewardSummary(theme, l10n, coins),
      if (dm.isNotEmpty)
        // DM notu okuma modunda da AYRISMALI: oyuncuya okunacak metinle
        // ayni gorunurse masada yanlislikla sesli okunur.
        Card(
          color: theme.colorScheme.tertiaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.questDmLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  dm,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      if (quest.isEmpty && reward.isEmpty && dm.isEmpty && !hasRealReward)
        const EmptyRecordHint(),
    ];
  }

  /// Gerçek ödülün okunur özeti (para + eşyalar).
  Widget _rewardSummary(ThemeData theme, L10n l10n, int coins) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.questRealReward, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          if (coins > 0) Text(formatCoins(coins)),
          for (final item in _rewardItems)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(
                    item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                    size: 18,
                    color: item.magic ? theme.colorScheme.tertiary : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.name)),
                ],
              ),
            ),
        ],
      ),
    ),
  );

  /// Gerçek ödül: para + eşyalar. Serbest metin ödül açıklamasının yanında,
  /// DM'in dağıtacağı somut listedir.
  Widget _rewardSection(ThemeData theme, L10n l10n) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.questRealReward, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(l10n.questRealRewardHint, style: theme.textTheme.bodySmall),
          const SizedBox(height: 12),
          Text(l10n.lootMoney, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              _coinField(_pp, 'pp'),
              const SizedBox(width: 8),
              _coinField(_gp, 'gp'),
              const SizedBox(width: 8),
              _coinField(_sp, 'sp'),
              const SizedBox(width: 8),
              _coinField(_cp, 'cp'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.lootItems, style: theme.textTheme.titleSmall),
              TextButton.icon(
                onPressed: _openCompendiumPicker,
                icon: const Icon(Icons.library_books_outlined, size: 18),
                label: Text(l10n.lootAddFromCompendium),
              ),
            ],
          ),
          if (_rewardItems.isEmpty)
            Text(l10n.lootNoItems, style: theme.textTheme.bodySmall),
          for (final (i, item) in _rewardItems.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                color: item.magic ? theme.colorScheme.tertiary : null,
              ),
              title: Text(item.name),
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() => _rewardItems.removeAt(i)),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newItem,
                  decoration: InputDecoration(
                    labelText: l10n.lootAddItem,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: Text(l10n.lootMagic),
                selected: _newItemMagic,
                onSelected: (v) => setState(() => _newItemMagic = v),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  /// Görevi hangi karakterlerin üstlendiği.
  ///
  /// Eskiden burasi "oyunculara goster" paneliydi (tek tek kabul ya da
  /// oylama). Oyuncu paneli kalkinca geriye masada gercekten sorulan sey
  /// kaldi: bu is kimin uzerinde?
  Widget _ownersSection(ThemeData theme, L10n l10n) {
    final characters =
        ref.watch(charactersProvider).value ?? const <Character>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.questOwnersSection, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.questOwnersHint, style: theme.textTheme.bodySmall),
            if (characters.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l10n.questNoCharacters,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            for (final c in characters)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: _selectedTargets.contains(c.id),
                title: Text(c.name),
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedTargets.add(c.id);
                    } else {
                      _selectedTargets.remove(c.id);
                    }
                  });
                  _persistOwners();
                },
              ),
          ],
        ),
      ),
    );
  }
}
