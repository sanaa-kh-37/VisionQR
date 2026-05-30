// lib/screens/batch_screen.dart
//
// Task 5 UI: pick a batch of quiz sheets -> run the full pipeline on each ->
// show per-student results and class summary -> export a CSV.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../services/batch_grading_service.dart';
import '../models/grade_report.dart';

class BatchScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const BatchScreen({super.key, this.onBack});

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  final ImagePicker _picker = ImagePicker();
  final BatchGradingService _service = BatchGradingService();

  List<File> _images = [];
  List<BatchRowResult> _results = [];
  bool _running = false;
  int _done = 0;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultiImage(imageQuality: 95);
    if (picked.isEmpty) return;
    setState(() {
      _images = picked.map((x) => File(x.path)).toList();
      _results = [];
      _done = 0;
    });
  }

  Future<void> _run() async {
    if (_images.isEmpty) return;
    setState(() {
      _running = true;
      _done = 0;
      _results = [];
    });
    final results = await _service.processAll(
      _images,
      onProgress: (done, total) {
        if (mounted) setState(() => _done = done);
      },
    );
    if (mounted) {
      setState(() {
        _results = results;
        _running = false;
      });
    }
  }

  Future<void> _export() async {
    final file = await _service.saveCsv(_results);
    await Share.shareXFiles([XFile(file.path)],
        text: 'Quiz batch results');
  }

  @override
  Widget build(BuildContext context) {
    final summary = _results.isEmpty ? null : _service.summarize(_results);

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: widget.onBack)
            : null,
        title: Text("Batch Grading",
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _running ? null : _pick,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent),
                    icon: const Icon(Icons.photo_library),
                    label: Text(_images.isEmpty
                        ? "Select Sheets"
                        : "${_images.length} selected"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                    (_running || _images.isEmpty) ? null : _run,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text("Process"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_running) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 10),
              Center(
                  child: Text("Grading $_done / ${_images.length} sheets…",
                      style: const TextStyle(color: Colors.white70))),
            ],

            if (summary != null && !_running) ...[
              _summaryCard(summary),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _export,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                icon: const Icon(Icons.file_download),
                label: const Text("Export CSV"),
              ),
              const SizedBox(height: 20),
              ..._results.map(_resultTile),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(BatchSummary s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Class Summary",
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueAccent,
                  fontSize: 16)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 12, children: [
            _stat("Graded", "${s.processed}", Colors.greenAccent),
            if (s.failed > 0) _stat("Failed", "${s.failed}", Colors.redAccent),
            _stat("Average", fmtNum(s.averageMarks), Colors.cyanAccent),
            _stat("Avg %", "${s.averagePercentage.toStringAsFixed(1)}%",
                Colors.cyanAccent),
            _stat("Highest", fmtNum(s.highest), Colors.greenAccent),
            _stat("Lowest", fmtNum(s.lowest), Colors.orangeAccent),
          ]),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
      ]),
    );
  }

  Widget _resultTile(BatchRowResult r) {
    if (!r.ok || r.report == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text("${r.fileName}\n${r.error ?? 'failed'}",
                style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ]),
      );
    }
    final rep = r.report!;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(children: [
        CircleAvatar(
          backgroundColor: _gradeColor(rep.grade).withValues(alpha: 0.15),
          child: Text(rep.grade,
              style: TextStyle(
                  color: _gradeColor(rep.grade),
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.name.isEmpty ? "Unknown" : r.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text("${r.regNo}  •  ${r.className}",
                  style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        Text(rep.scoreText,
            style: GoogleFonts.spaceGrotesk(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
      ]),
    );
  }

  Color _gradeColor(String g) {
    switch (g) {
      case 'A':
        return Colors.greenAccent;
      case 'B':
        return Colors.lightGreenAccent;
      case 'C':
        return Colors.cyanAccent;
      case 'D':
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }
}