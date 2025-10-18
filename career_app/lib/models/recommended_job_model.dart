// lib/models/recommended_job_model.dart
import './job_model.dart';

class RecommendedJob extends Job {
  final double matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;

  RecommendedJob({
    required super.id,
    required super.title,
    required super.company,
    required super.location,
    super.description,
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
  });

  factory RecommendedJob.fromJson(Map<String, dynamic> json) {
    // Job.fromJson'dan temel bilgileri al
    final Job baseJob = Job.fromJson(json);

    return RecommendedJob(
      id: baseJob.id,
      title: baseJob.title,
      company: baseJob.company,
      location: baseJob.location,
      description: baseJob.description,
      // Yeni (Recommended) alanları ekle
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      matchedSkills: List<String>.from(json['matched_skills'] ?? []),
      missingSkills: List<String>.from(json['missing_skills'] ?? []),
    );
  }
}
