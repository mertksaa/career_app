import 'package:flutter/material.dart';
import '../../models/job_model.dart';
import './edit_job_screen.dart';
import './applicants_screen.dart';

class EmployerJobDetailScreen extends StatelessWidget {
  final Job job;

  const EmployerJobDetailScreen({Key? key, required this.job})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(job.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditJobScreen(job: job),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başvuranları Görüntüle Butonu
            Card(
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.people, color: Colors.blue),
                title: const Text('Show Applicants'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // YENİ: Başvuranlar listesi ekranına yönlendirme
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ApplicantsScreen(jobId: job.id, jobTitle: job.title),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // İlan Bilgileri
            Text(
              'Company: ${job.company}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Location: ${job.location}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            const Text(
              'Job Description',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              job.description ?? 'No Descriptipn.',
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
