/// Iki macera arasindaki bos zaman faaliyetleri.
///
/// Kural ozeti PHB/DMG'nin "downtime" bolumunden: her faaliyet gun harciyor,
/// bazilarinin gunluk maliyeti ya da kazanci var. Buradaki degerler yalnizca
/// HATIRLATMA -- uygulama hicbirini zorlamiyor, DM kendi masasinin kuralini
/// uyguluyor.
library;

/// Bir faaliyet turu.
enum DowntimeKind {
  /// Zanaat: gunde 5 gp'lik deger, malzeme maliyeti degerin yarisi.
  craft,

  /// Arastirma: gunde 1 gp gider, bir bilgi parcasi.
  research,

  /// Is bulma: gunde kazanc, yeterlilige bagli.
  work,

  /// Egitim: yeni bir dil ya da alet yeterliligi (250 gp, 10 hafta).
  train,

  /// Iyilesme: uc gunde bir hastalik/zehir kurtarma avantaji.
  recuperate,

  /// Alem: sosyal baglanti, komplikasyon riski.
  carouse,

  /// Serbest: DM'in kendi tanimladigi is.
  custom;

  static DowntimeKind fromName(String? name) {
    for (final kind in values) {
      if (kind.name == name) return kind;
    }
    return DowntimeKind.custom;
  }
}

/// Bir faaliyetin masaya hatirlatilacak ozeti.
typedef DowntimeRule = ({
  /// Onerilen en az gun sayisi.
  int minimumDays,

  /// Gunluk gider (bakir); 0 = yok.
  int costPerDayCp,

  /// Gunluk kazanc (bakir); 0 = yok.
  int gainPerDayCp,
});

/// Faaliyetin varsayilan degerleri.
///
/// Bakir uzerinden tutuluyor cunku uygulamanin para birimi bakir
/// (`coinsCp`); gp'yi burada bir kez cevirmek, her cagiranin cevirmesinden
/// guvenli.
DowntimeRule downtimeRule(DowntimeKind kind) => switch (kind) {
  // Zanaat: gunde 5 gp deger uretir, malzemesi yarisi kadar.
  DowntimeKind.craft => (minimumDays: 1, costPerDayCp: 250, gainPerDayCp: 500),
  DowntimeKind.research => (minimumDays: 1, costPerDayCp: 100, gainPerDayCp: 0),
  // Is bulma: yeterlilige gore degisiyor, orta deger 1 gp/gun.
  DowntimeKind.work => (minimumDays: 1, costPerDayCp: 0, gainPerDayCp: 100),
  // Egitim: 10 hafta, 250 gp toplam -> gunde ~3.57 gp.
  DowntimeKind.train => (minimumDays: 70, costPerDayCp: 357, gainPerDayCp: 0),
  DowntimeKind.recuperate => (minimumDays: 3, costPerDayCp: 0, gainPerDayCp: 0),
  // Alem: yasam tarzina gore; orta duzey icin gunde 1 gp.
  DowntimeKind.carouse => (minimumDays: 1, costPerDayCp: 100, gainPerDayCp: 0),
  DowntimeKind.custom => (minimumDays: 1, costPerDayCp: 0, gainPerDayCp: 0),
};

/// Faaliyetin toplam gider/kazanc dengesini hesaplar (bakir).
///
/// Pozitif sonuc kazanc, negatif gider.
int downtimeNetCp(DowntimeKind kind, int days) {
  final rule = downtimeRule(kind);
  final span = days < 1 ? 1 : days;
  return (rule.gainPerDayCp - rule.costPerDayCp) * span;
}

/// Faaliyetin bittigi oyun-ici gun.
int downtimeEndDay(int startDay, int days) => startDay + (days < 1 ? 1 : days);

/// [today] gununde kac gun kaldigi; bittiyse 0.
int downtimeRemaining({
  required int startDay,
  required int days,
  required int today,
}) {
  final end = downtimeEndDay(startDay, days);
  final left = end - today;
  return left < 0 ? 0 : left;
}
