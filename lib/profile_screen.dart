import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'services/api_service.dart';
import 'services/session_service.dart';
import 'services/theme_service.dart';
import 'widgets/app_widgets.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  final String userEmail;
  final int refreshTick;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.refreshTick,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _totalScans = 0;
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    try {
      final history = await ApiService.fetchHistory(widget.userId);
      if (!mounted) return;
      setState(() {
        _totalScans = history.length;
        _errorMessage = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await SessionService.clearSession();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      buildFadeRoute(const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(radius: 28, child: Icon(Icons.person, size: 28)),
                  const SizedBox(height: 12),
                  Text(widget.userEmail, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text('User ID: ${widget.userId}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: const Text('Total Scans'),
              subtitle: _loading
                  ? const Text('Loading...')
                  : (_errorMessage != null
                      ? Text(_errorMessage!)
                      : Text('$_totalScans reports generated')),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeService.themeModeNotifier,
            builder: (context, mode, _) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Theme Mode'),
                  subtitle: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: mode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        await ThemeService.setThemeMode(value);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _loadStats,
              child: const Text('Retry Loading Profile Stats'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () async => _logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const AppCopyrightFooter(),
        ],
      ),
    );
  }
}