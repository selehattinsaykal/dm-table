import 'package:flutter/material.dart';

import '../theme.dart';
import 'ornaments.dart';

/// Icerik yokken gosterilen yonlendirici bos durum.
///
/// Once ekranlarda cogu yerde ya bombos bir alan ya da tek satir gri metin
/// vardi. Bos durum kullaniciya NE oldugunu ve SIRADAKI ADIMI soylemeli
/// (UX kurali: "Bos ekran birakma, yardimci mesaj + aksiyon goster").
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Kullaniciyi ileri tasiyan birincil aksiyon (ornegin "Karakter olustur").
  final Widget? action;

  /// Kart ici / bolme ici kullanim icin daha kucuk varyant.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fantasy = context.fantasyColors;
    final space = context.spacing;
    final ringSize = compact ? 52.0 : 72.0;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pirinc halka icinde ikon: "bos" alani bilincli bir tasarim
              // ogesi gibi gosterir, unutulmus bir bosluk gibi degil.
              Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fantasy.vellum,
                  border: Border.all(
                    color: fantasy.brass.withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                ),
                child: Icon(icon, size: ringSize * 0.44, color: fantasy.brass),
              ),
              SizedBox(height: space.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    (compact
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(color: theme.colorScheme.onSurface),
              ),
              if (message != null) ...[
                SizedBox(height: space.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action != null) ...[SizedBox(height: space.lg), action!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir sey ters gittiginde gosterilen kurtarilabilir hata durumu.
///
/// Onceden ekranlarda `Center(child: Text('$e'))` vardi: kullaniciya ham
/// istisna metni gosteriliyordu ve cikis yolu yoktu. Burada teknik ayrinti
/// KATLANMIS halde durur (gerektiginde DM'in bize bildirmesi icin), ustte
/// anlasilir bir mesaj ve bir "tekrar dene" yolu olur.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.title,
    this.message,
    this.detail,
    this.detailLabel,
    this.onRetry,
    this.retryLabel,
    super.key,
  });

  final String title;
  final String? message;

  /// Ham istisna metni. Varsayilan olarak GIZLI; kullanici acarsa gorunur.
  final String? detail;

  /// "Teknik ayrinti" acilir baslik metni (cagrilan yerin dilinden gelir).
  final String? detailLabel;

  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fantasy = context.fantasyColors;
    final space = context.spacing;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(space.lg),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              WaxSeal(
                icon: Icons.priority_high,
                size: 56,
                semanticLabel: title,
              ),
              SizedBox(height: space.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              if (message != null) ...[
                SizedBox(height: space.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                SizedBox(height: space.lg),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(retryLabel ?? 'Retry'),
                ),
              ],
              if (detail != null && detail!.isNotEmpty) ...[
                SizedBox(height: space.md),
                Theme(
                  // ExpansionTile kendi ayrac cizgilerini ceker; sus
                  // ayracimizla catismasin diye kapatiliyor.
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(horizontal: space.sm),
                    childrenPadding: EdgeInsets.all(space.sm),
                    title: Text(
                      detailLabel ?? 'Technical detail',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SelectableText(
                        detail!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: space.sm),
              SizedBox(width: 140, child: Divider(color: fantasy.rule)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Temali yukleme gostergesi.
///
/// 300ms'den uzun surebilecek her bekleme icin (UX kurali). Etiket verilirse
/// kullanici NEYIN beklendigini bilir; ekran okuyucu da bunu duyurur.
class AppLoading extends StatelessWidget {
  const AppLoading({this.label, this.compact = false, super.key});

  final String? label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final space = context.spacing;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: compact ? 22 : 30,
            child: CircularProgressIndicator(
              strokeWidth: compact ? 2.2 : 2.8,
              color: context.fantasyColors.brass,
            ),
          ),
          if (label != null) ...[
            SizedBox(height: space.md),
            Text(
              label!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Iskelet (skeleton) blogu — liste/kart yuklenirken yerini tutar.
///
/// Duzeni onceden ayirdigi icin icerik gelince sayfa ziplamaz (CLS).
/// `MediaQuery.disableAnimations` aciksa parilti durur (reduced-motion).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({this.width, this.height = 14, this.radius, super.key});

  final double? width;
  final double height;
  final double? radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final radius = widget.radius ?? context.radii.sm;

    if (reduceMotion) {
      if (_controller.isAnimating) _controller.stop();
      return _bar(scheme.surfaceContainerHigh, radius);
    }
    if (!_controller.isAnimating) _controller.repeat(reverse: true);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _bar(
          Color.lerp(
            scheme.surfaceContainerHigh,
            scheme.surfaceContainerHighest,
            _controller.value,
          )!,
          radius,
        ),
      ),
    );
  }

  Widget _bar(Color color, double radius) => Container(
    width: widget.width,
    height: widget.height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Kart listesi icin hazir iskelet — liste ekranlarinda `AppLoading` yerine
/// bunu kullan; gelecek duzeni onceden gosterdigi icin bekleme daha kisa
/// hissettirir.
class SkeletonList extends StatelessWidget {
  const SkeletonList({this.itemCount = 5, this.padding, super.key});

  final int itemCount;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final space = context.spacing;
    return ListView.separated(
      padding: padding ?? EdgeInsets.all(space.md),
      itemCount: itemCount,
      separatorBuilder: (_, _) => SizedBox(height: space.sm),
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.all(space.md),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(context.radii.lg),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 150 + (index % 3) * 40, height: 16),
            SizedBox(height: space.sm),
            const SkeletonBox(height: 12),
            SizedBox(height: space.xs + 2),
            SkeletonBox(width: 210 - (index % 2) * 50, height: 12),
          ],
        ),
      ),
    );
  }
}
