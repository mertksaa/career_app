import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLogin = true;
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _role = 'job_seeker';

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    bool success;

    // Klavye açıksa kapat
    FocusScope.of(context).unfocus();

    if (_isLogin) {
      success = await auth.login(_email, _password);
    } else {
      success = await auth.register(_email, _password, _role);
    }

    if (success) {
      if (!mounted) return;
      if (!_isLogin) {
        setState(() {
          _isLogin = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registration successful! Please login."),
          ),
        );
      } else {
        // pushReplacementNamed kullanarak geri dönüşü engelle
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? "An error occurred"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // AuthProvider'ı dinle (loading durumunu görmek için)
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.work_outline,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              Text(
                "Career AI",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(
                          _isLogin ? "Welcome Back" : "Create Account",
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          initialValue:
                              "employer@test.com", // Test için kolaylık (istersen sil)
                          decoration: const InputDecoration(
                            labelText: 'Email Address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (val) =>
                              (val == null || !val.contains('@'))
                              ? 'Invalid email'
                              : null,
                          onSaved: (val) => _email = val!,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          initialValue: "123456", // Test için kolaylık
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                          validator: (val) => (val == null || val.length < 6)
                              ? 'Min 6 characters'
                              : null,
                          onSaved: (val) => _password = val!,
                        ),
                        if (!_isLogin) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField(
                            value: _role,
                            decoration: const InputDecoration(
                              labelText: 'I am a...',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'job_seeker',
                                child: Text('Job Seeker'),
                              ),
                              DropdownMenuItem(
                                value: 'employer',
                                child: Text('Employer'),
                              ),
                            ],
                            onChanged: (val) =>
                                setState(() => _role = val.toString()),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          // Loading ise dönen yuvarlak, değilse buton göster
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  onPressed: _submit,
                                  child: Text(_isLogin ? 'Login' : 'Register'),
                                ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => setState(() => _isLogin = !_isLogin),
                          child: Text(
                            _isLogin
                                ? 'Create new account'
                                : 'I already have an account',
                          ),
                        ),
                      ],
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
