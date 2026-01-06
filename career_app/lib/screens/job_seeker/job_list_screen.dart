import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/job_model.dart';
import '../../models/recommended_job_model.dart';
import '../../widgets/job_card.dart';
import 'job_detail_screen.dart';
import 'favorites_screen.dart';
import 'my_applications_screen.dart';
import '../auth_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -- FİLTRELEME DEĞİŞKENLERİ --
  String _selectedLocation = "All";
  final List<String> _locations = [
    "All",
    "Remote",
    "Istanbul",
    "Ankara",
    "Izmir",
    "New York",
    "London",
    "Berlin",
  ];

  // -- ARAMA DEĞİŞKENLERİ --
  final TextEditingController _searchController = TextEditingController();
  String? _currentSearchQuery; // API'ye gönderilecek olan kelime

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Önerilenleri Çek
  Future<List<RecommendedJob>> _fetchRecommended() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ApiService().getRecommendedJobs(
      auth.token!,
      location: _selectedLocation,
    );
  }

  // Tüm İlanları Çek (Aramalı)
  Future<List<Job>> _fetchAllJobs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ApiService().getJobs(
      auth.token!,
      searchQuery: _currentSearchQuery, // Arama kelimesini buraya gönderiyoruz
    );
  }

  // Arama işlemini tetikleyen fonksiyon
  void _performSearch() {
    setState(() {
      // Eğer kutu boşsa null yap ki tümünü getirsin
      _currentSearchQuery = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Job Listings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Recommended For You"),
            Tab(text: "All Jobs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: ÖNERİLENLER (Şehir Filtreli) ---
          Column(
            children: [
              // ŞEHİR FİLTRESİ
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(vertical: 10),
                color: Colors.white,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _locations.length,
                  itemBuilder: (context, index) {
                    final loc = _locations[index];
                    final isSelected = _selectedLocation == loc;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(loc),
                        selected: isSelected,
                        onSelected: (bool selected) {
                          setState(() {
                            _selectedLocation = loc;
                          });
                        },
                        selectedColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // LİSTE
              Expanded(
                child: FutureBuilder<List<RecommendedJob>>(
                  future: _fetchRecommended(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_off,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text("No matches found in $_selectedLocation"),
                          ],
                        ),
                      );
                    }

                    final jobs = snapshot.data!;
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length,
                      itemBuilder: (context, index) {
                        final job = jobs[index];
                        return JobCard(
                          job: job,
                          isRecommended: true,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    JobDetailScreen(jobId: job.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // --- TAB 2: TÜM İLANLAR (Aramalı) ---
          Column(
            children: [
              // ARAMA ÇUBUĞU
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search jobs ",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _performSearch, // Ok tuşuna basınca ara
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 16,
                    ),
                  ),
                  onSubmitted: (_) =>
                      _performSearch(), // Klavyeden Enter'a basınca ara
                ),
              ),

              // LİSTE
              Expanded(
                child: FutureBuilder<List<Job>>(
                  future: _fetchAllJobs(), // Arama parametresiyle çağırır
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text("No jobs found matching your search."),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) {
                        final job = snapshot.data![index];
                        return JobCard(
                          job: job,
                          // Skor varsa göster
                          isRecommended:
                              (job.matchScore != null && job.matchScore! > 0),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    JobDetailScreen(jobId: job.id),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
