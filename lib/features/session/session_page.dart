import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/character_repository.dart';
import '../../data/combat_repository.dart';
import '../../data/providers.dart';
import '../../data/session_log_repository.dart';
import '../../data/shop_repository.dart';
import '../../data/world_repository.dart';
import '../../domain/rules/magic_item_pricing.dart';
import '../../l10n/app_localizations.dart';
import '../../net/protocol.dart' show PlayerPresence, decodeServerMsg;
import '../world/journey_card.dart';
import '../world/pick_image_file.dart';
import 'backup_page.dart';
import 'session_log_providers.dart';
import 'session_service.dart';

final sessionServiceProvider = Provider<SessionService>((ref) {
  final db = ref.watch(databaseProvider);
  final service = SessionService(
    db: db,
    characters: CharacterRepository(db),
    combat: CombatRepository(db),
    shops: ShopRepository(db),
    world: WorldRepository(db),
  );
  ref.onDispose(service.stop);
  return service;
});

/// DM onayi bekleyen satin almalar.
final pendingPurchasesProvider = StreamProvider<List<PendingPurchase>>((
  ref,
) async* {
  final service = ref.watch(sessionServiceProvider);
  yield service.pendingPurchases;
  await for (final _ in service.pendingChanged) {
    yield service.pendingPurchases;
  }
});

/// DM'in gordugu kisa aktivite bildirimleri (oyuncular arasi aktarim vb.).
final sessionActivityProvider = StreamProvider<String>(
  (ref) => ref.watch(sessionServiceProvider).activity,
);

/// Kodlu satin alma hata sebebini DM'in diline cevirir. `shop_repository`
/// oyuncuya da gonderilebildigi icin metin degil kod uretiyor.
String purchaseFailText(L10n l10n, String encoded) {
  final decoded = decodeServerMsg(encoded);
  if (decoded == null) return encoded;
  return switch (decoded.code) {
    'invalidQuantity' => l10n.pfInvalidQuantity,
    'itemNotFound' => l10n.pfItemNotFound,
    'shopNotFound' => l10n.pfShopNotFound,
    'shopClosed' => l10n.pfShopClosed,
    'soldOut' => l10n.pfSoldOut,
    'characterNotFound' => l10n.pfCharacterNotFound,
    'requestNotFound' => l10n.pfRequestNotFound,
    'onlyNLeft' => l10n.pfOnlyNLeft(
      decoded.args.isEmpty ? '' : decoded.args[0],
    ),
    'notEnoughGold' => l10n.pfNotEnoughGold(
      decoded.args.isNotEmpty ? decoded.args[0] : '',
      decoded.args.length > 1 ? decoded.args[1] : '',
    ),
    _ => encoded,
  };
}

/// Sunucunun acik olup olmadigi ve katilim adresi.
class SessionState {
  const SessionState({this.uri, this.error});

  final Uri? uri;
  final String? error;

  bool get isRunning => uri != null;
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() => const SessionState();

  Future<void> start() async {
    try {
      final uri = await ref.read(sessionServiceProvider).start();
      state = SessionState(uri: uri);
    } on Object catch (e) {
      state = SessionState(error: '$e');
    }
  }

  Future<void> stop() async {
    await ref.read(sessionServiceProvider).stop();
    state = const SessionState();
  }
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);

/// Bagli oyuncular degistikce yenilenen liste.
///
/// Sunucu baslatma durumunu da izler: panel (shell'de her sayfada acik) ilk
/// calistiginda sunucu henuz null olabilir; `isRunning` degisince provider
/// yeniden calisir, bu kez canli `playersChanged` akisina abone olur.
final connectedPlayersProvider = StreamProvider<List<ConnectedPlayerView>>((
  ref,
) async* {
  final service = ref.watch(sessionServiceProvider);
  ref.watch(sessionControllerProvider.select((s) => s.isRunning));
  final server = service.server;
  if (server == null) {
    yield const [];
    return;
  }
  yield _viewOf(service);
  await for (final _ in server.playersChanged) {
    yield _viewOf(service);
  }
});

List<ConnectedPlayerView> _viewOf(SessionService service) {
  final server = service.server;
  if (server == null) return const [];
  final connected = server.connectedTokens;
  return [
    for (final p in server.players)
      ConnectedPlayerView(
        name: p.name,
        characterId: p.characterId,
        presence: p.presence,
        online: connected.contains(p.token),
        lastSeen: p.lastSeen,
      ),
  ];
}

class ConnectedPlayerView {
  const ConnectedPlayerView({
    required this.name,
    this.characterId,
    this.presence = PlayerPresence.active,
    this.online = false,
    this.lastSeen,
  });

  final String name;
  final String? characterId;

  /// Oyuncunun tarayici gorunurlugu (aktif/arka plan).
  final PlayerPresence presence;

