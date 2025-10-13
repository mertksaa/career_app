import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/applicant_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import './cv_viewer_screen.dart';

class ApplicantsScreen extends StatefulWidget {
  final int jobId;
  final String jobTitle;

  const ApplicantsScreen({
    Key? key,
    required this.jobId,
    required this.jobTitle,
  }) : super(key: key);

  @override
  _ApplicantsScreenState createState() => _ApplicantsScreenState();
}

class _ApplicantsScreenState extends State<ApplicantsScreen> {
  late Future<List<Applicant>> _applicantsFuture;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _applicantsFuture = ApiService().getApplicants(
        authProvider.token!,
        widget.jobId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.jobTitle} - Başvuranlar')),
      body: FutureBuilder<List<Applicant>>(
        future: _applicantsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Bu ilana henüz başvuru yapılmamış.'),
            );
          }

          final applicants = snapshot.data!;
          return ListView.builder(
            itemCount: applicants.length,
            itemBuilder: (context, index) {
              final applicant = applicants[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(applicant.email),
                  trailing: applicant.cvPath != null
                      ? ElevatedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text(
                            'CV Görüntüle',
                            style: TextStyle(color: Colors.white),
                          ),
                          onPressed: () {
                            // KESİN ÇÖZÜM: Yeni CV Görüntüleme ekranını açıyoruz
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => CvViewerScreen(
                                  userId: applicant.id,
                                  userEmail: applicant.email,
                                ),
                              ),
                            );
                          },
                        )
                      : const Text(
                          'CV Yok',
                          style: TextStyle(color: Colors.grey),
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
