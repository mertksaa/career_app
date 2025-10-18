// lib/providers/snackbar_provider.dart
import 'package:flutter/material.dart';

class SnackbarProvider with ChangeNotifier {
  BuildContext? _context;

  // Hatanın olduğu 'setContext' metodu eklendi
  void setContext(BuildContext context) {
    _context = context;
  }

  // Snackbar göstermek için bir yardımcı fonksiyon
  void showSnackbar(String message, {bool isError = false}) {
    if (_context == null) {
      print('SnackbarProvider: Context ayarlanmamış!');
      return;
    }

    ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
