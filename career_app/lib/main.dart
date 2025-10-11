// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import './providers/auth_provider.dart';
import './providers/favorites_provider.dart';
import './screens/auth_screen.dart';
import './screens/main_nav_screen.dart';
import './screens/splash_screen.dart';
import './providers/applications_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, FavoritesProvider>(
          create: (ctx) => FavoritesProvider(),
          update: (ctx, auth, previous) =>
              previous!..fetchFavorites(auth.token ?? ''),
        ),
        // YENİ PROVIDER'I BURAYA EKLİYORUZ
        ChangeNotifierProxyProvider<AuthProvider, ApplicationsProvider>(
          create: (ctx) => ApplicationsProvider(),
          update: (ctx, auth, previous) {
            if (auth.isAuthenticated && auth.token != null) {
              previous?.fetchApplications(auth.token!);
            }
            return previous!;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Career AI Mobile',
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: Consumer<AuthProvider>(
          builder: (ctx, auth, _) {
            if (!auth.isAuthCheckComplete) {
              return const SplashScreen();
            } else if (auth.isAuthenticated) {
              return const MainNavScreen();
            } else {
              return const AuthScreen();
            }
          },
        ),
      ),
    );
  }
}
