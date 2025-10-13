import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'employer_job_detail_screen.dart';
import '../../providers/snackbar_provider.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({Key? key}) : super(key: key);

  @override
  _MyJobsScreenState createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  Future<List<Job>>? _myJobsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  void _fetchJobs() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      setState(() {
        _myJobsFuture = _apiService.getMyJobs(authProvider.token!);
      });
    }
  }

  Future<void> _deleteJob(int jobId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token == null) return;

    final result = await _apiService.deleteJob(authProvider.token!, jobId);

    if (!mounted) return;

    Provider.of<SnackbarProvider>(
      context,
      listen: false,
    ).show(result['message'], isError: !result['success']);

    if (result['success']) {
      _fetchJobs();
    }
  }

  void _showDeleteConfirmation(int jobId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İlanı Sil'),
        content: Text(
          '"$title" başlıklı ilanı silmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            child: const Text('İptal'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          TextButton(
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteJob(jobId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // DÜZELTME: Scaffold widget'ını buradan kaldırıyoruz.
    return RefreshIndicator(
      onRefresh: () async => _fetchJobs(),
      child: FutureBuilder<List<Job>>(
        future: _myJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(
              child: Text('İlanlar yüklenirken bir hata oluştu.'),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('Henüz hiç ilan yayınlamadınız.'));
          }

          final jobs = snapshot.data!;
          return ListView.builder(
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(
                    job.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(job.location),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _showDeleteConfirmation(job.id, job.title),
                  ),
                  onTap: () {
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (context) =>
                                EmployerJobDetailScreen(job: job),
                          ),
                        )
                        .then((_) => _fetchJobs());
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
