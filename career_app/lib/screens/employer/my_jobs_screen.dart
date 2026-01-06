import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/job_model.dart';
import '../../widgets/job_card.dart';
import 'employer_job_detail_screen.dart'; // <-- YENİ EKRANI IMPORT ET

class MyJobsScreen extends StatefulWidget {
  const MyJobsScreen({super.key});

  @override
  State<MyJobsScreen> createState() => _MyJobsScreenState();
}

class _MyJobsScreenState extends State<MyJobsScreen> {
  late Future<List<Job>> _myJobsFuture;

  @override
  void initState() {
    super.initState();
    _refreshJobs();
  }

  void _refreshJobs() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() {
      _myJobsFuture = ApiService().getMyJobs(auth.token!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "My Job Postings",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _refreshJobs,
          ),
        ],
      ),
      body: FutureBuilder<List<Job>>(
        future: _myJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text("You haven't posted any jobs yet."),
            );
          }

          final jobs = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return JobCard(
                job: job,
                isRecommended: false,
                onTap: () {
                  // DÜZELTME: Detay sayfasına gidiyor
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EmployerJobDetailScreen(job: job),
                    ),
                  ).then(
                    (_) => _refreshJobs(),
                  ); // Geri dönünce listeyi yenile (Silinmiş olabilir)
                },
              );
            },
          );
        },
      ),
    );
  }
}
