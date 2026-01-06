class Applicant {
  final int userId;
  final String email;
  final String applicationDate;
  final double matchScore;

  Applicant({
    required this.userId,
    required this.email,
    required this.applicationDate,
    required this.matchScore,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      userId: json['user_id'] ?? 0,
      email: json['email'] ?? '',
      applicationDate: json['application_date'] ?? '',
      // Backend'den sayı veya null gelebilir, double'a çeviriyoruz
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
