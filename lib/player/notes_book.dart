import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../net/protocol.dart';
import 'notes_edit.dart';
import 'player_client.dart';
import 'player_strings.dart';

/// Oyuncu notlari artik KITAPLAR: her not bir kitap (baslikli), kitaplar
/// sayfalardan olusur. Veri modeli mevcut protokol uzerinden yeniden yorumlanir
/// -- Kitap = [NoteSection] (baslik = kitap adi), Sayfa = [NoteEntry] (body =
/// sayfa metni). Boylece sunucu/DM tarafi ve senkron hic degismez; yalniz UI
/// ve [notes_edit] saf fonksiyonlari yeniden kullanilir.

const _uuid = Uuid();

/// Bir sayfanin azami karakter kapasitesi. Sayfa "dolunca" oyuncu → ile bir
/// sonraki sayfaya gecer (sonsuza kadar buyuyen tek metin blogu YOK).
const int _pageCharLimit = 1100;

// Orta cag paleti (fiziksel kitap: temadan bagimsiz sicak tonlar).
const _parchment = Color(0xFFEBDFBE);
const _parchmentEdge = Color(0xFFD8C79E);
const _ink = Color(0xFF3A2A18);
const _inkFaint = Color(0xFF6B573B);
const _gold = Color(0xFFC9A24B);
const _deskBg = Color(0xFF241A12);

/// Notlar sekmesi govdesi: kitaplik. Kitaba dokununca okuyucu/duzenleyici acilir.
class NotesBookshelf extends ConsumerWidget {
  const NotesBookshelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = PlayerL10n.of(context);
    final books = ref.watch(playerControllerProvider.select((s) => s.notes));
    final controller = ref.read(playerControllerProvider.notifier);

