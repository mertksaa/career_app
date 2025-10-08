import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({Key? key}) : super(key: key);

  @override
  _MainNavScreenState createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  // Her rol için ekran listeleri
  final List<Widget> _jobSeekerScreens = [
    const Center(child: Text('İş İlanları Ekranı')), // Placeholder
    const Center(child: Text('Favoriler Ekranı')), // Placeholder
    const Center(child: Text('Profil Ekranı')), // Placeholder
  ];

  final List<Widget> _employerScreens = [
    const Center(child: Text('İlanlarım Ekranı')), // Placeholder
    const Center(child: Text('İlan Oluştur Ekranı')), // Placeholder
    const Center(child: Text('Profil Ekranı')), // Placeholder
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider'dan kullanıcı rolünü al
    final userRole = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).user?.role;

    final bool isJobSeeker = userRole == 'job_seeker';

    // Role göre ekranları ve navigasyon bar item'larını seç
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
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
            },
          ),
        ],
      ),
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
