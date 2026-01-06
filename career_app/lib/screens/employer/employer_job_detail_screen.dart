import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'job_applicants_screen.dart';
import 'edit_job_screen.dart'; // <-- YENİ IMPORT

class EmployerJobDetailScreen extends StatefulWidget {
  final Job job;

  const EmployerJobDetailScreen({super.key, required this.job});

  @override
  State<EmployerJobDetailScreen> createState() =>
      _EmployerJobDetailScreenState();
}

class _EmployerJobDetailScreenState extends State<EmployerJobDetailScreen> {
  late Job currentJob; // Düzenleme yapılırsa anlık güncellemek için

  @override
  void initState() {
    super.initState();
    currentJob = widget.job;
  }

  void _deleteJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Job"),
        content: const Text("Are you sure you want to delete this job?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final response = await ApiService().deleteJob(auth.token!, currentJob.id);

      if (mounted) {
        if (response['success'] == true) {
          // success kontrolü
          Navigator.pop(context); // Listeye dön
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Job deleted.")));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? "Error")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Manage Job",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          // DÜZENLEME BUTONU
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () async {
              // Edit Ekranına Git
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditJobScreen(job: currentJob),
                ),
              );

              // Eğer güncelleme yapıldıysa (result == true), sayfayı yenilememiz lazım
              // Ancak basitlik olsun diye direkt pop edip listeye dönebiliriz
              // veya API'den tekrar çekebiliriz.
              // Şimdilik kullanıcıyı listeye geri gönderelim ki güncel hali görsün.
              if (result == true && mounted) {
                Navigator.pop(context);
              }
            },
          ),
          // SİLME BUTONU
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteJob,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // BAŞLIK BİLGİLERİ
            Text(
              currentJob.title ?? "No Title",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currentJob.company ?? "No Company",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  currentJob.location ?? "Remote",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const Divider(height: 32),

            // AÇIKLAMA
            const Text(
              "Description",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              currentJob.description ?? "",
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),

            // VIEW APPLICANTS BUTONU
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => JobApplicantsScreen(
                        jobId: currentJob.id,
                        jobTitle: currentJob.title ?? "Job",
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.people),
                label: const Text(
                  "View Applicants",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
