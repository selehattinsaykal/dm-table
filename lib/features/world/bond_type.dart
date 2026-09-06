import '../../l10n/app_localizations.dart';

/// Dunya grafigi bag turleri artik DB'de (duzenlenebilir): satir tipi drift'in
/// urettigi `BondType`'tir. Bu dosya yalnizca ilk acilista tohumlanan
/// VARSAYILANLARI ve renk secici paletini saglar.

/// Bir tohum bag turu tanimi.
typedef BondSeed = ({String code, String name, int color, int sort});

/// Ilk acilista eklenecek varsayilan bag turleri (L10n'a gore adlandirilir).
List<BondSeed> defaultBondTypes(L10n l10n) => [
  (code: 'road', name: l10n.bondRoad, color: 0xFF9DB0DA, sort: 0),
  (code: 'friendship', name: l10n.bondFriendship, color: 0xFF66BB6A, sort: 1),
  (code: 'enmity', name: l10n.bondEnmity, color: 0xFFEF5350, sort: 2),
  (code: 'trade', name: l10n.bondTrade, color: 0xFFFFB300, sort: 3),
  (code: 'family', name: l10n.bondFamily, color: 0xFFAB47BC, sort: 4),
  (code: 'alliance', name: l10n.bondAlliance, color: 0xFF42A5F5, sort: 5),
  (code: 'rivalry', name: l10n.bondRivalry, color: 0xFFFF7043, sort: 6),
  (code: 'love', name: l10n.bondLove, color: 0xFFEC407A, sort: 7),
  (code: 'vassalage', name: l10n.bondVassalage, color: 0xFF26A69A, sort: 8),
  // Fraksiyon uyeligi. Mevcut kampanyalar bunu v50 migration'inda aliyor
  // (`ensureDefaultBondTypes` yalnizca TAMAMEN bos tabloyu tohumluyor);
  // burasi taze kampanyalarin cevirili surumu.
  (code: 'membership', name: l10n.bondMembership, color: 0xFF8D6E63, sort: 9),
];

/// Bilinmeyen/silinmis bir tur koduna dusen kenarlar icin yedek renk.
const int kBondFallbackColor = 0xFF9DB0DA;

/// Renk secicideki hazir paleti.
const List<int> kBondPalette = [
  0xFF9DB0DA,
  0xFF66BB6A,
  0xFFEF5350,
  0xFFFFB300,
  0xFFAB47BC,
  0xFF42A5F5,
  0xFFFF7043,
  0xFFEC407A,
  0xFF26A69A,
  0xFF8D6E63,
  0xFF7E57C2,
  0xFF29B6F6,
  0xFFD4E157,
  0xFFFFCA28,
  0xFFEC7063,
  0xFF78909C,
  0xFFFFFFFF,
  0xFF90A4AE,
  0xFFF06292,
  0xFF4DB6AC,
];
