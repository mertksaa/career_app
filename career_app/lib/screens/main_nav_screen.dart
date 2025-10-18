// lib/screens/main_nav_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/snackbar_provider.dart'; // Snackbar provider'ı import et
import './job_seeker/job_list_screen.dart';
import './job_seeker/favorites_screen.dart';
import './job_seeker/applications_screen.dart';
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
  // Bu yerel state'e artık provider üzerinden erişeceğiz
  // int _selectedIndex = 0;

  late final List<Widget> _jobSeekerPages;
  late final List<Widget> _employerPages;

  @override
  void initState() {
    super.initState();

    // Snackbar'ı dinlemek için context'i kullan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SnackbarProvider>(context, listen: false).setContext(context);
    });

    _jobSeekerPages = [
      const JobListScreen(),
      const FavoritesScreen(),
      const ApplicationsScreen(),
      const ProfileScreen(),
    ];

    _employerPages = [
      const MyJobsScreen(),
      const CreateJobScreen(),
      const ProfileScreen(),
    ];
  }

  // Bu fonksiyona artık provider üzerinden erişeceğiz
  // void _onItemTapped(int index) {
  //   setState(() {
  //     _selectedIndex = index;
  //   });
  // }

  // İş Arayan için alt navigasyon barları
  final List<BottomNavigationBarItem> _jobSeekerItems = [
    const BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'İlanlar'),
    const BottomNavigationBarItem(
      icon: Icon(Icons.favorite_border),
      activeIcon: Icon(Icons.favorite),
      label: 'Favoriler',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.article_outlined),
      activeIcon: Icon(Icons.article),
      label: 'Başvurularım',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  // İşveren için alt navigasyon barları
  final List<BottomNavigationBarItem> _employerItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.list_alt),
      label: 'İlanlarım',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.add_circle_outline),
      activeIcon: Icon(Icons.add_circle),
      label: 'İlan Yayınla',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'Profil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // YENİ: Provider'ı dinle (listen: true)
    final navProvider = Provider.of<MainNavProvider>(context);

    final List<Widget> pages = auth.user?.role == 'employer'
        ? _employerPages
        : _jobSeekerPages;
    final List<BottomNavigationBarItem> items = auth.user?.role == 'employer'
        ? _employerItems
        : _jobSeekerItems;

    // Seçili sekmenin index'inin liste boyutunu aşmadığından emin ol
    // (örn: İş Arayan'da 4 sekme varken İşveren'e geçince 3 sekme kalıyor)
    int currentIndex = navProvider.selectedIndex;
    if (currentIndex >= pages.length) {
      currentIndex = 0;
      // Provider'ı da güncelle (bu build sırasında yapılmamalı, ama bir sonraki frame'de düzelir)
      // WidgetsBinding.instance.addPostFrameCallback((_) {
      //   navProvider.goToTab(0);
      // });
    }

    return Scaffold(
      appBar: AppBar(title: Text(items[currentIndex].label ?? 'Career AI')),
      // YENİ: provider.selectedIndex (güvenli index ile) kullan
      body: pages[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: items,
        // YENİ: provider.selectedIndex (güvenli index ile) kullan
        currentIndex: currentIndex,
        onTap: (index) {
          // YENİ: provider.goToTab kullan
          navProvider.goToTab(index);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
