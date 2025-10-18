// lib/screens/job_seeker/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../models/skill_analysis_model.dart'; // YENİ IMPORT
import '../../providers/auth_provider.dart';
import '../../providers/snackbar_provider.dart'; // YENİ IMPORT
import '../../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;

  // Constructor'ı jobId alacak şekilde güncelle
  const JobDetailScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final ApiService _apiService = ApiService();

  // Hem ilan detayı hem de analiz için Future'lar
  late Future<Job?> _jobFuture;
  late Future<SkillAnalysis?> _analysisFuture;
  late Future<Map<String, dynamic>> _combinedFuture;

  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    // Sayfa açıldığında her iki veriyi de aynı anda çek
    _combinedFuture = _loadAllData();
  }

  // İki API çağrısını paralel olarak yapan fonksiyon
  Future<Map<String, dynamic>> _loadAllData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      throw Exception('Giriş yapılmamış.');
    }

    // İki future'ı ayarla
    _jobFuture = _apiService.getJobDetails(token, widget.jobId);
    _analysisFuture = _apiService.getSkillAnalysis(token, widget.jobId);

    // İkisinin de bitmesini bekle
    final results = await Future.wait([_jobFuture, _analysisFuture]);

    return {
      'job': results[0] as Job?,
      'analysis': results[1] as SkillAnalysis?,
    };
  }

  // İlana başvurma fonksiyonu
  Future<void> _applyForJob(Job job) async {
    setState(() {
      _isApplying = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final snackbar = Provider.of<SnackbarProvider>(context, listen: false);

    // CV'si olup olmadığını AuthProvider'dan kontrol et (ekstra güvenlik)
    if (!authProvider.hasCv) {
      snackbar.showSnackbar(
        'Başvuru yapabilmek için önce CV yüklemelisiniz.',
        isError: true,
      );
      setState(() {
        _isApplying = false;
      });
      return;
    }

    final response = await _apiService.applyForJob(authProvider.token!, job.id);

    if (mounted) {
      snackbar.showSnackbar(response['message'], isError: !response['success']);
      setState(() {
        _isApplying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider'ı 'Başvur' butonu ve 'hasCv' kontrolü için al
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('İlan Detayı')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _combinedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!['job'] == null) {
            return const Center(child: Text('İlan bulunamadı.'));
          }

          // Veriler başarıyla çekildi
          final Job job = snapshot.data!['job'];
          final SkillAnalysis? analysis = snapshot.data!['analysis'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. İLAN BİLGİ KARTI ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.business,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              job.company,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              job.location,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. YETENEK ANALİZİ KARTI (YENİ) ---
                if (analysis != null &&
                    (analysis.userSkillsFound || analysis.jobSkillsFound))
                  _buildSkillAnalysisCard(analysis),

                // CV'si yoksa veya ilanda yetenek yoksa uyarı göster
                if (analysis != null && !analysis.userSkillsFound)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: Text(
                        'Yetenek analizi için lütfen profilinizden CV yükleyin.',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // --- 3. AÇIKLAMA KARTI ---
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'İlan Açıklaması',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 20, thickness: 1),
                        Text(
                          job.description ?? 'Açıklama bulunmuyor.',
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- 4. BAŞVUR BUTONU ---
                if (authProvider.user?.role == 'job_seeker')
                  ElevatedButton.icon(
                    onPressed: _isApplying || !authProvider.hasCv
                        ? null // CV'si yoksa veya başvuruyorsa butonu kilitle
                        : () => _applyForJob(job),
                    icon: _isApplying
                        ? Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(2.0),
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : Icon(
                            authProvider.hasCv
                                ? Icons.check_circle_outline
                                : Icons.warning_amber_rounded,
                          ),
                    label: Text(
                      _isApplying
                          ? 'Başvuruluyor...'
                          : (authProvider.hasCv
                                ? 'Hemen Başvur'
                                : 'Başvuru için CV Gerekli'),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- YETENEK ANALİZ KARTI WIDGET'I (YENİ) ---
  Widget _buildSkillAnalysisCard(SkillAnalysis analysis) {
    // Uygunluk skoru rengini belirle
    Color scoreColor;
    if (analysis.matchScore >= 0.7) {
      scoreColor = Colors.green;
    } else if (analysis.matchScore >= 0.4) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kariyer Analizi',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),

            // Uygunluk Skoru
            Text(
              'Uygunluk Skoru: ${(analysis.matchScore * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: scoreColor,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: analysis.matchScore,
                backgroundColor: scoreColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                minHeight: 10,
              ),
            ),
            const SizedBox(height: 20),

            // Eşleşen Yetenekler
            _buildSkillChipList(
              'Eşleşen Yetenekleriniz',
              analysis.matchedSkills,
              Colors.green[700]!,
              Icons.check_circle_outline,
            ),

            const SizedBox(height: 16),

            // Eksik Yetenekler
            _buildSkillChipList(
              'Eksik Yetenekler',
              analysis.missingSkills,
              Colors.red[700]!,
              Icons.warning_amber_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // --- YETENEK ETİKET (CHIP) LİSTESİ WIDGET'I (YENİ) ---
  Widget _buildSkillChipList(
    String title,
    List<String> skills,
    Color color,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (skills.isEmpty)
          Text(
            title == 'Eksik Yetenekler'
                ? 'Tüm gereksinimleri karşılıyorsunuz. Harika!'
                : 'CV\'niz ile ilandan eşleşen bir yetenek bulunamadı.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          )
        else
          Wrap(
            spacing: 8.0, // Yatay boşluk
            runSpacing: 4.0, // Dikey boşluk
            children: skills.map((skill) {
              return Chip(
                label: Text(
                  skill,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
                backgroundColor: color.withOpacity(0.1),
                side: BorderSide(color: color.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              );
            }).toList(),
          ),
      ],
    );
  }
}
