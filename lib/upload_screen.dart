import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'services/api_service.dart';
import 'widgets/app_widgets.dart';

class UploadScreen extends StatefulWidget {
  final int userId;
  final String userEmail;
  final VoidCallback? onPredictionSuccess;

  const UploadScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    this.onPredictionSuccess,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final picker = ImagePicker();

  File? _image;
  Uint8List? _heatmapImage;
  bool _loading = false;
  bool _showHeatmap = false;
  Map<String, dynamic>? _result;

  Future<void> pickImage() async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1400,
    );

    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _result = null;
        _heatmapImage = null;
        _showHeatmap = false;
      });
    }
  }

  Future<void> predict() async {
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an MRI image first')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _result = null;
      _heatmapImage = null;
    });

    try {
      debugPrint('PREDICT START user_id=${widget.userId}');

      final result = await ApiService.predict(
        image: _image!,
        userId: widget.userId,
      );

      if (!mounted) return;

      setState(() {
        _result = result.raw;
        _heatmapImage = result.heatmapBytes;
      });

      debugPrint('PREDICT RESULT user_id=${widget.userId}: ${result.raw}');

      widget.onPredictionSuccess?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = null;
      });
      debugPrint('PREDICT ERROR user_id=${widget.userId}: $e');
      await showErrorDialog(context, e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String _prediction() {
    if (_result == null) return 'Unknown';
    return (_result!['prediction'] ?? _result!['result'] ?? 'Unknown').toString();
  }

  double _confidence() {
    final value = _result?['confidence'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _riskLevel() {
    final predictionText = _prediction().toLowerCase();
    final confidence = _confidence();

    if (predictionText.contains('no tumor')) return 'Low';
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

  String _suggestionForRisk(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return 'Consult neurologist immediately';
      case 'medium':
        return 'Further diagnosis recommended';
      default:
        return 'No tumor detected, maintain healthy lifestyle';
    }
  }

  Map<String, double> _probabilityData() {
    final raw = _result?['probabilities'];

    if (raw is Map) {
      final parsed = <String, double>{};
      raw.forEach((key, value) {
        if (value is num) {
          parsed[key.toString()] = value.toDouble();
        } else {
          final parsedValue = double.tryParse(value.toString()) ?? 0;
          parsed[key.toString()] = parsedValue;
        }
      });
      if (parsed.isNotEmpty) return parsed;
    }

    return {_prediction(): _confidence()};
  }

  Future<void> _downloadReport() async {
    if (_result == null || _result!.containsKey('error')) return;

    try {
      final doc = pw.Document();
      final risk = _riskLevel();
      final confidence = _confidence();
      final date = DateTime.now().toLocal().toString();

      final originalBytes = await _image!.readAsBytes();
      final originalMemory = pw.MemoryImage(originalBytes);
      final heatmapMemory = _heatmapImage != null ? pw.MemoryImage(_heatmapImage!) : null;

      doc.addPage(
        pw.MultiPage(
          build: (context) => [
            pw.Center(
              child: pw.Text(
                'Brain Tumor Report',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 18),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 0.6),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('User ID: ${widget.userId}'),
                  pw.SizedBox(height: 4),
                  pw.Text('User Email: ${widget.userEmail}'),
                  pw.SizedBox(height: 4),
                  pw.Text('Prediction: ${_prediction()}'),
                  pw.SizedBox(height: 4),
                  pw.Text('Confidence: ${confidence.toStringAsFixed(2)}%'),
                  pw.SizedBox(height: 4),
                  pw.Text('Risk Level: $risk'),
                  pw.SizedBox(height: 4),
                  pw.Text('Date: $date'),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text('Original MRI Image', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Center(
              child: pw.Container(
                height: 220,
                width: 220,
                decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                child: pw.Image(originalMemory, fit: pw.BoxFit.cover),
              ),
            ),
            if (heatmapMemory != null) ...[
              pw.SizedBox(height: 16),
              pw.Text('Heatmap Image', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Container(
                  height: 220,
                  width: 220,
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.6)),
                  child: pw.Image(heatmapMemory, fit: pw.BoxFit.cover),
                ),
              ),
            ],
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      if (!mounted) return;
      await showErrorDialog(context, 'Unable to create report: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload MRI Scan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: InkWell(
              onTap: pickImage,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200, width: 1.5),
                        color: Colors.blue.shade50,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: _image == null
                          ? const Column(
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 52, color: Colors.blue),
                                SizedBox(height: 8),
                                Text('Tap to select MRI image'),
                                SizedBox(height: 4),
                                Text('Upload card style area', style: TextStyle(fontSize: 12)),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_image!, height: 210, fit: BoxFit.cover),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: pickImage,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Select Image'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : predict,
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('Predict'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_loading)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text('Analyzing MRI... please wait'),
                  ],
                ),
              ),
            ),
          if (_result != null) _buildResultSection(context),
        ],
      ),
    );
  }

  Widget _buildResultSection(BuildContext context) {
    final prediction = _prediction();
    final confidence = _confidence();
    final risk = _riskLevel();
    final riskColor = _riskColor(risk);
    final probabilities = _probabilityData();

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Prediction Result', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: riskColor.withValues(alpha: 0.15),
                    foregroundColor: riskColor,
                    child: const Icon(Icons.biotech),
                  ),
                  title: Text('Tumor Type: $prediction'),
                  subtitle: Text('Confidence: ${confidence.toStringAsFixed(2)}%'),
                  trailing: Chip(
                    label: Text(risk),
                    backgroundColor: riskColor.withValues(alpha: 0.16),
                    side: BorderSide.none,
                  ),
                ),
                if (_heatmapImage != null) ...[
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Heatmap View'),
                    subtitle: Text(_showHeatmap ? 'Showing heatmap' : 'Showing original image'),
                    value: _showHeatmap,
                    onChanged: (value) {
                      setState(() {
                        _showHeatmap = value;
                      });
                    },
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: _showHeatmap
                        ? Image.memory(_heatmapImage!, height: 210, fit: BoxFit.cover)
                        : (_image != null
                            ? Image.file(_image!, height: 210, fit: BoxFit.cover)
                            : const SizedBox.shrink()),
                  ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Probability Distribution', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                ...probabilities.entries.map((entry) {
                  final value = entry.value.clamp(0, 100);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${entry.key}: ${value.toStringAsFixed(1)}%'),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(value: value / 100, minHeight: 9),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: riskColor.withValues(alpha: 0.14),
              child: Icon(Icons.tips_and_updates_outlined, color: riskColor),
            ),
            title: const Text('Clinical Suggestion'),
            subtitle: Text(_suggestionForRisk(risk)),
          ),
        ),
        const SizedBox(height: 6),
        FilledButton.icon(
          onPressed: _downloadReport,
          icon: const Icon(Icons.download),
          label: const Text('Download Report'),
        ),
        const AppCopyrightFooter(),
      ],
    );
  }
}
