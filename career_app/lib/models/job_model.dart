class Job {
  final int id;
  final String title;
  final String company;
  final String location;
  final String? description;
  final String? requirements; // <-- YENİ EKLENEN
  final String? benefits; // İlerisi için hazır olsun
  final String? companyProfile;
  final double? matchScore;
  final bool isFavorite;
  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    this.description,
    this.requirements, // <-- Constructor'a ekle
    this.benefits,
    this.companyProfile,
    this.matchScore,
    this.isFavorite = false,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['job_id'] ?? 0,
      title: json['title'] ?? 'Başlık Yok',
      company: json['company'] ?? 'Şirket Bilgisi Yok',
      location: json['location'] ?? 'Konum Bilgisi Yok',
      description: json['description'],
      requirements: json['requirements_json'],
      benefits: json['benefits'],
      companyProfile: json['company_profile'],
      matchScore: json['match_score'] != null
          ? (json['match_score'] as num).toDouble()
          : null,
      isFavorite: json['is_favorite'] ?? false,
    );
  }
}
