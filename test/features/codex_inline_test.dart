import 'package:dm_table/features/codex/codex_inline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CodexInlineToken _t(CodexInlineKind k, String s) => CodexInlineToken(k, s);

/// Satir-ici bicimlendirme cozumleyici: **kalin**, *italik*, `kod`, [[wiki]].
void main() {
  test('duz metin tek parca', () {
    expect(tokenizeCodexInline('sadece metin'), [
      _t(CodexInlineKind.plain, 'sadece metin'),
    ]);
  });

  test('kalin/italik/kod', () {
    expect(tokenizeCodexInline('a **b** c'), [
      _t(CodexInlineKind.plain, 'a '),
      _t(CodexInlineKind.bold, 'b'),
      _t(CodexInlineKind.plain, ' c'),
    ]);
    expect(tokenizeCodexInline('*i*'), [_t(CodexInlineKind.italic, 'i')]);
    expect(tokenizeCodexInline('`kod`'), [_t(CodexInlineKind.code, 'kod')]);
  });

  test('wiki baglantisi', () {
    expect(tokenizeCodexInline('bak [[Ejderha Yuvası]] burada'), [
      _t(CodexInlineKind.plain, 'bak '),
      _t(CodexInlineKind.wiki, 'Ejderha Yuvası'),
      _t(CodexInlineKind.plain, ' burada'),
    ]);
  });

  test('karisik', () {
    expect(tokenizeCodexInline('**kalın** ve *italik* ve [[Sayfa]]'), [
      _t(CodexInlineKind.bold, 'kalın'),
      _t(CodexInlineKind.plain, ' ve '),
      _t(CodexInlineKind.italic, 'italik'),
      _t(CodexInlineKind.plain, ' ve '),
      _t(CodexInlineKind.wiki, 'Sayfa'),
    ]);
  });

  test('slash zar komutu', () {
    expect(tokenizeCodexInline('at /r1d20 hadi'), [
      _t(CodexInlineKind.plain, 'at '),
      _t(CodexInlineKind.roll, '1d20'),
      _t(CodexInlineKind.plain, ' hadi'),
    ]);
    expect(tokenizeCodexInline('/r1d10+5'), [
      _t(CodexInlineKind.roll, '1d10+5'),
    ]);
  });

  test('slash referans komutlari', () {
    expect(tokenizeCodexInline('/character(Felegor Ard Flamen)'), [
      _t(CodexInlineKind.characterRef, 'Felegor Ard Flamen'),
    ]);
    expect(tokenizeCodexInline('bak /monster(Goblin) ve /spell(Fireball)'), [
      _t(CodexInlineKind.plain, 'bak '),
      _t(CodexInlineKind.monsterRef, 'Goblin'),
      _t(CodexInlineKind.plain, ' ve '),
      _t(CodexInlineKind.spellRef, 'Fireball'),
    ]);
    expect(tokenizeCodexInline('/item(Longsword)'), [
      _t(CodexInlineKind.itemRef, 'Longsword'),
    ]);
  });

  test('link: /link(url)(kelime)', () {
    expect(tokenizeCodexInline('bak /link(https://a.b)(Tıkla) burada'), [
      _t(CodexInlineKind.plain, 'bak '),
      const CodexInlineToken(
        CodexInlineKind.link,
        'https://a.b',
        label: 'Tıkla',
      ),
      _t(CodexInlineKind.plain, ' burada'),
    ]);
  });

  test('page: /page(Başlık)(kelime)', () {
    expect(tokenizeCodexInline('/page(Ejderha Yuvası)(oraya git)'), [
      const CodexInlineToken(
        CodexInlineKind.pageRef,
        'Ejderha Yuvası',
        label: 'oraya git',
      ),
    ]);
  });

  test('link ile /r birlikte', () {
    expect(tokenizeCodexInline('/link(x)(y) /r1d6'), [
      const CodexInlineToken(CodexInlineKind.link, 'x', label: 'y'),
      _t(CodexInlineKind.plain, ' '),
      _t(CodexInlineKind.roll, '1d6'),
    ]);
  });

  test('slash + bicim birlikte', () {
    expect(tokenizeCodexInline('**Boss** /r2d6+3'), [
      _t(CodexInlineKind.bold, 'Boss'),
      _t(CodexInlineKind.plain, ' '),
      _t(CodexInlineKind.roll, '2d6+3'),
    ]);
  });

  test('bos metin bos liste', () {
    expect(tokenizeCodexInline(''), isEmpty);
  });

  test('markup olmadan duz', () {
    expect(tokenizeCodexInline('a + b = c'), [
      _t(CodexInlineKind.plain, 'a + b = c'),
    ]);
  });

  // buildCodexInline widget kurucusu (tablo hucreleri dahil tum bloklar kullanir)
  group('buildCodexInline', () {
    testWidgets('kalin metin bold span olarak cizilir', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildCodexInline(context, 'ad **HP** 12'),
            ),
          ),
        ),
      );
      final richText = tester.widget<RichText>(find.byType(RichText).first);
      final bold = <String>[];
      richText.text.visitChildren((span) {
        if (span is TextSpan &&
            span.text != null &&
            span.style?.fontWeight == FontWeight.bold) {
          bold.add(span.text!);
        }
        return true;
      });
      expect(bold, ['HP']);
    });

    testWidgets('wiki parcasi dokununca onTap cagirir', (tester) async {
      CodexInlineToken? tapped;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildCodexInline(
                context,
                'bak [[Yuva]]',
                onTap: (t) => tapped = t,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Yuva'));
      expect(tapped, _t(CodexInlineKind.wiki, 'Yuva'));
    });

    testWidgets(
      'link gorunen kelimeyi cizer, url degil; dokununca link token',
      (tester) async {
        CodexInlineToken? tapped;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => buildCodexInline(
                  context,
                  'ayrinti /link(https://ornek.com)(Tıkla)',
                  onTap: (t) => tapped = t,
                ),
              ),
            ),
          ),
        );
        expect(find.text('Tıkla'), findsOneWidget);
        expect(find.textContaining('https://ornek.com'), findsNothing);
        await tester.tap(find.text('Tıkla'));
        expect(tapped?.kind, CodexInlineKind.link);
        expect(tapped?.text, 'https://ornek.com');
      },
    );

    testWidgets('onTap null iken zar cipi tiklanamaz (duzenleme modu)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => buildCodexInline(context, '/r1d20'),
            ),
          ),
        ),
      );
      final inkWell = tester.widget<InkWell>(find.byType(InkWell).first);
      expect(inkWell.onTap, isNull);
    });
  });
}
