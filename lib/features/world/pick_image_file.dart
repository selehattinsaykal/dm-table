import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart';

/// Harita gorseli secer.
///
/// Platforma gore farkli arayuz: telefonda galeri (kullanicinin haritalari
/// zaten fotograflarinda), masaustunde dosya secme penceresi (galeri kavrami
/// yok, haritalar klasorlerde durur).
///
/// [typeLabel] masaustu dosya penceresindeki tur filtresinin adidir; cagiran
/// ekran `L10n.of(context).fileTypeImage` gecer (burada context yok).
Future<File?> pickImageFile({String? typeLabel}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked == null ? null : File(picked.path);
  }

  final picked = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: typeLabel,
        extensions: const ['png', 'jpg', 'jpeg', 'webp'],
      ),
    ],
  );
  return picked == null ? null : File(picked.path);
}

/// Bir klasor sec (toplu gorsel ice aktarma icin). Masaustunde dosya-secme
/// penceresi; mobilde desteklenmezse null doner.
Future<String?> pickDirectoryPath() => getDirectoryPath();

/// Video dosyasi secer (Kayitlar video blogu icin). Telefonda galeri,
/// masaustunde dosya-secme penceresi. [typeLabel] icin bkz. [pickImageFile].
Future<File?> pickVideoFile({String? typeLabel}) async {
  if (Platform.isAndroid || Platform.isIOS) {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    return picked == null ? null : File(picked.path);
  }

  final picked = await openFile(
    acceptedTypeGroups: [
      XTypeGroup(
        label: typeLabel,
        extensions: const ['mp4', 'mov', 'mkv', 'webm', 'avi', 'm4v'],
      ),
    ],
  );
  return picked == null ? null : File(picked.path);
}
