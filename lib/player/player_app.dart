import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/ui/ui.dart';
import '../app/app_settings.dart';
import '../app/theme.dart';
import '../features/dice/dice_3d.dart';
import '../net/protocol.dart';
import 'chat_tab.dart';
import 'notes_book.dart';
import 'player_client.dart';
import 'create_character_page.dart';
import 'player_strings.dart';
import 'web_fullscreen.dart';

/// Oyuncu paneli (tarayicida calisir).
///
/// Tek ekran: once ad + karakter secimi, sonra karakter kagidi ve savas
/// gorunumu. Masada telefondan tek elle kullanildigi icin her sey tek
/// kaydirmali kolonda.
class PlayerApp extends ConsumerWidget {
  const PlayerApp({required this.serverUri, super.key});

  final Uri serverUri;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: 'DM Table',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.lang.locale,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr'), Locale('en')],
      debugShowCheckedModeBanner: false,
      // Scope Navigator'in USTUNDE (builder) durur ki showDialog/bottomSheet
      // rotalari da PlayerL10n.of(context)'e ulasabilsin.
      builder: (context, child) => PlayerL10nScope(
        l10n: PlayerL10n(settings.lang),
        // Kagit taneciği DM uygulamasindaki ile ayni katman: iki taraf ayni
        // gorsel dili paylasir.
        child: ParchmentOverlay(child: child!),
      ),
      home: PlayerHome(serverUri: serverUri),
    );
  }
}

class PlayerHome extends ConsumerStatefulWidget {
  const PlayerHome({required this.serverUri, super.key});

  final Uri serverUri;

  @override
  ConsumerState<PlayerHome> createState() => _PlayerHomeState();
}

class _PlayerHomeState extends ConsumerState<PlayerHome>
    with WidgetsBindingObserver {
  final _nameController = TextEditingController();
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    // Sekme/uygulama arka plana gectiginde DM "away" gorsun; donunce "active".
    WidgetsBinding.instance.addObserver(this);
  }

  /// Zar pop-up'i icin: gorulen en yuksek sira numarasi. Ilk snapshot'ta
  /// mevcut en yuksek deger baz alinir ki gecmis atislar acilista patlamasin.
  int _lastPopupSeq = 0;
  bool _baselined = false;

  int _lastAnnouncementSeq = 0;
  int _lastNoticeSeq = 0;
  String? _lastLootId;
  String? _lastTransferId;
  String? _lastHandoutId;
  int _lastQuestAlertSeq = 0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Web'de sekme gizlenince `paused`/`hidden`, geri gelince `resumed`.
    // Basit kural: gorunurdegilse away, gorunurse active.
    final away =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (_joined) {
      ref
          .read(playerControllerProvider.notifier)
          .setPresence(away ? 'away' : 'active');
    }
  }

  /// Kendi yeni zar atisimiz geldiyse ortada animasyonlu pop-up gosterir.
  /// Yalnizca bu cihazin oyuncusuna ait (source == playerName) yeni atislar.
  void _maybeShowRoll(PlayerState state) {
    final snapshot = state.snapshot;
    if (snapshot == null) return;
    final rolls = snapshot.rolls;
    if (!_baselined) {
      _baselined = true;
      _lastPopupSeq = _maxRollSeq(rolls);
      return;
    }
    final own = newestOwnRoll(rolls, state.playerName, _lastPopupSeq);
    if (own?.seq != null) {
      _lastPopupSeq = own!.seq!;
      _showDicePopup(own);
    }
  }

  void _showDicePopup(DiceRoll roll) {
    if (!mounted) return;
    final l = PlayerL10n.of(context);
    final h = dieHeadline(
      sides: roll.sides,
      count: roll.count,
      total: roll.total,
      results: roll.results,
      keptIndex: roll.keptIndex,
    );
    showDieRoll(
      context,
      sides: roll.sides,
      headline: h.headline,
      naturalD20: h.naturalD20,
      total: roll.total,
      modifier: roll.modifier,
      count: roll.count,
      label: roll.label,
      detail: roll.detail,
      criticalText: l.critical,
      fumbleText: l.fumble,
      diceText: l.dice,
    );
  }

  /// Duyuru, ganimet ve zar pop-up'larini durum degisince tetikler.
  void _onState(PlayerState next) {
    _maybeShowRoll(next);

    // DM duyurusu -> ortada mesaj kutusu.
    if (next.announcementSeq > _lastAnnouncementSeq &&
        next.announcement != null) {
      _lastAnnouncementSeq = next.announcementSeq;
      _showAnnouncement(next.announcement!);
    }

    // DM bilgi notu (satin alma onayi vb.) -> hafif SnackBar.
    if (next.noticeSeq > _lastNoticeSeq && next.notice != null) {
      _lastNoticeSeq = next.noticeSeq;
      _showNotice(next.notice!);
    }

    // Yeni ganimet -> pop-up (yalnizca bana ya da herkese sunulmussa).
    final loot = next.snapshot?.loot;
    final forMe =
        loot != null &&
        (loot.targetCharacterId == null ||
            loot.targetCharacterId == next.claimedCharacterId);
    if (forMe && loot.id != _lastLootId) {
      _lastLootId = loot.id;
      _showLoot();
    }

    // Baska bir oyuncudan gonderme teklifi -> kabul/ret pop-up.
    final transfer = next.incomingTransfer;
    if (transfer != null && transfer.id != _lastTransferId) {
      _lastTransferId = transfer.id;
      _showTransferOffer(transfer);
    }

    // DM handout gosterdi -> gorsel pop-up (yeni handout'ta bir kez).
    final handout = next.snapshot?.handout;
    if (handout != null && handout.id != _lastHandoutId) {
      _lastHandoutId = handout.id;
      _showHandout(handout);
    }

    // Yeni gorev / oylama / odul -> pop-up ya da SnackBar.
    final alert = next.questAlert;
    if (alert != null && next.questAlertSeq > _lastQuestAlertSeq) {
      _lastQuestAlertSeq = next.questAlertSeq;
      _showQuestAlert(alert);
    }
  }

  /// Gorev uyarisi: karar isteyen bir gorev/oylama ortada pop-up olur (oyuncu
  /// dogrudan buradan kabul/ret verebilir), odul ise hafif bir SnackBar.
  void _showQuestAlert(QuestAlert alert) {
    if (!mounted) return;
    final l = PlayerL10n.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final quest = alert.quest;
    final title = quest.title.isEmpty ? l.questFallbackTitle : quest.title;

    if (alert.kind == QuestAlertKind.reward) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l.questRewardReady}: $title'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l.questOpenTab,
            onPressed: controller.openQuestsTab,
          ),
        ),
      );
      return;
    }

    final voting = alert.kind == QuestAlertKind.vote;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(voting ? Icons.how_to_vote : Icons.assignment_outlined),
        title: Text(voting ? l.questVoteBanner : l.questNewOffer),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(dialogContext).textTheme.titleMedium),
            if (quest.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(quest.text),
              ),
            if (quest.reward.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l.questReward}: ${quest.reward}',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.respondQuest(quest.id, accept: false);
            },
            child: Text(voting ? l.questVoteNo : l.questReject),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              controller.respondQuest(quest.id, accept: true);
            },
            child: Text(voting ? l.questVoteYes : l.questAccept),
          ),
        ],
      ),
    );
  }

  void _showHandout(HandoutView handout) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) =>
          _HandoutDialog(handout: handout, serverUri: widget.serverUri),
    );
  }

  void _showTransferOffer(IncomingTransfer t) {
    if (!mounted) return;
    final controller = ref.read(playerControllerProvider.notifier);
    final itemName = t.itemName.isEmpty
        ? PlayerL10n.of(context).unknownItem
        : t.itemName;
    final what = t.coinsCp > 0
        ? _coins(t.coinsCp)
        : (t.quantity > 1 ? '$itemName ×${t.quantity}' : itemName);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          t.coinsCp > 0
              ? Icons.paid
              : (t.magic ? Icons.auto_awesome : Icons.backpack_outlined),
        ),
        title: Text(PlayerL10n.of(context).transferTitle),
        content: Text(PlayerL10n.of(context).wantsToSend(t.fromName, what)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.respondTransfer(t.id, accept: false);
            },
            child: Text(PlayerL10n.of(context).decline),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              controller.respondTransfer(t.id, accept: true);
            },
            child: Text(PlayerL10n.of(context).accept),
          ),
        ],
      ),
    );
  }

  void _showNotice(String text) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger
      ?..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(PlayerL10n.of(context).serverText(text)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _showAnnouncement(String text) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.campaign_outlined),
        title: Text(PlayerL10n.of(context).dm),
        content: Text(PlayerL10n.of(context).serverText(text)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(PlayerL10n.of(context).ok),
          ),
        ],
      ),
    );
  }

  void _showLoot() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => const _LootDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(playerControllerProvider);
    ref.listen<PlayerState>(
      playerControllerProvider,
      (_, next) => _onState(next),
    );

    if (!_joined) {
      return _JoinScreen(controller: _nameController, onJoin: _join);
    }

    // Karakter secildiyse tam Scaffold'u _ClaimedView yonetir: ana sekmeler
    // hamburger menude (drawer), ust cubukta zar + baglanti gostergesi.
    if (state.snapshot != null && state.claimedCharacterId != null) {
      return _ClaimedView(state: state, serverUri: widget.serverUri);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DM Table'),
        actions: [_ConnectionIndicator(connected: state.connected)],
      ),
      body: state.snapshot == null
          ? const AppLoading()
          : _CharacterPicker(snapshot: state.snapshot!),
    );
  }

  void _join() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    ref
        .read(playerControllerProvider.notifier)
        .connect(uri: widget.serverUri, playerName: name);
    // Masaya katilir katilmaz "aktif" olarak gorun.
    ref.read(playerControllerProvider.notifier).setPresence('active');
    setState(() => _joined = true);
  }
}

/// Oyuncunun gordugu ILK ekran — masanin kapisi.
///
/// Duz bir form yerine "muhurlu davetiye" olarak kuruldu: mum muhru arma,
/// donemsel baslik ve parsomen zemin. Bos ad ile "Katil"a basmak eskiden
/// sessizce hicbir sey yapmiyordu; artik alanin altinda hata metni cikar
/// (UX kurali: hatayi alanin yaninda goster).
class _JoinScreen extends StatefulWidget {
  const _JoinScreen({required this.controller, required this.onJoin});

  final TextEditingController controller;
  final VoidCallback onJoin;

