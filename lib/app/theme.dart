import 'package:flutter/material.dart';

/// Uygulamanin "fantastik kimlik" tonlari: ColorScheme'in genel rollerine
/// (primary/secondary/tertiary) tam oturmayan, anlamli isimle erisilen ozel
/// tasarim jetonlari. Ihtiyac duyan herhangi bir widget `Color(0xFF...)`
/// yazmak yerine `context.fantasyColors.brass` gibi anlamli bir yoldan erisir;
/// boylece tema kimligi tek yerde kalir, dagilmaz.
@immutable
class AppFantasyColors extends ThemeExtension<AppFantasyColors> {
  const AppFantasyColors({
    required this.parchment,
    required this.ink,
    required this.gold,
    required this.brass,
    required this.wax,
    required this.vellum,
    required this.rule,
    required this.moss,
    required this.grain,
  });

  /// Sicak, acik parsomen tonu (kagit/kart zemini icin).
  final Color parchment;

  /// Parsomen uzerindeki koyu murekkep tonu (yuksek kontrastli metin).
  final Color ink;

  /// Parlak altin/bronz vurgu (odul, basari, onemli rozet gibi anlamsal
  /// vurgular icin; secondary/tertiary ile ayni tonda ama isimle erisilir).
  final Color gold;

  /// Sus/cerceve pirinci: ornament ayraclar, bolum basligi cizgileri, kemerli
  /// kart kenarlari. [gold]'dan farki: bu dekoratif, o anlamsal.
  final Color brass;

  /// Mum muhru kirmizisi — durum rozetleri ve "muhurlu" vurgular.
  ///
  /// ZEMIN rengidir, metin rengi degil: uzerine daima acik parsomen metin
  /// gelir (kontrast 4.8:1 koyu temada, 7.8:1 acik temada). Koyu zemin
  /// uzerinde metin/ikon rengi olarak kullanma — orada 2.7:1'de kalir.
  final Color wax;

  /// Uzun okuma yuzeyi (Codex sayfasi, stat blogu, el ilani) icin bir tik
  /// yukseltilmis kagit tonu; normal kart zemininden ayrisir.
  final Color vellum;

  /// Ince sus cizgisi rengi (hairline). Divider'dan daha sessiz.
  final Color rule;

  /// Yosun/bakir yesili — olumlu durum (kabul edildi, tamamlandi).
  final Color moss;

  /// Parsomen/tas dokusunun tanecik rengi; prosedurel doku boyayicisi
  /// (`ParchmentTexture`) bu tonu cok dusuk alfayla serper.
  final Color grain;

  /// [AppTheme] disinda kurulmus bir agac icin makul varsayilanlar.
  /// Gercek degerler `AppTheme._build` icinde uretilir; burasi yalnizca
  /// kit widget'lari cokmesin diye vardir.
  factory AppFantasyColors.fallback(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return AppFantasyColors(
      parchment: isDark ? const Color(0xFF2E261F) : const Color(0xFFF1E6CC),
      ink: isDark ? const Color(0xFFECE0CB) : const Color(0xFF241C15),
      gold: isDark ? const Color(0xFFCBA25A) : const Color(0xFF8A5D26),
      brass: isDark ? const Color(0xFFB08C4A) : const Color(0xFF96712F),
      wax: isDark ? const Color(0xFFA83A32) : const Color(0xFF8B2635),
      vellum: isDark ? const Color(0xFF241D17) : const Color(0xFFFBF4E4),
      rule: isDark ? const Color(0xFF4A3F35) : const Color(0xFFC9B893),
      moss: isDark ? const Color(0xFF7FA06A) : const Color(0xFF4F6B3C),
      grain: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF5A4632),
    );
  }

  @override
  AppFantasyColors copyWith({
    Color? parchment,
    Color? ink,
    Color? gold,
    Color? brass,
    Color? wax,
    Color? vellum,
    Color? rule,
    Color? moss,
    Color? grain,
  }) => AppFantasyColors(
    parchment: parchment ?? this.parchment,
    ink: ink ?? this.ink,
    gold: gold ?? this.gold,
    brass: brass ?? this.brass,
    wax: wax ?? this.wax,
    vellum: vellum ?? this.vellum,
    rule: rule ?? this.rule,
    moss: moss ?? this.moss,
    grain: grain ?? this.grain,
  );

  @override
  AppFantasyColors lerp(AppFantasyColors? other, double t) => AppFantasyColors(
    parchment: Color.lerp(parchment, other?.parchment, t)!,
    ink: Color.lerp(ink, other?.ink, t)!,
    gold: Color.lerp(gold, other?.gold, t)!,
    brass: Color.lerp(brass, other?.brass, t)!,
    wax: Color.lerp(wax, other?.wax, t)!,
    vellum: Color.lerp(vellum, other?.vellum, t)!,
    rule: Color.lerp(rule, other?.rule, t)!,
    moss: Color.lerp(moss, other?.moss, t)!,
    grain: Color.lerp(grain, other?.grain, t)!,
  );
}