    void createBook() => _promptText(
      context,
      title: l.newBook,
      label: l.bookNameLabel,
      onSubmit: (name) {
        final bookId = _uuid.v4();
        // Yeni kitap bir bos sayfayla acilir.
        final withBook = addSection(books, id: bookId, title: name);
        final withPage = addEntry(withBook, bookId, id: _uuid.v4());
        controller.saveNotes(withPage);
        _openBook(context, bookId);
      },
    );

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: createBook,
        icon: const Icon(Icons.menu_book_outlined),
        label: Text(l.newBook),
      ),
      body: books.isEmpty
          ? _EmptyShelf(onCreate: createBook)
          : GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                childAspectRatio: 3 / 4,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: books.length,
              itemBuilder: (context, i) => _BookCover(
                book: books[i],
                onOpen: () => _openBook(context, books[i].id),
              ),
            ),
    );
  }

  void _openBook(BuildContext context, String bookId) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BookReaderPage(bookId: bookId)));
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = PlayerL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 52,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(l.emptyBookshelf, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              l.startByAddingBook,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rafdaki bir kitap kapagi: deri renk + altin sirt + baslik + sayfa sayisi.
class _BookCover extends StatelessWidget {
  const _BookCover({required this.book, required this.onOpen});

  final NoteSection book;
  final VoidCallback onOpen;

  static const _leathers = [
    Color(0xFF5E3A24),
    Color(0xFF3E4C34),
    Color(0xFF463356),
    Color(0xFF5E2A2A),
    Color(0xFF34455E),
    Color(0xFF5E4A22),
  ];

  @override
  Widget build(BuildContext context) {
    final l = PlayerL10n.of(context);
    final title = book.title.trim().isEmpty ? l.untitledBook : book.title;
    final leather = _leathers[book.id.hashCode.abs() % _leathers.length];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(leather, Colors.white, 0.12)!,
                Color.lerp(leather, Colors.black, 0.18)!,
              ],
            ),
            border: Border.all(color: _gold.withValues(alpha: 0.5), width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Sirt.
              Container(
                width: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.28),
                  border: Border(
                    right: BorderSide(color: _gold.withValues(alpha: 0.4)),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cinzel',
                            color: Color(0xFFF3E7C8),
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.bookmark_border,
                            size: 14,
                            color: _gold.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.pageCount(book.entries.length),
                            style: TextStyle(
                              color: _gold.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bir kitabin okuyucu/duzenleyicisi: her seferinde tek parsomen sayfa,
/// ok tuslari/dugmelerle sayfa gecisi (gercek sayfa-cevirme animasyonu).
class BookReaderPage extends ConsumerStatefulWidget {
  const BookReaderPage({required this.bookId, super.key});

  final String bookId;

  @override
  ConsumerState<BookReaderPage> createState() => _BookReaderPageState();
}

class _BookReaderPageState extends ConsumerState<BookReaderPage>
    with SingleTickerProviderStateMixin {
  final _text = TextEditingController();
  final _editFocus = FocusNode();
  Timer? _saveTimer;

  int _index = 0;

  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  bool _flipping = false;
  bool _flipForward = true;
  int _flipFrom = 0;
  List<String> _flipBodies = const []; // animasyon sirasinda dondurulmus icerik

  @override
  void initState() {
    super.initState();
    _flip.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() {
          _flipping = false;
          _text.text = _bodyAt(_index);
        });
      }
    });
    // Ilk sayfa metnini yukle (post-frame: notes provider'i okuyabilmek icin).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _text.text = _bodyAt(_index);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _saveCurrent();
    _saveTimer?.cancel();
    _flip.dispose();
    _text.dispose();
    _editFocus.dispose();
    super.dispose();
  }

  List<NoteSection> get _notes => ref.read(playerControllerProvider).notes;

  NoteSection? get _book =>
      _notes.where((s) => s.id == widget.bookId).firstOrNull;

  List<NoteEntry> get _pages => _book?.entries ?? const [];

  String _bodyAt(int i) => (i >= 0 && i < _pages.length) ? _pages[i].body : '';

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 600), _saveCurrent);
    setState(() {}); // "sayfa doldu" ipucu icin
  }

  void _saveCurrent() {
    final pages = _pages;
    if (_index < 0 || _index >= pages.length) return;
    final page = pages[_index];
    if (page.body == _text.text) return;
    ref
        .read(playerControllerProvider.notifier)
        .saveNotes(
          editEntry(
            _notes,
            widget.bookId,
            page.id,
            title: '',
            body: _text.text,
          ),
        );
  }

  void _turnTo(int target) {
    if (_flipping || target == _index) return;
    if (target < 0) return;
    _saveCurrent();
    FocusScope.of(context).unfocus();
    setState(() {
      _flipForward = target > _index;
      _flipFrom = _index;
      // Animasyon suresince iki yaprak sabit icerik gosterir.
      _flipBodies = [for (final p in _pages) p.body];
      _index = target;
      _flipping = true;
    });
    _flip.forward(from: 0);
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _turnTo(_index + 1);
    } else if (_text.text.trim().isNotEmpty) {
      // Son sayfa dolu/yazili: yeni bos sayfa ekle ve ona gec.
      _saveCurrent();
      final id = _uuid.v4();
      ref
          .read(playerControllerProvider.notifier)
          .saveNotes(addEntry(_notes, widget.bookId, id: id));
      _turnTo(_index + 1);
    }
  }

  void _prev() {
    if (_index > 0) _turnTo(_index - 1);
  }

  Future<void> _renameBook() async {
    final l = PlayerL10n.of(context);
    _promptText(
      context,
      title: l.renameBook,
      label: l.bookNameLabel,
      initial: _book?.title ?? '',
      onSubmit: (name) => ref
          .read(playerControllerProvider.notifier)
          .saveNotes(renameSection(_notes, widget.bookId, name)),
    );
  }

  void _deleteBook() {
    final l = PlayerL10n.of(context);
    final title = (_book?.title ?? '').trim().isEmpty
        ? l.untitledBook
        : _book!.title;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteBook),
        content: Text(l.deleteBookConfirm(title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(playerControllerProvider.notifier)
                  .saveNotes(deleteSection(_notes, widget.bookId));
              Navigator.pop(context); // dialog
              Navigator.pop(context); // reader
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }

  void _deletePage() {
    final pages = _pages;
    if (pages.length <= 1) return; // en az bir sayfa kalsin
    final id = pages[_index].id;
    final newIndex = _index > 0 ? _index - 1 : 0;
    ref
        .read(playerControllerProvider.notifier)
        .saveNotes(deleteEntry(_notes, widget.bookId, id));
    setState(() {
      _index = newIndex;
      _text.text = _bodyAt(_index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = PlayerL10n.of(context);
    final book = _book;
    // Kitap silinmisse geri don.
    if (book == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: _deskBg);
    }
    final pages = _pages;
    final total = pages.isEmpty ? 1 : pages.length;
    final title = book.title.trim().isEmpty ? l.untitledBook : book.title;
    final full = _text.text.length >= _pageCharLimit;

    return Scaffold(
      backgroundColor: _deskBg,
      appBar: AppBar(
        backgroundColor: _deskBg,
        foregroundColor: const Color(0xFFEBDFBE),
        title: InkWell(
          onTap: _renameBook,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 6),
                const Icon(Icons.edit_outlined, size: 16),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: l.bookActions,
            onSelected: (v) {
              if (v == 'deletePage') _deletePage();
              if (v == 'deleteBook') _deleteBook();
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'deletePage', child: Text(l.deletePage)),
              PopupMenuItem(value: 'deleteBook', child: Text(l.deleteBook)),
            ],
          ),
        ],
      ),
      // Ok tuslari sayfa gecirir (metin alani odakli DEGILKEN; odakliyken
      // oklar imleci hareket ettirir -- beklenen davranis).
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowRight): _next,
          const SingleActivator(LogicalKeyboardKey.arrowLeft): _prev,
        },
        child: Focus(
          autofocus: true,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: AspectRatio(
                        aspectRatio: 3 / 4,
                        child: _flipping
                            ? _buildFlip()
                            : _Parchment(seed: _index, child: _editor(l, full)),
                      ),
                    ),
                  ),
                ),
              ),
              _controls(l, total),
            ],
          ),
        ),
      ),
    );
  }

  Widget _editor(PlayerL10n l, bool full) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            controller: _text,
            focusNode: _editFocus,
            maxLength: _pageCharLimit,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: _ink,
            style: const TextStyle(color: _ink, fontSize: 16, height: 1.5),
            decoration: InputDecoration(
              border: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
              counterText: '',
              hintText: l.writeHere,
              hintStyle: TextStyle(color: _inkFaint.withValues(alpha: 0.6)),
            ),
            onChanged: (_) => _scheduleSave(),
          ),
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  l.pageFullHint,
                  style: const TextStyle(color: _inkFaint, fontSize: 12),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 14, color: _inkFaint),
              ],
            ),
          ),
      ],
    );
  }

  Widget _controls(PlayerL10n l, int total) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton.filledTonal(
              onPressed: _index > 0 ? _prev : null,
              icon: const Icon(Icons.chevron_left),
              tooltip: '‹',
            ),
            Text(
              l.pageOf(_index + 1, total),
              style: const TextStyle(color: Color(0xFFC9A24B), fontSize: 13),
            ),
            IconButton.filledTonal(
              onPressed: _next,
              icon: const Icon(Icons.chevron_right),
              tooltip: '›',
            ),
          ],
        ),
      ),
    );
  }

  /// Sayfa-cevirme: gercek kitaptaki gibi KOSE KATLAMA. Sag-ust kose kavranip
  /// sola dogru suruklenir; sayfa diyagonal bir kirisik boyunca geriye katlanir,
  /// katlanan yapragin arkasinda murekkep ayna gibi sizar, altindan hedef sayfa
  /// aciga cikar. (Eski hali sirt etrafinda duz donen bir dikdortgendi -- kagit
  /// degil kapi gibi duruyordu.)
  Widget _buildFlip() {
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final e = Curves.easeInOutCubic.transform(_flip.value);
            // Ileri: eski sayfa katlanir, hedef altindan cikar.
            // Geri: gelen sayfa soldan geri katlanarak yerine oturur (t 1->0).
            final foldT = _flipForward ? e : 1 - e;
            final folding = _flipForward ? _flipFrom : _index;
            final revealed = _flipForward ? _index : _flipFrom;
            return CustomPaint(
              size: Size.infinite,
              painter: _PageFoldPainter(
                t: foldT,
                foldingBody: _bodyFrom(folding),
                foldingSeed: folding,
                revealedBody: _bodyFrom(revealed),
                revealedSeed: revealed,
              ),
            );
          },
        ),
      ),
    );
  }

  String _bodyFrom(int i) =>
      (i >= 0 && i < _flipBodies.length) ? _flipBodies[i] : '';
}

