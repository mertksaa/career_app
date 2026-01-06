import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class JobDetailScreen extends StatefulWidget {
  final int jobId;

  const JobDetailScreen({super.key, required this.jobId});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Future<Job?> _jobFuture;
  bool _isDescriptionExpanded = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _jobFuture = ApiService().getJobDetails(auth.token!, widget.jobId);
  }

  void _toggleFavorite() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final response = await ApiService().toggleFavorite(
      auth.token!,
      widget.jobId,
    );

    if (response['success'] == true) {
      setState(() {
        _isFavorite = response['is_favorite'] ?? !_isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['message']),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Job Details",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : Colors.black,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context),
      body: FutureBuilder<Job?>(
        future: _jobFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Job not found."));
          }

          final job = snapshot.data!;
          if (_isFavorite == false && job.isFavorite == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _isFavorite = true;
              });
            });
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            job.company?.substring(0, 1).toUpperCase() ?? "C",
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        job.title ?? "No Title",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        job.company ?? "No Company",
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Description",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildExpandableText(
                  job.description ?? "No description available.",
                ),
                const SizedBox(height: 24),
                if (job.requirements != null &&
                    job.requirements!.isNotEmpty) ...[
                  const Text(
                    "Requirements",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    job.requirements!,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () async {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          final scaffold = ScaffoldMessenger.of(context);

          scaffold.showSnackBar(const SnackBar(content: Text("Applying...")));

          // DÜZELTME: Senin servisin Map dönüyor, onu karşılıyoruz
          final response = await ApiService().applyForJob(
            auth.token!,
            widget.jobId,
          );

          if (response['success'] == true) {
            scaffold.showSnackBar(
              const SnackBar(
                content: Text("Successfully applied!"),
                backgroundColor: Colors.green,
              ),
            );
          } else {
            scaffold.showSnackBar(
              SnackBar(
                content: Text(response['message'] ?? "Failed to apply"),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          "Apply Now",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildExpandableText(String text) {
    if (text.length < 200)
      return Text(
        text,
        style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
      );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isDescriptionExpanded ? text : "${text.substring(0, 200)}...",
          style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
        ),
        TextButton(
          onPressed: () =>
              setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
          child: Text(
            _isDescriptionExpanded ? "Show Less" : "Read More",
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