/// `Theme.of(context).extension<AppFantasyColors>()` kisaltmasi.
///
/// Uzanti bulunamazsa CRASH ETMEZ, parlaklaga gore varsayilana duser: kit
/// widget'lari (bos durum, hata, muhur...) [AppTheme] disinda kurulmus bir
/// agacta da — testlerde, `Theme` ile yerel olarak ezilmis bir alt agacta —
/// calisabilmeli.
extension FantasyColorsContext on BuildContext {
  AppFantasyColors get fantasyColors {
    final theme = Theme.of(this);
    return theme.extension<AppFantasyColors>() ??
        AppFantasyColors.fallback(theme.brightness);
  }
}

/// Duzeni tutarli kilan bosluk olcegi. Ekranlarda `EdgeInsets.all(16)` gibi
/// serbest sayilar yerine tek bir ritim: 4 / 8 / 16 / 24 / 32.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
  });

  final double xs, sm, md, lg, xl;

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
  }) => AppSpacing(
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
  );

  // Bosluklar tema gecislerinde interpolasyona ihtiyac duymaz (sabit olcek).
  @override
  AppSpacing lerp(AppSpacing? other, double t) => this;
}

extension SpacingContext on BuildContext {
  AppSpacing get spacing =>
      Theme.of(this).extension<AppSpacing>() ?? const AppSpacing();
}

/// Kose yaricapi olcegi. Orta cag yuzeyleri oyulmus tas/ahsap panel gibi
/// durmali: bilincli olarak DUSUK yaricaplar (4/8/12/16). Once 10-14 arasi
/// yuvarlak koseler kullaniliyordu; o "modern SaaS karti" hissi veriyordu.
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({this.sm = 4, this.md = 8, this.lg = 12, this.xl = 16});

  final double sm, md, lg, xl;

  @override
  AppRadii copyWith({double? sm, double? md, double? lg, double? xl}) =>
      AppRadii(
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
      );

  @override
  AppRadii lerp(AppRadii? other, double t) => this;
}

extension RadiiContext on BuildContext {
  AppRadii get radii =>
      Theme.of(this).extension<AppRadii>() ?? const AppRadii();
}

/// Duyarli duzen esikleri. Daha once dosyalara serpilmis sihirli sayilardi
/// (DM kabugu 720, oyuncu paneli 760/1080); artik tek kaynak.
abstract final class Breakpoints {
  /// Bu genislikten itibaren yan navigasyon rayi (telefonda alt bar/drawer).
  static const double rail = 720;

  /// Oyuncu panelinde okunabilir metin sutununun azami genisligi.
  static const double readableContent = 1080;
}

/// Hareket suresi ve egrileri. Orta cag/agir malzeme hissi icin girisler
/// biraz uzun ve yumusak, cikislar kisa (UX kurali: exit < enter).
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 340);

  /// Agir bir kapak/kapi acilmasi hissi: hizli baslar, yumusak oturur.
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;
}

/// Uygulamanin gorsel kimligi: orta cag el yazmasi + modern okunabilirlik.
///
/// Iki mod: masada gece kullanimi icin koyu "mese & kor" temasi ve hazirlik
/// yaparken goz yormayan "parsomen" temasi. Sicak tonlar (parsomen, mese,
/// murekkep-kirmizisi, pirinc) + temiz, ferah bilesenler.
abstract final class AppTheme {
  /// Murekkep-kirmizisi ana vurgu (mum muhuru / stat blogu basligi tonu).
  static const _seed = Color(0xFF8B2E2E);

  static const parchment = Color(0xFFF1E6CC);
  static const ink = Color(0xFF241C15);

