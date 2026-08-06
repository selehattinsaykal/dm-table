import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/ui/ui.dart';
import '../net/protocol.dart';
import 'player_client.dart';
import 'player_strings.dart';

/// Oyuncu panelinin Sohbet sekmesi: masadaki sohbete yazar, fısıltı da
/// gonderebilir. Mesajlar snapshot'ta (`state.snapshot.chats`) gelir; DM
/// tarafı bu mesajların tümünü görür.
class ChatTab extends ConsumerStatefulWidget {
  const ChatTab({required this.state, super.key});

  final PlayerState state;

  @override
  ConsumerState<ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<ChatTab> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  /// null = genel, [_dmTarget] = DM'e ozel, aksi halde hedef karakter id'si.
  ///
  /// DM'in karakteri olmadigi icin ayri bir sentinel gerekiyor; sunucuya
  /// giderken `toCharacterId` degil `toDm` bayragina cevriliyor.
  String? _target;
  static const _dmTarget = '__dm__';
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<ChatMessage> _messages() => widget.state.snapshot?.chats ?? const [];

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final toDm = _target == _dmTarget;
    ref
        .read(playerControllerProvider.notifier)
        .sendChat(text, toCharacterId: toDm ? null : _target, toDm: toDm);
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final l = PlayerL10n.of(context);
    final theme = Theme.of(context);
    final messages = _messages();
    final snapshot = widget.state.snapshot;
    final myId = widget.state.claimedCharacterId;

    // Yeni mesaj geldiğinde dibe kay (yalnızca ilk eklemelerde).
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }

    // Fısıltı hedefi: masadaki sahiplenilmiş, kendisi dışındaki karakterler.
    final recipients = <({String id, String name})>[
      for (final c in snapshot?.characters ?? const <PlayerCharacterView>[])
        if (c.id != myId && c.claimedBy != null) (id: c.id, name: c.name),
    ];

    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? AppEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: l.chatEmpty,
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  itemCount: messages.length,
                  itemBuilder: (_, i) =>
                      _Bubble(message: messages[i], myId: myId),
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                _TargetDropdown(
                  target: _target,
                  recipients: recipients,
                  dmLabel: l.chatToDm,
                  dmTarget: _dmTarget,
                  generalLabel: l.chatGeneral,
                  onChanged: (v) => setState(() => _target = v),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: l.chatPlaceholder,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: l.send,
                  onPressed: _send,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Alıcı seçici: Genel ya da bir karakter (fısıltı). Tek karakter varsa
/// sadeleşir; hiç yoksa yalnızca Genel kalır.
class _TargetDropdown extends StatelessWidget {
  const _TargetDropdown({
    required this.target,
    required this.recipients,
    required this.generalLabel,
    required this.dmLabel,
    required this.dmTarget,
    required this.onChanged,
  });

  final String? target;
  final List<({String id, String name})> recipients;
  final String generalLabel;

  /// DM secenegi: gorunen ad ve sentinel deger.
  final String dmLabel;
  final String dmTarget;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String?>(
      value: target,
      underline: const SizedBox.shrink(),
      style: Theme.of(context).textTheme.bodyMedium,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(generalLabel)),
        DropdownMenuItem<String?>(value: dmTarget, child: Text(dmLabel)),
        for (final r in recipients)
          DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
      ],
      onChanged: (v) => onChanged(v),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.myId});

  final ChatMessage message;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    final mine =
        message.fromCharacterId != null && message.fromCharacterId == myId;
    final isDm = message.isDm;
    final name = isDm
        ? l.chatDm
        : (message.fromName.isEmpty
              ? (message.fromCharacterId ?? '?')
              : message.fromName);

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: isDm
            ? theme.colorScheme.tertiaryContainer
            : mine
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(mine ? 14 : 4),
          bottomRight: Radius.circular(mine ? 4 : 14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Yalnizca DM'in gordugu mesajlarda kucuk bir etiket: oyuncu
          // yanlislikla genel sandigi bir seyi ozel yazmasin (ya da tersi).
          if (message.toDm)
            Text(
              l.chatToDm,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.tertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: message.isWhisper ? FontStyle.italic : null,
            ),
          ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          bubble,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
