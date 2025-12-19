// lib/screens/job_seeker/job_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../models/skill_analysis_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/snackbar_provider.dart';
import '../../services/api_service.dart';
import '../../providers/applications_provider.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;
  const JobDetailScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>> _combinedFuture;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _combinedFuture = _loadAllData();
  }

  Future<Map<String, dynamic>> _loadAllData() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) throw Exception('Giriş yapılmamış.');

    final jobFuture = _apiService.getJobDetails(token, widget.jobId);
    final analysisFuture = _apiService.getSkillAnalysis(token, widget.jobId);
    final results = await Future.wait([jobFuture, analysisFuture]);

    return {
      'job': results[0] as Job?,
      'analysis': results[1] as SkillAnalysis?,
    };
  }

  Future<void> _applyForJob(Job job) async {
    setState(() => _isApplying = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final snackbar = Provider.of<SnackbarProvider>(context, listen: false);
    // <<< YENİ: ApplicationsProvider'ı al >>>
    final applicationsProvider = Provider.of<ApplicationsProvider>(
      context,
      listen: false,
    );

    if (!authProvider.hasCv) {
      snackbar.showSnackbar(
        'Upload your CV in your profile to apply for jobs.',
        isError: true,
      );
      setState(() => _isApplying = false);
      return;
    }

    final response = await _apiService.applyForJob(authProvider.token!, job.id);
    if (mounted) {
      snackbar.showSnackbar(response['message'], isError: !response['success']);

      // <<< YENİ: Başvuru başarılıysa listeyi yenile >>>
      if (response['success'] && authProvider.token != null) {
        // Arka planda yenilemeyi tetikle, bekleme
        applicationsProvider.fetchApplications(authProvider.token!);
      }

      setState(() => _isApplying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _combinedFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Hata oluştu: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!['job'] == null)
            return const Center(child: Text('İlan bulunamadı.'));

          final Job job = snapshot.data!['job'];
          final SkillAnalysis? analysis = snapshot.data!['analysis'];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- 1. İLAN BİLGİ KARTI (Şirket adı kaldırıldı) ---
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
                          job.title ?? 'Başlık Yok',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // *** DÜZELTME (İSTEK): Şirket adı buradan kaldırıldı ***
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              // Konum taşmaması için Expanded
                              child: Text(
                                job.location ?? 'No location',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. YETENEK ANALİZİ KARTI ---
                if (analysis != null &&
                    (analysis.userSkillsFound || analysis.jobSkillsFound))
                  _buildSkillAnalysisCard(analysis),
                if (analysis != null && !analysis.userSkillsFound)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: Text(
                        'Upload your CV to see skill analysis for this job.',
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // *** YENİ (İSTEK): ŞİRKET BİLGİLERİ KARTI ***
                _buildCompanyInfoCard(job.company),
                // Şirket bilgisi varsa SizedBox ekle
                if (job.company != null && job.company!.isNotEmpty)
                  const SizedBox(height: 16),

                // --- 4. AÇIKLAMA KARTI ---
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
                          'Job Description',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 20, thickness: 1),
                        Text(
                          job.description ?? 'No Description provided.',
                          style: const TextStyle(fontSize: 15, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- 5. BAŞVUR BUTONU ---
                if (authProvider.user?.role == 'job_seeker')
                  ElevatedButton.icon(
                    onPressed: _isApplying || !authProvider.hasCv
                        ? null
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
                          ? 'Applying...'
                          : (authProvider.hasCv
                                ? 'Apply Now'
                                : 'CV required to apply'),
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

  // --- YETENEK ANALİZ KARTI WIDGET'I ---
  Widget _buildSkillAnalysisCard(SkillAnalysis analysis) {
    Color scoreColor = analysis.matchScore >= 0.7
        ? Colors.green
        : (analysis.matchScore >= 0.4 ? Colors.orange : Colors.red);
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
              'Carrier Fit Analysis',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),
            Text(
              'Match score: ${(analysis.matchScore * 100).toStringAsFixed(0)}%',
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
            _buildSkillChipList(
              'matched Skills',
              analysis.matchedSkills,
              Colors.green[700]!,
              Icons.check_circle_outline,
            ),
            const SizedBox(height: 16),
            _buildSkillChipList(
              'missing Skills',
              analysis.missingSkills,
              Colors.red[700]!,
              Icons.warning_amber_rounded,
            ),
          ],
        ),
      ),
    );
  }

  // --- YETENEK ETİKET (CHIP) LİSTESİ WIDGET'I ---
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
            title == 'missing Skills'
                ? 'All skills matched from your CV!'
                : 'There are no matched skills from your CV.',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          )
        else
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: skills
                .map(
                  (skill) => Chip(
                    label: Text(
                      skill,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    backgroundColor: color.withOpacity(0.1),
                    side: BorderSide(color: color.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  // *** YENİ (İSTEK): Şirket Bilgileri Kartı Widget'ı ***
  Widget _buildCompanyInfoCard(String? companyInfo) {
    // Eğer şirket bilgisi yoksa veya boşsa, kartı hiç gösterme
    if (companyInfo == null || companyInfo.trim().isEmpty) {
      return const SizedBox.shrink(); // Boş widget döndür
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      // margin: const EdgeInsets.only(bottom: 16), // Altına SizedBox eklendi
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20, thickness: 1),
            Text(
              companyInfo,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
