import 'package:dm_table/features/codex/codex_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kayitlar yazarken otomatik tamamlama cozumlemesi (saf mantik).
void main() {
  group('codexActiveSuggestion', () {
    test('kapanmamis [[ wiki tetigini bulur', () {
      final s = codexActiveSuggestion('bak [[Ejder', 11);
      expect(s?.kind, CodexSuggestKind.wiki);
      expect(s?.start, 4);
      expect(s?.query, 'Ejder');
    });

    test('bos [[ tum sayfalari tetikler', () {
      final s = codexActiveSuggestion('git [[', 6);
      expect(s?.kind, CodexSuggestKind.wiki);
      expect(s?.query, '');
    });

    test('kapali ]] sonrasi tetik yok', () {
      expect(codexActiveSuggestion('[[Yuva]] devam', 14), isNull);
    });

    test('satir basindaki slash tetigi', () {
      final s = codexActiveSuggestion('/mon', 4);
      expect(s?.kind, CodexSuggestKind.slash);
      expect(s?.start, 0);
      expect(s?.query, 'mon');
    });

    test('bosluktan sonra slash tetigi', () {
      final s = codexActiveSuggestion('at /r', 5);
      expect(s?.kind, CodexSuggestKind.slash);
      expect(s?.start, 3);
      expect(s?.query, 'r');
    });

    test('kelime ortasindaki slash (a/b) tetiklemez', () {
      expect(codexActiveSuggestion('a/b', 3), isNull);
    });

    test('imlec tetigin oncesindeyse yok sayilir', () {
      // imlec 3'te: "bak" — [[ henuz yazilmadi.
      expect(codexActiveSuggestion('bak [[Ejder', 3), isNull);
    });
  });

  group('codexApplyWiki', () {
    test('[[kismi]] araligini secilen baslikla degistirir', () {
      // "bak [[Ejder" -> baslik "Ejderha Yuvasi"
      final v = codexApplyWiki('bak [[Ejder', 4, 11, 'Ejderha Yuvası');
      expect(v.text, 'bak [[Ejderha Yuvası]]');
      expect(v.selection.baseOffset, v.text.length);
    });

    test('metnin ortasinda calisir, kalani korur', () {
      final v = codexApplyWiki('bak [[Ej burada', 4, 8, 'Ejder');
      expect(v.text, 'bak [[Ejder]] burada');
    });
  });

  group('codexApplySlash', () {
    test('parantezli komutta imlec parantez icine gelir', () {
      final opt = codexSlashOptions.firstWhere(
        (o) => o.template == '/character()',
      );
      final v = codexApplySlash('/char', 0, 5, opt);
      expect(v.text, '/character()');
      expect(v.selection.baseOffset, '/character('.length);
      // Imlecin hemen sagi kapanis parantezi olmali.
      expect(v.text[v.selection.baseOffset], ')');
    });

    test('/r sablonu imleci sona koyar', () {
      final opt = codexSlashOptions.firstWhere((o) => o.template == '/r');
      final v = codexApplySlash('at /', 3, 4, opt);
      expect(v.text, 'at /r');
      expect(v.selection.baseOffset, v.text.length);
    });
  });

  group('CodexInlineField widget', () {
    testWidgets('[[ yazinca eslesen sayfa onerisi cikar ve secilir', (
      tester,
    ) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexInlineField(
              controller: controller,
              pageTitles: const ['Ejderha Yuvası', 'Şehir'],
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'bak [[Ejder');
      await tester.pump();

      expect(find.text('Ejderha Yuvası'), findsOneWidget);
      await tester.tap(find.text('Ejderha Yuvası'));
      await tester.pump();

      expect(controller.text, 'bak [[Ejderha Yuvası]]');
    });

    testWidgets('Tab secili oneriyi ekler', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexInlineField(
              controller: controller,
              pageTitles: const ['Ejderha Yuvası', 'Şehir'],
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'git [[');
      await tester.pump();
      // Secili (ilk) oneri: 'Ejderha Yuvası'.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.text, 'git [[Ejderha Yuvası]]');
    });

    testWidgets('ok tusu secimi degistirir, Tab onu ekler', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexInlineField(
              controller: controller,
              pageTitles: const ['Ejderha Yuvası', 'Şehir'],
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '[[');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown); // 2. oneriye gec
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(controller.text, '[[Şehir]]');
    });

    testWidgets('/ yazinca slash komutlari onerilir', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodexInlineField(
              controller: controller,
              pageTitles: const [],
              autofocus: true,
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '/mon');
      await tester.pump();

      expect(find.text('/monster(…)'), findsOneWidget);
      await tester.tap(find.text('/monster(…)'));
      await tester.pump();

      expect(controller.text, '/monster()');
    });
  });
}
