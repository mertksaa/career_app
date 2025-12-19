import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../models/recommended_job_model.dart';
import '../models/job_model.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final bool isRecommended;

  const JobCard({
    super.key,
    required this.job,
    required this.onTap,
    this.isRecommended = false,
  });

  @override
  Widget build(BuildContext context) {
    double? matchScore;
    if (isRecommended && job is RecommendedJob) {
      matchScore = (job as RecommendedJob).matchScore;
    }

    // Skor rengini belirle
    Color scoreColor = Colors.grey;
    if (matchScore != null) {
      if (matchScore >= 0.85)
        scoreColor = Colors.green; // Emerald
      else if (matchScore >= 0.50)
        scoreColor = Colors.orange;
      else
        scoreColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sol Taraf: Logo (veya İlk Harf)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    job.company?.substring(0, 1).toUpperCase() ?? "C",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Orta Taraf: Başlık ve Şirket
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title ?? "Başlık Yok",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.company ?? "Şirket Yok",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    // Konum ve Tip (Chip benzeri küçük yazılar)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            job.location ?? "Konum Belirtilmemiş",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sağ Taraf: Skor Göstergesi (Sadece Önerilenlerde)
              if (isRecommended && matchScore != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: CircularPercentIndicator(
                    radius: 24.0,
                    lineWidth: 5.0,
                    percent: matchScore, // 0.0 - 1.0 arası
                    center: Text(
                      "%${(matchScore * 100).toInt()}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    progressColor: scoreColor,
                    backgroundColor: Colors.grey[200]!,
                    circularStrokeCap: CircularStrokeCap.round,
                    animation: true,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
