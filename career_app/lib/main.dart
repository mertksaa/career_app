import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'result_view.dart'; // result_view.dart ile aynı klasördeyse bu import yeterli

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Career AI Mobile',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Android emulator için backend host
  final String backendBase = 'http://10.0.2.2:8000';

  String _status = 'Hazır';
  String _resultPretty = '';

  Future<void> pingBackend() async {
    setState(() => _status = 'Ping atılıyor...');
    try {
      final res = await http
          .get(Uri.parse('$backendBase/ping'))
          .timeout(const Duration(seconds: 5));
      setState(() {
        _status = 'Ping cevabı: ${res.body}';
      });
    } catch (e) {
      setState(() => _status = 'Ping hatası: $e');
    }
  }

  Future<void> pickAndUploadPdf() async {
    setState(() => _status = 'Dosya seçiliyor...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) {
      setState(() => _status = 'Dosya seçilmedi.');
      return;
    }
    final path = result.files.single.path!;
    setState(() => _status = 'Yükleniyor: ${result.files.single.name}');
    try {
      var uri = Uri.parse('$backendBase/upload_cv');
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', path));
      var streamed = await request.send();
      var resp = await http.Response.fromStream(streamed);
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final textSnippet = body['text_snippet'] ?? '';
        setState(() => _status = 'CV yüklendi. Analiz yapılıyor...');
        await analyzeText(textSnippet);
      } else {
        setState(() => _status = 'Upload hata: ${resp.statusCode}');
      }
    } catch (e) {
      setState(() => _status = 'Upload hata: $e');
    }
  }

  Future<void> analyzeText(String text) async {
    setState(() => _status = 'Analiz yapılıyor (metin)...');
    try {
      var uri = Uri.parse('$backendBase/analyze');
      var res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        // JSON -> RoleResult listesi
        final rolesJson = (body['roles'] as List).cast<Map>();
        final roles = rolesJson.map((e) => RoleResult.fromMap(e)).toList();

        // Optional: prettified raw JSON (debug)
        setState(() {
          _resultPretty = const JsonEncoder.withIndent('  ').convert(body);
          _status = 'Analiz tamamlandı';
        });

        // Yeni sayfaya yönlendir ve sonuçları göster
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Analiz Sonuçları')),
              body: ResultView(roles: roles),
            ),
          ),
        );
      } else {
        setState(() => _status = 'Analiz hata: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _status = 'Analiz hata: $e');
    }
  }

  Future<void> analyzeManualSkills(List<String> skills) async {
    setState(() => _status = 'Analiz yapılıyor (manuel skills)...');
    try {
      var uri = Uri.parse('$backendBase/analyze');
      var res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'skills': skills}),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final rolesJson = (body['roles'] as List).cast<Map>();
        final roles = rolesJson.map((e) => RoleResult.fromMap(e)).toList();

        setState(() {
          _resultPretty = const JsonEncoder.withIndent('  ').convert(body);
          _status = 'Analiz tamamlandı';
        });

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Analiz Sonuçları')),
              body: ResultView(roles: roles),
            ),
          ),
        );
      } else {
        setState(() => _status = 'Analiz hata: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _status = 'Analiz hata: $e');
    }
  }

  void openManualSkillsDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Beceri Listele (virgülle ayır)'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'örn: python, sql, pandas',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final raw = controller.text;
                final list = raw
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
                Navigator.of(ctx).pop();
                analyzeManualSkills(list);
              },
              child: const Text('Analiz Et'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Career AI - Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: pingBackend,
              icon: const Icon(Icons.router),
              label: const Text('Backend Ping'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickAndUploadPdf,
              icon: const Icon(Icons.upload_file),
              label: const Text('CV (PDF) Yükle & Analiz Et'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: openManualSkillsDialog,
              icon: const Icon(Icons.edit),
              label: const Text('Manuel Beceri Gir & Analiz Et'),
            ),
            const SizedBox(height: 12),
            Text('Durum: $_status'),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _resultPretty.isEmpty
                      ? 'Analiz sonucu burada görünecek.'
                      : _resultPretty,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
