// lib/providers/favorites_provider.dart
import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';

class FavoritesProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Job> _favoriteJobs = [];
  bool _isLoading = false;
  Set<int> _favoriteJobIds =
      {}; // Hızlı kontrol için favori ID'lerini tutan set

  List<Job> get favoriteJobs => _favoriteJobs;
  bool get isLoading => _isLoading;

  // Bir ilanın favori olup olmadığını hızlıca kontrol etmek için
  bool isFavorite(int jobId) {
    return _favoriteJobIds.contains(jobId);
  }

  // Kullanıcının favorilerini backend'den çeken fonksiyon
  Future<void> fetchFavorites(String token) async {
    _isLoading = true;
    notifyListeners();

    _favoriteJobs = await _apiService.getFavorites(token);
    _favoriteJobIds = _favoriteJobs.map((job) => job.id).toSet();

    _isLoading = false;
    notifyListeners();
  }

  // Bir ilanı favorilere ekleyen/çıkaran fonksiyon
  Future<void> toggleFavoriteStatus(String token, Job job) async {
    final isCurrentlyFavorite = isFavorite(job.id);

    // Arayüzü anında güncellemek için iyimser bir yaklaşımla listeyi hemen değiştiriyoruz
    if (isCurrentlyFavorite) {
      _favoriteJobs.removeWhere((j) => j.id == job.id);
      _favoriteJobIds.remove(job.id);
    } else {
      _favoriteJobs.add(job);
      _favoriteJobIds.add(job.id);
    }
    notifyListeners();

    // Ardından API isteğini gönderiyoruz
    final result = await _apiService.toggleFavorite(token, job.id);

    // Eğer API isteği başarısız olursa, yaptığımız değişikliği geri alıyoruz.
    if (!result['success']) {
      if (isCurrentlyFavorite) {
        _favoriteJobs.add(job);
        _favoriteJobIds.add(job.id);
      } else {
        _favoriteJobs.removeWhere((j) => j.id == job.id);
        _favoriteJobIds.remove(job.id);
      }
      // Kullanıcıya hata hakkında bilgi ver (opsiyonel)
      print("Favori işlemi başarısız oldu, geri alınıyor.");
      notifyListeners();
    }
  }
}
