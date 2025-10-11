// lib/screens/job_seeker/job_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/applications_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;

  const JobDetailScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  _JobDetailScreenState createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<Job?> _jobDetailFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _jobDetailFuture = _apiService.getJobDetails(
        authProvider.token!,
        widget.jobId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SADECE BİR TANE, EN DIŞTA SCAFFOLD KULLANIYORUZ
      appBar: AppBar(title: const Text('İlan Detayı')),
      body: FutureBuilder<Job?>(
        future: _jobDetailFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('İlan detayları yüklenemedi.'));
          }

          final job = snapshot.data!;

          // İç içe Scaffold yerine doğrudan sayfa içeriğini döndürüyoruz.
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // AppBar'daki favori butonu için Consumer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              job.title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Consumer<FavoritesProvider>(
                            builder: (context, favoritesProvider, child) {
                              final isFav = favoritesProvider.isFavorite(
                                job.id,
                              );
                              return IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav ? Colors.red : Colors.grey,
                                  size: 30,
                                ),
                                onPressed: () {
                                  final authProvider =
                                      Provider.of<AuthProvider>(
                                        context,
                                        listen: false,
                                      );
                                  if (authProvider.token != null) {
                                    favoritesProvider.toggleFavoriteStatus(
                                      authProvider.token!,
                                      job,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.company,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            job.location,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'İlan Detayları',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Text(
                        job.description ?? 'Açıklama bulunmuyor.',
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              // Başvur butonu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Consumer<ApplicationsProvider>(
                  builder: (context, applicationsProvider, child) {
                    final hasApplied = applicationsProvider.hasApplied(job.id);
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: hasApplied
                              ? Colors.grey
                              : Theme.of(context).primaryColor,
                        ),
                        onPressed: hasApplied
                            ? null
                            : () async {
                                final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false,
                                );
                                if (!authProvider.hasCv) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Lütfen önce profilinize CV yükleyin.',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }
                                final success = await applicationsProvider
                                    .applyForJob(authProvider.token!, job);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success
                                          ? 'Başvurunuz alındı!'
                                          : 'Başvuru başarısız oldu.',
                                    ),
                                    backgroundColor: success
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                );
                              },
                        child: Text(
                          hasApplied ? 'Daha Önce Başvuruldu' : 'Başvur',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
