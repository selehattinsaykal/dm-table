/// Kayitlar (Codex) bloklarinin ORTAK yerlesim ve gorunum jetonlari.
///
/// Bir blogun icerigi tur-ozel alanlarda (`text`, `items`, `path`...) durur;
/// burada tanimlananlar ise HER blokta gecerli olan "nasil gorunsun" alanlari:
/// genislik orani, hizalama, yukseklik ve ton. Hepsi ayni `dataJson` icinde
/// tasinir — semasiz oldugu icin veritabani gocu gerekmez.
///
/// Geriye donuk uyum: eski bloklarda bu alanlar yoktur ve tum varsayilanlar
/// eski davranisi birebir verir (tam genislik, sola yasli, otomatik yukseklik).
///
/// Bu katman saf Dart'tir (Flutter'a bagimli degil); Material karsiliklarina
/// donusum `features/codex/codex_style_ui.dart` icindedir.
library;

/// Blogun kullanilabilir genislik icindeki yatay hizasi.
enum CodexAlign {
  left,
  center,
  right;

  static CodexAlign fromName(Object? name) =>
      values.where((a) => a.name == name).firstOrNull ?? CodexAlign.left;
}

/// Bir blogun yerlesimi: genislik orani, hizalama ve istege bagli yukseklik.
///
/// [width] kullanilabilir genisligin orani (0.15–1.0). Boylece pencere
/// yeniden boyutlandiginda blok da oranini korur; sabit piksel genisligi
/// dar pencerelerde tasardi.
class CodexLayout {
  const CodexLayout({
    this.width = 1.0,
    this.align = CodexAlign.left,
    this.height,
  });

  /// Bir blogun inebilecegi en dar oran. Altinda tutamaklar tiklanamaz olur.
  static const double minWidth = 0.15;

  /// Yukseklik surukleyerek ayarlanabilen bloklar icin sinirlar (px).
  static const double minHeight = 80;
  static const double maxHeight = 1400;

  /// Kullanilabilir genisligin orani (0.15–1.0).
  final double width;

  final CodexAlign align;

  /// Sabit yukseklik (px). null ise icerik kendi yuksekligini belirler.
  final double? height;

  /// `dataJson` haritasindan okur. Bilinmeyen/bozuk degerler varsayilana duser.
  factory CodexLayout.fromData(
    Map<String, dynamic> data, {
    double defaultWidth = 1.0,
    CodexAlign defaultAlign = CodexAlign.left,
    double? defaultHeight,
  }) {
    final rawWidth = (data['width'] as num?)?.toDouble();
    final rawHeight = (data['height'] as num?)?.toDouble();
    return CodexLayout(
      width: clampWidth(rawWidth ?? defaultWidth),
      align: data.containsKey('align')
          ? CodexAlign.fromName(data['align'])
          : defaultAlign,
      height: rawHeight == null ? defaultHeight : clampHeight(rawHeight),
    );
  }

  /// Yalnizca yerlesim alanlarini iceren harita (blok verisine karistirilir).
  Map<String, dynamic> toData() => {
    'width': double.parse(width.toStringAsFixed(3)),
    'align': align.name,
    if (height != null) 'height': height!.roundToDouble(),
  };

  CodexLayout copyWith({
    double? width,
    CodexAlign? align,
    double? height,
    bool clearHeight = false,
  }) => CodexLayout(
    width: clampWidth(width ?? this.width),
    align: align ?? this.align,
    height: clearHeight
        ? null
        : (height == null ? this.height : clampHeight(height)),
  );

  bool get isFullWidth => width >= 0.999;

  static double clampWidth(double value) =>
      value.isNaN ? 1.0 : value.clamp(minWidth, 1.0);

  static double clampHeight(double value) =>
      value.isNaN ? minHeight : value.clamp(minHeight, maxHeight);

  @override
  bool operator ==(Object other) =>
      other is CodexLayout &&
      other.width == width &&
      other.align == align &&
      other.height == height;

  @override
  int get hashCode => Object.hash(width, align, height);

  @override
  String toString() =>
      'CodexLayout(w: $width, align: ${align.name}, h: $height)';
}

/// Grafik blogunun cizim turu.
enum CodexChartType {
  /// Yatay cubuklar — uzun etiketler icin en okunur olan.
  bar,

