import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/applications_provider.dart';

class ApplicationsScreen extends StatelessWidget {
  const ApplicationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final applicationsProvider = Provider.of<ApplicationsProvider>(context);
    final appliedJobs = applicationsProvider.appliedJobs;

    return Scaffold(
      body: applicationsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : appliedJobs.isEmpty
          ? const Center(
              child: Text(
                'Henüz hiç başvuru yapmadınız.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: appliedJobs.length,
              itemBuilder: (context, index) {
                final job = appliedJobs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                    title: Text(
                      job.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${job.company}\n${job.location}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
    );
  }
}
