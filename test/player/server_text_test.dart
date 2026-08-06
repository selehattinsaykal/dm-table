import 'package:dm_table/app/app_settings.dart';
import 'package:dm_table/net/protocol.dart';
import 'package:dm_table/player/player_strings.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sunucu -> oyuncu mesajlari: kodlama/cozme ve istemci tarafi ceviri.
void main() {
  test('encode/decode round-trip (argumanli ve argumansiz)', () {
    final noArgs = encodeServerMsg('needCharacter');
    expect(decodeServerMsg(noArgs)!.code, 'needCharacter');
    expect(decodeServerMsg(noArgs)!.args, isEmpty);

    final withArgs = encodeServerMsg('claimedBy', ['Ali']);
    final d = decodeServerMsg(withArgs)!;
    expect(d.code, 'claimedBy');
    expect(d.args, ['Ali']);
  });

  test('ham (DM serbest) metin kod degildir', () {
    expect(decodeServerMsg('Merhaba millet'), isNull);
  });

  test('serverText kodlu mesaji secili dile cevirir', () {
    const tr = PlayerL10n(AppLang.tr);
    const en = PlayerL10n(AppLang.en);
    final msg = encodeServerMsg('claimedBy', ['Ali']);

    expect(tr.serverText(msg), 'Bu karakteri Ali almış.');
    expect(en.serverText(msg), 'Ali has already claimed this character.');
  });

  test('serverText ham DM metnini oldugu gibi birakir', () {
    const en = PlayerL10n(AppLang.en);
    expect(en.serverText('Toplanın millet!'), 'Toplanın millet!');
  });

  test('healthLabel kodlari cevrilir', () {
    const tr = PlayerL10n(AppLang.tr);
    const en = PlayerL10n(AppLang.en);
    expect(tr.healthLabel('bloodied'), 'Ağır yaralı');
    expect(en.healthLabel('bloodied'), 'Bloodied');
  });

  test('bilinmeyen kod aynen doner (guvenli varsayilan)', () {
    const en = PlayerL10n(AppLang.en);
    expect(en.serverText(encodeServerMsg('someFutureCode')), 'someFutureCode');
  });
}