  /// Dikey sutunlar — az sayida kategoriyi karsilastirmak icin.
  column,

  /// Cizgi — sirali/zaman serisi (oturum basina XP gibi).
  line,

  /// Dolgulu cizgi.
  area,

  /// Pasta — parcanin butune orani.
  pie,

  /// Halka — pastanin ortasi bos, merkeze toplam yazilir.
  donut,

  /// Radar/orumcek agi — cok eksenli profil (yetenek puanlari gibi).
  radar,

  /// Tek satirda yigilmis %100 oran cubugu.
  stacked;

  static CodexChartType fromName(Object? name) =>
      values.where((t) => t.name == name).firstOrNull ?? CodexChartType.bar;
}

/// Grafik/sayac renk paleti. Tema jetonlarindan turetilir; sabit renk yok.
enum CodexPalette {
  /// Tema birincil rengi etrafinda tonlar.
  theme,

  /// Pirinc/altin — donemsel, sicak.
  brass,

  /// Ametist + patina + altin — yuksek ayrim gucu.
  jewel,

  /// Kor/mum muhru — uyari ve tehlike anlatan seriler.
  ember,

  /// Yosun/patina — dogal, sakin.
  forest,

  /// Tek renk tonlamasi — baski dostu, en sessiz.
  mono;

  static CodexPalette fromName(Object? name) =>
      values.where((p) => p.name == name).firstOrNull ?? CodexPalette.theme;
}

/// Ayrac blogunun cizgi bicimi.
enum CodexDividerStyle {
  /// Pirinc sus ayraci (uygulama kimligi).
  ornament,

  /// Duz ince cizgi.
  line,

  /// Kesik cizgi.
  dashed,

  /// Kalin dolu cizgi.
  thick,

  /// Uc nokta (bolum arasi nefes).
  dots,

  /// Yalnizca bosluk (gorunmez ayirici).
  space;

  static CodexDividerStyle fromName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull ??
      CodexDividerStyle.ornament;
}

/// Vurgu kutusu / metin tonu. Anlamli renk secimi (sabit renk yerine).
enum CodexTone {
  neutral,
  info,
  success,
  warning,
  danger,
  arcane,
  gold;

  static CodexTone fromName(Object? name) =>
      values.where((t) => t.name == name).firstOrNull ?? CodexTone.neutral;
}

/// Gorsel/videonun cerceveye oturma bicimi.
enum CodexMediaFit {
  /// Tamami gorunur (kirpilmaz).
  contain,

  /// Cerceveyi doldurur, tasan kisim kirpilir.
  cover,

  /// Orani bozarak doldurur.
  fill;

  static CodexMediaFit fromName(Object? name) =>
      values.where((f) => f.name == name).firstOrNull ?? CodexMediaFit.contain;
}

/// Sayac modulunun gosterim bicimi.
enum CodexCounterStyle {
  /// Etiket + eksi/arti + istege bagli oran cubugu (liste satiri).
  row,

  /// Buyuk rakamli kartlar (izgara).
  tile,

  /// Kompakt cipler (tek satirda cok sayac).
  chip;

  static CodexCounterStyle fromName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull ?? CodexCounterStyle.row;
}

/// Baglanti/zar gibi "tek dokunuslu" bloklarin gorunumu.
enum CodexChipStyle {
  /// Kucuk cip (varsayilan, satir arasi).
  chip,

  /// Genis dugme.
  button,

  /// Baslik + aciklama tasiyan kart.
  card;

  static CodexChipStyle fromName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull ?? CodexChipStyle.chip;
}

/// Sure sayacinin sayma yonu.
enum CodexTimerMode {
  /// Verilen sureden geriye sayar (tur suresi, mesalenin yanma suresi).
  countdown,

  /// Sifirdan yukari sayar (bir bolumun ne kadar surdugu).
  stopwatch;

  static CodexTimerMode fromName(Object? name) =>
      values.where((m) => m.name == name).firstOrNull ??
      CodexTimerMode.countdown;
}

/// Sure sayacinin gosterim bicimi.
enum CodexTimerStyle {
  /// Yalnizca buyuk rakamlar.
  digits,

  /// Rakam + kalan sureyi gosteren cubuk.
  bar,

  /// Rakam + halka (geri sayimda boyu kisalir).
  ring;

