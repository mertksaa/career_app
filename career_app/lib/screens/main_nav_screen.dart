// lib/screens/main_nav_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/snackbar_provider.dart';
import './job_seeker/job_list_screen.dart';
import './job_seeker/favorites_screen.dart';
import 'job_seeker/my_applications_screen.dart';
import './profile_screen.dart';
import './employer/my_jobs_screen.dart';
import './employer/create_job_screen.dart';

// YENİ PROVIDER: Sekme değişimini global olarak yönetmek için
class MainNavProvider with ChangeNotifier {
  int _selectedIndex = 0;

  int get selectedIndex => _selectedIndex;

  void goToTab(int index) {
    _selectedIndex = index;
    notifyListeners();
  }
}

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  late final List<Widget> _jobSeekerPages;
  late final List<Widget> _employerPages;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SnackbarProvider>(context, listen: false).setContext(context);
    });

    _jobSeekerPages = [
      const JobListScreen(),
      const FavoritesScreen(),
      const MyApplicationsScreen(),
      const ProfileScreen(),
    ];

    _employerPages = [
      const MyJobsScreen(),
      const CreateJobScreen(),
      const ProfileScreen(),
    ];
  }

  // İş Arayan Menü
  final List<BottomNavigationBarItem> _jobSeekerItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.list_alt),
      label: 'Job postings',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Favorites',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.article_outlined),
      activeIcon: Icon(Icons.article),
      label: 'My Applications',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  // İşveren Menü
  final List<BottomNavigationBarItem> _employerItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.list_alt),
      label: 'My Job Postings',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.add_circle_outline),
      activeIcon: Icon(Icons.add_circle),
      label: 'Publish a Job',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final navProvider = Provider.of<MainNavProvider>(context);

    final List<Widget> pages = auth.user?.role == 'employer'
        ? _employerPages
        : _jobSeekerPages;
    final List<BottomNavigationBarItem> items = auth.user?.role == 'employer'
        ? _employerItems
        : _jobSeekerItems;

    int currentIndex = navProvider.selectedIndex;
    if (currentIndex >= pages.length) {
      currentIndex = 0;
    }

    return Scaffold(
      // --- DÜZELTME BURADA: AppBar'ı kaldırdık ---
      // appBar: AppBar(...),  <-- BU SATIR ARTIK YOK
      // Çünkü JobListScreen ve diğer sayfaların kendi AppBar'ı var.
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        currentIndex: currentIndex,
        onTap: (index) {
          navProvider.goToTab(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
      ),
    );
  }
}