  /// Basliklar/etiketler icin serif (orta cag hissi): Cinzel (OFL).
  static const _display = 'Cinzel';

  /// UZUN OKUMA yuzeyleri icin serif: EB Garamond (OFL). Codex sayfalari,
  /// stat bloklari, lore metinleri bunu kullanir — el yazmasi hissi orada
  /// dogru. Yogun form/liste UI'i bilincli olarak sistemin sans fontunda
  /// kalir: kucuk etiketler ve rakam alanlari sans'ta daha net okunur.
  static const reading = 'EBGaramond';

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    const radii = AppRadii();

    // Algoritmik uyumu koru; kimligi (parsomen/mese + pirinc) enjekte et.
    final scheme = isDark
        ? base.copyWith(
            primary: const Color(0xFFE0765C), // kor kirmizisi (koyuda okunur)
            onPrimary: const Color(0xFF2A0E08),
            secondary: const Color(0xFFCBA25A), // altin
            tertiary: const Color(0xFFCBA25A),
            // Mese/maun basamaklari: her kademe bir onceki uzerinde net
            // ayrisacak kadar acilir, ama hepsi sicak kalir.
            surface: const Color(0xFF1A1511),
            surfaceContainerLowest: const Color(0xFF14100D),
            surfaceContainerLow: const Color(0xFF201A15),
            surfaceContainer: const Color(0xFF26201A),
            surfaceContainerHigh: const Color(0xFF2E261F),
            surfaceContainerHighest: const Color(0xFF382E25),
            onSurface: const Color(0xFFECE0CB),
            onSurfaceVariant: const Color(0xFFC3B49A),
            // 3:1 (WCAG arayuz bileseni esigi) icin acildi; onceki 0xFF6E6152
            // kart kenarliginda 2.86:1'de kaliyordu.
            outline: const Color(0xFF7A6C5B),
            outlineVariant: const Color(0xFF3B3027),
          )
        : base.copyWith(
            primary: const Color(0xFF7C2B2B),
            onPrimary: const Color(0xFFFBF3E2),
            secondary: const Color(0xFF8A5D26), // bronz (kontrast icin koyuldu)
            tertiary: const Color(0xFF8A5D26),
            surface: parchment,
            surfaceContainerLowest: const Color(0xFFFBF4E4),
            surfaceContainerLow: const Color(0xFFF5EAD3),
            surfaceContainer: const Color(0xFFEEE1C6),
            surfaceContainerHigh: const Color(0xFFE7D8B9),
            surfaceContainerHighest: const Color(0xFFE0CFAC),
            onSurface: ink,
            onSurfaceVariant: const Color(0xFF5A4D3D),
            outline: const Color(0xFF8D7C60),
            outlineVariant: const Color(0xFFCFC0A0),
          );

    final scaffold = isDark ? const Color(0xFF14100D) : parchment;

