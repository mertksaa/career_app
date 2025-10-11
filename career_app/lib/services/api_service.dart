import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job_model.dart';

class ApiService {
  // Android emülatörü için backend adresi.
  // Eğer gerçek bir telefon kullanıyorsan, bilgisayarının IP adresini yazmalısın.
  final String _baseUrl = 'http://10.0.2.2:8000';

  // Kayıt olma fonksiyonu
  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String role,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password, 'role': role}),
      );

      return _handleResponse(response);
    } catch (e) {
      // Ağ hatası veya başka bir istisna durumu
      print('Register Error: $e');
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  // Giriş yapma fonksiyonu
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      // FastAPI'nin OAuth2PasswordRequestForm'u 'x-www-form-urlencoded' formatında veri bekler
      final response = await http.post(
        Uri.parse('$_baseUrl/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      return _handleResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Bağlantı hatası: $e'};
    }
  }

  // HTTP cevaplarını işleyen yardımcı fonksiyon
  Map<String, dynamic> _handleResponse(http.Response response) {
    final dynamic decodedJson = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Başarılı cevap
      return {'success': true, 'data': decodedJson};
    } else {
      // Hatalı cevap
      // FastAPI'den gelen hata mesajını alıyoruz (genellikle 'detail' anahtarı altında)
      final String errorMessage =
          decodedJson is Map && decodedJson.containsKey('detail')
          ? decodedJson['detail']
          : 'Bilinmeyen bir hata oluştu.';
      return {'success': false, 'message': errorMessage};
    }
  }

  // Token ile kullanıcı bilgilerini getiren fonksiyon
  Future<Map<String, dynamic>> getUserDetails(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token', // Token'ı header'a ekliyoruz
        },
      );
      return _handleResponse(response);
    } catch (e) {
      print('GetUserDetails Error: $e');
      return {'success': false, 'message': 'Kullanıcı bilgileri alınamadı.'};
    }
  }

  Future<List<Job>> getJobs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs'),
        headers: {
          // Güvenli endpoint'ler için token göndermek iyi bir alışkanlıktır.
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Cevap UTF-8 olarak decode edilmeli, Türkçe karakter sorunu yaşamamak için.
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        print('Failed to load jobs: ${response.body}');
        return []; // Hata durumunda boş liste döndür
      }
    } catch (e) {
      print('GetJobs Error: $e');
      return []; // Hata durumunda boş liste döndür
    }
  }

  // Bir ilanı favorilere ekle/çıkar
  Future<Map<String, dynamic>> toggleFavorite(String token, int jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/jobs/$jobId/favorite'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      print('ToggleFavorite Error: $e');
      return {'success': false, 'message': 'İşlem sırasında bir hata oluştu.'};
    }
  }

  // Kullanıcının favori ilanlarını getir
  Future<List<Job>> getFavorites(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me/favorites'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        print('Failed to load favorites: ${response.body}');
        return [];
      }
    } catch (e) {
      print('GetFavorites Error: $e');
      return [];
    }
  }

  // Tek bir iş ilanının detaylarını getiren fonksiyon
  Future<Job?> getJobDetails(String token, int jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs/$jobId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return Job.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
      } else {
        print('Failed to load job details: ${response.body}');
        return null;
      }
    } catch (e) {
      print('GetJobDetails Error: $e');
      return null;
    }
  }

  // Bir ilana başvur
  Future<Map<String, dynamic>> applyForJob(String token, int jobId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/jobs/$jobId/apply'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      print('ApplyForJob Error: $e');
      return {
        'success': false,
        'message': 'Başvuru sırasında bir hata oluştu.',
      };
    }
  }

  // Kullanıcının başvurduğu ilanları getir
  Future<List<Job>> getApplications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/me/applications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        print('Failed to load applications: ${response.body}');
        return [];
      }
    } catch (e) {
      print('GetApplications Error: $e');
      return [];
    }
  }
}