  @override
  State<_JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<_JoinScreen> {
  String? _error;

  void _submit() {
    if (widget.controller.text.trim().isEmpty) {
      setState(() => _error = PlayerL10n.of(context).nameRequired);
      return;
    }
    setState(() => _error = null);
    widget.onJoin();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final space = context.spacing;

    return Scaffold(
      body: ParchmentSurface(
        vignette: true,
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(space.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: WaxSeal(letter: 'D', size: 64)),
                  SizedBox(height: space.lg),
                  Text(
                    'DM Table',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  SizedBox(height: space.xs),
                  Text(
                    l.joinTable,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const OrnamentDivider(),
                  TextField(
                    controller: widget.controller,
                    autofocus: true,
                    textInputAction: TextInputAction.go,
                    decoration: InputDecoration(
                      labelText: l.yourName,
                      helperText: l.joinTagline,
                      errorText: _error,
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _submit(),
                  ),
                  SizedBox(height: space.md),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(l.join),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterPicker extends ConsumerWidget {
  const _CharacterPicker({required this.snapshot});

  final TableSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = PlayerL10n.of(context);
    // DM'in karakter olusturmasini beklemek zorunda degil: oyuncu kendi
    // karakterini kurabilir (sunucu dogrular).
    final createButton = Padding(
      padding: const EdgeInsets.only(top: 8),
      child: FilledButton.tonalIcon(
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateCharacterPage())),
        icon: const Icon(Icons.person_add_alt, size: 18),
        label: Text(l.createCharacter),
      ),
    );

    if (snapshot.characters.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            children: [
              AppEmptyState(
                icon: Icons.person_off_outlined,
                title: l.noCharactersYet,
                message: l.noCharactersHint,
              ),
              createButton,
            ],
          ),
        ),
      );
    }

    // Genis ekranda okunabilir bir sutuna ortalanir.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SectionHeader(
              label: PlayerL10n.of(context).chooseCharacter,
              icon: Icons.badge_outlined,
              padding: EdgeInsets.only(bottom: context.spacing.sm),
            ),
            for (final c in snapshot.characters)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(c.name),
                  subtitle: Text(
                    [
                      if (c.classLine.isNotEmpty) c.classLine,
                      '${c.hitPointsCurrent}/${c.hitPointsMax} HP',
                    ].join(' · '),
                  ),
                  // Baskasinin sahiplendigi karakter secilemez.
                  enabled: c.claimedBy == null,
                  trailing: c.claimedBy == null
                      ? const Icon(Icons.chevron_right)
                      : Chip(label: Text(c.claimedBy!)),
                  onTap: c.claimedBy == null
                      ? () => ref
                            .read(playerControllerProvider.notifier)
                            .claim(c.id)
                      : null,
                ),
              ),
            createButton,
          ],
        ),
      ),
    );
  }
}

/// Karakter sahiplenildikten sonraki sekmeli gorunum.
///
/// Tek kaydirma yerine sekmeler: Karakter, (savas varsa) Savas, (DM harita
/// gosteriyorsa) Harita. Savas yeni basladiginda otomatik Savas sekmesine
/// gecilir; oyuncu sekmeler arasinda serbestce gezebilir.
class _ClaimedView extends ConsumerStatefulWidget {
  const _ClaimedView({required this.state, required this.serverUri});

  final PlayerState state;
  final Uri serverUri;

  @override
  ConsumerState<_ClaimedView> createState() => _ClaimedViewState();
}

class _ClaimedViewState extends ConsumerState<_ClaimedView> {
  int _tab = 0;

  // Savas her zaman index 1'de (Karakter=0). Kaybolunca Karakter'e don.
  static const _combatTabIndex = 1;

  /// Gorevler sekmesi: Karakter(0), Savas(1), Harita(2), Notlar(3), Gorevler(4).
  static const _questTabIndex = 4;

  @override
  void didUpdateWidget(_ClaimedView old) {
    super.didUpdateWidget(old);
    // Odul SnackBar'indaki "Aç" -> Gorevler sekmesi.
    if (widget.state.questTabRequestSeq > old.state.questTabRequestSeq) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = _questTabIndex);
      });
    }
    final hadCombat = old.state.snapshot?.combat != null;
    final hasCombat = widget.state.snapshot?.combat != null;
    if (hasCombat && !hadCombat) {
      // Savas basladi -> otomatik savas sekmesine gec.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = _combatTabIndex);
      });
    } else if (!hasCombat && hadCombat && _tab == _combatTabIndex) {
      // Savas bitti -> Karakter'e don (yoksa index kayar, Harita'ya atlar).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _tab = 0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final character = state.myCharacter;
    if (character == null) {
      return const Scaffold(body: AppLoading());
    }

    final combat = state.snapshot?.combat;
    final maps = state.snapshot?.maps ?? const <MapView>[];
    final l = PlayerL10n.of(context);

    // Ana sekmeler hamburger menude (drawer) durur; savas/harita yokken devre
    // disi. Notlar ve Ayarlar her zaman acik.
    final tabs = <_PlayerTab>[
      _PlayerTab(
        icon: Icons.person,
        label: l.tabCharacter,
        body: _CharacterTab(
          key: const ValueKey('character'),
          state: state,
          character: character,
          serverUri: widget.serverUri,
        ),
      ),
      _PlayerTab(
        icon: Icons.shield,
        label: l.tabCombat,
        enabled: combat != null,
        body: combat != null
            ? _CombatTab(
                key: const ValueKey('combat'),
                combat: combat,
                myCharacterId: character.id,
                serverUri: widget.serverUri,
                myHpCurrent: character.hitPointsCurrent,
                myHpMax: character.hitPointsMax,
              )
            : _EmptyPane(icon: Icons.shield_outlined, text: l.noCombat),
      ),
      _PlayerTab(
        icon: Icons.map,
        label: l.tabMap,
        enabled: maps.isNotEmpty,
        fullBleed: true,
        body: maps.isNotEmpty
            ? _MapTab(
                key: const ValueKey('map'),
                maps: maps,
                mapShops: state.snapshot?.mapShops ?? const [],
                purse: character.coinsCp,
                serverUri: widget.serverUri,
              )
            : _EmptyPane(icon: Icons.map_outlined, text: l.noMap),
      ),
      _PlayerTab(
        icon: Icons.sticky_note_2,
        label: l.tabNotes,
        body: const _NotesTab(key: ValueKey('notes')),
      ),
      _PlayerTab(
        icon: Icons.assignment,
        label: l.tabQuests,
        body: const _QuestsTab(key: ValueKey('quests')),
        badge: state.pendingQuestCount,
      ),
      _PlayerTab(
        icon: Icons.chat_bubble_outline,
        label: l.tabChat,
        body: ChatTab(key: const ValueKey('chat'), state: state),
      ),
      _PlayerTab(
        icon: Icons.settings,
        label: l.tabSettings,
        body: const _SettingsTab(key: ValueKey('settings')),
      ),
    ];

    // Secili sekme devre disiysa Karakter'e dus.
    final index = tabs[_tab.clamp(0, tabs.length - 1)].enabled ? _tab : 0;

    // DM takvim kurduysa oyun-ici tarih basligin altinda durur; metin
    // sunucuda bicimlenir (oyuncu paneli takvim yapisini bilmez).
    final inGameDate = state.snapshot?.inGameDate;
    final inGameSeason = state.snapshot?.inGameSeason;

    final appBar = AppBar(
      title: inGameDate == null
          ? Text(tabs[index].label)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(tabs[index].label),
                Text(
                  inGameSeason == null
                      ? inGameDate
                      : '$inGameDate · $inGameSeason',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
      actions: [
        // DM handout gosteriyorsa: tekrar acmak icin kalici dugme.
        if (state.snapshot?.handout != null)
          IconButton(
            tooltip: l.handout,
            icon: const Icon(Icons.attach_file),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => _HandoutDialog(
                handout: state.snapshot!.handout!,
                serverUri: widget.serverUri,
              ),
            ),
          ),
        IconButton(
          tooltip: l.rollDice,
          icon: const Icon(Icons.casino_outlined),
          onPressed: () => showPlayerDiceSheet(
            context,
            ref.read(playerControllerProvider.notifier),
          ),
        ),
        _ConnectionIndicator(connected: state.connected),
      ],
    );

    // Icerik: genis ekranda okunabilir bir sutuna ortalanip sinirlanir
    // (masaustunde tam genislige yayilip cirkinlesmesin).
    Widget bounded(Widget content) => LayoutBuilder(
      builder: (context, c) {
        final pad = c.maxWidth > _maxContentWidth
            ? (c.maxWidth - _maxContentWidth) / 2
            : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: content,
        );
      },
    );

    // Harita gibi fullBleed sekmeler tam genislikte kalir; digerleri genis
    // ekranda okunabilir sutuna ortalanir. Boylece haritanin yan bosluklari da
    // dikey kaydiricinin parcasi olur (fare orada tekerlek cevirince sayfa kayar).
    final content = IndexedStack(
      index: index,
      children: [for (final t in tabs) t.fullBleed ? t.body : bounded(t.body)],
    );

    // Genis ekran (masaustu/tablet): kalici yan navigasyon rayi; dar ekran
    // (telefon): hamburger drawer.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _wideBreakpoint;
        if (!wide) {
          return Scaffold(
            appBar: appBar,
            drawer: _MainDrawer(
              characterName: character.name,
              classLine: character.classLine,
              tabs: tabs,
              index: index,
              onSelect: (i) => setState(() => _tab = i),
            ),
            body: content,
          );
        }

        // Rayda yalnizca erisilebilir sekmeler; secili olani esle.
        final railTabs = [
          for (final (i, t) in tabs.indexed)
            if (t.enabled) (index: i, tab: t),
        ];
        var railSelected = railTabs.indexWhere((e) => e.index == index);
        if (railSelected < 0) railSelected = 0;

        return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: railSelected,
                onDestinationSelected: (r) =>
                    setState(() => _tab = railTabs[r].index),
                labelType: NavigationRailLabelType.all,
                leading: _RailHeader(
                  name: character.name,
                  classLine: character.classLine,
                ),
                destinations: [
                  for (final e in railTabs)
                    NavigationRailDestination(
                      icon: _TabIcon(tab: e.tab),
                      label: Text(e.tab.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }
}

/// Genis ekranda icerigin ortalandigi azami genislik ve rayin acildigi esik.
/// Degerler [Breakpoints]'tan gelir (tek kaynak); oyuncu paneli rayi DM
/// kabugundan biraz daha genis bir esikte acilir (dar tarayici pencereleri).
const double _maxContentWidth = Breakpoints.readableContent;
const double _wideBreakpoint = Breakpoints.rail + 40;

/// NavigationRail basligi: karakter adi + sinif satiri (masaustu).
class _RailHeader extends StatelessWidget {
  const _RailHeader({required this.name, required this.classLine});

  final String name;
  final String classLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              child: Text(name.isEmpty ? '?' : name.characters.first),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ust cubuktaki baglanti gostergesi (wifi acik/kapali).
class _ConnectionIndicator extends StatelessWidget {
  const _ConnectionIndicator({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 12),
    child: Icon(
      connected ? Icons.wifi : Icons.wifi_off,
      color: connected
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.error,
    ),
  );
}

/// Ana navigasyon: hamburger menuden acilan drawer. Alt (karakter ici)
/// navigasyon _CharacterTab icindeki sekme cubugunda kalir.
class _MainDrawer extends StatelessWidget {
  const _MainDrawer({
    required this.characterName,
    required this.classLine,
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final String characterName;
  final String classLine;
  final List<_PlayerTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(characterName, style: theme.textTheme.titleLarge),
                  if (classLine.isNotEmpty)
                    Text(
                      classLine,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final (i, t) in tabs.indexed)
              ListTile(
                leading: _TabIcon(tab: t),
                title: Text(t.label),
                enabled: t.enabled,
                selected: i == index,
                // Drawer kendi context'inden kapatilir (Scaffold ataya bakar).
                onTap: t.enabled
                    ? () {
                        Scaffold.of(context).closeDrawer();
                        onSelect(i);
                      }
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

/// Ayarlar sekmesi: dil ve tema secimi (cihaza yerel, localStorage'da saklanir).
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = PlayerL10n.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(appSettingsProvider);
    final controller = ref.read(appSettingsProvider.notifier);

    Widget section(String title, Widget child) => Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        section(
          l.settingsLanguage,
          SegmentedButton<AppLang>(
            segments: [
              for (final lang in AppLang.values)
                ButtonSegment(value: lang, label: Text(lang.label)),
            ],
            selected: {settings.lang},
            showSelectedIcon: false,
            onSelectionChanged: (s) => controller.setLang(s.first),
          ),
        ),
        const SizedBox(height: 12),
        section(
          l.settingsTheme,
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.light, label: Text(l.themeLight)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
              ButtonSegment(
                value: ThemeMode.system,
                label: Text(l.themeSystem),
              ),
            ],
            selected: {settings.themeMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => controller.setThemeMode(s.first),
          ),
        ),
      ],
    );
  }
}

/// Bir sekme tanimi.
class _PlayerTab {
  const _PlayerTab({
    required this.icon,
    required this.label,
    required this.body,
    this.enabled = true,
    this.fullBleed = false,
    this.badge = 0,
  });

  final IconData icon;
  final String label;
  final Widget body;

  /// Sifirdan buyukse sekme ikonunda sayi rozeti cikar. Kaynak: "islem
  /// bekleyen" is sayisi -- ayri bir "okundu" durumu tutulmaz, oyuncu isi
  /// yapinca kendiliginden duser.
  final int badge;

  /// Devre disiysa soluk gorunur ve tiklanamaz (ama sekme kaybolmaz).
  final bool enabled;

  /// true ise icerik genis ekranda ortalanmis sutuna sikistirilmaz; sekme
  /// kendi genisligini yonetir (harita: yan bosluklarin sayfayi kaydirmasi
  /// icin dikey kaydiricinin tam genislikte olmasi gerekir).
  final bool fullBleed;
}

/// Sekme ikonu; [_PlayerTab.badge] doluysa uzerinde sayi rozeti gosterir.
class _TabIcon extends StatelessWidget {
  const _TabIcon({required this.tab});

  final _PlayerTab tab;

  @override
  Widget build(BuildContext context) => tab.badge > 0
      ? Badge.count(count: tab.badge, child: Icon(tab.icon))
      : Icon(tab.icon);
}

/// Ust sekme cubugu (Karakter | Savaş | Harita). Devre disi sekmeler soluk.
class _PlayerTabBar extends StatelessWidget {
  const _PlayerTabBar({
    required this.tabs,
    required this.index,
    required this.onSelect,
  });

  final List<_PlayerTab> tabs;
  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          for (final (i, t) in tabs.indexed)
            Expanded(
              child: Opacity(
                opacity: t.enabled ? 1 : 0.38,
                child: InkWell(
                  onTap: t.enabled ? () => onSelect(i) : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          width: 2,
                          color: i == index && t.enabled
                              ? theme.colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          t.icon,
                          size: 20,
                          color: i == index && t.enabled
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          t.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: i == index && t.enabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Devre disi sekmenin (savas/harita yokken) icerigi.
class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Karakter sekmesi: can, statlar, yuvalar, magaza, envanter, zar gunlugu.
/// Karakter ana sekmesi: kendi icinde alt sekmeler (Genel | Envanter |
/// Karakter [+ Büyüler yalnizca buyu yapanlarda]).
class _CharacterTab extends ConsumerStatefulWidget {
  const _CharacterTab({
    required this.state,
    required this.character,
    required this.serverUri,
    super.key,
  });

  final PlayerState state;
  final PlayerCharacterView character;
  final Uri serverUri;

  @override
  ConsumerState<_CharacterTab> createState() => _CharacterTabState();
}

class _CharacterTabState extends ConsumerState<_CharacterTab> {
  int _sub = 0;

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final character = widget.character;
    final isCaster =
        character.spellSlots.isNotEmpty || character.spells.isNotEmpty;
    final l = PlayerL10n.of(context);

    final subs = <_PlayerTab>[
      _PlayerTab(
        icon: Icons.shield_moon,
        label: l.subGeneral,
        body: _GeneralSubTab(state: state, character: character),
      ),
      _PlayerTab(
        icon: Icons.backpack,
        label: l.subInventory,
        body: _InventorySubTab(state: state, character: character),
      ),
      _PlayerTab(
        icon: Icons.menu_book,
        label: l.tabCharacter,
        body: _StorySubTab(character: character, serverUri: widget.serverUri),
      ),
      if (isCaster)
        _PlayerTab(
          icon: Icons.auto_awesome,
          label: l.spells,
          body: _SpellsSubTab(character: character),
        ),
    ];

    final index = _sub.clamp(0, subs.length - 1);

    return Column(
      children: [
        _PlayerTabBar(
          tabs: subs,
          index: index,
          onSelect: (i) => setState(() => _sub = i),
        ),
        Expanded(
          child: IndexedStack(
            index: index,
            children: [for (final t in subs) t.body],
          ),
        ),
      ],
    );
  }
}

/// Genel: kimlik, can, statlar, zar gunlugu.
class _GeneralSubTab extends StatelessWidget {
  const _GeneralSubTab({required this.state, required this.character});

  final PlayerState state;
  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.lastError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(PlayerL10n.of(context).serverText(state.lastError!)),
            ),
          ),
        if (state.saveRequest != null) ...[
          _SaveRequestCard(request: state.saveRequest!, character: character),
          const SizedBox(height: 12),
        ],
        _IdentityCard(character: character),
        const SizedBox(height: 12),
        _HitPointsCard(character: character),
        if (character.hitPointsCurrent == 0) ...[
          const SizedBox(height: 12),
          _DeathSaveCard(character: character),
        ],
        // Kisa dinlenme kartI YALNIZCA DM dinlenmeyi acinca cikar.
        if (state.snapshot?.shortRestCharacterIds.contains(character.id) ??
            false) ...[
          const SizedBox(height: 12),
          _ShortRestCard(character: character),
        ],
        const SizedBox(height: 12),
        _StatsCard(character: character),
        if (state.snapshot?.rolls.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _RollLogCard(rolls: state.snapshot!.rolls),
        ],
      ],
    );
  }
}

