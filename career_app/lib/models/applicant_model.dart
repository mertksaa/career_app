// lib/models/applicant_model.dart
class Applicant {
  final int userId;
  final String email;
  final bool hasCv; // <<< YENİ ALAN (hasCv hatası için)
  final String applicationDate; // <<< YENİ ALAN (applicationDate hatası için)

  Applicant({
    required this.userId,
    required this.email,
    required this.hasCv,
    required this.applicationDate,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      userId: json['user_id'],
      email: json['email'],
      // Gelen 'has_cv' değeri 1 (true) veya 0 (false) olabilir (SQLite bool)
      // VEYA null olabilir (LEFT JOIN)
      hasCv: json['has_cv'] == 1 || json['has_cv'] == true, // <<< YENİ PARSE
      applicationDate: json['application_date'] ?? '', // <<< YENİ PARSE
    );
  }
}
