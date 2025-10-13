// lib/providers/snackbar_provider.dart
import 'package:flutter/material.dart';

// Gösterilecek mesajın bilgilerini tutan bir sınıf
class SnackbarInfo {
  final String message;
  final bool isError;
  SnackbarInfo(this.message, {this.isError = false});
}

// Bu Provider, sadece gösterilecek mesaj değiştiğinde dinleyicileri uyaracak
class SnackbarProvider with ChangeNotifier {
  SnackbarInfo? _snackbarInfo;

  SnackbarInfo? get snackbarInfo => _snackbarInfo;

  // Dışarıdan bu fonksiyon çağrılarak yeni bir mesaj gösterilmesi tetiklenecek
  void show(String message, {bool isError = false}) {
    _snackbarInfo = SnackbarInfo(message, isError: isError);
    notifyListeners();
  }

  // Mesaj gösterildikten sonra temizlemek için
  void clear() {
    _snackbarInfo = null;
  }
}
