import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/job_model.dart';
import '../models/applicant_model.dart';
import '../models/recommended_job_model.dart';
import '../models/skill_analysis_model.dart';

class ApiService {
  // Android emülatörü için backend adresi.
  // Eğer gerçek bir telefon kullanıyorsan, bilgisayarının IP adresini yazmalısın.
  final String _baseUrl = 'http://10.0.2.2:8000';
  String getBaseUrl() => _baseUrl;
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
    final dynamic decodedJson = jsonDecode(utf8.decode(response.bodyBytes));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return {
        'success': true,
        'data': decodedJson,
        'message': decodedJson is Map && decodedJson.containsKey('message')
            ? decodedJson['message']
            : 'İşlem başarılı.',
      };
    } else {
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

  Future<List<Job>> getJobs(
    String token, {
    String? searchQuery,
    int page = 1, // Varsayılan sayfa 1
    int size = 20, // Varsayılan boyut 20
  }) async {
    try {
      // URL'yi dinamik olarak oluştur (sayfalama parametreleri ile)
      var uri = Uri.parse('$_baseUrl/jobs').replace(
        queryParameters: {
          'page': page.toString(),
          'size': size.toString(),
          if (searchQuery != null && searchQuery.isNotEmpty)
            'search': searchQuery,
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        // Backend'den gelen her bir json objesini Job.fromJson ile dönüştür
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        print('Failed to load jobs (page: $page): ${response.body}');
        return []; // Hata durumunda boş liste
      }
    } catch (e) {
      print('GetJobs Error (page: $page): $e');
      return []; // Hata durumunda boş liste
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

  Future<bool> getCvStatus(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/me/cv/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return data['has_cv'] ?? false;
      } else {
        // Hata durumunda (örn: 404, 500) CV'si yok varsay
        return false;
      }
    } catch (e) {
      print('GetCvStatus Error: $e');
      return false;
    }
  }

  String getApplicantCvUrl(int applicantUserId, {String? timestamp}) {
    String url = '$_baseUrl/users/$applicantUserId/cv';

    if (timestamp != null) {
      url += '?v=$timestamp';
    }

    return url;
  }

  Future<List<RecommendedJob>> getRecommendedJobs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs/recommended'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        // Boş liste gelirse (CV yoksa veya eşleşme yoksa)
        if (jobsJson.isEmpty) {
          return [];
        }
        return jobsJson.map((json) => RecommendedJob.fromJson(json)).toList();
      } else {
        print('Failed to load recommended jobs: ${response.body}');
        return [];
      }
    } catch (e) {
      print('GetRecommendedJobs Error: $e');
      return [];
    }
  }

  Future<SkillAnalysis?> getSkillAnalysis(String token, int jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs/$jobId/analysis'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return SkillAnalysis.fromJson(data);
      } else {
        print('Failed to load skill analysis: ${response.body}');
        return null;
      }
    } catch (e) {
      print('GetSkillAnalysis Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> uploadCv(String token, String filePath) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/users/me/cv'),
      );

      // Header'a token'ı ekle
      request.headers['Authorization'] = 'Bearer $token';

      // Dosyayı isteğe ekle
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      print('UploadCv Error: $e');
      return {'success': false, 'message': 'CV yüklenirken bir hata oluştu.'};
    }
  }

  Future<Map<String, dynamic>> createJob(
    String token,
    String title,
    String description,
    String location,
    String company,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/jobs'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'location': location,
          'company': company,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      print('CreateJob Error: $e');
      return {
        'success': false,
        'message': 'İlan oluşturulurken bir hata oluştu.',
      };
    }
  }

  Future<List<Job>> getMyJobs(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/employer/me/jobs'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return jobsJson.map((json) => Job.fromJson(json)).toList();
      } else {
        print('Failed to load my jobs: ${response.body}');
        return [];
      }
    } catch (e) {
      print('GetMyJobs Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> deleteJob(String token, int jobId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/jobs/$jobId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return _handleResponse(response);
    } catch (e) {
      print('DeleteJob Error: $e');
      return {'success': false, 'message': 'İlan silinirken bir hata oluştu.'};
    }
  }

  Future<Map<String, dynamic>> updateJob(
    String token,
    int jobId,
    String title,
    String description,
    String location,
    String company,
  ) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/jobs/$jobId'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'location': location,
          'company': company,
        }),
      );
      return _handleResponse(response);
    } catch (e) {
      print('UpdateJob Error: $e');
      return {
        'success': false,
        'message': 'İlan güncellenirken bir hata oluştu.',
      };
    }
  }

  Future<List<Applicant>> getApplicants(String token, int jobId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/jobs/$jobId/applicants'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> applicantsJson = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        return applicantsJson.map((json) => Applicant.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      print('GetApplicants Error: $e');
      return [];
    }
  }
}
