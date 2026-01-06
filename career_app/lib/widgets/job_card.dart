import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../models/recommended_job_model.dart'; // Bunu import etmeye devam edelim, zarar gelmez
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
    // --- DÜZELTME BURADA ---
    // Artık "is RecommendedJob" kontrolü yapmıyoruz.
    // Direkt modelin içindeki matchScore'u alıyoruz.
    double? matchScore = job.matchScore;
    // -----------------------

    Color scoreColor = Colors.grey;
    if (matchScore != null) {
      if (matchScore >= 0.85) {
        scoreColor = const Color(0xFF10B981); // Emerald (Yeşil)
      } else if (matchScore >= 0.50) {
        scoreColor = Colors.orange;
      } else if (matchScore > 0) {
        scoreColor = Colors.red;
      }
    }

    // Skor 0 ise veya null ise gösterme (Gürültü yapmasın)
    bool shouldShowScore = isRecommended && matchScore != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 110,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.03,
            ), // withOpacity yerine withValues/alpha (Flutter sürümüne göre)
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // 1. Logo
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      job.company?.substring(0, 1).toUpperCase() ?? "C",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // 2. Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        job.title ?? "No Title",
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.company ?? "No Company",
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 10,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                job.location ?? "Remote",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // 3. Skor Alanı
                if (shouldShowScore)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: CircularPercentIndicator(
                      radius: 22.0,
                      lineWidth: 4.0,
                      percent: matchScore! > 1.0 ? 1.0 : matchScore,
                      center: Text(
                        "%${(matchScore * 100).toInt()}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      progressColor: scoreColor,
                      backgroundColor: Colors.grey[100]!,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
