import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'widgets/app_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final int userId;
  final String userEmail;
  final int refreshTick;
  final ValueChanged<int> onNavigateToTab;

  const DashboardScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.refreshTick,
    required this.onNavigateToTab,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  String _lastPrediction = 'No scans yet';
  String _riskLevel = 'Low';
  int _totalScans = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      _loadSummary();
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final list = await ApiService.fetchHistory(widget.userId);
      debugPrint('DASHBOARD HISTORY user_id=${widget.userId}: $list');

      final parsed = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      if (!mounted) return;

      setState(() {
        _totalScans = parsed.length;
        if (parsed.isNotEmpty) {
          final latest = parsed.first;
          _lastPrediction = ApiService.extractPrediction(latest);
          final confidence = ApiService.extractConfidence(latest);
          _riskLevel = _deriveRisk(_lastPrediction, confidence);
        } else {
          _lastPrediction = 'No scans yet';
          _riskLevel = 'Low';
        }
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

  String _deriveRisk(String prediction, double confidence) {
    final text = prediction.toLowerCase();
    if (text.contains('no tumor')) return 'Low';
    if (confidence >= 80) return 'High';
    if (confidence >= 50) return 'Medium';
    return 'Low';
  }

  Color _riskColor(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.userEmail.split('@').first;

    return RefreshIndicator(
      onRefresh: _loadSummary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Welcome, $name',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('Monitor brain MRI scans and risk insights'),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Unable to load dashboard data'),
                    const SizedBox(height: 8),
                    Text(_errorMessage!, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    FilledButton(onPressed: _loadSummary, child: const Text('Retry')),
                  ],
                ),
              ),
            )
          else ...[
            AppInfoCard(
              title: 'Total Scans',
              value: '$_totalScans',
              icon: Icons.analytics_outlined,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
            AppInfoCard(
              title: 'Last Prediction',
              value: _lastPrediction,
              icon: Icons.biotech_outlined,
              color: Colors.indigo,
            ),
            const SizedBox(height: 12),
            AppInfoCard(
              title: 'Risk Level',
              value: _riskLevel,
              icon: Icons.shield_outlined,
              color: _riskColor(_riskLevel),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => widget.onNavigateToTab(1),
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Upload Scan'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => widget.onNavigateToTab(2),
                            icon: const Icon(Icons.history),
                            label: const Text('View History'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const AppCopyrightFooter(),
          ],
          if (!_loading && _errorMessage != null) const AppCopyrightFooter(),
        ],
      ),
    );
  }
}
