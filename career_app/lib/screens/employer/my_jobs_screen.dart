// lib/screens/employer/my_jobs_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/snackbar_provider.dart';
import '../../services/api_service.dart';
import './edit_job_screen.dart';
import './employer_job_detail_screen.dart';

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({Key? key}) : super(key: key);

  @override
  _MyJobsScreenState createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  late Future<List<Job>> _myJobsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _myJobsFuture = _fetchMyJobs();
  }

  Future<List<Job>> _fetchMyJobs() {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) {
      return Future.value([]); // Token yoksa boş liste döndür
    }
    // Future'ı state'te tutarak yeniden build'lerde tekrar çağrılmasını engelle
    return _apiService.getMyJobs(token);
  }

  Future<void> _refreshJobs() async {
    // Yenileme tetiklendiğinde Future'ı yeniden ayarla
    setState(() {
      _myJobsFuture = _fetchMyJobs();
    });
  }

  Future<void> _deleteJob(int jobId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete posting'),
        content: const Text('Are you sure you want to delete this posting?'),
        actions: [
          TextButton(
            child: const Text('cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('delete', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldDelete == null || !shouldDelete) {
      return;
    }

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    final response = await _apiService.deleteJob(token!, jobId);

    if (!mounted) return;

    // HATA DÜZELTMESİ: '.show' -> '.showSnackbar' olarak değiştirildi
    Provider.of<SnackbarProvider>(
      context,
      listen: false,
    ).showSnackbar(response['message'], isError: !response['success']);

    if (response['success']) {
      _refreshJobs(); // Silme başarılıysa listeyi yenile
    }
  }

  void _navigateToDetail(Job job) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EmployerJobDetailScreen(job: job),
          ),
        )
        .then((_) {
          // Detaydan veya düzenleme ekranından geri dönüldüğünde
          // olası değişiklikleri görmek için listeyi yenile
          _refreshJobs();
        });
  }

  void _navigateToEdit(Job job) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => EditJobScreen(job: job)))
        .then((_) {
          // Düzenleme ekranından geri dönüldüğünde listeyi yenile
          _refreshJobs();
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshJobs,
        child: FutureBuilder<List<Job>>(
          future: _myJobsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error occured: ${snapshot.error}'));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Text(
                  'No postings yet.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              );
            }

            final jobs = snapshot.data!;
            return ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    title: Text(
                      job.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(job.location),
                    onTap: () => _navigateToDetail(job),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                          ),
                          onPressed: () => _navigateToEdit(job),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () => _deleteJob(job.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
