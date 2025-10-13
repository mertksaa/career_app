import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/snackbar_provider.dart';
import './job_seeker/job_list_screen.dart';
import './job_seeker/favorites_screen.dart';
import './job_seeker/applications_screen.dart';
import './profile_screen.dart';
import './employer/create_job_screen.dart';
import './employer/my_jobs_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;
  late SnackbarProvider _snackbarProvider;

  // Ekran listeleri
  final List<Widget> _jobSeekerScreens = [
    const JobListScreen(),
    const FavoritesScreen(),
    const ApplicationsScreen(),
    const ProfileScreen(),
  ];
  final List<Widget> _employerScreens = [
    const MyJobsScreen(),
    const CreateJobScreen(),
    const ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Provider'ı dinlemeye başlıyoruz
    _snackbarProvider = Provider.of<SnackbarProvider>(context);
    _snackbarProvider.addListener(_showSnackbar);
  }

  @override
  void dispose() {
    // Sayfa kapandığında dinleyiciyi kaldırıyoruz
    _snackbarProvider.removeListener(_showSnackbar);
    super.dispose();
  }

  // SnackbarProvider'da bir değişiklik olduğunda bu fonksiyon çalışacak
  void _showSnackbar() {
    final info = _snackbarProvider.snackbarInfo;
    if (info != null && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(info.message),
          backgroundColor: info.isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _snackbarProvider.clear(); // Mesajı gösterdikten sonra temizliyoruz
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userRole = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.role;
    final bool isJobSeeker = userRole == 'job_seeker';
    final screens = isJobSeeker ? _jobSeekerScreens : _employerScreens;
    final navItems = isJobSeeker
        ? [
            const BottomNavigationBarItem(
              icon: Icon(Icons.list),
              label: 'İlanlar',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.favorite),
              label: 'Favoriler',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.check_box),
              label: 'Başvurularım',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ]
        : [
            const BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: 'İlanlarım',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.add_box),
              label: 'İlan Ver',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Profil',
            ),
          ];

    return Scaffold(
      appBar: AppBar(
        title: Text(navItems[_selectedIndex].label ?? 'Career App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthProvider>(context, listen: false).logout(),
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
      ),
    );
  }
}
