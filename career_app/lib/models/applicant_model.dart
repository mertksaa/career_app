class Applicant {
  final int userId;
  final String email;
  final bool hasCv;
  final String applicationDate;
  final String? lastUpdated;

  Applicant({
    required this.userId,
    required this.email,
    required this.hasCv,
    required this.applicationDate,
    this.lastUpdated,
  });

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      userId: json['user_id'],
      email: json['email'],
      hasCv: json['has_cv'] == 1 || json['has_cv'] == true,
      applicationDate: json['application_date'] ?? '',
      lastUpdated: json['last_updated'],
    );
  }
}
