import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './screens/auth_screen.dart';
import './screens/main_nav_screen.dart';
import './screens/splash_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuthProvider(),
      child: MaterialApp(
        title: 'Career AI Mobile',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            // Basitleştirilmiş ve doğru mantık:
            if (!auth.isAuthCheckComplete) {
              // Otomatik giriş kontrolü bitmediyse bekleme ekranı göster
              return const SplashScreen();
            } else if (auth.isAuthenticated) {
              // Kontrol bitti ve kullanıcı giriş yapmışsa ana ekranı göster
              return const MainNavScreen();
            } else {
              // Kontrol bitti ve kullanıcı giriş yapmamışsa giriş ekranını göster
              return const AuthScreen();
            }
          },
        ),
      ),
    );
  }
}
