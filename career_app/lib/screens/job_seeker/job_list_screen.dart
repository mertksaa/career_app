// lib/screens/job_seeker/job_list_screen.dart
// SENİN KODUN + SADECE PAGINATION VE ENTER İLE ARAMA EKLEMELERİ
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:career_app/screens/main_nav_screen.dart';

import '../../models/job_model.dart';
import '../../models/recommended_job_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/api_service.dart';
import './job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({Key? key}) : super(key: key);

  @override
  _JobListScreenState createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Veri listeleri
  List<Job> _allJobs = [];
  List<RecommendedJob> _recommendedJobs = [];

  // Yükleme durumları (Sayfalama için yeni state'ler eklendi)
  bool _isRecommendedLoading = true;
  bool _isAllJobsLoading = true; // <<< İlk yükleme durumu
  bool _isAllJobsLoadingMore = false; // <<< Sayfalama yükleme durumu
  bool _hasMoreAllJobs = true; // <<< Daha fazla ilan var mı?
  int _allJobsCurrentPage = 1; // <<< Mevcut sayfa no
  final int _allJobsPageSize = 20; // <<< Sayfa boyutu (isteğin üzerine 20)
  bool _hasCv = false;

  // Arama ve Scroll Controller (ScrollController eklendi, debounce kaldırıldı)
  final _searchController = TextEditingController();
  // Timer? _debounce; // <<< KALDIRILDI (Enter ile arama için)
  final ScrollController _allJobsScrollController =
      ScrollController(); // <<< YENİ ScrollController

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    _hasCv = auth.hasCv;

    // Scroll listener ekle (Sayfalama için) <<< YENİ
    _allJobsScrollController.addListener(_onAllJobsScroll);

    // İlk verileri çek
    _fetchRecommendedData();
    _fetchAllJobsData(isInitialLoad: true); // <<< İlk yükleme olarak işaretle
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    // _debounce?.cancel(); // <<< KALDIRILDI
    _allJobsScrollController.removeListener(
      _onAllJobsScroll,
    ); // <<< Listener'ı kaldır
    _allJobsScrollController.dispose(); // <<< Controller'ı dispose et
    super.dispose();
  }

  // <<< YENİ: Sayfalama için scroll listener fonksiyonu >>>
  void _onAllJobsScroll() {
    // Eğer listenin sonuna yaklaşıldıysa VE yükleme yapılmıyorsa VE daha fazla ilan varsa
    if (_allJobsScrollController.position.pixels >=
            _allJobsScrollController.position.maxScrollExtent -
                300 && // Sona 300px kala
        !_isAllJobsLoadingMore &&
        _hasMoreAllJobs) {
      _fetchAllJobsData(); // Sonraki sayfayı çek (isInitialLoad: false olacak)
    }
  }

  // Önerilen İlanları Çek (Senin kodun - Değişiklik yok)
  Future<void> _fetchRecommendedData() async {
    if (!mounted) return;
    setState(() {
      _isRecommendedLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();

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
    if (mounted) {
      setState(() {
        _isRecommendedLoading = false;
      });
    }
  }

  // <<< GÜNCELLENDİ: Tüm İlanları Çek (Sayfalama mantığı ile) >>>
  Future<void> _fetchAllJobsData({
    String? query,
    bool isInitialLoad = false,
  }) async {
    // Aynı anda birden fazla yükleme isteğini engelle
    if (_isAllJobsLoadingMore && !isInitialLoad) return;
    // Zaten son sayfaya ulaşıldıysa (ve ilk yükleme değilse) tekrar istek atma
    if (!isInitialLoad && !_hasMoreAllJobs) return;
    if (!mounted) return;

    // Yükleme durumunu ayarla
    setState(() {
      if (isInitialLoad) {
        _isAllJobsLoading = true; // Tam ekran yükleme göstergesi
        _allJobsCurrentPage = 1; // Sayfayı sıfırla
        _allJobs.clear(); // Listeyi temizle (yeni arama veya yenileme için)
        _hasMoreAllJobs = true; // Başlangıçta daha fazla veri olduğunu varsay
        // Yeni arama/yenileme için scroll'u en başa al
        if (_allJobsScrollController.hasClients) {
          _allJobsScrollController.jumpTo(0);
        }
      } else {
        _isAllJobsLoadingMore = true; // Liste sonunda küçük yükleme göstergesi
      }
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();

    if (authProvider.token != null) {
      try {
        // API'den ilgili sayfayı (page) ve boyutu (size) iste
        final fetchedJobs = await apiService.getJobs(
          authProvider.token!,
          searchQuery:
              query ?? _searchController.text, // Mevcut arama sorgusunu kullan
          page: _allJobsCurrentPage,
          size: _allJobsPageSize,
        );

        if (mounted) {
          setState(() {
            // Gelen yeni ilanları mevcut listeye ekle
            _allJobs.addAll(fetchedJobs);
            // Eğer API'den gelen liste, istediğimiz boyuttan küçükse, son sayfaya ulaştık
            if (fetchedJobs.length < _allJobsPageSize) {
              _hasMoreAllJobs = false;
            }
            // Bir sonraki sayfa numarasını artır
            _allJobsCurrentPage++;
          });
        }
      } catch (e) {
        print("Error fetching all jobs data (page: $_allJobsCurrentPage): $e");
        // Hata mesajını Flutter loguna yazdırıyoruz
        if (mounted)
          setState(
            () => _hasMoreAllJobs = false,
          ); // Hata durumunda daha fazla yükleme yapma
      }
    } else {
      if (mounted) setState(() => _hasMoreAllJobs = false); // Token yoksa
    }

    // Yükleme durumlarını güncelle
    if (mounted) {
      setState(() {
        _isAllJobsLoading = false; // İlk yükleme bitti
        _isAllJobsLoadingMore = false; // Daha fazla yükleme bitti
      });
    }
  }

  // <<< KALDIRILDI: Otomatik arama fonksiyonu >>>
  // void _onSearchChanged(String query) { ... }

  @override
  Widget build(BuildContext context) {
    // Bu build metodu aynı kalıyor...
    return Column(
      children: [
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
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Size Özel Sekmesi (Değişiklik yok)
              _isRecommendedLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildRecommendedView(context),
              // Tüm İlanlar Sekmesi (Yükleme göstergesi güncellendi)
              // İlk yükleme yapılıyorsa VE liste boşsa göstergeyi göster
              _isAllJobsLoading && _allJobs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _buildAllJobsView(context),
            ],
          ),
        ),
      ],
    );
  }

  // --- ARAYÜZ: SİZE ÖZEL ---
  // Senin kodundaki _buildRecommendedView (Değişiklik yok)
  Widget _buildRecommendedView(BuildContext context) {
    if (!_hasCv) {
      return _buildUploadCvPrompt(context);
    }
    if (_recommendedJobs.isEmpty) {
      return _buildEmptyState(
        'Size Uygun İlan Bulunamadı',
        'Profilinize ve yeteneklerinize uyan bir ilan henüz yayınlanmamış veya bulunamadı.',
        Icons.search_off,
        _fetchRecommendedData,
      );
    }
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

  // Size Özel Kartı (Senin kodundaki UI düzeltmeleri uygulanmış hali - Değişiklik yok)
  Widget _buildRecommendedJobCard(BuildContext context, RecommendedJob job) {
    final favoritesProvider = context.watch<FavoritesProvider>();
    final authProvider = context.read<AuthProvider>();
    final isFav = favoritesProvider.isFavorite(job.id);
    Color scoreColor = job.matchScore >= 0.7
        ? Colors.green
        : (job.matchScore >= 0.4 ? Colors.orange : Colors.red);

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JobDetailScreen(jobId: job.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.title ?? 'Başlık Yok',
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
              Text(
                job.description ?? 'Açıklama yok',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: 7,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
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
                      job.location ?? 'Konum Yok',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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

  // CV Yükleme Uyarısı (Senin kodun - Değişiklik yok)
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

  // <<< GÜNCELLENDİ: TÜM İLANLAR ARAYÜZÜ (Pagination ve Arama Çubuğu Düzeltmesi) >>>
  Widget _buildAllJobsView(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          // <<< GÜNCELLENDİ: Arama çubuğu onChanged yerine onSubmitted kullanıyor >>>
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'İlanlarda Ara (Başlığa Göre)...',
              hintText: 'Aramak için yazıp Enter\'a basın', // Hint eklendi
              prefixIcon: const Icon(Icons.search),
              // Arama kutusunun sağ tarafına temizleme butonu ekleyelim
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        // Controller'ı temizle
                        _searchController.clear();
                        // Temizleyince aramayı sıfırla ve ilk sayfayı getir
                        _fetchAllJobsData(query: '', isInitialLoad: true);
                      },
                    )
                  : null, // Boşsa temizleme ikonunu gösterme
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // onChanged: _onSearchChanged, // <<< KALDIRILDI
            textInputAction:
                TextInputAction.search, // Klavye Enter tuşunu "Ara" yapar
            onSubmitted: (value) {
              // <<< YENİ: Enter'a basınca tetiklenir
              // Arama yaparken ilk sayfadan başla
              _fetchAllJobsData(query: value, isInitialLoad: true);
            },
          ),
        ),
        Expanded(
          // Yükleme bittiyse VE liste hala boşsa boş state göster
          child: !_isAllJobsLoading && _allJobs.isEmpty
              ? _buildEmptyState(
                  'İlan Bulunamadı',
                  'Aramanızla eşleşen veya mevcut bir ilan bulunamadı.',
                  Icons.find_in_page_outlined,
                  () => _fetchAllJobsData(
                    query: _searchController.text,
                    isInitialLoad: true,
                  ),
                )
              // Değilse RefreshIndicator ve ListView göster
              : RefreshIndicator(
                  // Yukarı çekince yenileme
                  onRefresh: () => _fetchAllJobsData(
                    query: _searchController.text,
                    isInitialLoad: true,
                  ),
                  child: Consumer<FavoritesProvider>(
                    builder: (context, favoritesProvider, child) {
                      // Sayfalama için ListView.builder güncellendi
                      return ListView.builder(
                        controller:
                            _allJobsScrollController, // <<< Scroll Controller bağlandı
                        // Liste eleman sayısı = İlan sayısı + (daha fazla ilan varsa 1 tane yükleme göstergesi)
                        itemCount:
                            _allJobs.length +
                            (_hasMoreAllJobs
                                ? 1
                                : 0), // <<< itemCount güncellendi
                        itemBuilder: (context, index) {
                          // <<< YENİ: Eğer index, listenin son elemanıysa yükleme göstergesi >>>
                          if (index == _allJobs.length) {
                            // Yükleme yapılıyorsa göstergeyi göster, değilse boşluk bırak
                            return _isAllJobsLoadingMore
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 24.0,
                                      ),
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                : const SizedBox(
                                    height: 10,
                                  ); // Liste sonu estetik boşluk
                          }

                          // Normal ilan kartını göster (Senin kodundaki UI düzeltmeleri uygulanmış hali)
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
                                job.title ?? 'Başlık Yok',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                job.description ?? 'Açıklama yok',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ), // Açıklama göster
                              isThreeLine: false, // Sabit yükseklik
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
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) =>
                                      JobDetailScreen(jobId: job.id),
                                ),
                              ),
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

  // Ortak Boş Durum Widget'ı (Senin kodun - Değişiklik yok)
  Widget _buildEmptyState(
    String title,
    String message,
    IconData icon,
    VoidCallback onRefresh,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Yeniden Dene'),
              onPressed: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
} // State sınıfının sonu
