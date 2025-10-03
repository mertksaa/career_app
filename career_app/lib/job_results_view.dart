import 'package:flutter/material.dart';

class JobResult {
  final int jobId;
  final String title;
  final String company;
  final String location;
  final double score;

  JobResult({
    required this.jobId,
    required this.title,
    required this.company,
    required this.location,
    required this.score,
  });

  factory JobResult.fromMap(Map m) {
    return JobResult(
      jobId: (m['job_id'] ?? 0) is int
          ? m['job_id']
          : int.tryParse('${m['job_id']}') ?? 0,
      title: m['title'] ?? '',
      company: m['company'] ?? '',
      location: m['location'] ?? '',
      score: (m['score'] is num)
          ? (m['score'] as num).toDouble()
          : double.tryParse('${m['score']}') ?? 0.0,
    );
  }
}

class JobResultsView extends StatelessWidget {
  final List<JobResult> results;
  final String query;

  const JobResultsView({super.key, required this.results, required this.query});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matching Jobs')),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Text(
              'Query: $query',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text('No results found.'))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final r = results[i];
                        return Card(
                          elevation: 2,
                          child: ListTile(
                            title: Text(r.title),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(r.company),
                                const SizedBox(height: 4),
                                Text(r.location),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${(r.score * 100).round()}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Icon(Icons.work_outline, size: 20),
                              ],
                            ),
                            onTap: () {
                              // İleride: detay sayfası / kaydet / paylaş
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Selected: ${r.title} (${r.jobId})',
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
