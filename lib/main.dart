import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'home_shell.dart';
import 'login_screen.dart';
import 'services/session_service.dart';
import 'services/theme_service.dart';

void main() {
  runApp(const BrainTumorApp());
}

class BrainTumorApp extends StatefulWidget {
  const BrainTumorApp({super.key});

  @override
  State<BrainTumorApp> createState() => _BrainTumorAppState();
}

class _BrainTumorAppState extends State<BrainTumorApp> {
  @override
  void initState() {
    super.initState();
    ThemeService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeModeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: "Brain Tumor Detection",
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const _AppStartupGate(),
        );
      },
    );
  }
}

class _AppStartupGate extends StatefulWidget {
  const _AppStartupGate();

  @override
  State<_AppStartupGate> createState() => _AppStartupGateState();
}

class _AppStartupGateState extends State<_AppStartupGate> {
  late final Future<SessionData?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionFuture = _restoreSession();
  }

  Future<SessionData?> _restoreSession() async {
    try {
      final session = await SessionService.getSession();
      if (session == null) return null;

      if (!SessionService.isValidSession(session)) {
        await SessionService.clearSession();
        return null;
      }

      return session;
    } catch (_) {
      await SessionService.clearSession();
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SessionData?>(
      future: _sessionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupSplash();
        }

        final session = snapshot.data;
        if (session == null) {
          return const LoginScreen();
        }

        return HomeShell(userId: session.userId, userEmail: session.email);
      },
    );
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: GradientBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: Colors.white,
                child: Icon(Icons.biotech, size: 34, color: AppTheme.primaryBlue),
              ),
              SizedBox(height: 14),
              Text(
                'Brain Tumor Detection',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}