/// DM kisa dinlenme actiginda cikan hit die paneli.
///
/// Hit die harcamak 5e'de OYUNCUNUN kararidir: kac tane, ne zaman. Eskiden
/// DM masada tek tek harcatiyordu; artik dinlenmeyi DM acar, harcamayi
/// oyuncu yapar. Atis sunucuda atilip paylasilan gunluge dustugu icin
/// oyuncunun ekraninda kendi zar animasyonu kendiliginden oynar.
class _ShortRestCard extends ConsumerWidget {
  const _ShortRestCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final l = PlayerL10n.of(context);
    final remaining = character.hitDiceTotal - character.hitDiceUsed;
    final full = character.hitPointsCurrent >= character.hitPointsMax;

    return Card(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  size: 18,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.shortRestOpen,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              l.hitDiceLeft(remaining, character.hitDiceTotal),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              // Cani doluyken zar harcatmak israf; kural geregi de anlamsiz.
              onPressed: remaining <= 0 || full
                  ? null
                  : () => controller.spendHitDie(),
              icon: const Icon(Icons.casino_outlined, size: 18),
              label: Text(l.spendHitDie),
            ),
            if (full)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.hitPointsFull,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// DM'in istedigi kurtarma atisi; oyuncu tek dokunusla atar (kendi kurtarma
/// modifiyesiyle) ve sonuc paylasilan gunluge duser.
class _SaveRequestCard extends ConsumerWidget {
  const _SaveRequestCard({required this.request, required this.character});

  final SaveRequest request;
  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final mod = character.savingThrows[request.ability] ?? 0;
    final modText = mod >= 0 ? '+$mod' : '$mod';
    final l = PlayerL10n.of(context);

    return Card(
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.savingThrow, style: theme.textTheme.titleMedium),
                  Text(
                    l.saveRequestSubtitle(request.dc, request.ability),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () {
                controller.rollDice(
                  label: l.saveRequestLabel(request.ability, request.dc),
                  sides: 20,
                  modifier: mod,
                );
                controller.clearSaveRequest();
              },
              child: Text(l.rollWithMod(modText)),
            ),
          ],
        ),
      ),
    );
  }
}

/// DM'in sundugu ganimet pop-up'i: esyalar + para. Oyuncu "Al" ile kendine
/// aktarir; hepsi alininca ya da DM kapatinca kendiliginden kapanir.
/// DM'in gosterdigi handout: gorsel (+ istege bagli baslik) tam genislikte.
class _HandoutDialog extends StatelessWidget {
  const _HandoutDialog({required this.handout, required this.serverUri});

  final HandoutView handout;
  final Uri serverUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final text = handout.text;
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (text != null)
            // Metin handout'u (AI görev metni gibi): kaydırılabilir metin.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: SelectableText(text, style: theme.textTheme.bodyLarge),
              ),
            )
          else if (handout.url != null)
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(
                  serverUri.replace(path: handout.url!).toString(),
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const SizedBox(height: 220, child: AppLoading()),
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 160,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          if (handout.caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(handout.caption!, style: theme.textTheme.titleMedium),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l.close),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LootDialog extends ConsumerWidget {
  const _LootDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final loot = state.snapshot?.loot;
    final forMe =
        loot != null &&
        (loot.targetCharacterId == null ||
            loot.targetCharacterId == state.claimedCharacterId);

    // Ganimet bittiyse/kapandiysa kendini kapat.
    if (!forMe) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final empty = loot.items.isEmpty && loot.coinsCp <= 0;
    final l = PlayerL10n.of(context);
    return AlertDialog(
      icon: const Icon(Icons.card_giftcard),
      title: Text(l.loot),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loot.coinsCp > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.paid),
                title: Text(_coins(loot.coinsCp)),
                trailing: FilledButton(
                  onPressed: controller.takeLootCoins,
                  child: Text(l.take),
                ),
              ),
            for (final item in loot.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                  color: item.magic ? theme.colorScheme.tertiary : null,
                ),
                title: Text(item.name),
                trailing: FilledButton.tonal(
                  onPressed: () => controller.takeLootItem(item.id),
                  child: Text(l.take),
                ),
              ),
            if (empty)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(l.allTaken, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}

/// Haritadaki hazine pininin ganimetini gosterir.
///
/// Veriyi snapshot'taki pinin GUNCEL durumundan okur (DM'in anlik `loot`
/// kutusu degil): esya/para alininca pin azalir, hepsi alininca pin DB'den
/// silinir ve dialog kendini kapatir. "Tumunu al" tek islemde hepsini alir.
class _TreasureLootDialog extends ConsumerWidget {
  const _TreasureLootDialog({required this.pinId});

  final String pinId;

