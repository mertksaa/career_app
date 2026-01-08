import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class EditProfileManualScreen extends StatefulWidget {
  const EditProfileManualScreen({super.key});

  @override
  State<EditProfileManualScreen> createState() =>
      _EditProfileManualScreenState();
}

class _EditProfileManualScreenState extends State<EditProfileManualScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllerlar
  final _titleController = TextEditingController();
  final _skillsController = TextEditingController();
  final _summaryController = TextEditingController();

  bool _isLoading = false;

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // API Çağrısı
    final response = await ApiService().updateProfileManual(
      auth.token!,
      _titleController.text,
      _skillsController.text,
      _summaryController.text,
    );

    setState(() => _isLoading = false);

    if (mounted) {
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Profile updated! Calculating matches..."),
          ),
        );
        Navigator.pop(context); // Geri dön
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(response['message'])));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile (Manual)"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "No CV? No Problem!",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Fill in the details below to get job recommendations.",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // 1. İş Unvanı
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: "Job Title / Profession",
                  hintText: "e.g. Electrician, Driver, Sales Manager",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work_outline),
                ),
                validator: (v) =>
                    v!.isEmpty ? "Please enter a job title" : null,
              ),
              const SizedBox(height: 16),

              // 2. Yetenekler
              TextFormField(
                controller: _skillsController,
                decoration: const InputDecoration(
                  labelText: "Skills (Comma separated)",
                  hintText: "e.g. Welding, Forklift, English, Excel",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.build_circle_outlined),
                ),
                validator: (v) =>
                    v!.isEmpty ? "Please enter at least one skill" : null,
              ),
              const SizedBox(height: 16),

              // 3. Özet / Deneyim
              TextFormField(
                controller: _summaryController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Experience & Summary",
                  hintText:
                      "Describe your experience. Example: I have 5 years of experience in truck driving across Europe...",
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) =>
                    v!.isEmpty ? "Please describe your experience" : null,
              ),
              const SizedBox(height: 32),

              // Kaydet Butonu
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Save & Find Jobs",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
