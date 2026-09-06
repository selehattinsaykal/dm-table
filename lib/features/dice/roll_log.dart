import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/rules/dice.dart';

/// Oturum boyunca atilan zarlarin kaydi.
///
/// **Neden bellekte, veritabaninda degil:** gunluk yalnizca "az once ne
/// gelmisti?" sorusunu cevapliyor. Kalici olsaydi kampanya dosyasi her
/// seansta binlerce satirla buyurdu ve gecen haftanin atisi masada hicbir ise
/// yaramazdi. Kalici olmasi gereken seyler (XP odulu, olay notu) zaten
/// oturum gunlugune (`SessionLogEntries`) yaziliyor.
///
/// Eskiden bu liste LAN sunucusunda dururdu (oyuncu panelleriyle ortak).
/// Sunucu kalkinca kayit DM'in kendi tarafina tasindi.
class RollLog extends Notifier<List<DiceRoll>> {
  /// Kac atis saklanir. Masada geriye donup bakilan sey son birkac atis;
  /// sinirsiz liste yalnizca bellegi ve kaydirma cubugunu buyuturdu.
  static const capacity = 50;

  @override
  List<DiceRoll> build() => const [];

  /// En yeni atis SONA eklenir; gosterim tarafi ters cevirir.
  void add(DiceRoll roll) {
    final next = [...state, roll];
    state = next.length <= capacity
        ? next
        : next.sublist(next.length - capacity);
  }

  void clear() => state = const [];
}

final rollLogProvider = NotifierProvider<RollLog, List<DiceRoll>>(RollLog.new);