  /// Pinin snapshot'taki kalan ganimetini bulur; pin yoksa ya da bossa null.
  ({int coinsCp, List<LootItemView> items})? _pinLoot(PlayerState state) {
    final maps = state.snapshot?.maps ?? const <MapView>[];
    for (final map in maps) {
      for (final pin in map.pins) {
        if (pin.id != pinId) continue;
        final items = pin.lootItems ?? const <LootItemView>[];
        final coins = pin.lootCoinsCp ?? 0;
        if (items.isEmpty && coins <= 0) return null;
        return (coinsCp: coins, items: items);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final loot = _pinLoot(state);
    final l = PlayerL10n.of(context);

    // Hazine bosaldiysa / pin silindiyse kendini kapat.
    if (loot == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    final items = loot.items;
    final coins = loot.coinsCp;
    return AlertDialog(
      icon: const Icon(Icons.diamond),
      title: Text(l.treasure),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (coins > 0)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.paid),
                title: Text(_coins(coins)),
                trailing: FilledButton(
                  onPressed: () => controller.takeTreasureLootCoins(pinId),
                  child: Text(l.take),
                ),
              ),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                  color: item.magic ? theme.colorScheme.tertiary : null,
                ),
                title: Text(item.name),
                trailing: FilledButton.tonal(
                  onPressed: () =>
                      controller.takeTreasureLootItem(pinId, item.id),
                  child: Text(l.take),
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (items.isNotEmpty || coins > 0)
          TextButton.icon(
            onPressed: () => controller.takeAllTreasureLoot(pinId),
            icon: const Icon(Icons.inventory_2_outlined),
            label: Text(l.takeAll),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.close),
        ),
      ],
    );
  }
}

/// Envanter: magaza (aciksa), envanter (kusanilmis/bagli), uzmanliklar, para.
class _InventorySubTab extends StatelessWidget {
  const _InventorySubTab({required this.state, required this.character});

  final PlayerState state;
  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    // Gonderilebilecek diger oyuncular: sahiplenilmis, kendisi disindaki
    // karakterler.
    final recipients = <({String id, String name})>[
      for (final c
          in state.snapshot?.characters ?? const <PlayerCharacterView>[])
        if (c.claimedBy != null && c.id != character.id)
          (id: c.id, name: c.name),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.snapshot?.shop case final shop?) ...[
          _ShopCard(shopId: shop.id),
          const SizedBox(height: 12),
        ],
        _InventoryCard(character: character, recipients: recipients),
        const SizedBox(height: 12),
        // Ortak keseler: yalnizca uye olunanlar snapshot'a duser, bu yuzden
        // liste bossa kart hic cizilmez (kesesiz masaya maliyeti sifir).
        if ((state.snapshot?.partyInventories ?? const []).isNotEmpty) ...[
          _PartyInventoriesCard(
            inventories: state.snapshot!.partyInventories,
            character: character,
          ),
          const SizedBox(height: 12),
        ],
        _ProficienciesCard(character: character),
      ],
    );
  }
}

/// Karakter: portre, hikaye, gorunus, diller, kisilik.
class _StorySubTab extends StatelessWidget {
  const _StorySubTab({required this.character, required this.serverUri});

  final PlayerCharacterView character;
  final Uri serverUri;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [_StoryViewCard(character: character, serverUri: serverUri)],
    );
  }
}

/// Büyüler: bilinen buyuler + yuvalar.
class _SpellsSubTab extends StatelessWidget {
  const _SpellsSubTab({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (character.spellSlots.isNotEmpty) ...[
          _SlotsCard(character: character),
          const SizedBox(height: 12),
        ],
        _SpellsListCard(character: character),
      ],
    );
  }
}

