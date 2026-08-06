import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../data/db/database.dart';
import '../../l10n/app_localizations.dart';
import 'bond_type.dart';
import 'world_providers.dart';

/// Kosedeki dislikten acilan bag turu ayarlari: renk/ad duzenle, yeni tur ekle,
/// sil. Degisiklikler aninda DB'ye yazilir ve grafige yansir.
Future<void> showBondTypeSettings(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _BondTypeSettingsSheet(),
  );
}

class _BondTypeSettingsSheet extends ConsumerWidget {
  const _BondTypeSettingsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    final bonds = ref.watch(bondTypesProvider).value ?? const [];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.bondSettingsTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final b in bonds)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Color(b.color),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      title: Text(b.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _edit(context, existing: b),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ref
                                .read(worldRepositoryProvider)
                                .deleteBondType(b.code),
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, existing: b),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.bondNewType),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, {BondType? existing}) {
    return showDialog<void>(
      context: context,
      builder: (_) => _BondEditDialog(existing: existing),
    );
  }
}

/// Renk cemberinde surukleme/hex degisikligi VAR OLAN bir turu ANINDA DB'ye
/// yazar (grafikteki kenarlar kaydetmeden once bile canli guncellenir);
/// "Iptal" orijinal renge geri doner (rollback). Yeni tur olustururken henuz
/// bir DB satiri olmadigi icin renk yalniz "Olustur"da yazilir.
class _BondEditDialog extends ConsumerStatefulWidget {
  const _BondEditDialog({this.existing});

  final BondType? existing;

  @override
  ConsumerState<_BondEditDialog> createState() => _BondEditDialogState();
}

