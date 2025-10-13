// lib/screens/employer/cv_viewer_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart'; // Yeni paketi import et
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CvViewerScreen extends StatefulWidget {
  final int userId;
  final String userEmail;

  const CvViewerScreen({
    Key? key,
    required this.userId,
    required this.userEmail,
  }) : super(key: key);

  @override
  _CvViewerScreenState createState() => _CvViewerScreenState();
}

class _CvViewerScreenState extends State<CvViewerScreen> {
  Future<http.Response>? _pdfFuture;

  @override
  void initState() {
    super.initState();
    _fetchCv();
  }

  // PDF dosyasını byte olarak çeken fonksiyon
  void _fetchCv() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    final Uri cvUrl = Uri.parse(
      '${ApiService().getBaseUrl()}/cv/${widget.userId}',
    );

    // http.get ile isteği, token'ı header'a ekleyerek yapıyoruz
    setState(() {
      _pdfFuture = http.get(
        cvUrl,
        headers: {'Authorization': 'Bearer ${authProvider.token!}'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.userEmail} - CV')),
      body: FutureBuilder<http.Response>(
        future: _pdfFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.statusCode != 200) {
            return const Center(
              child: Text('CV yüklenirken bir hata oluştu veya CV bulunamadı.'),
            );
          }

          // Gelen cevabın body'sindeki byte verisini PDF görüntüleyiciye veriyoruz
          return SfPdfViewer.memory(snapshot.data!.bodyBytes);
        },
      ),
    );
  }
}