/// Parsomen dokulu yaprak: sicak kagit + hafif vinyet + lif benekleri, altin
/// ince cerceve. [seed] beneklerin dagilimini sabitler (her rebuild'de ayni).
class _Parchment extends StatelessWidget {
  const _Parchment({required this.seed, required this.child});

  final int seed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(
          painter: _ParchmentPainter(seed),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ParchmentPainter extends CustomPainter {
  _ParchmentPainter(this.seed);
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Temiz kagit: sicak gradyan (lif benekleri bilincli olarak YOK -- yazi
    // alaninda "karama" gibi duruyordu).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF1E6C8), _parchment, _parchmentEdge],
        ).createShader(rect),
    );

    // Kenar vinyeti (yipranma hissi).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.9,
          colors: [
            const Color(0x00000000),
            Colors.brown.withValues(alpha: 0.20),
          ],
          stops: const [0.7, 1.0],
        ).createShader(rect),
    );

    // Ince altin cerceve.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(6), const Radius.circular(3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _gold.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(_ParchmentPainter old) => old.seed != seed;
}

/// Gercek sayfa cevirme: KOSE KATLAMA (page fold).
///
/// Geometri, kagit katlamanin fiziginden gelir. Sag-ust kose [c], sanki
/// parmakla kavranip [p] noktasina cekilir; kagit ancak [c] ile [p]'nin
/// **dikey orta dikmesi** boyunca katlanabilir -- bu dogru katlama cizgisidir.
/// Cizginin [c] tarafinda kalan parca (yaprak) o cizgiye gore YANSITILARAK
/// cizilir; yansima matrisi metni de aynaladigi icin arka yuzde murekkebin
/// kagittan sizmasi bedavaya gelir. Kalan parca yerinde durur, altta hedef
/// sayfa aciga cikar.
class _PageFoldPainter extends CustomPainter {
  _PageFoldPainter({
    required this.t,
    required this.foldingBody,
    required this.foldingSeed,
    required this.revealedBody,
    required this.revealedSeed,
  });

