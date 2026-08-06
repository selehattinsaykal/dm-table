import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import 'player/player_app.dart';

/// Oyuncu panelinin entrypoint'i.
///
/// Web'e derlenip DM uygulamasinin icine gomulur ve LAN uzerinden servis
/// edilir:
///
///   flutter build web -t lib/main_player.dart --output=assets/player_web
///
/// DIKKAT: Bu dosyanin import grafigine `drift`, `dart:io` ya da baska bir
/// native bagimlilik girmemeli; oyuncu paneli tarayicida calisiyor.
void main() {
  // Sunucu adresi sayfanin kendi adresidir: paneli zaten oradan indirdik.
  final uri = Uri.parse(web.window.location.href);

  runApp(
    ProviderScope(
      child: PlayerApp(
        serverUri: Uri(scheme: uri.scheme, host: uri.host, port: uri.port),
      ),
    ),
  );
}
