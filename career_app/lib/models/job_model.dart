class Job {
  final int id;
  final String title;
  final String company;
  final String location;
  final String? description;

  Job({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    this.description,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['job_id'] ?? 0,
      title: json['title'] ?? 'Başlık Yok',
      company: json['company'] ?? 'Şirket Bilgisi Yok',
      location: json['location'] ?? 'Konum Bilgisi Yok',
      description: json['description'],
    );
  }
}
