import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/applicant_model.dart'; // Modelin güncel olduğundan emin ol
import 'package:percent_indicator/circular_percent_indicator.dart';

class JobApplicantsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;

  const JobApplicantsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<JobApplicantsScreen> createState() => _JobApplicantsScreenState();
}

class _JobApplicantsScreenState extends State<JobApplicantsScreen> {
  late Future<List<Applicant>> _applicantsFuture;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _applicantsFuture = ApiService().getApplicants(auth.token!, widget.jobId);
  }

  // Manuel Profil Detaylarını Gösteren Pencere
  void _showManualProfileDialog(BuildContext context, Applicant app) {
    // Backend'den gelen veri yapısını güvenli şekilde alıyoruz
    final manualInfo = app.profileData?['manual_info'] ?? {};

    final title = manualInfo['title'] ?? 'No Title';
    final summary = manualInfo['summary'] ?? 'No Summary';
    final skills = manualInfo['raw_skills'] ?? 'No Skills';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.account_circle, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSectionTitle("Skills"),
              Text(skills, style: const TextStyle(fontSize: 15)),
              const Divider(height: 24),
              _buildSectionTitle("Experience & Summary"),
              Text(summary, style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).primaryColor,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Applicants: ${widget.jobTitle}"),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: FutureBuilder<List<Applicant>>(
        future: _applicantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No applicants yet."));
          }

          final applicants = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: applicants.length,
            separatorBuilder: (ctx, i) => const Divider(),
            itemBuilder: (context, index) {
              final app = applicants[index];
              final score = app.matchScore;

              Color scoreColor = Colors.red;
              if (score >= 0.70)
                scoreColor = Colors.green;
              else if (score >= 0.40)
                scoreColor = Colors.orange;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    app.email.isNotEmpty ? app.email[0].toUpperCase() : "?",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  app.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Applied: ${app.applicationDate.split('T')[0]}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Skor Halkası
                    CircularPercentIndicator(
                      radius: 22.0,
                      lineWidth: 4.0,
                      percent: score > 1.0 ? 1.0 : score,
                      center: Text(
                        "%${(score * 100).toInt()}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      progressColor: scoreColor,
                      backgroundColor: Colors.grey[100]!,
                    ),
                    const SizedBox(width: 12),

                    // Butonlar: PDF ise İndir, Manuel ise Görüntüle
                    if (app.hasCv == 2)
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          color: Colors.orange,
                        ),
                        tooltip: "View Profile",
                        onPressed: () => _showManualProfileDialog(context, app),
                      )
                    else if (app.hasCv == 1)
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.blue),
                        tooltip: "Download CV",
                        onPressed: () {
                          final url = ApiService().getApplicantCvUrl(
                            app.userId,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Downloading CV...")),
                          );
                          print("CV Link: $url");
                          // Not: Gerçek cihazda url_launcher kullanmalısın
                        },
                      )
                    else
                      const Tooltip(
                        message: "No CV",
                        child: Icon(Icons.highlight_off, color: Colors.grey),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
