// GELISTIRME ARACI — urun paketine girmez.
//
// Tema jetonlarini ve `app/ui` kitini tek sayfada gosterir; tasarim
// degisikliklerini tarayicida (acik/koyu yan yana) gozle dogrulamak icin.
//
//   flutter run -d chrome -t lib/dev_theme_preview.dart
//   flutter build web -t lib/dev_theme_preview.dart -o build/theme_preview
//
// Not: `main.dart` bu dosyayi import ETMEZ, dolayisiyla urun derlemelerine
// dahil olmaz.
import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'app/ui/ui.dart';

void main() => runApp(const _PreviewApp());

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    home: const _SideBySide(),
  );
}

/// Acik ve koyu temayi yan yana gosterir: kontrast ve kimlik farklari ayni
/// ekranda karsilastirilabilsin.
class _SideBySide extends StatelessWidget {
  const _SideBySide();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Theme(
          data: AppTheme.light(),
          child: const ParchmentOverlay(child: _Gallery(title: 'Parşömen')),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: Theme(
          data: AppTheme.dark(),
          child: const ParchmentOverlay(child: _Gallery(title: 'Meşe & Kor')),
        ),
      ),
    ],
  );
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fantasy = context.fantasyColors;
    final space = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: space.md),
        children: [
          const SectionHeader(label: 'Tipografi', icon: Icons.text_fields),
          Text(
            'Yitik Diyar Vakayinamesi',
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: space.xs),
          Text('Başlık — Cinzel', style: theme.textTheme.bodySmall),
          SizedBox(height: space.md),
          IlluminatedParagraph(
            'Kadim taş kapının ardında, üç yüz yıldır kimsenin adını anmadığı '
            'bir salon uzanıyordu. Duvarlardaki meşaleler kendiliğinden '
            'tutuştu ve gölgeler geri çekildi.',
          ),
          SizedBox(height: space.xs),
          Text('Okuma gövdesi — EB Garamond', style: theme.textTheme.bodySmall),
          SizedBox(height: space.md),
          Text(
            'Yoğun arayüz metni sistem sans fontunda kalır: form etiketleri, '
            'listeler ve rakam alanları burada daha net okunur.',
            style: theme.textTheme.bodyMedium,
          ),

          const OrnamentDivider(),

          const SectionHeader(label: 'Renk jetonları', icon: Icons.palette),
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
            children: [
              _Swatch('primary', theme.colorScheme.primary),
              _Swatch('gold', fantasy.gold),
              _Swatch('brass', fantasy.brass),
              _Swatch('wax', fantasy.wax),
              _Swatch('moss', fantasy.moss),
              _Swatch('vellum', fantasy.vellum),
              _Swatch('rule', fantasy.rule),
            ],
          ),

          const OrnamentDivider(),

          const SectionHeader(label: 'Bileşenler', icon: Icons.widgets),
          Wrap(
            spacing: space.sm,
            runSpacing: space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton(onPressed: () {}, child: const Text('Onayla')),
              OutlinedButton(onPressed: () {}, child: const Text('Vazgeç')),
              TextButton(onPressed: () {}, child: const Text('Ayrıntı')),
              const WaxSeal(icon: Icons.check, semanticLabel: 'Mühürlendi'),
              const WaxSeal(letter: 'R', size: 40),
            ],
          ),
          SizedBox(height: space.md),
          Wrap(
            spacing: space.sm,
            children: [
              const Chip(label: Text('Savaşçı')),
              Chip(
                label: const Text('Seçili'),
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.16,
                ),
              ),
              const Chip(label: Text('Büyücü')),
            ],
          ),
          SizedBox(height: space.md),
          const TextField(
            decoration: InputDecoration(
              labelText: 'Karakter adı',
              helperText: 'Masada görünecek ad',
            ),
          ),
          SizedBox(height: space.md),
          Card(
            child: Padding(
              padding: EdgeInsets.all(space.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 76,
                    child: ArchFrame(child: ColoredBox(color: fantasy.vellum)),
                  ),
                  SizedBox(width: space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rohan', style: theme.textTheme.titleMedium),
                        Text(
                          'Rogue 1 · 9/9 HP',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const WaxSeal(
                    icon: Icons.shield,
                    size: 30,
                    semanticLabel: 'Zırh',
                  ),
                ],
              ),
            ),
          ),

          const OrnamentDivider(),

          const SectionHeader(label: 'Durumlar', icon: Icons.info_outline),
          SizedBox(
            height: 240,
            child: AppEmptyState(
              icon: Icons.people_outline,
              title: 'Henüz karakter yok',
              message: 'Aşağıdaki düğmeden ilk karakteri oluştur.',
              compact: true,
              action: FilledButton(
                onPressed: () {},
                child: const Text('Karakter oluştur'),
              ),
            ),
          ),
          SizedBox(
            height: 260,
            child: AppErrorState(
              title: 'Bir şeyler ters gitti',
              message: 'Bu bölüm yüklenemedi. Tekrar dene.',
              detail: 'SqliteException(1): no such table: quests',
              detailLabel: 'Teknik ayrıntı',
              retryLabel: 'Tekrar dene',
              onRetry: () {},
            ),
          ),
          const SizedBox(height: 160, child: SkeletonList(itemCount: 2)),
          const SizedBox(height: 90, child: AppLoading(label: 'Yükleniyor…')),
          SizedBox(height: space.xl * 2),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color);

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 62,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(context.radii.sm),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
      const SizedBox(height: 4),
      Text(name, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
}
