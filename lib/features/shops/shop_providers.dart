import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/custom_content_repository.dart';
import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/shop_repository.dart';

final shopRepositoryProvider = Provider<ShopRepository>(
  (ref) => ShopRepository(ref.watch(databaseProvider)),
);

final customContentProvider = Provider<CustomContentRepository>(
  (ref) => CustomContentRepository(ref.watch(databaseProvider)),
);

final shopsProvider = StreamProvider<List<Shop>>(
  (ref) => ref.watch(shopRepositoryProvider).watchShops(),
);

final shopProvider = StreamProvider.family<Shop?, String>(
  (ref, id) => ref.watch(shopRepositoryProvider).watchShop(id),
);

final shopStockProvider = StreamProvider.family<List<ShopStockData>, String>(
  (ref, shopId) => ref.watch(shopRepositoryProvider).watchStock(shopId),
);

/// Magazanin cozulmus satirlari (ad + nihai fiyat).
///
/// Stok ya da magaza ayarlari degistiginde yeniden hesaplanmasi icin ikisini
/// de izliyor. Dikkat: `.future` DEGIL, AsyncValue izleniyor -- bir akisin
/// `.future`'ini await etmek yalnizca ilk degeri yakaliyor, sonraki
/// silme/ekleme emisyonlarinda saglam sekilde yeniden calismiyor. Silme
/// "sonradan etki ediyor / olmuyor" hatasinin sebebi buydu.
final shopEntriesProvider = FutureProvider.family<List<ShopEntry>, String>((
  ref,
  shopId,
) async {
  // Her iki akisin her emisyonunda bu saglayici yeniden calissin.
  ref.watch(shopProvider(shopId));
  ref.watch(shopStockProvider(shopId));
  return ref.watch(shopRepositoryProvider).entries(shopId);
});