/// Kimlik: sinif/seviye/tur/background/hizalama.
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = <String>[
      if (character.classLine.isNotEmpty) character.classLine,
      PlayerL10n.of(context).levelN(character.level),
      if (character.speciesName != null) character.speciesName!,
      if (character.backgroundName != null) character.backgroundName!,
      if (character.alignment != null && character.alignment!.isNotEmpty)
        character.alignment!,
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(character.name, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(lines.join(' · '), style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Silah/zirh/alet uzmanliklari. Hepsi bossa gizlenir.
class _ProficienciesCard extends StatelessWidget {
  const _ProficienciesCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final groups = <String, List<String>>{
      l.weapons: character.weaponProficiencies,
      l.armorProf: character.armorProficiencies,
      l.tools: character.toolProficiencies,
    }..removeWhere((_, v) => v.isEmpty);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.proficiencies, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final entry in groups.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${entry.key}: ',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: entry.value.join(', ')),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Portre + hikaye/gorunus/diller/kisilik (oyuncu icin salt okunur).
class _StoryViewCard extends StatelessWidget {
  const _StoryViewCard({required this.character, required this.serverUri});

  final PlayerCharacterView character;
  final Uri serverUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final url = character.portraitUrl;

    Widget section(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(value, style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final hasStory = [
      character.appearance,
      character.personality,
      character.ideal,
      character.bond,
      character.flaw,
      character.notes,
    ].any((s) => s.trim().isNotEmpty);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (url != null)
            // Portreyi ortala ve genisligini sinirla: masaustunde kart ~1080px
            // genis olabiliyor; eskiden BoxFit.cover ile portre ince yatay bir
            // dilime kirpiliyordu ("bozuk" gorunum). Sabit 3:4 kutu her ekranda
            // duzgun bir portre verir.
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Image.network(
                    serverUri.replace(path: url).toString(),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) =>
                        progress == null ? child : const AppLoading(),
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.person, size: 48)),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(character.name, style: theme.textTheme.titleLarge),
                if (character.languages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RichText(
                      text: TextSpan(
                        style: theme.textTheme.bodyMedium,
                        children: [
                          TextSpan(
                            text: l.languagesLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: character.languages.join(', ')),
                        ],
                      ),
                    ),
                  ),
                section(l.appearance, character.appearance),
                section(l.personality, character.personality),
                section(l.ideal, character.ideal),
                section(l.bond, character.bond),
                section(l.flaw, character.flaw),
                section(l.storyLabel, character.notes),
                if (!hasStory && character.languages.isEmpty && url == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l.noCharacterInfo,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bilinen buyuler, seviyeye gore.
class _SpellsListCard extends StatelessWidget {
  const _SpellsListCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final spells = character.spells;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.spells, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (spells.isEmpty)
              Text(l.noSpellsYet, style: theme.textTheme.bodySmall)
            else
              for (final s in spells)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          s.level == 0 ? 'C' : '${s.level}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          s.name,
                          style: TextStyle(
                            fontWeight: s.prepared || s.alwaysPrepared
                                ? FontWeight.bold
                                : null,
                          ),
                        ),
                      ),
                      for (final tag in [
                        if (s.concentration) 'C',
                        if (s.ritual) 'R',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            tag,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ),
                      if (s.prepared || s.alwaysPrepared)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
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

/// Savas sekmesi: savas takipcisi tum ekrani kaplar.
class _CombatTab extends StatelessWidget {
  const _CombatTab({
    required this.combat,
    required this.myCharacterId,
    required this.serverUri,
    this.myHpCurrent,
    this.myHpMax,
    super.key,
  });

  final CombatView combat;
  final String myCharacterId;
  final Uri serverUri;
  final int? myHpCurrent;
  final int? myHpMax;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      _CombatCard(
        combat: combat,
        myCharacterId: myCharacterId,
        serverUri: serverUri,
        myHpCurrent: myHpCurrent,
        myHpMax: myHpMax,
      ),
    ],
  );
}

/// Harita sekmesi: gezinilebilir harita + tam ekran dugmesi.
/// Harita sekmesi: gorunur yapilmis haritalar arasinda gezinme.
///
/// Birden fazla kok harita varsa ustte bir kok secici cikar; ic ice alt
/// yerlere hem harita pinlerinden hem "Alt yerler" listesinden girilir. Dukkan
/// pinine (DM haritadan erisilebilir yaptiysa) dokununca dukkan acilir.
class _MapTab extends StatefulWidget {
  const _MapTab({
    required this.maps,
    required this.mapShops,
    required this.purse,
    required this.serverUri,
    super.key,
  });

  final List<MapView> maps;
  final List<ShopView> mapShops;
  final int purse;
  final Uri serverUri;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  String? _root;

  /// Kok haritalar: ust'u hic olmayan ya da ust'u gorunur olmayan haritalar.
  List<MapView> _roots() {
    final ids = widget.maps.map((m) => m.locationId).toSet();
    return widget.maps
        .where(
          (m) =>
              m.parentLocationId == null || !ids.contains(m.parentLocationId),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roots = _roots();
    if (roots.isEmpty) return const SizedBox.shrink();
    final selected = (_root != null && roots.any((r) => r.locationId == _root))
        ? _root!
        : roots.first.locationId;

    return Column(
      children: [
        if (roots.length > 1)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final r in roots)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r.locationName),
                      selected: r.locationId == selected,
                      onSelected: (_) => setState(() => _root = r.locationId),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            // Kaydirici tam genislikte: genis ekranda kart ortalanir, yanindaki
            // bosluklar da kaydirilabilir alanin parcasidir. Fare haritanin
            // uzerindeyken tekerlek zoom yapar (bkz. _ZoomScrollClaim), yan
            // bosluktayken sayfa yukari/asagi kayar.
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: _MapNavigator(
                    key: ValueKey(selected),
                    rootLocationId: selected,
                    maps: widget.maps,
                    mapShops: widget.mapShops,
                    purse: widget.purse,
                    serverUri: widget.serverUri,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Harita(lar) uzerinde gezinme: gorsel + pinler + alt-yer giris/geri + dukkan.
///
/// Yalnizca DM'in actigi pinler burada -- gizliler istemciye hic gonderilmiyor.
/// Oyuncu, revealed location-pine ya da "Alt yerler" listesine dokununca alt
/// haritaya girer; haritadan erisilebilir dukkan pinine dokununca dukkan acilir.
/// Gezinme yigini burada tutulur, snapshot guncellense de oyuncu bulundugu alt
/// haritada kalir. Hem sekmede hem tam ekran sayfasinda kullanilir.
class _MapNavigator extends StatefulWidget {
  const _MapNavigator({
    required this.rootLocationId,
    required this.maps,
    required this.serverUri,
    this.mapShops = const [],
    this.purse = 0,
    this.fullscreen = false,
    super.key,
  });

  final String rootLocationId;
  final List<MapView> maps;
  final List<ShopView> mapShops;
  final int purse;
  final Uri serverUri;

  /// true ise tam ekran sayfasindayiz: harita alani ekrani doldurur, alt yer
  /// listesi/notlar gizlenir, sag ustte kapat dugmesi olur.
  final bool fullscreen;

  @override
  State<_MapNavigator> createState() => _MapNavigatorState();
}

class _MapNavigatorState extends State<_MapNavigator> {
  late List<String> _stack = [widget.rootLocationId];

  MapView? _mapFor(String id) =>
      widget.maps.where((m) => m.locationId == id).firstOrNull;

  @override
  void didUpdateWidget(_MapNavigator old) {
    super.didUpdateWidget(old);
    if (widget.rootLocationId != old.rootLocationId) {
      _stack = [widget.rootLocationId];
    } else {
      _stack = _stack.where((id) => _mapFor(id) != null).toList();
      if (_stack.isEmpty) _stack = [widget.rootLocationId];
    }
  }

  void _enter(String locationId) {
    if (_mapFor(locationId) == null) return;
    setState(() => _stack = [..._stack, locationId]);
  }

  void _back() {
    if (_stack.length <= 1) return;
    setState(() => _stack = _stack.sublist(0, _stack.length - 1));
  }

  String _breadcrumb() =>
      _stack.map((id) => _mapFor(id)?.locationName ?? '?').join('  ›  ');

  void _openShop(ShopView shop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          child: _ShopCard(shopId: shop.id),
        ),
      ),
    );
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullscreenMapPage(
          rootLocationId: _stack.last,
          maps: widget.maps,
          mapShops: widget.mapShops,
          purse: widget.purse,
          serverUri: widget.serverUri,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final map = _mapFor(_stack.last) ?? _mapFor(widget.rootLocationId);
    if (map == null) return const SizedBox.shrink();

    final availableIds = widget.maps.map((m) => m.locationId).toSet();
    final shopById = {for (final s in widget.mapShops) s.id: s};

    bool canEnter(MapPinView pin) =>
        pin.kind == 'location' &&
        pin.targetLocationId != null &&
        availableIds.contains(pin.targetLocationId);
    bool canOpenShop(MapPinView pin) =>
        pin.kind == 'shop' &&
        pin.targetShopId != null &&
        shopById.containsKey(pin.targetShopId);

    void onTapPin(MapPinView pin) {
      if (canEnter(pin)) {
        _enter(pin.targetLocationId!);
      } else if (canOpenShop(pin)) {
        _openShop(shopById[pin.targetShopId]!);
      } else if (pin.kind == 'treasure' &&
          ((pin.lootItems?.isNotEmpty ?? false) ||
              (pin.lootCoinsCp ?? 0) > 0)) {
        _showTreasureLoot(context, pin);
      } else {
        _showPinInfo(context, pin);
      }
    }

    final children = widget.maps
        .where((m) => m.parentLocationId == map.locationId)
        .toList();

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          if (_stack.length > 1)
            IconButton(
              tooltip: PlayerL10n.of(context).back,
              icon: const Icon(Icons.arrow_back),
              onPressed: _back,
            )
          else
            const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(map.locationName, style: theme.textTheme.titleMedium),
                if (_stack.length > 1)
                  Text(
                    _breadcrumb(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  )
                else if (map.description.isNotEmpty)
                  Text(map.description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (widget.fullscreen)
            IconButton(
              tooltip: PlayerL10n.of(context).close,
              icon: const Icon(Icons.fullscreen_exit),
              onPressed: () => Navigator.of(context).pop(),
            )
          else
            IconButton(
              tooltip: PlayerL10n.of(context).fullscreen,
              icon: const Icon(Icons.fullscreen),
              onPressed: _openFullscreen,
            ),
        ],
      ),
    );

    final surface = _MapSurface(
      map: map,
      serverUri: widget.serverUri,
      actionable: (pin) => canEnter(pin) || canOpenShop(pin),
      onTapPin: onTapPin,
      fullscreen: widget.fullscreen,
    );

    if (widget.fullscreen) {
      // Center YOK: surface tum alani viewport olarak kullaniyor ki zoom
      // gorseli ekran kenarina kadar buyutsun.
      return Column(
        children: [
          header,
          Expanded(child: surface),
        ],
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          surface,
          _childrenList(context, children),
          _notes(context, map),
        ],
      ),
    );
  }

  Widget _childrenList(BuildContext context, List<MapView> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PlayerL10n.of(context).subLocations,
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final child in children)
                ActionChip(
                  avatar: const Icon(Icons.place, size: 18),
                  label: Text(child.locationName),
                  onPressed: () => _enter(child.locationId),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _notes(BuildContext context, MapView map) {
    final theme = Theme.of(context);
    final noted = map.pins.where((p) => p.note.isNotEmpty).toList();
    if (noted.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pin in noted)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.bodySmall,
                  children: [
                    TextSpan(
                      text: '${pin.label}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: pin.note),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fare tekerlegi / izleme-yuzeyi kaydirma olayini "sahiplenir" ki icindeki
/// [InteractiveViewer] zoom yaparken ebeveyn kaydirici (SingleChildScrollView)
/// AYNI ANDA sayfayi kaydirmasin.
///
/// Neden gerekli: InteractiveViewer tekerlek olayini duz bir `Listener` ile
/// isliyor ve pointer-signal resolver'a KAYDOLMUYOR; ebeveyn Scrollable ise
/// resolver kullaniyor. Ikisi de tetiklendiginden harita uzerinde tekerlek hem
/// zoom yapiyor hem sayfayi kaydiriyordu. Burada olayi resolver'a kaydederek
/// (IV'den daha derin oldugumuz icin ilk biz kaydoluruz, resolver ilk kaydolani
/// secer) Scrollable'i bastiriyoruz; zoom IV'nin kendi Listener'iyla surer.
/// Haritanin DISINDA (yan bosluk) bu widget olayi gormedigi icin sayfa normal
/// kayar.
class _ZoomScrollClaim extends StatelessWidget {
  const _ZoomScrollClaim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: child,
    );
  }
}

/// Tek bir haritanin gorseli + pinleri. En-boy orani korunur ki pinler dogru
/// otursun (tam ekranda da BoxFit.contain letterbox'i pinleri kaydirmasin).
class _MapSurface extends StatelessWidget {
  const _MapSurface({
    required this.map,
    required this.serverUri,
    required this.actionable,
    required this.onTapPin,
    this.fullscreen = false,
  });

  final MapView map;
  final Uri serverUri;

  /// Pin tiklaninca bir sey oluyor mu (alt haritaya girer ya da dukkan acar)?
  final bool Function(MapPinView pin) actionable;
  final void Function(MapPinView pin) onTapPin;

  /// Tam ekranda harita, verilen alanin TAMAMINI viewport olarak kullanir:
  /// yakinlastirinca gorsel (kartta oldugu gibi kendi kutusuna degil) ekran
  /// kenarina kadar buyur. Karttaysa gorsel en-boy oranina gore kutulanir.
  final bool fullscreen;

  @override
  Widget build(BuildContext context) {
    final url = map.imageUrl;
    if (url == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(PlayerL10n.of(context).noMapForPlace),
      );
    }
    final imageUrl = serverUri.replace(path: url);

    // Kart: gorsel en-boy oraninda kutulanir, InteractiveViewer o kutu icinde
    // zoom yapar (kartta zaten siyah bosluk yok).
    if (!fullscreen) {
      return _ZoomScrollClaim(
        child: InteractiveViewer(
          maxScale: 5,
          child: AspectRatio(
            aspectRatio: map.aspectRatio <= 0 ? 1 : map.aspectRatio,
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                fit: StackFit.expand,
                children: [
                  _MapImage(url: imageUrl),
                  for (final pin in map.pins)
                    Positioned(
                      left: pin.x * constraints.maxWidth - 14,
                      top: pin.y * constraints.maxHeight - 28,
                      child: _PlayerPin(
                        pin: pin,
                        actionable: actionable(pin),
                        onTap: () => onTapPin(pin),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Tam ekran: viewport = tum alan. Cocuk da tum alan kadar; gorsel bu kutu
    // icinde ortalanip en-boy oraniyla yerlestirilir, etrafi (siyah) kutunun
    // parcasi. Zoom TUM cocugu buyuttugu icin gorsel siyah alanlara dogru
    // acilir ve yalnizca ekran kenarinda kirpilir. Pinler gorselin gercek
    // dikdortgenine hizalanir.
    final ar = map.aspectRatio <= 0 ? 1.0 : map.aspectRatio;
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxW = constraints.maxWidth;
        final boxH = constraints.maxHeight;
        // Gorselin kutu icindeki "contain" dikdortgeni.
        final double imgW;
        final double imgH;
        if (boxW / boxH > ar) {
          imgH = boxH;
          imgW = boxH * ar;
        } else {
          imgW = boxW;
          imgH = boxW / ar;
        }
        final offsetX = (boxW - imgW) / 2;
        final offsetY = (boxH - imgH) / 2;

        return _ZoomScrollClaim(
          child: InteractiveViewer(
            maxScale: 5,
            child: SizedBox(
              width: boxW,
              height: boxH,
              child: Stack(
                children: [
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: imgW,
                    height: imgH,
                    child: _MapImage(url: imageUrl),
                  ),
                  for (final pin in map.pins)
                    Positioned(
                      left: offsetX + pin.x * imgW - 14,
                      top: offsetY + pin.y * imgH - 28,
                      child: _PlayerPin(
                        pin: pin,
                        actionable: actionable(pin),
                        onTap: () => onTapPin(pin),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Haritayi tam ekran + (mumkunse) yatay gosterir.
class _FullscreenMapPage extends StatefulWidget {
  const _FullscreenMapPage({
    required this.rootLocationId,
    required this.maps,
    required this.serverUri,
    this.mapShops = const [],
    this.purse = 0,
  });

  final String rootLocationId;
  final List<MapView> maps;
  final List<ShopView> mapShops;
  final int purse;
  final Uri serverUri;

  @override
  State<_FullscreenMapPage> createState() => _FullscreenMapPageState();
}

class _FullscreenMapPageState extends State<_FullscreenMapPage> {
  @override
  void initState() {
    super.initState();
    enterFullscreenLandscape();
  }

  @override
  void dispose() {
    exitFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: _MapNavigator(
        rootLocationId: widget.rootLocationId,
        maps: widget.maps,
        mapShops: widget.mapShops,
        purse: widget.purse,
        serverUri: widget.serverUri,
        fullscreen: true,
      ),
    ),
  );
}

/// Harita gorselini indirip cizer; yukleme ve hata durumlarini ACIKCA
/// gosterir.
///
/// Eski surumde `Image.network` yalnizca sessizce yukleniyordu: istek asili
/// kalirsa oyuncu bos/gri, "sonsuza dek donen" bir alan goruyordu ve neyin
/// yanlis gittigi anlasilamiyordu. Artik yuklenirken gostergesi, hata olursa
/// URL + hata metni cikiyor -- masada tani koymak icin.
class _MapImage extends StatelessWidget {
  const _MapImage({required this.url});

  final Uri url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Image.network(
      url.toString(),
      fit: BoxFit.contain,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        final value =
            progress.expectedTotalBytes != null &&
                progress.expectedTotalBytes! > 0
            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
            : null;
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(value: value),
              const SizedBox(height: 8),
              Text(
                PlayerL10n.of(context).mapLoading,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(
                PlayerL10n.of(context).mapFailed,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Text(
                url.toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                '$error',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerPin extends StatelessWidget {
  const _PlayerPin({
    required this.pin,
    required this.onTap,
    this.actionable = false,
  });

  final MapPinView pin;
  final VoidCallback onTap;

  /// Pine dokununca bir sey oluyorsa (alt haritaya girer ya da dukkan acar)
  /// vurgulanir. Location'da giris ikonu, dukkanda magaza ikonu gosterilir.
  final bool actionable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = actionable
        ? theme.colorScheme.tertiary
        : theme.colorScheme.primary;
    final icon = actionable && pin.kind == 'location'
        ? Icons.login
        : iconForPinKind(pin.kind);
    // GestureDetector + Tooltip: mobilde tooltip icin basili tutmak gerekiyor,
    // asil etkilesim dokunma. Pine dokununca bilgisi aciliyor.
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: actionable ? 3 : 2,
              ),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              pin.label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

IconData iconForPinKind(String kind) => switch (kind) {
  'location' => Icons.place,
  'place' => Icons.signpost,
  'npc' => Icons.person,
  'shop' => Icons.storefront,
  'encounter' => Icons.shield,
  'treasure' => Icons.diamond,
  _ => Icons.sticky_note_2,
};

/// Pine dokununca etiketini ve (varsa) notunu alttan acilan bir panelde
/// gosterir. Oyuncu haritayi "gezebilsin" diye.
void _showPinInfo(BuildContext context, MapPinView pin) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  iconForPinKind(pin.kind),
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(pin.label, style: theme.textTheme.titleLarge),
                ),
              ],
            ),
            if (pin.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(pin.note, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      );
    },
  );
}

/// Hazine pini icin ganimet dialogu acar.
///
/// Dialogun kendisi snapshot'taki pinin guncel durumunu izler; esya/para
/// alininca azalir, hepsi alininca pin DB'den silinir ve dialog kapanir.
void _showTreasureLoot(BuildContext context, MapPinView pin) {
  showDialog<void>(
    context: context,
    builder: (context) => _TreasureLootDialog(pinId: pin.id),
  );
}

/// DM'in actigi magaza.
/// Magaza karti.
///
/// **Magazayi id ile alir, hazir bir [ShopView] ile DEGIL.** Kart alttan
/// acilan bir panelde de gosteriliyor; o panel bir kez kurulup acik kaldigi
/// icin kurulurken kopyalanan bir gorunum donuk kalirdi: oyuncu alisveris
/// yapinca ne kesesindeki para ne de kalan adet degisir, panel kapatilip
/// yeniden acilana kadar eski degerler gorunurdu. Snapshot her yenilendiginde
/// dogru satirin YENIDEN OKUNMASI icin id tutuluyor.
class _ShopCard extends ConsumerWidget {
  const _ShopCard({required this.shopId});

  final String shopId;

  /// Magazayi canli snapshot'ta arar: hem DM'in actigi magaza hem de
  /// haritadan erisilenler.
  static ShopView? _shopOf(PlayerState state, String id) {
    final snapshot = state.snapshot;
    if (snapshot == null) return null;
    if (snapshot.shop?.id == id) return snapshot.shop;
    return snapshot.mapShops.where((s) => s.id == id).firstOrNull;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final l = PlayerL10n.of(context);

    final shop = _shopOf(state, shopId);
    // Magaza kapandiysa/kaldirildiysa panel bos bir kart gostermesin.
    if (shop == null) return const SizedBox.shrink();
    final purse = state.myCharacter?.coinsCp ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(shop.name, style: theme.textTheme.titleMedium),
                ),
                Text(_coins(purse), style: theme.textTheme.labelLarge),
              ],
            ),
            if (shop.ownerName != null && shop.ownerName!.isNotEmpty)
              Text(shop.ownerName!, style: theme.textTheme.bodySmall),
            if (shop.requiresApproval)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l.purchasesNeedApproval,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            const Divider(height: 20),
            if (shop.closed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 18,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.shopClosedMsg,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )
            else if (shop.items.isEmpty)
              Text(l.shelvesEmpty, style: theme.textTheme.bodySmall)
            else
              for (final item in shop.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: item.soldOut
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              [
                                _coins(item.priceCp),
                                if (!item.unlimited) l.pieces(item.quantity),
                                if (item.rarity != null) item.rarity!,
                                if (item.requiresAttunement) 'attunement',
                              ].join(' · '),
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        // Parasi yetmiyorsa ya da tukendiyse basilamaz;
                        // sunucu da ayrica dogruluyor.
                        onPressed: item.soldOut || purse < item.priceCp
                            ? null
                            : () => controller.buy(item.stockId),
                        child: Text(l.take),
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

class _InventoryCard extends ConsumerWidget {
  const _InventoryCard({required this.character, this.recipients = const []});

  final PlayerCharacterView character;

  /// Esya/para gonderilebilecek diger oyuncular. Bossa gonderme dugmeleri
  /// devre disi (masada tek oyuncu).
  final List<({String id, String name})> recipients;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final l = PlayerL10n.of(context);
    final canSend = recipients.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.inventory, style: theme.textTheme.titleMedium),
                ),
                Text(
                  _coins(character.coinsCp),
                  style: theme.textTheme.labelLarge,
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: canSend && character.coinsCp > 0
                      ? l.sendMoney
                      : l.cantSendMoney,
                  icon: const Icon(Icons.send, size: 18),
                  onPressed: canSend && character.coinsCp > 0
                      ? () => _sendCoinsDialog(
                          context,
                          ref,
                          recipients,
                          character.coinsCp,
                        )
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (character.inventory.isEmpty)
              Text(l.bagEmpty, style: theme.textTheme.bodySmall)
            else
              for (final line in character.inventory)
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: line.equipped ? l.unequip : l.equip,
                      icon: Icon(
                        line.equipped
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 18,
                        color: line.equipped ? theme.colorScheme.primary : null,
                      ),
                      onPressed: () => controller.toggleEquipped(line.id),
                    ),
                    Expanded(
                      child: Text(
                        line.name.isEmpty ? l.unknownItem : line.name,
                        style: line.magic
                            ? TextStyle(color: theme.colorScheme.tertiary)
                            : null,
                      ),
                    ),
                    if (line.attuned)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          Icons.link,
                          size: 16,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    if (line.quantity > 1) Text('×${line.quantity}'),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: canSend ? l.send : l.noPlayerToSend,
                      icon: const Icon(Icons.send_outlined, size: 18),
                      onPressed: canSend
                          ? () =>
                                _sendItemDialog(context, ref, line, recipients)
                          : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l.drop,
                      icon: const Icon(Icons.remove_circle_outline, size: 18),
                      onPressed: () => controller.dropItem(line.id),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}

/// Uyesi oldugun ortak keseler: serbestce al ve koy (DM onayi yok).
///
/// Uye olunmayan kese snapshot'a hic dusmez, bu yuzden burada gorunurluk
/// suzmesi yapilmaz -- gelen her kese kullanilabilir demektir.
class _PartyInventoriesCard extends ConsumerWidget {
  const _PartyInventoriesCard({
    required this.inventories,
    required this.character,
  });

  final List<PartyInventoryView> inventories;
  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final controller = ref.read(playerControllerProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.partyPurses, style: theme.textTheme.titleMedium),
            for (final inv in inventories)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text(inv.name, style: theme.textTheme.bodyMedium),
                subtitle: Text(
                  _coins(inv.coinsCp),
                  style: theme.textTheme.labelSmall,
                ),
                children: [
                  // Para satiri.
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _coins(inv.coinsCp),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: inv.coinsCp > 0
                            ? () => _partyCoinsDialog(
                                context,
                                ref,
                                inventoryId: inv.id,
                                max: inv.coinsCp,
                                deposit: false,
                              )
                            : null,
                        child: Text(l.partyTake),
                      ),
                      TextButton(
                        onPressed: character.coinsCp > 0
                            ? () => _partyCoinsDialog(
                                context,
                                ref,
                                inventoryId: inv.id,
                                max: character.coinsCp,
                                deposit: true,
                              )
                            : null,
                        child: Text(l.partyDeposit),
                      ),
                    ],
                  ),
                  const Divider(height: 8),
                  if (inv.items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        l.partyPurseEmpty,
                        style: theme.textTheme.bodySmall,
                      ),
                    )
                  else
                    for (final item in inv.items)
                      Row(
                        children: [
                          Icon(
                            item.magic
                                ? Icons.auto_awesome
                                : Icons.backpack_outlined,
                            size: 16,
                            color: item.magic
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.name.isEmpty ? l.unknownItem : item.name,
                              style: item.magic
                                  ? TextStyle(color: theme.colorScheme.tertiary)
                                  : null,
                            ),
                          ),
                          if (item.quantity > 1) Text('×${item.quantity}'),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: l.partyTake,
                            icon: const Icon(Icons.download_outlined, size: 18),
                            onPressed: () =>
                                controller.takePartyItem(inv.id, item.id),
                          ),
                        ],
                      ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: character.inventory.isEmpty
                          ? null
                          : () => _depositPartyItemSheet(
                              context,
                              ref,
                              inventoryId: inv.id,
                            ),
                      icon: const Icon(Icons.upload_outlined, size: 18),
                      label: Text(
                        character.inventory.isEmpty
                            ? l.partyNothingToDeposit
                            : l.partyDepositItem,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Ortak keseye para koyma / keseden para alma. `_sendCoinsDialog` ile ayni
/// birim secici deseni.
void _partyCoinsDialog(
  BuildContext context,
  WidgetRef ref, {
  required String inventoryId,
  required int max,
  required bool deposit,
}) {
  var unit = 100; // gp
  final amountController = TextEditingController();
  const units = [('pp', 1000), ('gp', 100), ('sp', 10), ('cp', 1)];

  showDialog<void>(
    context: context,
    builder: (context) {
      final l = PlayerL10n.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(deposit ? l.partyDepositMoney : l.partyTakeMoney),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l.amount,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: unit,
                    items: [
                      for (final (label, mul) in units)
                        DropdownMenuItem(value: mul, child: Text(label)),
                    ],
                    onChanged: (v) => setState(() => unit = v ?? 100),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.inPurse(_coins(max)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final amount =
                    (int.tryParse(amountController.text.trim()) ?? 0) * unit;
                if (amount <= 0) return;
                final controller = ref.read(playerControllerProvider.notifier);
                if (deposit) {
                  controller.depositPartyCoins(inventoryId, amount);
                } else {
                  controller.takePartyCoins(inventoryId, amountCp: amount);
                }
                Navigator.pop(context);
              },
              child: Text(deposit ? l.partyDeposit : l.partyTake),
            ),
          ],
        ),
      );
    },
  );
}

/// Kendi cantandan ortak keseye esya koyma listesi.
///
/// Envanteri PARAMETREDEN DEGIL canli snapshot'tan okur: panel acikken baska
/// bir yerden esya eklenip cikarilabiliyor (aktarim, ganimet, alisveris) ve
/// kurulurken kopyalanan liste donuk kalirdi.
void _depositPartyItemSheet(
  BuildContext context,
  WidgetRef ref, {
  required String inventoryId,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final l = PlayerL10n.of(context);
        final theme = Theme.of(context);
        final inventory =
            ref.watch(playerControllerProvider).myCharacter?.inventory ??
            const <InventoryLine>[];
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  l.partyDepositItem,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              for (final line in inventory)
                ListTile(
                  leading: Icon(
                    line.magic ? Icons.auto_awesome : Icons.backpack_outlined,
                    color: line.magic ? theme.colorScheme.tertiary : null,
                  ),
                  title: Text(line.name.isEmpty ? l.unknownItem : line.name),
                  subtitle: line.quantity > 1
                      ? Text('×${line.quantity}')
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    if (line.quantity > 1) {
                      _depositQuantityDialog(
                        context,
                        ref,
                        inventoryId: inventoryId,
                        line: line,
                      );
                    } else {
                      ref
                          .read(playerControllerProvider.notifier)
                          .depositPartyItem(inventoryId, line.id);
                    }
                  },
                ),
            ],
          ),
        );
      },
    ),
  );
}

/// Istifli esyada kac tane konacagini sorar.
void _depositQuantityDialog(
  BuildContext context,
  WidgetRef ref, {
  required String inventoryId,
  required InventoryLine line,
}) {
  var quantity = 1;
  showDialog<void>(
    context: context,
    builder: (context) {
      final l = PlayerL10n.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(line.name.isEmpty ? l.unknownItem : line.name),
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.partyQuantity),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: quantity > 1
                    ? () => setState(() => quantity--)
                    : null,
              ),
              Text('$quantity'),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: quantity < line.quantity
                    ? () => setState(() => quantity++)
                    : null,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                ref
                    .read(playerControllerProvider.notifier)
                    .depositPartyItem(inventoryId, line.id, quantity: quantity);
                Navigator.pop(context);
              },
              child: Text(l.partyDeposit),
            ),
          ],
        ),
      );
    },
  );
}

