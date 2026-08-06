import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/character_image_store.dart';
import 'character_providers.dart';

/// Karakter portresi (yuvarlak).
///
/// Portre yolu yoksa ya da dosya bulunamazsa adin bas harfine, o da yoksa
/// kisi ikonuna duser. Portre diskte durdugu icin cozumleme asenkron; yukleme
/// sirasinda da bas harf gosterilir (bos daire yanip sonmez).
class CharacterAvatar extends ConsumerWidget {
  const CharacterAvatar({
    required this.portraitPath,
    required this.name,
    this.radius = 20,
    super.key,
  });

  /// `Characters.portraitPath` / `Npcs.portraitPath` (uygulama klasorune
  /// gore GORELI yol).
  final String? portraitPath;

  /// Portre yoksa bas harfi gosterilecek ad.
  final String name;

  final double radius;

  /// Portresiz durumda gosterilecek yedek.
  Widget get _fallback => name.trim().isEmpty
      ? Icon(Icons.person, size: radius)
      : Text(name.trim().characters.first.toUpperCase());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = portraitPath;
    if (path == null || path.isEmpty) {
      return CircleAvatar(radius: radius, child: _fallback);
    }

    final store = ref.watch(characterRepositoryProvider).portraits;
    return FutureBuilder<File>(
      future: store.resolve(path),
      builder: (context, snap) {
        final file = snap.data;
        if (file == null || !file.existsSync()) {
          return CircleAvatar(radius: radius, child: _fallback);
        }
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      },
    );
  }
}

/// Portresi ayri bir depodan gelen kayitlar (NPC'ler) icin.
///
/// [CharacterAvatar] karakter deposunu kullanir; NPC portreleri
/// `WorldRepository.portraits`'te durur.
class StoredAvatar extends StatelessWidget {
  const StoredAvatar({
    required this.store,
    required this.portraitPath,
    required this.name,
    this.radius = 20,
    super.key,
  });

  final CharacterImageStore store;
  final String? portraitPath;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = portraitPath;
    final fallback = name.trim().isEmpty
        ? Icon(Icons.person, size: radius)
        : Text(name.trim().characters.first.toUpperCase());

    if (path == null || path.isEmpty) {
      return CircleAvatar(radius: radius, child: fallback);
    }
    return FutureBuilder<File>(
      future: store.resolve(path),
      builder: (context, snap) {
        final file = snap.data;
        if (file == null || !file.existsSync()) {
          return CircleAvatar(radius: radius, child: fallback);
        }
        return CircleAvatar(radius: radius, backgroundImage: FileImage(file));
      },
    );
  }
}
