// lib/screens/job_seeker/job_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/api_service.dart';
import './job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen> {
  List<Job> _jobs = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchJobs(); // İlk açılışta tüm ilanları çek
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // API'den ilanları çeken ana fonksiyon
  Future<void> _fetchJobs({String? query}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      final apiService = ApiService();
      final fetchedJobs = await apiService.getJobs(
        authProvider.token!,
        searchQuery: query,
      );
      if (mounted) {
        setState(() {
          _jobs = fetchedJobs;
          _isLoading = false;
        });
      }
    }
  }

  // Kullanıcı yazmayı bıraktıktan sonra aramayı tetikleyen fonksiyon
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchJobs(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Column(
      children: [
        // ARAMA ÇUBUĞU
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'İlanlarda Ara...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        // İLAN LİSTESİ
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _jobs.isEmpty
              ? const Center(child: Text('Aramanızla eşleşen ilan bulunamadı.'))
              : RefreshIndicator(
                  onRefresh: _fetchJobs,
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      return ListView.builder(
                        itemCount: _jobs.length,
                        itemBuilder: (context, index) {
                          final job = _jobs[index];
                          final isFav = favoritesProvider.isFavorite(job.id);
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
                                backgroundColor: Theme.of(
                                  context,
                                ).primaryColorLight,
                                child: Icon(
                                  Icons.work_outline,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              title: Text(
                                job.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text('${job.company}\n${job.location}'),
                              isThreeLine: true,
                              trailing: IconButton(
                                icon: Icon(
                                  isFav
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: isFav ? Colors.red : Colors.grey,
                                ),
                                onPressed: () {
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
                  ),
                ),
        ),
      ],
    );
  }
}
