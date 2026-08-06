import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/ui/ui.dart';
import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import '../../net/protocol.dart';
import '../characters/character_providers.dart';
import '../session/session_page.dart';

/// DM'in gördüğü canlı sohbet. Mesajlar `SessionService`'te bellekte tutulur;
/// oyuncuların yazdıkları buraya akar, DM de genel ya da fısıltı gönderir.
final chatMessagesProvider = StreamProvider<List<ChatMessage>>((ref) async* {
  final service = ref.watch(sessionServiceProvider);
  // Broadcast akışı yeni dinleyiciye mevcut değeri tekrar oynatmaz; ilk
  // değer buradan gelir, sonra her değişimde yeniden verilir (oturum
  // sayfasındaki pendingPurchasesProvider deseniyle aynı).
  yield service.chats;
  await for (final _ in service.chatMessages) {
    yield service.chats;
  }
});

/// DM Sohbet sekmesi: masadaki tüm konuşmaları izler, DM genel/fısıltı yazar.
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  String? _target; // null = genel; dolu = hedef karakter id.
  int _lastCount = 0;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final service = ref.read(sessionServiceProvider);
    if (!(service.server?.isRunning ?? false)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(L10n.of(context).chatNeedSession)));
      return;
    }
    service.sendChatAsDm(text, toCharacterId: _target);
    _controller.clear();
    // Yeni mesaj gelince aşağıya kay. DM kendi mesajını da görmeli.
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      _scroll.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final messages = ref.watch(chatMessagesProvider).value ?? const [];
    final characters = ref.watch(charactersProvider).value ?? const [];
    final nameOf = {for (final c in characters) c.id: c.name};

    // Yeni mesaj geldiğinde listenin dibine kay (yalnızca ilk eklemelerde).
    if (messages.length != _lastCount) {
      _lastCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    }

    final serverOn =
        ref.watch(sessionServiceProvider).server?.isRunning ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navChat)),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? _EmptyChat(needSession: !serverOn, onRetry: () {})
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messages.length,
                    itemBuilder: (_, i) =>
                        _ChatBubble(message: messages[i], nameOf: nameOf),
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
                  _TargetSelector(
                    target: _target,
                    characters: characters,
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
                        hintText: l10n.chatPlaceholder,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Alıcı seçici: Genel (null) ya da bir karakter (fısıltı).
class _TargetSelector extends StatelessWidget {
  const _TargetSelector({
    required this.target,
    required this.characters,
    required this.onChanged,
  });

  final String? target;
  final List<Character> characters;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return DropdownButton<String?>(
      value: target,
      underline: const SizedBox.shrink(),
      style: Theme.of(context).textTheme.bodyMedium,
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(l10n.chatGeneral)),
        for (final c in characters)
          DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
      ],
      onChanged: (v) => onChanged(v),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.needSession, required this.onRetry});

  final bool needSession;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    return Center(
      child: AppEmptyState(
        icon: Icons.chat_bubble_outline,
        title: needSession ? l10n.chatNeedSession : l10n.chatEmpty,
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.nameOf});

  final ChatMessage message;
  final Map<String, String> nameOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    final mine = message.isDm;
    final name = message.isDm
        ? l10n.chatDm
        : message.fromName.isEmpty
        ? (message.fromCharacterId ?? '?')
        : message.fromName;
    // DM'e ozel mesajin hedefi bir karakter DEGIL; adi dogrudan "DM".
    final targetName = message.toDm
        ? l10n.chatDm
        : message.toCharacterId == null
        ? null
        : nameOf[message.toCharacterId] ?? message.toCharacterId;

    // Fısıltıyı (kimden kime gittiği) küçük bir satır olarak üstte gösterir.
    final whisperLine = message.isWhisper
        ? Text(
            '${l10n.chatWhisper}: ${targetName ?? '?'}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.tertiary,
              fontStyle: FontStyle.italic,
            ),
          )
        : null;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: mine
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
        children: [
          ?whisperLine,
          Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontStyle: message.isWhisper
                  ? FontStyle.italic
                  : FontStyle.normal,
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
