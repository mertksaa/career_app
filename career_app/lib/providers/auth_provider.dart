import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _token;
  User? _user;
  bool _hasCv = false;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isAuthCheckComplete = false;

  String? get token => _token;
  User? get user => _user;
  bool get hasCv => _hasCv;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isAuthCheckComplete => _isAuthCheckComplete;

  AuthProvider() {
    tryAutoLogin();
  }

  void setCvStatus(bool hasCv) {
    _hasCv = hasCv;
    notifyListeners();
  }

  Future<bool> register(String email, String password, String role) async {
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

      // Token alındı, şimdi kullanıcı detaylarını çekmeyi ZORUNLU kılıyoruz
      final userSuccess = await _fetchAndSetUser();

      _setLoading(false);

      // Eğer kullanıcı bilgisi çekilemediyse girişi başarısız say
      if (userSuccess) {
        return true;
      } else {
        _setError("Giriş başarılı ancak profil bilgileri alınamadı.");
        await logout(); // Temizle
        return false;
      }
    } else {
      _setError(result['message']);
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    _token = await _storage.read(key: 'auth_token');
    if (_token != null) {
      print("Token found, fetching user details...");
      await _fetchAndSetUser();
    } else {
      print("No token found.");
    }
    _isAuthCheckComplete = true;
    notifyListeners();
  }

  // Bu fonksiyon artık başarı durumunu (true/false) dönüyor
  Future<bool> _fetchAndSetUser() async {
    if (_token == null) return false;

    try {
      final result = await _apiService.getUserDetails(_token!);
      if (result['success']) {
        _user = User.fromJson(result['data']);

        // CV Durumunu Çek
        try {
          final bool cvStatus = await _apiService.getCvStatus(_token!);
          _hasCv = cvStatus;
        } catch (_) {
          _hasCv = false;
        }
        notifyListeners();
        return true;
      }
    } catch (e) {
      print("User fetch error: $e");
    }
    return false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners(); // Hata mesajı geldiğinde ekranı güncellesin
  }
}