  static CodexTimerStyle fromName(Object? name) =>
      values.where((s) => s.name == name).firstOrNull ?? CodexTimerStyle.digits;
}

/// Sure sayacinin durumu.
///
/// Gecen sure HER SANIYE veritabanina yazilmaz: yalnizca [startedAt] (baslama
/// ani) ve duraklatilana kadar [accumulated] birikimi saklanir; anlik deger
/// bunlardan hesaplanir. Boylece sayfadan cikip donunce — hatta uygulama
/// yeniden acilinca — sayac dogru yerden devam eder ve saniyede bir yazma
/// yapilmaz.
class CodexTimer {
  const CodexTimer({
    this.mode = CodexTimerMode.countdown,
    this.duration = const Duration(minutes: 5),
    this.startedAt,
    this.accumulated = Duration.zero,
    this.style = CodexTimerStyle.digits,
    this.alarm = true,
    this.loop = false,
  });

  static const Duration minDuration = Duration(seconds: 1);
  static const Duration maxDuration = Duration(hours: 24);

  final CodexTimerMode mode;

  /// Geri sayimin hedef suresi (kronometrede yalnizca oran cubugu icin).
  final Duration duration;

  /// Sayac calisiyorsa son baslama ani; durmussa null.
  final DateTime? startedAt;

  /// Onceki calisma araliklarindan biriken sure.
  final Duration accumulated;

  final CodexTimerStyle style;

  /// Geri sayim bitince sesli/gorsel uyari.
  final bool alarm;

  /// Bitince kendiliginden yeniden baslasin mi (tur suresi icin).
  final bool loop;

  bool get isRunning => startedAt != null;

  Duration elapsedAt(DateTime now) {
    final since = startedAt == null
        ? Duration.zero
        : now.difference(startedAt!);
    final total = accumulated + (since.isNegative ? Duration.zero : since);
    return mode == CodexTimerMode.countdown && total > duration
        ? duration
        : total;
  }

  /// Geri sayimda kalan sure; kronometrede [Duration.zero].
  Duration remainingAt(DateTime now) => mode == CodexTimerMode.countdown
      ? duration - elapsedAt(now)
      : Duration.zero;

  /// Geri sayimin hedefi ne kadar once gectigi.
  ///
  /// [elapsedAt] hedefte KIRPILIR (ekranda "-00:12" gormek istemeyiz); bu ise
  /// kirpilmamis farktir. Uygulama kapaliyken coktan dolmus bir sayaci
  /// acilista duyurmamak icin gerekli.
  Duration overdueAt(DateTime now) {
    if (mode != CodexTimerMode.countdown) return Duration.zero;
    final since = startedAt == null
        ? Duration.zero
        : now.difference(startedAt!);
    final raw = accumulated + (since.isNegative ? Duration.zero : since);
    final over = raw - duration;
    return over.isNegative ? Duration.zero : over;
  }

  bool isFinishedAt(DateTime now) =>
      mode == CodexTimerMode.countdown && elapsedAt(now) >= duration;

  /// 0–1 arasi doluluk. Geri sayimda KALAN oranidir (dolu baslar, boslar).
  double progressAt(DateTime now) {
    if (duration <= Duration.zero) return 0;
    final ratio = elapsedAt(now).inMilliseconds / duration.inMilliseconds;
    final clamped = ratio.clamp(0.0, 1.0);
    return mode == CodexTimerMode.countdown ? 1 - clamped : clamped;
  }

  CodexTimer startedAtTime(DateTime now) =>
      isRunning ? this : copyWith(startedAt: now);

  /// Duraklatir: o ana kadarki sure [accumulated] icine yazilir.
  CodexTimer pausedAt(DateTime now) => isRunning
      ? copyWith(accumulated: elapsedAt(now), clearStartedAt: true)
      : this;

  CodexTimer get reset =>
      copyWith(accumulated: Duration.zero, clearStartedAt: true);

  /// Bittiginde uygulanacak durum: dongudeyse bastan baslar, degilse durur.
  CodexTimer finishedAt(DateTime now) => loop
      ? copyWith(accumulated: Duration.zero, startedAt: now)
      : copyWith(accumulated: duration, clearStartedAt: true);

