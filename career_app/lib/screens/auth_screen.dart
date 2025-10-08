import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

// Ekranın modunu (Giriş mi, Kayıt mı) belirtmek için bir enum
enum AuthMode { Login, Register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  AuthMode _authMode = AuthMode.Login;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Sadece kayıt modunda kullanılacak
  String _selectedRole = 'job_seeker';

  void _switchAuthMode() {
    setState(() {
      _authMode = _authMode == AuthMode.Login
          ? AuthMode.Register
          : AuthMode.Login;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return; // Form geçerli değilse işlemi durdur
    }
    _formKey.currentState!.save();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    bool success = false;
    if (_authMode == AuthMode.Login) {
      success = await authProvider.login(
        _emailController.text,
        _passwordController.text,
      );
    } else {
      success = await authProvider.register(
        _emailController.text,
        _passwordController.text,
        _selectedRole,
      );
      if (success) {
        // Kayıt başarılıysa kullanıcıya bilgi ver ve giriş moduna geçir
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kayıt başarılı! Şimdi giriş yapabilirsiniz.'),
            backgroundColor: Colors.green,
          ),
        );
        _switchAuthMode();
      }
    }

    // Eğer giriş başarısızsa veya kayıt başarısızsa hata mesajını göster
    if (!success && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLogin = _authMode == AuthMode.Login;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 80,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  isLogin ? 'Hoş Geldiniz!' : 'Hesap Oluşturun',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Lütfen geçerli bir email girin.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Şifre',
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length < 6) {
                      return 'Şifre en az 6 karakter olmalı.';
                    }
                    return null;
                  },
                ),
                // Kayıt modundaysa rol seçimi göster
                if (!isLogin) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Hesap Tipi',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'job_seeker',
                        child: Text('İş Arıyorum'),
                      ),
                      DropdownMenuItem(
                        value: 'employer',
                        child: Text('İş Verenim'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                ],
                const SizedBox(height: 24),
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _submit,
                        child: Text(isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
                      ),
                TextButton(
                  onPressed: _switchAuthMode,
                  child: Text(
                    isLogin
                        ? 'Hesabınız yok mu? Kayıt Olun'
                        : 'Zaten bir hesabınız var mı? Giriş Yapın',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