/// Alici secici (birden fazla oyuncu varsa dropdown, tekse sabit).
class _RecipientDropdown extends StatelessWidget {
  const _RecipientDropdown({
    required this.recipients,
    required this.value,
    required this.onChanged,
  });

  final List<({String id, String name})> recipients;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: PlayerL10n.of(context).toWhom,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    items: [
      for (final r in recipients)
        DropdownMenuItem(value: r.id, child: Text(r.name)),
    ],
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

/// Esya gonderme diyalogu: alici + (staklanabilirse) adet.
void _sendItemDialog(
  BuildContext context,
  WidgetRef ref,
  InventoryLine line,
  List<({String id, String name})> recipients,
) {
  if (recipients.isEmpty) return;
  var target = recipients.first.id;
  var qty = 1;
  showDialog<void>(
    context: context,
    builder: (context) {
      final l = PlayerL10n.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            l.sendTitle(line.name.isEmpty ? l.unknownItem : line.name),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RecipientDropdown(
                recipients: recipients,
                value: target,
                onChanged: (v) => setState(() => target = v),
              ),
              if (line.quantity > 1) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(l.diceCount),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qty > 1 ? () => setState(() => qty--) : null,
                    ),
                    Text('$qty'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: qty < line.quantity
                          ? () => setState(() => qty++)
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                ref
                    .read(playerControllerProvider.notifier)
                    .offerItem(
                      toCharacterId: target,
                      itemId: line.id,
                      quantity: qty,
                    );
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(content: Text(l.sentAwaitingApproval)),
                );
              },
              child: Text(l.send),
            ),
          ],
        ),
      );
    },
  );
}

