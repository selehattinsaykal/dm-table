/// Olum kurtarma atislari.
///
/// Kural (2024 PHB): 0 can. Her tur d20. 10+ basari, 9- basarisizlik.
/// Dogal 20 dogrudan 1 canla ayaga kaldirir; dogal 1 IKI basarisizlik sayar.
/// Uc basari stabil, uc basarisizlik olum. 0 candayken alinan her hasar bir
/// basarisizlik, kritik vurus IKI basarisizlik.
library;

/// Sayacin durumu.
enum DeathSaveState {
  /// Henuz karara baglanmadi.
  pending,

  /// Uc basari: stabil, artik atmiyor.
  stable,

  /// Dogal 20: 1 canla ayakta.
  revived,

  /// Uc basarisizlik.
  dead,
}

/// Bir sayac anlik goruntusu.
typedef DeathSaves = ({int successes, int failures});

const DeathSaves emptyDeathSaves = (successes: 0, failures: 0);

/// Bir atisin sonucunu sayaca isler.
///
/// [roll] ham d20 sonucu (1..20). [modifier] varsayilan 0: 5e'de olum
/// kurtarmasi modifiersiz atilir ama bazi ozellikler bonus veriyor, o yuzden
/// disari acik.
({DeathSaves saves, DeathSaveState state}) rollDeathSave(
  DeathSaves current,
  int roll, {
  int modifier = 0,
}) {
  // Dogal 20/1 HAM zara bakar; modifier onlari degistirmez.
  if (roll == 20) {
    return (saves: emptyDeathSaves, state: DeathSaveState.revived);
  }

  var successes = current.successes;
  var failures = current.failures;

  if (roll == 1) {
    failures += 2;
  } else if (roll + modifier >= 10) {
    successes += 1;
  } else {
    failures += 1;
  }

  return _settle((successes: successes, failures: failures));
}

/// 0 candayken hasar almanin sonucu.
///
/// Kural: her vurus bir basarisizlik, KRITIK vurus iki. Ayrica gelen hasar
/// azami cani asiyorsa yaratik dogrudan olur -- o kontrol cagiran tarafta
/// (can/azami can bilgisi burada yok).
({DeathSaves saves, DeathSaveState state}) damageWhileDown(
  DeathSaves current, {
  bool critical = false,
}) => _settle((
  successes: current.successes,
  failures: current.failures + (critical ? 2 : 1),
));

/// Iyilesen ya da stabilize edilen yaratigin sayaci sifirlanir.
DeathSaves resetDeathSaves() => emptyDeathSaves;

/// Sayaci sinirlara oturtur ve durumu belirler.
({DeathSaves saves, DeathSaveState state}) _settle(DeathSaves raw) {
  final successes = raw.successes > 3 ? 3 : raw.successes;
  final failures = raw.failures > 3 ? 3 : raw.failures;
  final saves = (successes: successes, failures: failures);

  // Olum once bakilir: ayni atista hem uc basari hem uc basarisizliga
  // ulasmak mumkun degil, ama bozuk bir kayit ikisini birden tasiyorsa
  // daha kotu sonucu gostermek dogru olan.
  if (failures >= 3) return (saves: saves, state: DeathSaveState.dead);
  if (successes >= 3) return (saves: saves, state: DeathSaveState.stable);
  return (saves: saves, state: DeathSaveState.pending);
}

/// Mevcut sayaca gore durum (atis yapmadan okumak icin).
DeathSaveState deathSaveState(DeathSaves saves) => _settle(saves).state;
