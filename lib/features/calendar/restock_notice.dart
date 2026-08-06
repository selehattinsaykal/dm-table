import 'package:flutter/material.dart';

import '../../data/reminder_repository.dart';
import '../../l10n/app_localizations.dart';
import 'calendar_providers.dart';

/// Gün ilerledikten sonra DM'e "bu arada ne oldu" bildirir: stoğu yenilenen
/// mağazalar + tetiklenen takvim hatırlatıcıları.
///
/// Olay yoksa sessiz kalır — her gün ilerletmede "hiçbir şey olmadı" demek
/// gürültü olurdu.
///
/// Günü ilerleten yerlerin hepsi (takvim sayfası, parti molası, yolculuk) aynı
/// bildirimi versin diye ortak: yenilemenin/hatırlatıcının sessizce geçmesi
/// DM'in habersiz kalmasına yol açıyordu.
void showRestockNotice(BuildContext context, GameDayAdvance result) =>
    showRestockNoticeWith(
      ScaffoldMessenger.of(context),
      L10n.of(context),
      result.restockedShops,
      reminders: result.reminders,
    );

/// Aynı bildirimin önceden yakalanmış messenger/L10n ile hâli.
///
/// Bildirimi gösteren ekranın kendisi kapanıyorsa ([BuildContext] artık
/// geçerli değilken) bu kullanılır — SnackBar `ScaffoldMessenger`'a ait olduğu
/// için kapanan sayfadan sonra da görünür.
void showRestockNoticeWith(
  ScaffoldMessengerState messenger,
  L10n l10n,
  List<String> restockedShops, {
  List<DueReminder> reminders = const [],
}) {
  // Hatırlatıcı önce: DM'in olay örgüsünü ilgilendiren şey bu, stok ikincil.
  if (reminders.isNotEmpty) {
    final titles = reminders.map((r) => r.reminder.title).toSet().toList();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(l10n.reminderFired(titles.join(' · '))),
      ),
    );
  }
  if (restockedShops.isEmpty) return;
  messenger.showSnackBar(
    SnackBar(content: Text(l10n.shopRestocked(restockedShops.join(', ')))),
  );
}
