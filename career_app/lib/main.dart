import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

// Provider'lar
import 'providers/auth_provider.dart';
import 'providers/favorites_provider.dart';
import 'providers/applications_provider.dart';
import 'providers/snackbar_provider.dart';

// Ekranlar
import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/main_nav_screen.dart'; // MainNavProvider burada tanımlı

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => ApplicationsProvider()),
        ChangeNotifierProvider(create: (_) => SnackbarProvider()),

        // --- DÜZELTME: BU SATIR EKSİKTİ ---
        // Sekme geçişlerini yöneten provider'ı buraya ekledik.
        ChangeNotifierProvider(create: (_) => MainNavProvider()),
        // ----------------------------------
      ],
      child: MaterialApp(
        title: 'Career AI',
        debugShowCheckedModeBanner: false,

        // --- MODERN TEMA AYARLARI ---
        theme: ThemeData(
          useMaterial3: true,

          // Renk Paleti (Profesyonel Teal & Slate)
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F172A), // Slate 900 (Koyu Lacivert)
            primary: const Color(0xFF0F172A),
            secondary: const Color(0xFF3B82F6), // Blue 500 (Canlı Mavi)
            tertiary: const Color(
              0xFF10B981,
            ), // Emerald 500 (Yeşil - Skorlar için)
            background: const Color(
              0xFFF8FAFC,
            ), // Slate 50 (Kırık Beyaz Arkaplan)
            surface: Colors.white,
          ),

          // Yazı Tipi (Google Fonts - Poppins)
          textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),

          // Buton Tasarımları
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),

          // Input Alanları
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),

        // -----------------------------
        home: const SplashScreen(),
        routes: {
          '/auth': (ctx) => const AuthScreen(),
          '/home': (ctx) => const MainNavScreen(),
        },
      ),
    );
  }
}