/// Para gonderme diyalogu: alici + miktar + birim (pp/gp/sp/cp).
void _sendCoinsDialog(
  BuildContext context,
  WidgetRef ref,
  List<({String id, String name})> recipients,
  int purse,
) {
  if (recipients.isEmpty) return;
  var target = recipients.first.id;
  var unit = 100; // gp
  final amountController = TextEditingController();
  const units = [('pp', 1000), ('gp', 100), ('sp', 10), ('cp', 1)];

  showDialog<void>(
    context: context,
    builder: (context) {
      final l = PlayerL10n.of(context);
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l.sendMoney),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RecipientDropdown(
                recipients: recipients,
                value: target,
                onChanged: (v) => setState(() => target = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: l.amount,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: unit,
                    items: [
                      for (final (label, mul) in units)
                        DropdownMenuItem(value: mul, child: Text(label)),
                    ],
                    onChanged: (v) => setState(() => unit = v ?? 100),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                l.inPurse(_coins(purse)),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                final amount = int.tryParse(amountController.text.trim()) ?? 0;
                final cp = amount * unit;
                if (cp <= 0) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l.enterValidAmount)),
                  );
                  return;
                }
                if (cp > purse) {
                  messenger.showSnackBar(
                    SnackBar(content: Text(l.notEnoughMoney)),
                  );
                  return;
                }
                ref
                    .read(playerControllerProvider.notifier)
                    .offerCoins(toCharacterId: target, coinsCp: cp);
                Navigator.pop(context);
                messenger.showSnackBar(
                  SnackBar(content: Text(l.sentAwaitingApproval)),
                );
              },
              child: Text(l.send),
            ),
          ],
        ),
      );
    },
  ).whenComplete(amountController.dispose);
}

/// Bakiri okunur paraya cevirir. Oyuncu paneli veri katmanina bagimli
/// olmadigi icin bicimleyici burada tekrar tanimli.
String _coins(int cp) {
  if (cp == 0) return '0 gp';
  final pp = cp ~/ 1000;
  final gp = (cp % 1000) ~/ 100;
  final sp = (cp % 100) ~/ 10;
  final rest = cp % 10;
  return [
    if (pp > 0) '$pp pp',
    if (gp > 0) '$gp gp',
    if (sp > 0) '$sp sp',
    if (rest > 0) '$rest cp',
  ].join(' ');
}

class _HitPointsCard extends ConsumerStatefulWidget {
  const _HitPointsCard({required this.character});

  final PlayerCharacterView character;

  @override
  ConsumerState<_HitPointsCard> createState() => _HitPointsCardState();
}

class _HitPointsCardState extends ConsumerState<_HitPointsCard> {
  int _amount = 1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.character;
    final controller = ref.read(playerControllerProvider.notifier);
    final ratio = c.hitPointsMax == 0
        ? 0.0
        : c.hitPointsCurrent / c.hitPointsMax;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(c.name, style: theme.textTheme.titleLarge),
            Text(c.classLine, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${c.hitPointsCurrent}',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: c.hitPointsCurrent == 0
                        ? theme.colorScheme.error
                        : null,
                  ),
                ),
                Text(
                  ' / ${c.hitPointsMax}',
                  style: theme.textTheme.titleMedium,
                ),
                if (c.temporaryHitPoints > 0) ...[
                  const SizedBox(width: 10),
                  Chip(label: Text('+${c.temporaryHitPoints}')),
                ],
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 6,
              color: ratio <= 0.25
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => controller.changeHitPoints(-_amount),
                    child: Text(PlayerL10n.of(context).damage),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: '$_amount',
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(isDense: true),
                    onChanged: (v) => _amount = int.tryParse(v) ?? 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => controller.changeHitPoints(_amount),
                    child: Text(PlayerL10n.of(context).heal),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 0 HP'deki oyuncunun olum kurtarma paneli. Sunucu d20 atip 5e kurallarini
/// uyguluyor; burada yalnizca sayaclar (3 basari / 3 basarisizlik) gosterilip
/// atis istegi yollaniyor. Dogal 20'de sunucu 1 HP verdigi icin kart snapshot
/// guncellenince kendiliginden kayboluyor.
class _DeathSaveCard extends ConsumerWidget {
  const _DeathSaveCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final successes = character.deathSaveSuccesses;
    final failures = character.deathSaveFailures;
    final stabilized = successes >= 3;
    final dead = failures >= 3;
    final resolved = stabilized || dead;

