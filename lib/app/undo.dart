import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';

/// Geri alinabilir tek bir islem.
///
/// Geri alma, degisikligi TERSINE CEVIREN bir kapanis (closure) tasiyor;
/// veritabaninin eski halini kopyalamiyor. Sebep: bu uygulamada yikici
/// islemlerin cogu tek satirlik (bir katilimci silindi, bir XP verildi) ve
/// o satirin eski degerini kapanista tutmak, her tablo icin anlik goruntu
/// almaktan hem ucuz hem de dogru.
class UndoEntry {
  UndoEntry({required this.label, required this.undo}) : at = DateTime.now();

  /// Kullaniciya gosterilen ad: "Katilimci silindi", "12 hasar".
  final String label;

  /// Islemi geri alan is. Basarisiz olursa yigin kilitlenmesin diye
  /// [UndoController.undo] hatayi yutuyor.
  final Future<void> Function() undo;

  final DateTime at;
}

/// Uygulama geneli geri alma yigini.
///
/// Yalnizca OTURUM boyunca yasiyor (diske yazilmiyor): uygulamayi kapatip
/// acinca geri alinabilir bir gecmis olmasi beklentisi yaratmak, o gecmisin
/// tutarli oldugunu garanti etmek anlamina gelirdi ve etmiyor -- arada
/// kaydin kendisini degistiren baska islemler olabiliyor.
class UndoController extends Notifier<List<UndoEntry>> {
  /// Yigin siniri. Daha uzunu masada kimsenin hatirlamadigi bir gecmis.
  static const maxDepth = 30;

  @override
  List<UndoEntry> build() => const [];

  /// Yeni bir geri alinabilir islem kaydeder.
  void push(String label, Future<void> Function() undo) {
    final next = [UndoEntry(label: label, undo: undo), ...state];
    state = next.length > maxDepth ? next.sublist(0, maxDepth) : next;
  }

  UndoEntry? get top => state.isEmpty ? null : state.first;

  /// En son islemi geri alir; yigin bossa null doner.
  Future<UndoEntry?> undo() async {
    if (state.isEmpty) return null;
    final entry = state.first;
    state = state.sublist(1);
    try {
      await entry.undo();
    } on Object {
      // Geri alinamayan islem (arada kayit silinmis olabilir) yigini
      // kilitlemesin; sessizce dusuyor.
      return null;
    }
    return entry;
  }

  void clear() => state = const [];
}

final undoControllerProvider =
    NotifierProvider<UndoController, List<UndoEntry>>(UndoController.new);

/// `Ctrl+Z` / `Cmd+Z` kisayolunu kabugun ETRAFINA baglar.
///
/// Komut paletiyle ayni yerde duruyor: kisayol her sekmede gecerli olsun,
/// her sayfa kendi bagini kurmak zorunda kalmasin.
class UndoShortcut extends ConsumerWidget {
  const UndoShortcut({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> run() async {
      final messenger = ScaffoldMessenger.maybeOf(context);
      final l10n = L10n.of(context);
      final entry = await ref.read(undoControllerProvider.notifier).undo();
      if (entry == null) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(l10n.undoDone(entry.label)),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): run,
        const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): run,
      },
      child: child,
    );
  }
}

/// Ray basindaki geri alma dugmesi.
///
/// Yigin bosken SOLGUN ama gorunur duruyor: ozelligin var oldugunu
/// bilmenin tek yolu bu. Dokunmatikte klavye kisayoluna erisim olmadigi
/// icin de gerekli.
///
/// Uzun bas / sag tik: son islemlerin listesi. Listeden secmek O NOKTAYA
/// KADAR geri aliyor (tek tek degil), cunku araya giren islemleri
/// atlayarak geri almak tutarsiz bir duruma yol acardi.
class UndoRailButton extends ConsumerWidget {
  const UndoRailButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final entries = ref.watch(undoControllerProvider);
    final controller = ref.read(undoControllerProvider.notifier);
    final top = entries.isEmpty ? null : entries.first;

    Future<void> undoOne() async {
      final messenger = ScaffoldMessenger.of(context);
      final entry = await controller.undo();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            entry == null ? l10n.undoNothing : l10n.undoDone(entry.label),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }

    return GestureDetector(
      onSecondaryTap: entries.isEmpty ? null : () => _showHistory(context, ref),
      onLongPress: entries.isEmpty ? null : () => _showHistory(context, ref),
      child: IconButton(
        tooltip: top == null
            ? l10n.undoNothing
            : '${l10n.undoTitle}: ${top.label}  (Ctrl+Z)',
        icon: const Icon(Icons.undo),
        onPressed: entries.isEmpty ? null : undoOne,
      ),
    );
  }

  static Future<void> _showHistory(BuildContext context, WidgetRef ref) async {
    final l10n = L10n.of(context);
    final entries = ref.read(undoControllerProvider);
    final controller = ref.read(undoControllerProvider.notifier);

    final index = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(l10n.undoHistory),
        children: [
          for (final (i, entry) in entries.indexed)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(entry.label),
            ),
        ],
      ),
    );
    if (index == null) return;

    // Secilen ADIMA KADAR geri al: aradakileri atlamak, birbirine bagli
    // islemlerde tutarsiz bir duruma yol acardi.
    for (var i = 0; i <= index; i++) {
      await controller.undo();
    }
  }
}