  /// Su anda canli soketi var mi (token ile yeniden baglanabilir).
  final bool online;

  /// Son baglanti koptugu an; [online] degilken anlamli.
  final DateTime? lastSeen;
}

class SessionPage extends ConsumerWidget {
  const SessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final session = ref.watch(sessionControllerProvider);
    final controller = ref.read(sessionControllerProvider.notifier);

    // Oyuncular arasi aktarim tamamlaninca DM kisa bir bildirim gorur.
    ref.listen(sessionActivityProvider, (_, next) {
      final msg = next.asData?.value;
      if (msg != null && msg.isNotEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navSession),
        actions: [
          IconButton(
            tooltip: l10n.sessionBackup,
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => Navigator.of(
              context,
              rootNavigator: true,
            ).push(MaterialPageRoute(builder: (_) => const BackupPage())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!session.isRunning)
            _StartCard(onStart: controller.start, error: session.error)
          else ...[
            _JoinCard(uri: session.uri!),
            const SizedBox(height: 16),
            const _PurchaseApprovals(),
            // Savas OTOMATIK yansitiliyor (Başlat/Bitir); harita gorunurlugu de
            // Dünya sekmesindeki ağaçtan (⋮ "Oyunculara göster") ayarlaniyor.
            // Bu yuzden burada elle secici yok.
            const _PlayersCard(),
            const SizedBox(height: 16),
            const _DmToolsCard(),
            const SizedBox(height: 16),
            // Suren yolculuk yoksa hic yer kaplamaz.
            const JourneyCard(),
            OutlinedButton.icon(
              onPressed: controller.stop,
              icon: const Icon(Icons.stop),
              label: Text(l10n.sessionCloseTable),
            ),
          ],
          const SizedBox(height: 16),
          const _SessionLogCard(),
        ],
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.onStart, this.error});

  final Future<void> Function() onStart;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sessionOpenTable, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l10n.sessionStartHint, style: theme.textTheme.bodyMedium),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(l10n.sessionStartServer),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final address = uri.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: QrImageView(data: address, size: 220),
            ),
            const SizedBox(height: 16),
            SelectableText(
              address,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: address));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l10n.sessionAddressCopied)),
                  );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.sessionCopyAddress),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyuncularin satin alma istekleri.
