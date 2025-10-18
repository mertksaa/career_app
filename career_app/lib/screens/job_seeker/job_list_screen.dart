// lib/screens/job_seeker/job_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Profil ekranına yönlendirme (Provider aracılığıyla)
import 'package:career_app/screens/main_nav_screen.dart';

import '../../models/job_model.dart';
import '../../models/recommended_job_model.dart'; // YENİ MODEL
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/api_service.dart';
import './job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

// Düzeltme: Sekmeli bir arayüz için 'TickerProviderStateMixin' ekliyoruz
class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Veri listeleri
  List<Job> _allJobs = [];
  List<RecommendedJob> _recommendedJobs = [];

  // Yükleme durumları
  bool _isRecommendedLoading = true;
  bool _isAllJobsLoading = true;
  bool _hasCv = false;

  // 'Tüm İlanlar' sekmesi için arama araçları
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // AuthProvider'dan CV durumunu al
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _hasCv = auth.hasCv;

    // Verileri çek
    _fetchRecommendedData();
    _fetchAllJobsData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // --- Veri Çekme Fonksiyonları ---

  // Önerilen İlanları Çek
  Future<void> _fetchRecommendedData() async {
    if (!mounted) return;
    setState(() {
      _isRecommendedLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();

    // Sadece CV'si varsa önerileri çek
    if (_hasCv) {
      try {
        final fetchedJobs = await apiService.getRecommendedJobs(
          authProvider.token!,
        );
        if (mounted) {
          setState(() {
            _recommendedJobs = fetchedJobs;
          });
        }
      } catch (e) {
        print("Error fetching recommended data: $e");
      }
    }
    // CV'si olmasa bile yüklemeyi bitir (uyarıyı göstermek için)
    if (mounted) {
      setState(() {
        _isRecommendedLoading = false;
      });
    }
  }

  // Tüm İlanları Çek
  Future<void> _fetchAllJobsData({String? query}) async {
    if (!mounted) return;
    setState(() {
      _isAllJobsLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();

    try {
      final fetchedJobs = await apiService.getJobs(
        authProvider.token!,
        searchQuery: query,
      );
      if (mounted) {
        setState(() {
          _allJobs = fetchedJobs;
        });
      }
    } catch (e) {
      print("Error fetching all jobs data: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isAllJobsLoading = false;
        });
      }
    }
  }

  // 'Tüm İlanlar' sekmesi için arama geciktirici
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchAllJobsData(query: query);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. SEKMELER (TABS)
        TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(icon: Icon(Icons.star_outline), text: 'Size Özel'),
            Tab(icon: Icon(Icons.travel_explore_outlined), text: 'Tüm İlanlar'),
          ],
        ),
        // 2. SEKMELİ İÇERİK (TABBARVIEW)
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- SEKME 1: SİZE ÖZEL ---
              _isRecommendedLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRecommendedView(context),
              // --- SEKME 2: TÜM İLANLAR ---
              _isAllJobsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAllJobsView(context),
            ],
          ),
        ),
      ],
    );
  }

  // --- ARAYÜZ: SİZE ÖZEL (ÖNERİLEN İLANLAR) ---
  Widget _buildRecommendedView(BuildContext context) {
    // 1. CV Yoksa: CV Yükleme Uyarısı Göster
    if (!_hasCv) {
      return _buildUploadCvPrompt(context);
    }

    // 2. CV Var ama Öneri Yoksa
    if (_recommendedJobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // HATA DÜZELTMESİ: İkon 'search_off' olarak değiştirildi
              Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Size Uygun İlan Bulunamadı',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Profilinize ve yeteneklerinize uyan bir ilan henüz yayınlanmamış veya bulunamadı.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Yeniden Dene'),
                onPressed: _fetchRecommendedData,
              ),
            ],
          ),
        ),
      );
    }

    // 3. Öneriler Varsa: Modern Kart Listesini Göster
    return RefreshIndicator(
      onRefresh: _fetchRecommendedData,
      child: ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _recommendedJobs.length,
        itemBuilder: (context, index) {
          final job = _recommendedJobs[index];
          return _buildRecommendedJobCard(context, job);
        },
      ),
    );
  }

  // ARAYÜZ: Modern İlan Kartı
  Widget _buildRecommendedJobCard(BuildContext context, RecommendedJob job) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final authProvider = context.read<AuthProvider>();
    final isFav = favoritesProvider.isFavorite(job.id);

    // Uygunluk skoru rengini belirle
    Color scoreColor;
    if (job.matchScore >= 0.7) {
      scoreColor = Colors.green;
    } else if (job.matchScore >= 0.4) {
      scoreColor = Colors.orange;
    } else {
      scoreColor = Colors.red;
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(
                jobId: job.id,
                // Detay ekranına bu bilgileri yollayabiliriz (Adım 4)
                // matchScore: job.matchScore,
                // matchedSkills: job.matchedSkills,
                // missingSkills: job.missingSkills,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst Satır: Başlık ve Favori Butonu
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
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
                ],
              ),
              const SizedBox(height: 8),

              // Şirket ve Konum
              Text(
                job.company,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Uygunluk Skoru (Modern Arayüz)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Uygunluk Skoru: ${(job.matchScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: job.matchScore,
                      backgroundColor: scoreColor.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ARAYÜZ: CV Yükleme Uyarısı
  Widget _buildUploadCvPrompt(BuildContext context) {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_upload_outlined,
                size: 80,
                color: Colors.indigo,
              ),
              const SizedBox(height: 16),
              const Text(
                'Size Özel İlanları Keşfedin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'CV\'nizi yükleyerek yeteneklerinize en uygun iş ilanlarını ve size özel "Uygunluk Skoru"nu görmeye başlayın.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_pin_circle_outlined),
                label: const Text('Profilime Git ve CV Yükle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: () {
                  // Kullanıcıyı Profil sekmesine yönlendir (index 3)
                  // Bu 'MainNavProvider'ı kullanır (main_nav_screen.dart'ta tanımlı)
                  final navProvider = Provider.of<MainNavProvider>(
                    context,
                    listen: false,
                  );
                  navProvider.goToTab(3);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ARAYÜZ: TÜM İLANLAR ---
  // (Bu, senin mevcut kodunun güncellenmiş halidir)
  Widget _buildAllJobsView(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Column(
      children: [
        // ARAMA ÇUBUĞU
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'İlanlarda Ara (Başlığa Göre)...',
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
          child: _allJobs.isEmpty
              ? const Center(child: Text('Aramanızla eşleşen ilan bulunamadı.'))
              : RefreshIndicator(
                  onRefresh: () =>
                      _fetchAllJobsData(query: _searchController.text),
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      return ListView.builder(
                        itemCount: _allJobs.length,
                        itemBuilder: (context, index) {
                          final job = _allJobs[index];
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
