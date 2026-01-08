class Applicant {
  final int userId;
  final String email;
  final String applicationDate;
  final double matchScore;
  final int hasCv; // 0: Yok, 1: PDF, 2: Manuel
  final Map<String, dynamic>? profileData;

  Applicant({
    required this.userId,
    required this.email,
    required this.applicationDate,
    required this.matchScore,
    required this.hasCv,
    this.profileData,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      applicationDate: json['application_date'] ?? '',
      // Backend'den sayı veya null gelebilir, double'a çeviriyoruz
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      hasCv: json['has_cv'] ?? 0,
      profileData: json['profile_data'],
    );
  }
}