///
/// Magaza "onay iste" modundayken buraya duser; DM onaylayana kadar altin
/// ve stok dokunulmaz.
class _PurchaseApprovals extends ConsumerWidget {
  const _PurchaseApprovals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingPurchasesProvider).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final service = ref.read(sessionServiceProvider);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sessionPurchaseRequests(pending.length),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final p in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${p.characterName} → '
                            '${p.quantity > 1 ? "${p.quantity}× " : ""}'
                            '${p.itemName}',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            formatCoins(p.totalCp),
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.sessionReject,
                      icon: const Icon(Icons.close),
                      onPressed: () => service.rejectPurchase(p.id),
                    ),
                    IconButton(
                      tooltip: l10n.sessionApprove,
                      icon: const Icon(Icons.check),
                      onPressed: () async {
                        final result = await service.approvePurchase(p.id);
                        if (result is PurchaseFailed && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                purchaseFailText(l10n, result.reason),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// DM araclari: oyunculara duyuru, kurtarma atisi istegi ve ganimet.
///
/// Ustteki hedef secici hepsi icin gecerli: "Herkes" ya da tek bir oyuncu.
class _DmToolsCard extends ConsumerStatefulWidget {
  const _DmToolsCard();

  @override
  ConsumerState<_DmToolsCard> createState() => _DmToolsCardState();
}

class _DmToolsCardState extends ConsumerState<_DmToolsCard> {
  final _announce = TextEditingController();
  final _dc = TextEditingController(text: '15');
  final _coins = TextEditingController();
  final _items = TextEditingController();
  final _handoutCaption = TextEditingController();
  String _ability = 'DEX';

  /// Hedef karakter id'si; null = herkes.
  String? _target;

  static const _abilities = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

  @override
  void dispose() {
    _announce.dispose();
    _dc.dispose();
    _coins.dispose();
    _items.dispose();
    _handoutCaption.dispose();
    super.dispose();
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final service = ref.read(sessionServiceProvider);
    final players = ref.watch(connectedPlayersProvider).value ?? const [];
    final targets = [
      for (final p in players)
        if (p.characterId != null) p,
    ];
    // Hedef kopmussa "Herkes"e dus.
    if (_target != null && !targets.any((p) => p.characterId == _target)) {
      _target = null;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.sessionDmTools, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<String?>(
              initialValue: _target,
              decoration: InputDecoration(
                labelText: l10n.sessionTarget,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.sessionEveryone),
                ),
                for (final p in targets)
                  DropdownMenuItem(value: p.characterId, child: Text(p.name)),
              ],
              onChanged: (v) => setState(() => _target = v),
            ),
            const Divider(height: 24),

            // Duyuru.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _announce,
                    decoration: InputDecoration(
                      labelText: l10n.sessionAnnouncement,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final text = _announce.text.trim();
                    if (text.isEmpty) return;
                    service.announce(text, characterId: _target);
                    _announce.clear();
                    _snack(l10n.sessionAnnouncementSent);
                  },
                  child: Text(l10n.sessionSend),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Kurtarma istegi.
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    initialValue: _ability,
                    decoration: InputDecoration(
                      labelText: l10n.sessionAbility,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      for (final a in _abilities)
                        DropdownMenuItem(value: a, child: Text(a)),
                    ],
                    onChanged: (v) => setState(() => _ability = v ?? 'DEX'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _dc,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'DC',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () {
                      final dc = int.tryParse(_dc.text.trim()) ?? 10;
                      service.requestSave(
                        ability: _ability,
                        dc: dc,
                        characterId: _target,
                      );
                      _snack(l10n.sessionSaveRequested);
                    },
                    child: Text(l10n.sessionRequestSave),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ganimet.
            Row(
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _coins,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.sessionGold,
                      suffixText: 'gp',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _items,
                    decoration: InputDecoration(
                      labelText: l10n.sessionItemsCsv,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final gp = int.tryParse(_coins.text.trim()) ?? 0;
                    final items = _items.text
                        .split(',')
                        .map((s) => s.trim())
                        .where((s) => s.isNotEmpty)
                        .toList();
                    if (gp <= 0 && items.isEmpty) return;
                    service.giveLoot(
                      coinsCp: gp * 100,
                      items: [for (final n in items) (name: n, magic: false)],
                      targetCharacterId: _target,
                    );
                    _coins.clear();
                    _items.clear();
                    _snack(l10n.sessionLootOffered);
                  },
                  child: Text(l10n.sessionGiveLoot),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Handout (gorsel paylasimi) — herkese.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _handoutCaption,
                    decoration: InputDecoration(
                      labelText: l10n.sessionHandoutCaption,
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _shareHandout(service, l10n),
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: Text(l10n.sessionHandoutShow),
                ),
                if (service.activeHandout != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: l10n.sessionHandoutClear,
                    icon: const Icon(Icons.hide_image_outlined),
                    onPressed: () {
                      service.clearHandout();
                      setState(() {});
                      _snack(l10n.sessionHandoutCleared);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareHandout(SessionService service, L10n l10n) async {
    final picked = await pickImageFile();
    if (picked == null) return;
    try {
      await service.showHandout(image: picked, caption: _handoutCaption.text);
      _handoutCaption.clear();
      if (mounted) {
        setState(() {});
        _snack(l10n.sessionHandoutShared);
      }
    } on FormatException catch (e) {
      if (mounted) _snack(e.message);
    }
  }
}

class _PlayersCard extends ConsumerWidget {
  const _PlayersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final players = ref.watch(connectedPlayersProvider).value ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.sessionConnectedPlayers(players.length),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (players.isEmpty)
              Text(
                l10n.sessionNobodyConnected,
                style: theme.textTheme.bodySmall,
              )
            else
              for (final p in players)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(p.name),
                  subtitle: Text(
                    p.characterId == null
                        ? l10n.sessionNoCharacter
                        : l10n.sessionHasCharacter,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Kalici oturum gunlugu: XP odulleri ve elle notlar. En yeni ustte.
class _SessionLogCard extends ConsumerWidget {
  const _SessionLogCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final entries = ref.watch(sessionLogProvider).value ?? const [];
    final repo = ref.read(sessionLogRepositoryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history_edu_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.sessionLogTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l10n.sessionLogAdd,
                  icon: const Icon(Icons.add),
                  onPressed: () => _addEntry(context, repo, l10n),
                ),
                if (entries.isNotEmpty)
                  IconButton(
                    tooltip: l10n.sessionLogClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    onPressed: () => _confirmClear(context, repo, l10n),
                  ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
                child: Text(
                  l10n.sessionLogEmpty,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              )
            else
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 44,
                        child: Text(
                          _hhmm(e.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          e.message,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      InkWell(
                        onTap: () => repo.deleteEntry(e.id),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _addEntry(
    BuildContext context,
    SessionLogRepository repo,
    L10n l10n,
  ) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionLogAdd),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (text != null && text.isNotEmpty) await repo.add(text);
  }

  Future<void> _confirmClear(
    BuildContext context,
    SessionLogRepository repo,
    L10n l10n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.sessionLogClear),
        content: Text(l10n.sessionLogClearConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.sessionLogClear),
          ),
        ],
      ),
    );
    if (ok == true) await repo.clear();
  }
}
