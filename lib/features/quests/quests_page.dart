import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/async_view.dart';
import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../data/loot_repository.dart';
import '../../data/quest_repository.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../characters/character_providers.dart';
import '../loot/loot_page.dart';
import 'quest_providers.dart';

/// DM Görevler sekmesi: görevleri kart olarak listeler, elle oluştur/düzenle,
/// belirli oyunculara göster, tamamla, sil. Oyuncuların kabul/ret durumu
/// kartta görünür (DB canlı akışı).
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

    final targets = QuestRepository.targetsOf(quest);
    final acc = QuestRepository.acceptancesOf(quest);
    final accepted = [
      for (final id in targets)
        if (acc[id] == true) nameOf(id),
    ];
    final rejected = [
      for (final id in targets)
        if (acc[id] == false) nameOf(id),
    ];
    final pending = [
      for (final id in targets)
        if (!acc.containsKey(id)) nameOf(id),
    ];
    final voting = quest.shareMode == QuestRepository.modeVote;
    final pool = QuestRepository.poolOf(quest);

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
                    )
                  else if (quest.shared)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.cast_connected,
                        size: 18,
                        color: theme.colorScheme.secondary,
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
              if (pool != null) ...[
                const SizedBox(height: 6),
                _statusChip(
                  theme,
                  Icons.diamond_outlined,
                  theme.colorScheme.tertiary,
                  '${l10n.questRewardPending}: '
                  '${_poolSummary(pool, l10n)}',
                ),
              ],
              if (quest.shared || quest.voteStatus.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 2,
                  children: [
                    if (voting)
                      _statusChip(
                        theme,
                        Icons.how_to_vote,
                        theme.colorScheme.tertiary,
                        switch (quest.voteStatus) {
                          QuestRepository.votePassed => l10n.questVotePassed,
                          QuestRepository.voteFailed => l10n.questVoteFailed,
                          _ => l10n.questVoteOngoing,
                        },
                      ),
                    if (accepted.isNotEmpty)
                      _statusChip(
                        theme,
                        Icons.check,
                        theme.colorScheme.primary,
                        '${l10n.questAcceptedBy}: ${accepted.join(', ')}',
                      ),
                    if (rejected.isNotEmpty)
                      _statusChip(
                        theme,
                        Icons.close,
                        theme.colorScheme.error,
                        '${l10n.questRejectedBy}: ${rejected.join(', ')}',
                      ),
                    if (pending.isNotEmpty)
                      _statusChip(
                        theme,
                        Icons.hourglass_empty,
                        theme.colorScheme.outline,
                        '${l10n.questPending}: ${pending.join(', ')}',
                      ),
                    if (targets.isEmpty)
                      _statusChip(
                        theme,
                        Icons.info_outline,
                        theme.colorScheme.outline,
                        l10n.questNoTargets,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Dagitilmayi bekleyen odul havuzunun kisa ozeti ("120 gp + 2 eşya").
  static String _poolSummary(
    ({int coinsCp, List<({String id, String name, bool magic})> items}) pool,
    L10n l10n,
  ) => [
    if (pool.coinsCp > 0) formatCoins(pool.coinsCp),
    if (pool.items.isNotEmpty) l10n.questRewardItemCount(pool.items.length),
  ].join(' + ');

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
    // Not: "oyunculara goster" bilincli olarak burada DEGIL -- paylasim
    // (tek tek kabul / oylama) gorevin kendi sayfasindan yapilir.
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 20),
      onSelected: (v) async {
        switch (v) {
          case 'complete':
            await repo.setDone(quest.id, !quest.done);
          case 'delete':
            await _deleteDialog(context, repo, l10n);
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
    if (ok == true) await repo.delete(quest.id);
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

  /// Paylaşım panelindeki seçim (kaydedilmemiş; "Göster"e basınca yazılır).
  final _selectedTargets = <String>{};
  String _shareMode = QuestRepository.modeIndividual;

  bool _loaded = false;

  /// Duzenleme modu; KAPALI baslar (bkz. `app/ui/edit_mode.dart`). Bir goreve
  /// bakmak — masada en sik yapilan sey — artik bos bir form duvari degil,
  /// okunur bir ozet.
  ///
  /// PAYLASIM bolumu bu modun DISINDA: gorevi oyunculara acmak bir hazirlik
  /// degil, oyun sirasindaki asil hamledir.
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
      _shareMode = q.shareMode;
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

  /// Formu DB'ye yazar (sayfayı KAPATMAZ) — paylaşmadan önce de çağrılır ki
  /// oyunculara yarım kalmış metin gitmesin.
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

  /// Görevi seçili oyunculara açar. Oylama modunda oylama başlar (%50+ kabul
  /// görevi HERKESE verir, altında kalırsa kimse alamaz).
  Future<void> _share(L10n l10n) async {
    if (_selectedTargets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questNoTargets)));
      return;
    }
    await _persist();
    await ref
        .read(questRepositoryProvider)
        .setShared(
          widget.questId,
          shared: true,
          targets: _selectedTargets.toList(),
          mode: _shareMode,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _shareMode == QuestRepository.modeVote
              ? l10n.questVoteStarted
              : l10n.questShared,
        ),
      ),
    );
  }

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
    // Paylaşım durumu canlı okunur: oyuncular kabul/ret verdikçe ya da oylama
    // sonuçlandıkça bu sayfa kendini günceller.
    final quest = ref
        .watch(questsProvider)
        .value
        ?.where((q) => q.id == widget.questId)
        .firstOrNull;

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
                // Paylasim her iki modda da acik: gorevi oyunculara acmak
                // oyun sirasindaki hamle, hazirlik degil.
                _shareSection(theme, l10n, quest),
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

  /// Gerçek ödül: para + eşyalar. Görev tamamlanınca kabul eden oyunculara
  /// ORTAK ganimet havuzu olarak açılır.
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

  /// Paylaşım: hangi oyunculara, hangi biçimde (tek tek kabul / oylama).
  Widget _shareSection(ThemeData theme, L10n l10n, Quest? quest) {
    final characters =
        ref.watch(charactersProvider).value ?? const <Character>[];
    final repo = ref.read(questRepositoryProvider);
    final voting = _shareMode == QuestRepository.modeVote;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.questShareSection, style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: QuestRepository.modeIndividual,
                  icon: const Icon(Icons.how_to_reg, size: 18),
                  label: Text(l10n.questModeIndividual),
                ),
                ButtonSegment(
                  value: QuestRepository.modeVote,
                  icon: const Icon(Icons.how_to_vote, size: 18),
                  label: Text(l10n.questModeVote),
                ),
              ],
              selected: {_shareMode},
              onSelectionChanged: (s) => setState(() => _shareMode = s.first),
            ),
            const SizedBox(height: 6),
            Text(
              voting ? l10n.questModeVoteHint : l10n.questModeIndividualHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Text(l10n.questSharePick, style: theme.textTheme.titleSmall),
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
                subtitle: quest == null
                    ? null
                    : _targetStatus(l10n, quest, c.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedTargets.add(c.id);
                  } else {
                    _selectedTargets.remove(c.id);
                  }
                }),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: characters.isEmpty ? null : () => _share(l10n),
                  icon: Icon(voting ? Icons.how_to_vote : Icons.cast, size: 18),
                  label: Text(voting ? l10n.questStartVote : l10n.questShow),
                ),
                if (quest?.shared ?? false)
                  OutlinedButton.icon(
                    onPressed: () =>
                        repo.setShared(widget.questId, shared: false),
                    icon: const Icon(Icons.cast_outlined, size: 18),
                    label: Text(l10n.questHide),
                  ),
              ],
            ),
            if (quest != null &&
                quest.shareMode == QuestRepository.modeVote &&
                quest.voteStatus.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.how_to_vote,
                    size: 16,
                    color: theme.colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    switch (quest.voteStatus) {
                      QuestRepository.votePassed => l10n.questVotePassed,
                      QuestRepository.voteFailed => l10n.questVoteFailed,
                      _ => l10n.questVoteOngoing,
                    },
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bir hedefin kabul/ret durumu (paylaşılmamış görevde boş).
  Widget? _targetStatus(L10n l10n, Quest quest, String characterId) {
    if (!QuestRepository.targetsOf(quest).contains(characterId)) return null;
    final answer = QuestRepository.acceptancesOf(quest)[characterId];
    final label = switch (answer) {
      true => l10n.questAcceptedBy,
      false => l10n.questRejectedBy,
      null => l10n.questPending,
    };
    return Text(label);
  }
}
