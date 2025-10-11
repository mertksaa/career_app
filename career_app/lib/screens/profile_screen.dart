import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // AuthProvider'dan kullanıcı bilgilerini ve CV durumunu al
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    // Kullanıcı bilgisi henüz yüklenmemişse (teorik olarak olmamalı)
    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Profil Kartı
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.indigoAccent,
                    child: Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.email,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(
                      user.role == 'job_seeker' ? 'İş Arayan' : 'İşveren',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.indigo,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sadece iş arayanlar için CV Yönetimi Kartı
          if (user.role == 'job_seeker')
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: Icon(
                  authProvider.hasCv ? Icons.check_circle : Icons.cancel,
                  color: authProvider.hasCv ? Colors.green : Colors.red,
                ),
                title: const Text('CV Yönetimi'),
                subtitle: Text(
                  authProvider.hasCv ? 'CV Yüklendi' : 'CV Yüklenmedi',
                ),
                trailing: ElevatedButton(
                  onPressed: () {
                    // TODO: CV yükleme fonksiyonu burada çağrılacak.
                    // Şimdilik durumu değiştirmek için provider'daki fonksiyonu kullanalım.
                    authProvider.setCvStatus(!authProvider.hasCv);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          authProvider.hasCv
                              ? 'CV durumu "Yüklendi" olarak değiştirildi.'
                              : 'CV durumu "Yüklenmedi" olarak değiştirildi.',
                        ),
                      ),
                    );
                  },
                  child: Text(authProvider.hasCv ? 'Değiştir' : 'Yükle'),
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Çıkış Yap Butonu
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Çıkış Yap', style: TextStyle(color: Colors.red)),
            onTap: () {
              // Onay diyaloğu göster
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Çıkış Yap'),
                  content: const Text(
                    'Çıkış yapmak istediğinizden emin misiniz?',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('İptal'),
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                    ),
                    TextButton(
                      child: const Text(
                        'Evet',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: () {
                        Navigator.of(ctx).pop(); // Diyaloğu kapat
                        Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).logout();
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
