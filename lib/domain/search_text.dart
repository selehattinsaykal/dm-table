/// Arama icin metin normalizasyonu.
///
/// Turkce klavyeyle "ilkyardim" yazan biri "İlkyardım" kaydini bulabilmeli,
/// ama `toLowerCase()` tek basina yetmiyor: "İ" harfi Unicode'da iki kod
/// noktasina aciliyor ve "I" harfi de yanlis tarafa dusuyor. Once bu iki harf
/// elle esleniyor, sonra kucultuluyor.
///
/// DIKKAT: veritabanindaki `nameLower` sutunlari ice aktarma sirasinda BU
/// fonksiyonla uretildi. Davranisi degistirmek butun aramalari sessizce
/// bozar; yeni bir kural gerekiyorsa [searchFold] gibi ayri bir fonksiyon ekle.
String searchNormalize(String value) =>
    value.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

/// Turkce harfleri ASCII karsiliklarina indirger.
///
/// Masada kimse arama kutusuna "Öfke" yazmak icin klavye duzeni degistirmiyor;
/// "ofke" de bulmali. [searchNormalize]'in ustune uygulanir ve YALNIZCA
/// bellekteki eslestirmelerde kullanilir -- veritabani sutunlari katlanmamis
/// halde duruyor.
String searchFold(String value) {
  const folded = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
    'â': 'a',
    'î': 'i',
    'û': 'u',
  };
  final buffer = StringBuffer();
  for (final rune in searchNormalize(value).runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(folded[ch] ?? ch);
  }
  return buffer.toString();
}

/// Adi ekranda cevrilmis olan kayitlari GORUNEN ada gore suzer ve siralar.
///
/// Kutuphane kayitlari veritabaninda Ingilizce duruyor ama ekranda Turkce
/// gorunuyor; SQL'de aramak "hançer" yazan kullaniciya hicbir sey bulmazdi.
/// Ingilizce ad da eslesmeye devam ediyor -- kural kitabindan bakan DM
/// "longsword" yazabilsin.
///
/// [sortKey] verilmezse siralama yalnizca gorunen ada gore yapilir; buyulu
/// esyalarda oldugu gibi once baska bir eksen gerekiyorsa oradan gelir.
List<T> filterByShownName<T>(
  Iterable<T> rows,
  String query, {
  required String Function(T) shown,
  required String Function(T) original,
  int Function(T, T)? sortKey,
}) {
  final needle = searchFold(query.trim());
  final out =
      rows
          .where(
            (row) =>
                needle.isEmpty ||
                searchFold(shown(row)).contains(needle) ||
                searchFold(original(row)).contains(needle),
          )
          .toList()
        ..sort(sortKey ?? (a, b) => compareTurkish(shown(a), shown(b)));
  return out;
}

/// Turk alfabesine gore siralama.
///
/// `String.compareTo` kod birimlerine bakiyor; Turkce harfler Latin blogunun
/// disinda oldugu icin Ç, Ğ, İ, Ö, Ş, Ü hep Z'den SONRA geliyor ve liste
/// okuyana rastgele siralanmis gibi gorunuyor. Burada alfabedeki gercek sira
/// kullaniliyor.
///
/// Q, W ve X Turk alfabesinde yok ama SRD adlarinda geciyor ("Watchers");
/// sozluk gelenegine uyup Latin siralarina konuyorlar. Harf olmayan
/// karakterler (rakam, noktalama) hepsinden once gelir.
int compareTurkish(String a, String b) {
  const alphabet = 'abcçdefgğhıijklmnoöpqrsştuüvwxyz';
  final left = searchNormalize(a);
  final right = searchNormalize(b);
  final shortest = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < shortest; i++) {
    final l = alphabet.indexOf(left[i]);
    final r = alphabet.indexOf(right[i]);
    if (l == r) {
      // Ikisi de alfabede yoksa kod noktasi karari verir.
      if (l == -1 && left[i] != right[i]) {
        return left.codeUnitAt(i).compareTo(right.codeUnitAt(i));
      }
      continue;
    }
    // Harf olmayan karakter once gelir: "1. Seviye" sayilari basa toplasin.
    if (l == -1) return -1;
    if (r == -1) return 1;
    return l.compareTo(r);
  }
  return left.length.compareTo(right.length);
}
