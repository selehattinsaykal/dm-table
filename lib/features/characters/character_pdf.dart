import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/db/database.dart';
import '../../domain/models/ability.dart';
import '../../domain/models/character_build.dart';
import '../../domain/rules/character_math.dart';

/// Karakter kagidini yazdirilabilir bir PDF'e cevirir.
///
/// **Neden var:** masaya kagit getirmek isteyen oyuncu icin. Ekran
/// goruntusu almak kagidin yarisini kesiyor, uygulamanin kendi duzeni de
/// A4'e gore degil.
///
/// Saf `pdf` paketi kullaniliyor (yerel eklenti YOK): cikti bayt dizisi
/// olarak donuyor, dosyaya yazmayi cagiran yapiyor. Boylece Windows'ta
/// yazici surucusune bagimlilik olusmuyor ve ayni kod her platformda
/// calisiyor.
Future<List<int>> buildCharacterPdf({
  required Character character,
  required CharacterBuild build,
  String? className,
  String? speciesName,
  String? backgroundName,
}) async {
  // GOMULU FONT ZORUNLU. PDF'in yerlesik Helvetica'si WinAnsi kodlamasi
  // kullaniyor ve Turkce harflerin cogu (s, g, i, I, o, c) orada YOK;
  // paket onlarin yerine capraz cizgili bir kutu ciziyordu. Yani "Sehmuz"
  // yazan bir kagit "[ ]eyhmuz" olarak cikiyordu.
  //
  // EB Garamond zaten uygulamanin okuma fontu ve Latin + Turkce kapsamina
  // ALTKUMELENMIS (bkz. pubspec) -- ek bir varlik yuku getirmiyor.
  final doc = pw.Document(theme: await _theme());

  pw.Widget box(String label, String value, {double width = 84}) =>
      pw.Container(
        width: width,
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 0.8),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 2),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
          ],
        ),
      );

  String signed(int value) => value >= 0 ? '+$value' : '$value';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        // --- Baslik
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    character.name,
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    [
                      ?speciesName,
                      ?className,
                      ?backgroundName,
                      'Lv ${build.totalLevel}',
                    ].join('  •  '),
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (character.playerName != null)
              pw.Text(
                character.playerName!,
                style: const pw.TextStyle(fontSize: 10),
              ),
          ],
        ),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),

        // --- Yetenek puanlari
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            for (final ability in Ability.values)
              box(
                ability.name.toUpperCase().substring(0, 3),
                '${build.abilities[ability]}'
                ' (${signed(build.abilityModifier(ability))})',
                width: 80,
              ),
          ],
        ),
        pw.SizedBox(height: 12),

        // --- Savas degerleri
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            box('AC', '${build.armorClass}'),
            box('Initiative', signed(build.initiative)),
            box('Speed', '${build.baseSpeed}'),
            box('Prof', signed(build.proficiencyBonus)),
            box(
              'HP',
              '${character.hitPointsCurrent}/${character.hitPointsMax}',
            ),
            box('Passive Per.', '${build.passivePerception}'),
          ],
        ),
        pw.SizedBox(height: 16),

        // --- Kurtarmalar + beceriler yan yana
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _section('Saving Throws', [
                for (final ability in Ability.values)
                  _line(
                    ability.name,
                    signed(build.savingThrow(ability)),
                    marked: build.saveProficiencies.contains(ability),
                  ),
              ]),
            ),
            pw.SizedBox(width: 16),
            pw.Expanded(
              flex: 2,
              child: _section('Skills', [
                for (final skill in Skill.values)
                  _line(
                    '${skill.label} (${skill.ability.name.substring(0, 3)})',
                    signed(build.skillModifier(skill)),
                    marked: build.skillProficiencies.contains(skill),
                    doubled: build.skillExpertise.contains(skill),
                  ),
              ]),
            ),
          ],
        ),
        pw.SizedBox(height: 16),

        // --- Kisilik: bos birakilmis alanlar YAZDIRILMIYOR, kagitta bos
        // baslik gorunmesin.
        if (character.personality.isNotEmpty)
          _text('Personality', character.personality),
        if (character.ideal.isNotEmpty) _text('Ideal', character.ideal),
        if (character.bond.isNotEmpty) _text('Bond', character.bond),
        if (character.flaw.isNotEmpty) _text('Flaw', character.flaw),
        if (character.appearance.isNotEmpty)
          _text('Appearance', character.appearance),
        if (character.notes.isNotEmpty) _text('Notes', character.notes),
      ],
    ),
  );

  return doc.save();
}

/// Gomulu fontu yukler; okunamazsa varsayilan temaya duser.
///
/// Font okunamamasi (varlik paketten dusmus, dosya bozuk) kagidin HIC
/// cikmamasina yol acmamali: Turkce olmayan bir kagit, kagit olmamasindan
/// iyidir.
Future<pw.ThemeData?> _theme() async {
  try {
    final data = await rootBundle.load('assets/fonts/EBGaramond.ttf');
    final font = pw.Font.ttf(data);
    return pw.ThemeData.withFont(base: font, bold: font, italic: font);
  } on Object {
    return null;
  }
}

pw.Widget _section(String title, List<pw.Widget> children) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 4),
    ...children,
  ],
);

pw.Widget _line(
  String label,
  String value, {
  bool marked = false,
  bool doubled = false,
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
  child: pw.Row(
    children: [
      // Yeterlilik daire, uzmanlik dolu daire: kagitta renk yok, isaret
      // sekille verilmeli.
      pw.Text(
        doubled ? '(o)' : (marked ? ' o ' : '   '),
        style: const pw.TextStyle(fontSize: 8),
      ),
      pw.SizedBox(width: 4),
      pw.Expanded(
        child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
      ),
      pw.Text(
        value,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    ],
  ),
);

pw.Widget _text(String title, String body) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 8),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(body, style: const pw.TextStyle(fontSize: 9)),
    ],
  ),
);
