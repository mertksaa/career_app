// lib/screens/job_seeker/favorites_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/favorites_provider.dart';
import '../../providers/auth_provider.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // FavoritesProvider'ı dinleyerek favori listesindeki değişikliklerden haberdar ol
    final favoritesProvider = Provider.of<FavoritesProvider>(context);
    final favoriteJobs = favoritesProvider.favoriteJobs;

    return Scaffold(
      body: favoritesProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : favoriteJobs.isEmpty
          ? const Center(
              child: Text(
                'No favorite jobs yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: favoriteJobs.length,
              itemBuilder: (context, index) {
                final job = favoriteJobs[index];
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
                    // Favoriler ekranında, ilanı favorilerden çıkarmak için dolu kalp göster
                    trailing: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        // Favorilerden çıkarma işlemi
                        final authProvider = Provider.of<AuthProvider>(
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
                    ),
                  ),
                );
              },
            ),
    );
  }
}
