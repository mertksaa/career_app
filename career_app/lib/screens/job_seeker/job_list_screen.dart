import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/job_model.dart';
import '../../models/recommended_job_model.dart';
import '../../widgets/job_card.dart';
import 'job_detail_screen.dart';

class JobListScreen extends StatefulWidget {
  const JobListScreen({super.key});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -- FİLTRELEME --
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

  // -- ARAMA --
  final TextEditingController _searchController = TextEditingController();
  String? _currentSearchQuery;

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

  // API Çağrıları
  Future<List<RecommendedJob>> _fetchRecommended() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ApiService().getRecommendedJobs(
      auth.token!,
      location: _selectedLocation,
    );
  }

  Future<List<Job>> _fetchAllJobs() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return ApiService().getJobs(auth.token!, searchQuery: _currentSearchQuery);
  }

  void _performSearch() {
    setState(() {
      _currentSearchQuery = _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // --- DÜZELTME BURADA: Tek ve Temiz AppBar ---
      appBar: AppBar(
        title: const Text(
          "Job Postings",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false, // Sola yaslı
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Recommended"),
            Tab(text: "All Jobs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- TAB 1: ÖNERİLENLER ---
          Column(
            children: [
              // Şehir Filtresi Çubuğu
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
                          setState(() => _selectedLocation = loc);
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
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide.none,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: FutureBuilder<List<RecommendedJob>>(
                  future: _fetchRecommended(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState(
                        Icons.location_off,
                        "No matches found in $_selectedLocation",
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) => JobCard(
                        job: snapshot.data![index],
                        isRecommended: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JobDetailScreen(
                              jobId: snapshot.data![index].id,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // --- TAB 2: TÜM İLANLAR ---
          Column(
            children: [
              // Arama Kutusu
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search jobs (e.g. Frontend)...",
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _performSearch,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<Job>>(
                  future: _fetchAllJobs(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState(
                        Icons.search_off,
                        "No jobs found.",
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      itemBuilder: (context, index) => JobCard(
                        job: snapshot.data![index],
                        // Skor varsa göster (0'dan büyükse)
                        isRecommended:
                            (snapshot.data![index].matchScore != null &&
                            snapshot.data![index].matchScore! > 0),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => JobDetailScreen(
                              jobId: snapshot.data![index].id,
                            ),
                          ),
                        ),
                      ),
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

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
