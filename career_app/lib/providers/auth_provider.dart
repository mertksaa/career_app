import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart'; // Yeni User modelimizi import ediyoruz
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  User? _user; // Artık kullanıcı bilgilerini saklayacağız
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthCheckComplete = false;

  // Getter'lar
  String? get token => _token;
  User? get user => _user; // User için getter
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated =>
      _token != null && _user != null; // Artık user'ı da kontrol ediyoruz
  bool get isAuthCheckComplete => _isAuthCheckComplete;

  AuthProvider() {
    tryAutoLogin();
  }

  // ... (register fonksiyonu aynı kalıyor) ...
  Future<bool> register(String email, String password, String role) async {
    // ...
    // Bu fonksiyonun içeriği aynı, dokunmuyoruz.
    // ...
    _setLoading(true);
    _setError(null);
    final result = await _apiService.register(email, password, role);
    _setLoading(false);
    if (result['success']) {
      return true;
    } else {
      _setError(result['message']);
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _setError(null);

    final result = await _apiService.login(email, password);

    if (result['success']) {
      _token = result['data']['access_token'];
      await _storage.write(key: 'auth_token', value: _token);

      // Giriş başarılıysa, hemen kullanıcı bilgilerini çek
      await _fetchAndSetUser();

      _setError(null);
      _setLoading(false);
      return true;
    } else {
      _setError(result['message']);
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null; // Kullanıcıyı da temizle
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      print("Token found, fetching user details...");
      // Token varsa kullanıcı bilgilerini çekmeyi dene
      await _fetchAndSetUser();
    } else {
      print("No token found.");
    }
    _isAuthCheckComplete = true;
    notifyListeners();
  }

  // Yeni özel fonksiyon: Token kullanarak kullanıcı bilgilerini çeker ve state'i günceller
  Future<void> _fetchAndSetUser() async {
    if (_token == null) return;

    final result = await _apiService.getUserDetails(_token!);
    if (result['success']) {
      _user = User.fromJson(result['data']);
    } else {
      // Eğer token geçersizse veya başka bir hata olursa çıkış yap
      print("Failed to fetch user, logging out.");
      await logout();
    }
  }

  // Bu private helper'ları da ekleyelim
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
  }
}
