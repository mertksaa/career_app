// lib/screens/employer/cv_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CvViewerScreen extends StatelessWidget {
  final int userId;
  final String userEmail;

  const CvViewerScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final apiService = ApiService();

    final cvUrl = apiService.getApplicantCvUrl(userId);

    if (token == null) {
      return Scaffold(
        appBar: AppBar(title: Text('$userEmail CV\'si')),
        body: const Center(
          child: Text('Giriş yapılmamış veya token geçersiz.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('$userEmail CV\'si')),
      body: SfPdfViewer.network(
        cvUrl,
        headers: {'Authorization': 'Bearer $token'},

        // <<< HATA DÜZELTMESİ (void callback) >>>
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          // Hata durumunda konsola yaz ve SnackBar göster
          print("CV yüklenemedi: ${details.error} - ${details.description}");

          // 'context'in hala geçerli olup olmadığını kontrol et
          if (ScaffoldMessenger.of(context).mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('CV yüklenemedi: ${details.description}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5), // Uzun süre kalsın
              ),
            );
          }

          // Opsiyonel: Hata sonrası sayfayı kapat
          // if (Navigator.of(context).canPop()) {
          //   Navigator.of(context).pop();
          // }

          // HİÇBİR ŞEY DÖNDÜRME (return yok)
        },
        // <<< DÜZELTME SONU >>>
      ),
    );
  }
}