  /// 0 = sayfa duz duruyor, 1 = tamamen cevrilmis.
  final double t;
  final String foldingBody;
  final int foldingSeed;
  final String revealedBody;
  final int revealedSeed;

  static const _style = TextStyle(color: _ink, fontSize: 16, height: 1.5);
  static const _padLeft = 22.0;
  static const _padTop = 20.0;
  static const _padH = 44.0;

  /// Tek bir parsomen yaprak (doku + metin). [inkAlpha] < 1 ise metin, arka
  /// yuzden sizan soluk murekkep olarak cizilir.
  void _sheet(
    Canvas canvas,
    Size size,
    int seed,
    String body, {
    double inkAlpha = 1,
  }) {
    _ParchmentPainter(seed).paint(canvas, size);
    if (body.isEmpty) return;
    TextPainter(
        text: TextSpan(
          text: body,
          style: inkAlpha >= 1
              ? _style
              : _style.copyWith(color: _ink.withValues(alpha: inkAlpha)),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout(maxWidth: size.width - _padH)
      ..paint(canvas, const Offset(_padLeft, _padTop));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));

    // 1. Altta aciga cikan hedef sayfa.
    _sheet(canvas, size, revealedSeed, revealedBody);

    // Kavranan kose ve suruklendigi nokta. p soldan disari cikinca (t=1)
    // katlama cizgisi sol kenari gecer, yani sayfa tamamen cevrilmis olur.
    // y bilesenindeki sin() kavisi ortada diyagonal tilt uretir; basta ve
    // sonda kirisik dikeye doner -- elle cevirmenin dogal yayi.
    final c = Offset(w, 0);
    final p = Offset(w - 2 * w * t, h * 0.5 * sin(pi * t));
    final d = p - c;
    final len = d.distance;

    // Henuz kavranmamis: duz sayfa.
    if (len < 0.5) {
      _sheet(canvas, size, foldingSeed, foldingBody);
      canvas.restore();
      return;
    }

    final n = Offset(d.dx / len, d.dy / len); // katlama cizgisinin normali
    final mid = c + d / 2; // cizgi bu noktadan gecer
    final k = mid.dx * n.dx + mid.dy * n.dy;
    final lift = sin(pi * t.clamp(0.0, 1.0)); // yaprak en dik oldugunda 1

    // Katlama cizgisinin bir yanindaki yari duzlem (s=+1 duz kalan taraf,
    // s=-1 kosenin oldugu yaprak tarafi).
    final along = Offset(-n.dy, n.dx);
    final big = (w + h) * 3;
    Path halfPlane(double s) {
      final a = mid + along * big;
      final b = mid - along * big;
      final off = n * (big * s);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx + off.dx, b.dy + off.dy)
        ..lineTo(a.dx + off.dx, a.dy + off.dy)
        ..close();
    }