  factory CodexTimer.fromJson(Map<Object?, Object?> json) {
    final seconds = (json['duration'] as num?)?.round() ?? 300;
    final startedMs = (json['startedAt'] as num?)?.toInt();
    return CodexTimer(
      mode: CodexTimerMode.fromName(json['mode']),
      duration: clampDuration(Duration(seconds: seconds)),
      startedAt: startedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(startedMs),
      accumulated: Duration(
        milliseconds: (json['accumulated'] as num?)?.round() ?? 0,
      ),
      style: CodexTimerStyle.fromName(json['style']),
      alarm: json['alarm'] as bool? ?? true,
      loop: json['loop'] as bool? ?? false,
    );
  }

  /// [startedAt] durmus sayacta da (null olarak) YAZILIR: blok verisi bir
  /// haritanin uzerine yayiliyor, alan atlanirsa eski baslama ani kalir ve
  /// duraklatilan sayac kendi kendine islemeye devam ederdi.
  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'duration': duration.inSeconds,
    'startedAt': startedAt?.millisecondsSinceEpoch,
    'accumulated': accumulated.inMilliseconds,
    'style': style.name,
    'alarm': alarm,
    'loop': loop,
  };

  static Duration clampDuration(Duration value) {
    if (value < minDuration) return minDuration;
    if (value > maxDuration) return maxDuration;
    return value;
  }

  CodexTimer copyWith({
    CodexTimerMode? mode,
    Duration? duration,
    DateTime? startedAt,
    Duration? accumulated,
    CodexTimerStyle? style,
    bool? alarm,
    bool? loop,
    bool clearStartedAt = false,
  }) => CodexTimer(
    mode: mode ?? this.mode,
    duration: clampDuration(duration ?? this.duration),
    startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    accumulated: accumulated ?? this.accumulated,
    style: style ?? this.style,
    alarm: alarm ?? this.alarm,
    loop: loop ?? this.loop,
  );
}

/// Sureyi masa basinda okunur bicimler: "04:30", "1:02:03".
String formatCodexDuration(Duration value) {
  final total = value.isNegative ? Duration.zero : value;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// Tek bir sayacin durumu (sayac blogu bunlardan bir liste tutar).
class CodexCounter {
  const CodexCounter({
    required this.label,
    this.value = 0,
    this.min,
    this.max,
    this.step = 1,
    this.icon,
  });

  final String label;
  final int value;

  /// Alt/ust sinir (null ise sinirsiz). [max] varsa oran cubugu cizilebilir.
  final int? min;
  final int? max;

  /// Bir dokunusun degistirdigi miktar.
  final int step;

  /// Istege bagli emoji.
  final String? icon;

  factory CodexCounter.fromJson(Map<Object?, Object?> json) => CodexCounter(
    label: '${json['label'] ?? ''}',
    value: (json['value'] as num?)?.round() ?? 0,
    min: (json['min'] as num?)?.round(),
    max: (json['max'] as num?)?.round(),
    step: ((json['step'] as num?)?.round() ?? 1).clamp(1, 1000),
    icon: (json['icon'] as String?)?.trim().isEmpty ?? true
        ? null
        : json['icon'] as String,
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'value': value,
    if (min != null) 'min': min,
    if (max != null) 'max': max,
    'step': step,
    if (icon != null) 'icon': icon,
  };

  /// Degeri sinirlar icinde tutarak degistirir.
  CodexCounter withValue(int next) => copyWith(value: clamp(next));

  /// Bir adim artirir/azaltir.
  CodexCounter bumped(int direction) => withValue(value + step * direction);

  int clamp(int candidate) {
    var v = candidate;
    if (min != null && v < min!) v = min!;
    if (max != null && v > max!) v = max!;
    return v;
  }

  /// [max] (ve varsa [min]) tanimliysa 0–1 arasi doluluk orani.
  double? get ratio {
    if (max == null) return null;
    final low = min ?? 0;
    final span = max! - low;
    if (span <= 0) return null;
    return ((value - low) / span).clamp(0.0, 1.0);
  }

  CodexCounter copyWith({
    String? label,
    int? value,
    int? min,
    int? max,
    int? step,
    String? icon,
    bool clearMin = false,
    bool clearMax = false,
  }) => CodexCounter(
    label: label ?? this.label,
    value: value ?? this.value,
    min: clearMin ? null : (min ?? this.min),
    max: clearMax ? null : (max ?? this.max),
    step: step ?? this.step,
    icon: icon ?? this.icon,
  );
}
