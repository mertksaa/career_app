// lib/screens/employer/create_job_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/snackbar_provider.dart';
import '../../services/api_service.dart';
import '../main_nav_screen.dart';

class CreateJobScreen extends StatefulWidget {
  const CreateJobScreen({Key? key}) : super(key: key);

  @override
  _CreateJobScreenState createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _companyController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final apiService = ApiService();

    final response = await apiService.createJob(
      authProvider.token!,
      _titleController.text,
      _descriptionController.text,
      _locationController.text,
      _companyController.text,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // HATA DÜZELTMESİ: '.show' -> '.showSnackbar' olarak değiştirildi
    Provider.of<SnackbarProvider>(
      context,
      listen: false,
    ).showSnackbar(response['message'], isError: !response['success']);

    if (response['success']) {
      // Formu temizle
      _formKey.currentState?.reset();
      _titleController.clear();
      _locationController.clear();
      _companyController.clear();
      _descriptionController.clear();

      // Kullanıcıyı 'İlanlarım' sekmesine yönlendir (index 0)
      Provider.of<MainNavProvider>(context, listen: false).goToTab(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextFormField(
                  controller: _titleController,
                  labelText: 'Job Title',
                  icon: Icons.title,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _companyController,
                  labelText: 'Company Title',
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _locationController,
                  labelText: 'Location',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 16),
                _buildTextFormField(
                  controller: _descriptionController,
                  labelText: 'Job Description and Requirements',
                  icon: Icons.description,
                  maxLines: 8,
                ),
                const SizedBox(height: 24),
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submitForm,
                        icon: const Icon(Icons.publish),
                        label: const Text('Publish Job'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        alignLabelWithHint: maxLines > 1,
      ),
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'This field cannot be left blank.';
        }
        return null;
      },
    );
  }
}
