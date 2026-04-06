import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'home_shell.dart';
import 'register_screen.dart';
import 'services/api_service.dart';
import 'services/session_service.dart';
import 'widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool rememberMe = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      await showErrorDialog(context, 'Please enter email and password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {

      final auth = await ApiService.login(
        email: email,
        password: password,
      );

      debugPrint('LOGIN SUCCESS user_id=${auth.userId} email=${auth.email}');

      if (rememberMe) {
        await SessionService.saveSession(userId: auth.userId, email: auth.email);
        debugPrint('SESSION SAVED user_id=${auth.userId}');
      } else {
        await SessionService.clearSession();
        debugPrint('SESSION CLEARED (rememberMe=false)');
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        buildFadeRoute(
          HomeShell(
            userId: auth.userId,
            userEmail: auth.email,
          ),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      debugPrint('LOGIN ERROR: $e');
      await showErrorDialog(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Brain Tumor Detection', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 6),
                        const Text('Secure medical login'),
                        const SizedBox(height: 20),
                        TextField(
                          controller: emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckboxListTile(
                          value: rememberMe,
                          onChanged: (value) {
                            setState(() {
                              rememberMe = value ?? true;
                            });
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: const Text('Remember Me'),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: loading ? null : login,
                          child: loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Login'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              buildFadeRoute(const RegisterScreen()),
                            );
                          },
                          child: const Text('Create New Account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}