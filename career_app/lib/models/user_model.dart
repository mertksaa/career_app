// lib/models/user_model.dart

class User {
  final int id;
  final String email;
  final String role;

  User({required this.id, required this.email, required this.role});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(id: json['id'], email: json['email'], role: json['role']);
  }
}
