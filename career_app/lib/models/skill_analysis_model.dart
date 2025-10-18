class SkillAnalysis {
  final double matchScore;
  final List<String> matchedSkills;
  final List<String> missingSkills;
  final bool userSkillsFound;
  final bool jobSkillsFound;

  SkillAnalysis({
    required this.matchScore,
    required this.matchedSkills,
    required this.missingSkills,
    required this.userSkillsFound,
    required this.jobSkillsFound,
  });

  factory SkillAnalysis.fromJson(Map<String, dynamic> json) {
    return SkillAnalysis(
      matchScore: (json['match_score'] as num?)?.toDouble() ?? 0.0,
      matchedSkills: List<String>.from(json['matched_skills'] ?? []),
      missingSkills: List<String>.from(json['missing_skills'] ?? []),
      userSkillsFound: json['user_skills_found'] ?? false,
      jobSkillsFound: json['job_skills_found'] ?? false,
    );
  }
}