class _BondEditDialogState extends ConsumerState<_BondEditDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final TextEditingController _hex;
  late Color _color;
  late final Color _original;
  final _hexFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _color = Color(widget.existing?.color ?? kBondPalette.first);
    _original = _color;
    _hex = TextEditingController(text: colorToHex(_color));
    _hexFocus.addListener(() {
      // Odaktan cikinca kutuyu gecerli renge gore normalize et (kisa/gecersiz
      // girisleri temizler).
      if (!_hexFocus.hasFocus) _hex.text = colorToHex(_color);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  /// Var olan turu duzenlerken rengi hemen DB'ye yazar (otomatik yayin).
  /// Yeni tur olustururken (henuz code yok) yalniz yerel state guncellenir.
  void _publish(Color c) {
    final existing = widget.existing;
    if (existing == null) return;
    final name = _name.text.trim();
    ref
        .read(worldRepositoryProvider)
        .upsertBondType(
          code: existing.code,
          name: name.isEmpty ? existing.name : name,
          color: c.toARGB32(),
          sort: existing.sortOrder,
        );
  }

  void _onWheelChanged(Color c) => setState(() {
    _color = c;
    if (!_hexFocus.hasFocus) _hex.text = colorToHex(c);
  });

  void _onWheelCommitted(Color c) {
    setState(() => _color = c);
    _publish(c);
  }

  void _onHexChanged(String value) {
    final parsed = hexToColor(value);
    if (parsed == null) return;
    setState(() => _color = parsed);
    _publish(parsed);
  }

  void _cancel() {
    // Duzenleme sirasinda aninda yayinlanan renk varsa orijinaline dondur.
    if (widget.existing != null && _color.toARGB32() != _original.toARGB32()) {
      _publish(_original);
    }
    Navigator.pop(context);
  }

  Future<void> _saveNewOrRename() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(worldRepositoryProvider);
    final existing = widget.existing;
    await repo.upsertBondType(
      code: existing?.code ?? 'bond-${const Uuid().v4()}',
      name: name,
      color: _color.toARGB32(),
      sort: existing?.sortOrder ?? 100,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10n.of(context);
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(
        widget.existing == null ? l10n.bondNewType : l10n.worldGraphChangeType,
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              decoration: InputDecoration(
                labelText: l10n.worldNameLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.bondColorLabel, style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Center(
              child: _ColorWheel(
                color: _color,
                onChanged: _onWheelChanged,
                onChangeEnd: _onWheelCommitted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _hex,
                    focusNode: _hexFocus,
                    maxLength: 7,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: l10n.bondHexLabel,
                      prefixText: '#',
                      counterText: '',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: _onHexChanged,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: Text(l10n.cancel)),
        FilledButton(onPressed: _saveNewOrRename, child: Text(l10n.save)),
      ],
    );
  }
}

/// HSV disk: aci = hue, merkezden uzaklik = doygunluk. Ayrica bir parlaklik
/// (value) kaydiricisi. Surukleme sirasinda [onChanged] (yalniz yerel state),
/// biraktiginda [onChangeEnd] (DB'ye yazilsin) cagrilir.
class _ColorWheel extends StatefulWidget {
  const _ColorWheel({
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final ValueChanged<Color> onChangeEnd;

  static const double size = 200;

  @override
  State<_ColorWheel> createState() => _ColorWheelState();
}

class _ColorWheelState extends State<_ColorWheel> {
  late HSVColor _hsv = HSVColor.fromColor(widget.color);

  @override
  void didUpdateWidget(_ColorWheel old) {
    super.didUpdateWidget(old);
    // Disaridan (hex alani) gelen degisiklikle senkron kal.
    if (widget.color.toARGB32() != old.color.toARGB32()) {
      _hsv = HSVColor.fromColor(widget.color);
    }
  }

  void _updateFromPosition(Offset local) {
    const r = _ColorWheel.size / 2;
    final center = const Offset(r, r);
    final d = local - center;
    final dist = min(d.distance, r);
    final angle = atan2(d.dy, d.dx);
    final hue = (angle * 180 / pi + 360) % 360;
    final sat = (dist / r).clamp(0.0, 1.0);
    setState(() => _hsv = _hsv.withHue(hue).withSaturation(sat));
    widget.onChanged(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = L10n.of(context);
    return Column(
      children: [
        GestureDetector(
          onPanStart: (d) => _updateFromPosition(d.localPosition),
          onPanUpdate: (d) => _updateFromPosition(d.localPosition),
          onPanEnd: (_) => widget.onChangeEnd(_hsv.toColor()),
          onTapUp: (d) {
            _updateFromPosition(d.localPosition);
            widget.onChangeEnd(_hsv.toColor());
          },
          child: CustomPaint(
            size: const Size.square(_ColorWheel.size),
            painter: _WheelPainter(hsv: _hsv),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.brightness_6_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Slider(
                value: _hsv.value,
                label: l10n.bondBrightness,
                onChanged: (v) {
                  setState(() => _hsv = _hsv.withValue(v));
                  widget.onChanged(_hsv.toColor());
                },
                onChangeEnd: (v) => widget.onChangeEnd(_hsv.toColor()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.hsv});

  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: r);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    // Hue halkasi (aci) + doygunluk (merkezden kenara beyaz->seffaf).
    const sweep = SweepGradient(
      colors: [
        Color(0xFFFF0000),
        Color(0xFFFFFF00),
        Color(0xFF00FF00),
        Color(0xFF00FFFF),
        Color(0xFF0000FF),
        Color(0xFFFF00FF),
        Color(0xFFFF0000),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = sweep.createShader(rect));
    const radial = RadialGradient(colors: [Colors.white, Color(0x00FFFFFF)]);
    canvas.drawRect(rect, Paint()..shader = radial.createShader(rect));

    // Parlaklik: value dustukce ustune siyah bindir.
    if (hsv.value < 1.0) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.black.withValues(alpha: 1 - hsv.value),
      );
    }
    canvas.restore();

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black26,
    );

    // Secili nokta.
    final angle = hsv.hue * pi / 180;
    final dist = hsv.saturation * r;
    final pos = center + Offset(cos(angle) * dist, sin(angle) * dist);
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(
      pos,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black38,
    );
  }

  @override
  bool shouldRepaint(_WheelPainter old) => old.hsv != hsv;
}

String colorToHex(Color c) =>
    (c.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// "RGB", "RRGGBB", "#RRGGBB" bicimlerini kabul eder; gecersizse null.
Color? hexToColor(String input) {
  var h = input.trim().replaceAll('#', '');
  if (h.length == 3) {
    h = h.split('').map((c) => '$c$c').join();
  }
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  if (v == null) return null;
  return Color(0xFF000000 | v);
}
