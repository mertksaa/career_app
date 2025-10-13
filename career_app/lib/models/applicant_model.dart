// lib/models/applicant_model.dart
class Applicant {
  final int id;
  final String email;
  final String? cvPath;

  Applicant({required this.id, required this.email, this.cvPath});

  factory Applicant.fromJson(Map<String, dynamic> json) {
    return Applicant(
      id: json['id'],
      email: json['email'],
      cvPath: json['cv_path'],
    );
  }
}
