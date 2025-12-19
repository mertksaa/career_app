import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Ekran çizildikten hemen sonra kontrolü başlat
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Provider'a eriş (listen: false çünkü sadece fonksiyon çağırıyoruz)
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Otomatik giriş yapmayı dene (Token var mı? Geçerli mi?)
    // Bu işlem backend'e gidip geldiği için biraz sürebilir.
    await auth.tryAutoLogin();

    if (!mounted) return; // Ekran kapandıysa işlem yapma

    // Kontrol bitti, şimdi yönlendirme yapalım
    if (auth.isAuthenticated) {
      // Giriş yapılmış -> Ana Sayfaya git
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Giriş yapılmamış -> Login/Register ekranına git
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary, // Arkaplan rengi
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo veya İkon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.work_outline_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            // Uygulama Adı
            const Text(
              "Career AI",
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            // Yükleniyor animasyonu
            const CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}
