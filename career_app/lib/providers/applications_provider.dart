import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';

class ApplicationsProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Job> _appliedJobs = [];
  bool _isLoading = false;
  Set<int> _appliedJobIds = {};

  List<Job> get appliedJobs => _appliedJobs;
  bool get isLoading => _isLoading;

  bool hasApplied(int jobId) {
    return _appliedJobIds.contains(jobId);
  }

  Future<void> fetchApplications(String token) async {
    _isLoading = true;
    notifyListeners();

    _appliedJobs = await _apiService.getApplications(token);
    _appliedJobIds = _appliedJobs.map((job) => job.id).toSet();

    _isLoading = false;
    notifyListeners();
  }

  // Bir ilana başvuran fonksiyon
  Future<bool> applyForJob(String token, Job job) async {
    // Arayüzü anında güncelle
    _appliedJobs.add(job);
    _appliedJobIds.add(job.id);
    notifyListeners();

    final result = await _apiService.applyForJob(token, job.id);

    // Eğer API isteği başarısız olursa, yaptığımız değişikliği geri al
    if (!result['success']) {
      _appliedJobs.removeWhere((j) => j.id == job.id);
      _appliedJobIds.remove(job.id);
      print("Başvuru işlemi başarısız oldu, geri alınıyor.");
      notifyListeners();
      return false;
    }
    return true;
  }
}