    final theme = ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: [
        AppFantasyColors(
          parchment: isDark ? const Color(0xFF2E261F) : parchment,
          ink: isDark ? const Color(0xFFECE0CB) : ink,
          gold: isDark ? const Color(0xFFCBA25A) : const Color(0xFF8A5D26),
          // Acik temada 3:1 icin koyulastirildi (0xFFA5813C 2.92'de kaliyordu);
          // sus cizgileri parsomen uzerinde secilmeliydi.
          brass: isDark ? const Color(0xFFB08C4A) : const Color(0xFF96712F),
          wax: isDark ? const Color(0xFFA83A32) : const Color(0xFF8B2635),
          vellum: isDark ? const Color(0xFF241D17) : const Color(0xFFFBF4E4),
          rule: isDark ? const Color(0xFF4A3F35) : const Color(0xFFC9B893),
          moss: isDark ? const Color(0xFF7FA06A) : const Color(0xFF4F6B3C),
          grain: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF5A4632),
        ),
        const AppSpacing(),
        radii,
      ],
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _display,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          // Orta cag kitabesi hissi: basliklar biraz genis harf araliginda.
          letterSpacing: 0.8,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        // Hata metni alanin HEMEN altinda kalir (UX: hatayi alanin yaninda
        // goster, sayfanin tepesinde toplama).
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: scheme.error, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radii.md),
          borderSide: BorderSide(color: scheme.error, width: 1.8),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.md),
          ),
          // Dokunma hedefi >= 44px: yatay 18 / dikey 14 padding + metin
          // yuksekligi bunu guvenle asar.
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.md),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.md),
          ),
          side: BorderSide(color: scheme.outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.sm),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          // Ikon-butonlar varsayilan olarak 40px'e dusebiliyordu; masada
          // telefonla kullanildigi icin 44x44 minimuma sabitlendi.
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radii.md),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        showCheckmark: false,
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        selectedColor: scheme.primary.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        labelStyle: TextStyle(fontSize: 13, color: scheme.onSurface),
      ),
      listTileTheme: ListTileThemeData(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF201A15)
            : const Color(0xFFEEE1C6),
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.20),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark
            ? const Color(0xFF201A15)
            : const Color(0xFFEEE1C6),
        indicatorColor: scheme.primary.withValues(alpha: 0.20),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
        selectedIconTheme: IconThemeData(color: scheme.primary),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 12,
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
        labelStyle: const TextStyle(
          fontFamily: _display,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
        unselectedLabelStyle: const TextStyle(fontFamily: _display),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.xl),
          side: BorderSide(
            color: isDark ? const Color(0xFF4A3F35) : const Color(0xFFC9B893),
          ),
        ),
        titleTextStyle: TextStyle(
          fontFamily: _display,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: scheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radii.xl + 4),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF2E261F)
            : const Color(0xFF2C2118),
        contentTextStyle: const TextStyle(color: Color(0xFFECE0CB)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.md),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E261F) : const Color(0xFF2C2118),
          borderRadius: BorderRadius.circular(radii.sm),
          border: Border.all(
            color: isDark ? const Color(0xFF4A3F35) : const Color(0xFF4A3F35),
          ),
        ),
        textStyle: const TextStyle(color: Color(0xFFECE0CB), fontSize: 12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHigh,
        circularTrackColor: scheme.surfaceContainerHigh,
      ),
    );

    return theme.copyWith(textTheme: _text(theme.textTheme, scheme));
  }

  /// Basliklar serif + genis harf araligi (orta cag kitabesi); govde temiz,
  /// ferah ve modern.
  static TextTheme _text(TextTheme t, ColorScheme scheme) {
    TextStyle? head(TextStyle? s, {double spacing = 0.5}) => s?.copyWith(
      fontFamily: _display,
      fontWeight: FontWeight.w600,
      letterSpacing: spacing,
      color: scheme.onSurface,
    );
    return t.copyWith(
      displayLarge: head(t.displayLarge, spacing: 1.0),
      displayMedium: head(t.displayMedium, spacing: 0.9),
      displaySmall: head(t.displaySmall, spacing: 0.8),
      headlineLarge: head(t.headlineLarge, spacing: 0.8),
      headlineMedium: head(t.headlineMedium, spacing: 0.7),
      headlineSmall: head(t.headlineSmall, spacing: 0.6),
      titleLarge: head(t.titleLarge),
      // Govde: satir yuksekligi 1.5 (UX kurali) — 1.4'ten yukseltildi.
      bodyLarge: t.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: t.bodyMedium?.copyWith(height: 1.5),
      bodySmall: t.bodySmall?.copyWith(height: 1.45),
      // Kucuk buyuk-harf etiketler (overline) donemsel serifte: "OTURUM",
      // "ENVANTER" gibi bolum etiketleri madeni kitabe gibi durur.
      labelSmall: t.labelSmall?.copyWith(
        fontFamily: _display,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.1,
      ),
    );
  }
}

/// Uzun okuma yuzeyleri (Codex govdesi, lore, el ilani metni) icin el yazmasi
/// serifi. Yogun form UI'inda KULLANMA — orada sans daha net.
TextStyle readingStyle(BuildContext context, {TextStyle? base}) {
  final t = base ?? Theme.of(context).textTheme.bodyLarge!;
  return t.copyWith(
    fontFamily: AppTheme.reading,
    // Garamond kucuk govdeli bir serif; ayni optik boyut icin biraz buyutulur.
    fontSize: (t.fontSize ?? 16) * 1.08,
    height: 1.55,
  );
}

/// Stat bloklarinda ve karakter kagidinda kullanilan, oyun terimleri icin
/// tabular rakam hizalamasi olan metin stili.
TextStyle statStyle(BuildContext context) => Theme.of(context)
    .textTheme
    .bodyMedium!
    .copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
