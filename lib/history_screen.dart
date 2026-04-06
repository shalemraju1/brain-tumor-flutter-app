import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'widgets/app_widgets.dart';

class HistoryScreen extends StatefulWidget {

  final int userId;
  final int refreshTick;

  const HistoryScreen({
    super.key,
    required this.userId,
    required this.refreshTick,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {

  List<Map<String, dynamic>> history = [];
  bool loading = true;
  String? errorMessage;

  Future<void> loadHistory() async {
    setState(() => loading = true);

    try {
      final decoded = await ApiService.fetchHistory(widget.userId);
      final parsed = decoded
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;

      setState(() {
        history = parsed;
        errorMessage = null;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) {
      loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Prediction History"),
      ),
      body: RefreshIndicator(
        onRefresh: loadHistory,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 32),
                              const SizedBox(height: 10),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: () async => loadHistory(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
            : history.isEmpty
                ? const Center(child: Text("No History Found"))
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: history.length + 1,
                    itemBuilder: (context, index) {
                      if (index == history.length) {
                        return const AppCopyrightFooter();
                      }

                      final item = history[index];
                      final prediction = ApiService.extractPrediction(item);
                      final confidence = ApiService.extractConfidence(item);
                      final date = (item["date"] ?? item["created_at"] ?? "").toString();

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.analytics_outlined)),
                          title: Text(prediction),
                          subtitle: Text("Confidence: ${confidence.toStringAsFixed(2)}%"),
                          trailing: SizedBox(
                            width: 92,
                            child: Text(
                              date,
                              textAlign: TextAlign.right,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}