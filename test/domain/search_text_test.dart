import 'package:dm_table/domain/search_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('searchNormalize', () {
    test('Turkce I/i ciftini dogru esler', () {
      // Bu iki harf `toLowerCase()` ile yanlis tarafa dusuyor.
      expect(searchNormalize('İlkyardım'), 'ilkyardım');
      expect(searchNormalize('IŞIK'), 'ışık');
    });
  });

  group('searchFold', () {
    test('Turkce harfleri ASCII karsiliklarina indirger', () {
      expect(searchFold('Öfke'), 'ofke');
      expect(searchFold('Silah Ustası'), 'silah ustasi');
      expect(searchFold('Çelme Saldırısı'), 'celme saldirisi');
      expect(searchFold('Zekâ'), 'zeka');
    });

    test('ASCII klavyeyle yazilan sorgu Turkce adi bulur', () {
      // Masada kimse arama icin klavye duzeni degistirmiyor.
      expect(searchFold('Büyü Ustalığı').contains(searchFold('buyu')), isTrue);
      expect(
        searchFold('Kadim Yakarış').contains(searchFold('yakaris')),
        isTrue,
      );
    });
  });

  group('compareTurkish', () {
    test('Turk alfabesindeki sirayi kullanir', () {
      // `compareTo` bunlarin hepsini Z'den SONRA koyuyor.
      final words = ['zeytin', 'çilek', 'ıhlamur', 'ürün', 'armut', 'şeftali'];
      expect([...words]..sort(compareTurkish), [
        'armut',
        'çilek',
        'ıhlamur',
        'şeftali',
        'ürün',
        'zeytin',
      ]);
    });

    test('c ile ç ve g ile ğ ayri harf', () {
      expect(compareTurkish('cam', 'çam'), lessThan(0));
      expect(compareTurkish('ağa', 'aga'), greaterThan(0));
    });

    test('i ile ı ayri harf; alfabede ı once gelir', () {
      expect(compareTurkish('ılık', 'ilik'), lessThan(0));
    });

    test('buyuk/kucuk harf farki siralamayi degistirmez', () {
      expect(compareTurkish('Çilek', 'çilek'), 0);
    });

    test('harf olmayan karakterler basa gelir', () {
      final rows = ['Öfke', '1. Seviye', 'Atlet'];
      expect([...rows]..sort(compareTurkish), ['1. Seviye', 'Atlet', 'Öfke']);
    });

    test('Turk alfabesinde olmayan q/w/x Latin sirasina oturur', () {
      // SRD adlarinda geciyorlar ("Watchers"); listenin basina dusmemeliler.
      final rows = ['Zehirci', 'Watchers', 'Vahşi Saldırgan', 'Yorulmaz'];
      expect([...rows]..sort(compareTurkish), [
        'Vahşi Saldırgan',
        'Watchers',
        'Yorulmaz',
        'Zehirci',
      ]);
    });

    test('onek olan sozcuk once gelir', () {
      expect(compareTurkish('kan', 'kanat'), lessThan(0));
    });
  });
}
