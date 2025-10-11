import 'package:career_app/providers/favorites_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import './job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  late Future<List<Job>> _jobsFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    // Bu widget ağaca ilk eklendiğinde iş ilanlarını çekme işlemini başlat
    // `listen: false` ile `initState` içinde Provider'ı güvenle kullanabiliriz.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      _jobsFuture = _apiService.getJobs(authProvider.token!);
    } else {
      // Token yoksa (teorik olarak olmamalı), boş bir future ata
      _jobsFuture = Future.value([]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider'a erişim için
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      // Scaffold'ı buradan kaldırıyoruz, çünkü body'de kullanılacak.
      body: FutureBuilder<List<Job>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'İlanlar yüklenirken bir hata oluştu: ${snapshot.error}',
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('Gösterilecek iş ilanı bulunamadı.'),
            );
          }

          final jobs = snapshot.data!;
          // FavoritesProvider'daki değişiklikleri dinlemek için Consumer kullanıyoruz
          return Consumer<FavoritesProvider>(
            builder: (context, favoritesProvider, child) {
              return ListView.builder(
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  final job = jobs[index];
                  final isFav = favoritesProvider.isFavorite(
                    job.id,
                  ); // İlanın favori olup olmadığını kontrol et

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
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).primaryColorLight,
                        child: Icon(
                          Icons.work_outline,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      title: Text(
                        job.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text('${job.company}\n${job.location}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        // İkonu ve rengini favori durumuna göre dinamik olarak ayarla
                        icon: Icon(
                          isFav ? Icons.favorite : Icons.favorite_border,
                          color: isFav ? Colors.red : Colors.grey,
                        ),
                        onPressed: () {
                          // Favori durumunu değiştirme fonksiyonunu çağır
                          if (authProvider.token != null) {
                            favoritesProvider.toggleFavoriteStatus(
                              authProvider.token!,
                              job,
                            );
                          }
                        },
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                JobDetailScreen(jobId: job.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
