import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _pickAndUploadCv(BuildContext context) async {
    final scaffold = ScaffoldMessenger.of(context);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;
      if (filePath != null) {
        scaffold.showSnackBar(
          const SnackBar(content: Text('Uploading CV... Please wait.')),
        );
        final response = await ApiService().uploadCv(auth.token!, filePath);

        if (response['success']) {
          auth.setCvStatus(true);
          scaffold.showSnackBar(
            const SnackBar(
              content: Text(
                'CV uploaded successfully! Recommendations are being updated.',
              ),
            ),
          );
        } else {
          scaffold.showSnackBar(SnackBar(content: Text(response['message'])));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Burada 'listen: true' (varsayılan) kalmalı ki profil bilgileri güncellensin
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                user?.email.substring(0, 1).toUpperCase() ?? "U",
                style: const TextStyle(
                  fontSize: 40,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.email ?? "No Email",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              user?.role == 'employer'
                  ? "Employer Account"
                  : "Job Seeker Account",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            if (user?.role == 'job_seeker') ...[
              _buildProfileOption(
                context,
                icon: Icons.upload_file,
                title: "Upload New CV",
                subtitle: auth.hasCv
                    ? "You have an active CV"
                    : "No CV uploaded yet",
                onTap: () => _pickAndUploadCv(context),
                isHighlight: !auth.hasCv,
              ),
              const SizedBox(height: 16),
            ],

            // --- GÜVENLİ ÇIKIŞ BUTONU ---
            _buildProfileOption(
              context,
              icon: Icons.logout,
              title: "Log Out",
              subtitle: "Sign out from your account",
              onTap: () async {
                // 1. Dinlemeyen (listen: false) bir provider örneği al
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );

                // 2. Çıkış işleminin bitmesini bekle
                await authProvider.logout();

                // 3. Ekran hala açıksa güvenli yönlendirme yap
                if (context.mounted) {
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/auth', (route) => false);
                }
              },
              isDestructive: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isHighlight = false,
  }) {
    return Card(
      elevation: 0,
      color: isHighlight
          ? Theme.of(context).primaryColor.withOpacity(0.05)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isHighlight
            ? BorderSide(color: Theme.of(context).primaryColor)
            : BorderSide.none,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withOpacity(0.1)
                : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDestructive ? Colors.red : Colors.black87,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}
