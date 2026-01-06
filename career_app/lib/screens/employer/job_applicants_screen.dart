import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/applicant_model.dart';
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
              if (score >= 0.85)
                scoreColor = Colors.green;
              else if (score >= 0.50)
                scoreColor = Colors.orange;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    app.email.isNotEmpty ? app.email[0].toUpperCase() : "?",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  app.email,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Date: ${app.applicationDate.split('T')[0]}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularPercentIndicator(
                      radius: 20.0,
                      lineWidth: 4.0,
                      percent: score > 1.0 ? 1.0 : score,
                      center: Text(
                        "%${(score * 100).toInt()}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      progressColor: scoreColor,
                      backgroundColor: Colors.grey[100]!,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.download, color: Colors.blue),
                      onPressed: () {
                        // Senin servisindeki fonksiyonu çağırıyoruz
                        final url = ApiService().getApplicantCvUrl(app.userId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("CV Link: $url")),
                        );
                        print("CV URL: $url");
                      },
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
