import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'dashboard_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'upload_screen.dart';

class HomeShell extends StatefulWidget {
  final int userId;
  final String userEmail;

  const HomeShell({
    super.key,
    required this.userId,
    required this.userEmail,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  int _refreshTick = 0;

  void _notifyDataChanged() {
    setState(() {
      _refreshTick++;
    });
  }

  void _goToTab(int tabIndex) {
    setState(() {
      if (_index == 1 && tabIndex == 0) {
        _refreshTick++;
      }
      _index = tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        userId: widget.userId,
        userEmail: widget.userEmail,
        refreshTick: _refreshTick,
        onNavigateToTab: _goToTab,
      ),
      UploadScreen(
        userId: widget.userId,
        userEmail: widget.userEmail,
        onPredictionSuccess: _notifyDataChanged,
      ),
      HistoryScreen(userId: widget.userId, refreshTick: _refreshTick),
      ProfileScreen(
        userId: widget.userId,
        userEmail: widget.userEmail,
        refreshTick: _refreshTick,
      ),
    ];

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(child: IndexedStack(index: _index, children: pages)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _goToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.upload_file), label: 'Upload'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}