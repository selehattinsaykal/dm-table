import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'states.dart';

/// [AsyncValue] icin ortak yukleme/hata gorunumu (DM uygulamasi).
///
/// Bu dosya bilincli olarak `ui.dart` disa aktarim listesinde DEGIL: `L10n`e
/// bagli oldugu icin oyuncu web paketine sizmasin (panelin kendi
/// [PlayerL10n]'i var). DM ekranlari dogrudan import eder.
///
/// Neden var: ekranlarin cogunda hata dali `Center(child: Text('$e'))` idi —
/// kullaniciya ham istisna metni gosteriyor, cikis yolu birakmiyordu. Tek bir
/// yerden yonetince hem gorunum tutarli oluyor hem de "tekrar dene" her
/// ekranda ayni sekilde calisiyor.
///
/// [onRetry] genelde `() => ref.invalidate(birProvider)` olur.
Widget asyncView<T>(
  BuildContext context,
  AsyncValue<T> value, {
  required Widget Function(T data) data,
  Widget? loading,
  VoidCallback? onRetry,
}) {
  final l10n = L10n.of(context);
  return value.when(
    data: data,
    loading: () => loading ?? AppLoading(label: l10n.stateLoading),
    error: (error, stack) => AppErrorState(
      title: l10n.stateErrorTitle,
      message: l10n.stateErrorMessage,
      detail: '$error',
      detailLabel: l10n.stateErrorDetail,
      onRetry: onRetry,
      retryLabel: l10n.stateRetry,
    ),
  );
}