    final page = Path()..addRect(rect);
    final flat = Path.combine(PathOperation.intersect, page, halfPlane(1));
    final flap = Path.combine(PathOperation.intersect, page, halfPlane(-1));

    // 2. Katlanmayan kisim yerinde durur.
    canvas.save();
    canvas.clipPath(flat);
    _sheet(canvas, size, foldingSeed, foldingBody);
    canvas.restore();

    // Katlama cizgisine gore yansima matrisi: q' = q - 2((q-mid)·n)n.
    final m = Matrix4.identity();
    m.storage[0] = 1 - 2 * n.dx * n.dx;
    m.storage[1] = -2 * n.dx * n.dy;
    m.storage[4] = -2 * n.dx * n.dy;
    m.storage[5] = 1 - 2 * n.dy * n.dy;
    m.storage[12] = 2 * n.dx * k;
    m.storage[13] = 2 * n.dy * k;

    // 3. Kalkan yapragin alttaki sayfaya dusurdugu yumusak golge.
    canvas.drawPath(
      flap.transform(m.storage).shift(const Offset(-3, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.10 + 0.26 * lift)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 + 9 * lift),
    );

    // 4. Yapragin ARKA yuzu. Yansima altinda cizildigi icin metin kendiliginden
    // aynalanir; dusuk alfa "murekkep kagittan siziyor" hissini verir.
    canvas.save();
    canvas.transform(m.storage);
    canvas.clipPath(flap);
    _sheet(canvas, size, foldingSeed + 5000, foldingBody, inkAlpha: 0.30);
    // Kirisiga yakin taraf isigi kaybeder (kagit orada kivriliyor).
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(mid, mid - n * max(len * 0.8, 24), [
          Colors.black.withValues(alpha: 0.06 + 0.30 * lift),
          const Color(0x00000000),
        ]),
    );
    canvas.restore();

    // 5. Kirisik: ince acik kenar cizgisi (katlanan kagidin sirti).
    canvas.drawLine(
      mid + along * big,
      mid - along * big,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.22 * lift)
        ..strokeWidth = 1.4,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PageFoldPainter old) =>
      old.t != t ||
      old.foldingSeed != foldingSeed ||
      old.revealedSeed != revealedSeed ||
      old.foldingBody != foldingBody ||
      old.revealedBody != revealedBody;
}

/// Kitap adi / yeniden adlandirma icin tek satirlik girdi (yerel; player_app'in
/// private yardimcilarina bagimli olmamak icin).
void _promptText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  required ValueChanged<String> onSubmit,
}) {
  final controller = TextEditingController(text: initial);
  void submit() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    onSubmit(text);
    Navigator.pop(context);
  }

  showDialog<void>(
    context: context,
    builder: (context) {
      final l = PlayerL10n.of(context);
      return AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => submit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(onPressed: submit, child: Text(l.ok)),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
