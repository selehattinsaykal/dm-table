/// Takvim hatırlatıcılarının saf tekrar matematiği.
///
/// Drift/Flutter bilmez; [GameMonth] listesi dışında hiçbir şeye bağlı değil.
/// Takvimin yapısı kampanyaya göre değiştiği için (ay sayısı, ay uzunlukları)
/// tekrar hesabı burada tek yerde durur.
library;

import 'game_calendar.dart';

/// Bir hatırlatıcının tekrar biçimi.
///
/// Veritabanında **kod** olarak saklanır (enum indeksi değil): araya yeni tür
/// eklemek eski satırların anlamını kaydırmasın.
enum ReminderRepeat {
  /// Tek seferlik; tetiklenince kapanır.
  once('once'),

  /// Her N günde bir (N >= 1).
  everyNDays('everyNDays'),

  /// Her ayın aynı gününde. Ay o güne kadar sürmüyorsa (kısa ay) **ayın son
  /// gününe çekilir** — atlanmaz; "her ayın 30'u" kaydı 28 günlük bir ayda
  /// sessizce kaybolmamalı.
  monthly('monthly'),

  /// Her yıl aynı ay + gün.
  yearly('yearly');

  const ReminderRepeat(this.code);

  final String code;

  static ReminderRepeat fromCode(String code) => ReminderRepeat.values
      .firstWhere((r) => r.code == code, orElse: () => ReminderRepeat.once);
}

/// Tekrar hesabı için gereken en az bilgi (Drift satırından bağımsız).
typedef ReminderSpec = ({
  ReminderRepeat repeat,
  int everyNDays,
  GameDate start,
});

/// [spec]'in `(fromDay, toDay]` aralığına düşen tetiklenme günleri.
///
/// Alt sınır **hariç**, üst sınır **dahil**: gün ilerletme "dün geceden bugüne"
/// mantığıyla çalışıyor; içinde bulunulan gün iki kez saymamalı.
/// Sonuç artan sırada ve sınırlıdır ([maxOccurrences]) — bozuk bir periyot ya
/// da çok uzun bir yolculuk arayüzü kilitlemesin.
List<int> occurrencesBetween(
  ReminderSpec spec,
  List<GameMonth> months, {
  required int fromDay,
  required int toDay,
  int maxOccurrences = 200,
}) {
  if (toDay <= fromDay) return const [];
  final startDay = absoluteDay(spec.start, months);
  final out = <int>[];

  switch (spec.repeat) {
    case ReminderRepeat.once:
      if (startDay > fromDay && startDay <= toDay) out.add(startDay);

    case ReminderRepeat.everyNDays:
      final step = spec.everyNDays < 1 ? 1 : spec.everyNDays;
      // İlk tetiklenme baslangictan ONCE olamaz.
      var day = startDay;
      if (day <= fromDay) {
        // Kac adim atlanacagi dogrudan hesaplanir; gun gun dongu, 10 yillik
        // bir sicramada yuz binlerce tur donerdi.
        final skipped = ((fromDay - day) ~/ step) + 1;
        day += skipped * step;
      }
      while (day <= toDay && out.length < maxOccurrences) {
        out.add(day);
        day += step;
      }

    case ReminderRepeat.monthly:
      if (months.isEmpty) break;
      var date = fromAbsoluteDay(fromDay, months);
      // fromDay HARIC oldugu icin bir sonraki gunden basla.
      date = advance(date, 1, months);
      var monthIndex = date.monthIndex;
      var year = date.year;
      while (out.length < maxOccurrences) {
        final day = spec.start.day.clamp(1, daysInMonth(months, monthIndex));
        final abs = absoluteDay((
          year: year,
          monthIndex: monthIndex,
          day: day,
        ), months);
        if (abs > toDay) break;
        if (abs > fromDay && abs >= startDay) out.add(abs);
        monthIndex++;
        if (monthIndex >= months.length) {
          monthIndex = 0;
          year++;
        }
      }

    case ReminderRepeat.yearly:
      if (months.isEmpty) break;
      final length = daysInYear(months);
      if (length < 1) break;
      var year = fromAbsoluteDay(fromDay, months).year;
      // Bir yil geriden basla: yil sonuna yakin bir capa, fromDay'in yilinda
      // zaten gecmis olabilir ama bir sonraki yilda araliga dusebilir.
      year -= 1;
      while (out.length < maxOccurrences) {
        final abs = absoluteDay((
          year: year,
          monthIndex: spec.start.monthIndex,
          day: spec.start.day,
        ), months);
        if (abs > toDay) break;
        if (abs > fromDay && abs >= startDay) out.add(abs);
        year++;
      }
  }

  return out;
}

/// [spec]'in [afterDay]'den SONRAKİ ilk tetiklenmesi; yoksa `null`.
///
/// Listede "sıradaki: 12 Hasat" göstermek için. Tek seferlik ve geçmiş bir
/// kayıt `null` döner.
int? nextOccurrence(
  ReminderSpec spec,
  List<GameMonth> months, {
  required int afterDay,
}) {
  // Bir yildan uzun araliklarda bile bir sonuc bulunsun diye pencere genis
  // tutuluyor; everyNDays cok buyuk olursa yine null doner (dogru davranis:
  // "ongorulebilir bir gelecekte yok").
  final year = daysInYear(months);
  final window = year < 1 ? 3650 : year * 5;
  final hits = occurrencesBetween(
    spec,
    months,
    fromDay: afterDay,
    toDay: afterDay + window,
    maxOccurrences: 1,
  );
  return hits.isEmpty ? null : hits.first;
}