    Widget dots(int filled, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              i < filled ? Icons.circle : Icons.circle_outlined,
              size: 18,
              color: color,
            ),
          ),
      ],
    );

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.favorite_border, color: theme.colorScheme.error),
                const SizedBox(width: 8),
                Text(l.deathSaves, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.deathSaveSuccesses),
                dots(successes, Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l.deathSaveFailures),
                dots(failures, theme.colorScheme.error),
              ],
            ),
            const SizedBox(height: 16),
            if (resolved)
              Center(
                child: Text(
                  stabilized ? l.deathSaveStabilized : l.deathSaveDead,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: stabilized ? Colors.green : theme.colorScheme.error,
                  ),
                ),
              )
            else
              FilledButton.icon(
                onPressed: () =>
                    controller.rollDeathSave(label: l.deathSaveLabel),
                icon: const Icon(Icons.casino_outlined),
                label: Text(l.deathSaveRoll),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends ConsumerWidget {
  const _StatsCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final l = PlayerL10n.of(context);

    void roll(String label, int modifier) =>
        controller.rollDice(label: label, modifier: modifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 12,
              children: [
                for (final (label, value) in [
                  ('AC', '${character.armorClass ?? '—'}'),
                  (l.initiative, _signed(character.initiative)),
                  (l.proficiencyBonus, _signed(character.proficiencyBonus)),
                  (l.passivePerception, '${character.passivePerception}'),
                ])
                  SizedBox(
                    width: 96,
                    child: Column(
                      children: [
                        Text(value, style: theme.textTheme.titleLarge),
                        Text(label, style: theme.textTheme.labelSmall),
                      ],
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            // Ana stat'a dokun -> yetenek kontrolu; uzun bas -> kurtarma.
            Text(
              l.statHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final e in character.abilityModifiers.entries)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => roll(l.abilityCheck(e.key), e.value),
                      onLongPress: () => roll(
                        l.abilitySave(e.key),
                        character.savingThrows[e.key] ?? e.value,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          children: [
                            Text(e.key, style: theme.textTheme.labelSmall),
                            Text(
                              _signed(e.value),
                              style: theme.textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (character.savingThrows.isNotEmpty) ...[
              const Divider(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.savingThrows),
                children: [
                  for (final e in character.savingThrows.entries)
                    _RollRow(
                      label: e.key,
                      value: e.value,
                      onTap: () => roll(l.abilitySave(e.key), e.value),
                    ),
                ],
              ),
            ],
            if (character.skills.isNotEmpty) ...[
              const Divider(height: 24),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(l.skills),
                children: [
                  for (final e in character.skills.entries)
                    _RollRow(
                      label: e.key,
                      value: e.value,
                      onTap: () => roll(e.key, e.value),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _signed(int? value) =>
      value == null ? '—' : (value >= 0 ? '+$value' : '$value');
}

/// Dok ununca zar atan beceri/kurtarma satiri.
class _RollRow extends StatelessWidget {
  const _RollRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value >= 0 ? '+$value' : '$value'),
          const SizedBox(width: 8),
          const Icon(Icons.casino_outlined, size: 16),
        ],
      ),
    ),
  );
}

/// Paylasilan zar gunlugu; hem oyuncularin hem DM'in gorunur atislari.
class _RollLogCard extends StatelessWidget {
  const _RollLogCard({required this.rolls});

  final List<DiceRoll> rolls;

  @override
  Widget build(BuildContext context) {
    if (rolls.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    // En yeni en ustte.
    final recent = rolls.reversed.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              PlayerL10n.of(context).diceLog,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final r in recent)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${r.source ?? 'DM'} · ${r.label}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${r.total}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      r.detail,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
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

/// Oyuncunun serbest zar atma paneli. Sonuc sunucuya gidip herkese yansir.
void showPlayerDiceSheet(BuildContext context, PlayerController controller) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      var count = 1;
      var modifier = 0;
      const dice = [4, 6, 8, 10, 12, 20, 100];
      final l = PlayerL10n.of(context);
      return StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l.rollDice, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(l.diceCount),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: count > 1 ? () => setState(() => count--) : null,
                  ),
                  Text('$count'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: count < 20
                        ? () => setState(() => count++)
                        : null,
                  ),
                  const Spacer(),
                  Text(l.diceMod),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => setState(() => modifier--),
                  ),
                  Text(modifier >= 0 ? '+$modifier' : '$modifier'),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => modifier++),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sides in dice)
                    FilledButton.tonal(
                      onPressed: () {
                        controller.rollDice(
                          label: '${count}d$sides',
                          sides: sides,
                          count: count,
                          modifier: modifier,
                        );
                        Navigator.pop(context);
                      },
                      child: Text('d$sides'),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Paylasilan gunlukte bu oyuncuya ait, [lastSeq]'ten yeni en son atisi bulur.
///
/// Zar pop-up'i yalnizca "benim" (source == [myName]) ve daha once
/// gosterilmemis atislarda cikar; baskasinin atisi ya da acilistaki gecmis
/// atislar patlamaz. Gunluk 30'da kapansa da `seq` artmaya devam ettigi icin
/// guvenilir.
DiceRoll? newestOwnRoll(List<DiceRoll> rolls, String myName, int lastSeq) {
  DiceRoll? best;
  for (final r in rolls) {
    final s = r.seq;
    if (s == null || s <= lastSeq) continue;
    if (r.source != myName) continue;
    if (best == null || s > (best.seq ?? 0)) best = r;
  }
  return best;
}

/// Gunlukteki en yuksek sira numarasi (baz alma icin). Bos ise 0.
int _maxRollSeq(List<DiceRoll> rolls) =>
    rolls.fold(0, (m, r) => (r.seq ?? 0) > m ? (r.seq ?? 0) : m);

class _SlotsCard extends ConsumerWidget {
  const _SlotsCard({required this.character});

  final PlayerCharacterView character;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final l = PlayerL10n.of(context);
    final levels = character.spellSlots.keys.toList()..sort();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.spellSlots, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final level in levels)
              Row(
                children: [
                  SizedBox(width: 90, child: Text(l.slotLevel(level))),
                  for (var i = 0; i < character.spellSlots[level]!; i++)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        i < (character.spentSlots[level] ?? 0)
                            ? Icons.circle
                            : Icons.circle_outlined,
                        size: 18,
                      ),
                      onPressed: () {
                        final used = character.spentSlots[level] ?? 0;
                        final next = {...character.spentSlots};
                        next[level] = i + 1 == used ? i : i + 1;
                        controller.setSpentSlots(next);
                      },
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CombatCard extends ConsumerWidget {
  const _CombatCard({
    required this.combat,
    required this.myCharacterId,
    required this.serverUri,
    this.myHpCurrent,
    this.myHpMax,
  });

  final CombatView combat;
  final String myCharacterId;
  final Uri serverUri;

  /// Oyuncu SAVAS listesinde yalnizca KENDI canini isminin yaninda gorur.
  final int? myHpCurrent;
  final int? myHpMax;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final myTurn =
        combat.combatants
            .where((c) => c.id == combat.activeCombatantId)
            .firstOrNull
            ?.characterId ==
        myCharacterId;

    return Card(
      color: myTurn ? theme.colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    combat.encounterName ?? l.combatTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (combat.started) Text(l.roundN(combat.round)),
              ],
            ),
            if (myTurn) ...[
              const SizedBox(height: 8),
              Text(
                l.yourTurn,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final c in combat.combatants)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      width: 3,
                      color: c.id == combat.activeCombatantId
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: _InitiativeCell(
                        combatant: c,
                        isMine: c.characterId == myCharacterId,
                        onRoll: () => ref
                            .read(playerControllerProvider.notifier)
                            .rollInitiative(label: l.initiative),
                      ),
                    ),
                    _CombatantAvatar(combatant: c, serverUri: serverUri),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.name,
                        style: TextStyle(
                          decoration: c.defeated
                              ? TextDecoration.lineThrough
                              : null,
                          fontWeight: c.characterId == myCharacterId
                              ? FontWeight.bold
                              : null,
                        ),
                      ),
                    ),
                    if (c.characterId == myCharacterId && myHpCurrent != null)
                      Text(
                        '$myHpCurrent/$myHpMax',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    else if (c.healthLabel != null)
                      Text(
                        PlayerL10n.of(context).healthLabel(c.healthLabel!),
                        style: theme.textTheme.labelSmall,
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

/// Savas listesindeki katilimci portresi. Canavarda DM'in ekledigi gorsel,
/// oyuncuda karakter portresi; yoksa tipe gore bir simge (kisi/canavar).
class _CombatantAvatar extends StatelessWidget {
  const _CombatantAvatar({required this.combatant, required this.serverUri});

  final CombatantView combatant;
  final Uri serverUri;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallback = Icon(
      combatant.isPlayer ? Icons.person : Icons.pest_control,
      size: 18,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final url = combatant.portraitUrl;
    if (url == null) {
      return CircleAvatar(
        radius: 16,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        child: fallback,
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(serverUri.replace(path: url).toString()),
      // Gorsel inemezse (yol bozuk/sunucu kapali) simgeye dus.
      onBackgroundImageError: (_, _) {},
      child: null,
    );
  }
}

/// Savas listesindeki inisiyatif hucresi. Kendi karakteri henuz atmadiysa zar
/// dugmesi; baskasi atmadiysa kum saati; atildiysa sayi gosterir. Oyuncu zara
/// basinca sunucu atar, sayi yerine gecer ve katilimci siraya oturur.
class _InitiativeCell extends StatelessWidget {
  const _InitiativeCell({
    required this.combatant,
    required this.isMine,
    required this.onRoll,
  });

  final CombatantView combatant;
  final bool isMine;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!combatant.initiativeRolled) {
      if (isMine) {
        return IconButton(
          tooltip: PlayerL10n.of(context).rollInitiative,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.casino, color: theme.colorScheme.primary),
          onPressed: onRoll,
        );
      }
      return Icon(
        Icons.hourglass_empty,
        size: 18,
        color: theme.colorScheme.outline,
      );
    }
    return Text(
      '${combatant.initiative}',
      textAlign: TextAlign.center,
      style: theme.textTheme.titleSmall,
    );
  }
}

/// Notlar sekmesi: basliklar altinda notlar. Sunucuda karaktere bagli
/// saklanir; oyuncu duzenledikce butun belge kaydedilir.
/// Oyuncunun Görevler sekmesi: DM'in bu oyuncuya gösterdiği görevler; her biri
/// kabul/reddedilebilir. Durum snapshot'tan (myStatus) gelir.
class _QuestsTab extends ConsumerWidget {
  const _QuestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final quests = ref.watch(
      playerControllerProvider.select((s) => s.snapshot?.quests ?? const []),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    if (quests.isEmpty) {
      return _EmptyPane(icon: Icons.assignment_outlined, text: l.noQuests);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: quests.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final q = quests[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.title.isEmpty ? l.questFallbackTitle : q.title,
                  style: theme.textTheme.titleMedium,
                ),
                if (q.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(q.text, style: theme.textTheme.bodyMedium),
                  ),
                if (q.reward.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.emoji_events_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${l.questReward}: ${q.reward}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                if (q.rewardReady)
                  _QuestRewardPool(quest: q)
                else if (q.mode == 'vote' && q.voteStatus == 'pending')
                  _QuestVotePending(quest: q)
                else if (q.myStatus == 'accepted')
                  _QuestDecision(
                    icon: Icons.check_circle,
                    color: theme.colorScheme.primary,
                    label: q.voteStatus == 'passed'
                        ? l.questVotePassed
                        : l.questYouAccepted,
                    changeLabel: l.questChangeReject,
                    // Oylamayla alinan gorevden tek basina cikilamaz.
                    onChange: q.voteStatus == 'passed'
                        ? null
                        : () => controller.respondQuest(q.id, accept: false),
                  )
                else if (q.myStatus == 'rejected')
                  _QuestDecision(
                    icon: Icons.cancel,
                    color: theme.colorScheme.error,
                    label: l.questYouRejected,
                    changeLabel: l.questChangeAccept,
                    onChange: () => controller.respondQuest(q.id, accept: true),
                  )
                else
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            controller.respondQuest(q.id, accept: true),
                        icon: const Icon(Icons.check, size: 18),
                        label: Text(
                          q.mode == 'vote' ? l.questVoteYes : l.questAccept,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () =>
                            controller.respondQuest(q.id, accept: false),
                        icon: const Icon(Icons.close, size: 18),
                        label: Text(
                          q.mode == 'vote' ? l.questVoteNo : l.questReject,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Verilmiş kararı + fikir değiştirme düğmesini gösterir.
class _QuestDecision extends StatelessWidget {
  const _QuestDecision({
    required this.icon,
    required this.color,
    required this.label,
    required this.changeLabel,
    required this.onChange,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String changeLabel;

  /// Null ise karar kilitlidir (oylamayla alinan gorev).
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: TextStyle(color: color)),
        ),
        if (onChange != null)
          TextButton(onPressed: onChange, child: Text(changeLabel)),
      ],
    );
  }
}

/// Oylama surerken gosterilen durum: oyun kaydedildi, sonuc bekleniyor.
/// Oy degistirmek serbest (oylama sonuclanana kadar).
class _QuestVotePending extends ConsumerWidget {
  const _QuestVotePending({required this.quest});

  final QuestView quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final controller = ref.read(playerControllerProvider.notifier);

    if (quest.myStatus == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.how_to_vote,
                size: 18,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l.questVoteBanner,
                  style: TextStyle(color: theme.colorScheme.tertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton.icon(
                onPressed: () =>
                    controller.respondQuest(quest.id, accept: true),
                icon: const Icon(Icons.check, size: 18),
                label: Text(l.questVoteYes),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () =>
                    controller.respondQuest(quest.id, accept: false),
                icon: const Icon(Icons.close, size: 18),
                label: Text(l.questVoteNo),
              ),
            ],
          ),
        ],
      );
    }

    final votedYes = quest.myStatus == 'accepted';
    return Row(
      children: [
        Icon(
          votedYes ? Icons.thumb_up : Icons.thumb_down,
          size: 18,
          color: theme.colorScheme.tertiary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '${votedYes ? l.questVotedYes : l.questVotedNo} — ${l.questVoteWaiting}',
            style: TextStyle(color: theme.colorScheme.tertiary),
          ),
        ),
        TextButton(
          onPressed: () => controller.respondQuest(quest.id, accept: !votedYes),
          child: Text(votedYes ? l.questVoteNo : l.questVoteYes),
        ),
      ],
    );
  }
}

/// Gorev tamamlaninca acilan ORTAK odul havuzu. Gorevi kabul eden herkes ayni
/// havuzu gorur: bir esyayi kim once alirsa digerlerinden kaybolur. Havuz
/// bosalinca gorev sunucuda silinir ve kart listeden kendiliginden dusut.
class _QuestRewardPool extends ConsumerWidget {
  const _QuestRewardPool({required this.quest});

  final QuestView quest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final controller = ref.read(playerControllerProvider.notifier);
    final coins = quest.rewardCoinsCp;
    final items = quest.rewardItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.diamond, size: 18, color: theme.colorScheme.tertiary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                l.questRewardReady,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          ],
        ),
        Text(l.questRewardShareHint, style: theme.textTheme.bodySmall),
        if (coins > 0)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.paid),
            title: Text(_coins(coins)),
            trailing: FilledButton(
              onPressed: () => controller.takeQuestRewardCoins(quest.id),
              child: Text(l.take),
            ),
          ),
        for (final item in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(
              item.magic ? Icons.auto_awesome : Icons.backpack_outlined,
              color: item.magic ? theme.colorScheme.tertiary : null,
            ),
            title: Text(item.name),
            trailing: FilledButton.tonal(
              onPressed: () =>
                  controller.takeQuestRewardItem(quest.id, item.id),
              child: Text(l.take),
            ),
          ),
        if (coins > 0 || items.isNotEmpty)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => controller.takeAllQuestReward(quest.id),
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: Text(l.takeAll),
            ),
          ),
      ],
    );
  }
}

/// Notlar sekmesi: oyuncunun not KITAPLIGI (bkz. notes_book.dart).
class _NotesTab extends StatelessWidget {
  const _NotesTab({super.key});

  @override
  Widget build(BuildContext context) => const NotesBookshelf();
}
