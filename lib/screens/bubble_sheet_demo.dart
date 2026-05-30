// lib/screens/bubble_sheet_demo.dart
//
// Standalone DEMO for the read_bubble_sheet deliverable.
// Pick a sheet image -> runs read_bubble_sheet -> shows the structured
// {part1, part2} result and highlights the three special cases:
//   valid letter (blue) | unattempted/null (grey) | INVALID multi-fill (red)
//
// Wire it up from anywhere, e.g.:
//   Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const BubbleSheetDemo()));

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/student_answers.dart';
import '../services/bubble_sheet_reader.dart';

class BubbleSheetDemo extends StatefulWidget {
  final VoidCallback? onBack;
  const BubbleSheetDemo({super.key, this.onBack});

  @override
  State<BubbleSheetDemo> createState() => _BubbleSheetDemoState();
}

class _BubbleSheetDemoState extends State<BubbleSheetDemo> {
  final ImagePicker _picker = ImagePicker();

  File? _image;
  StudentAnswers? _answers;
  String? _error;
  bool _loading = false;

  Future<void> _run(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() {
      _image = File(picked.path);
      _loading = true;
      _error = null;
      _answers = null;
    });

    try {
      final result = await read_bubble_sheet(File(picked.path));
      setState(() => _answers = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('read_bubble_sheet — Demo'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
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
                    onPressed: _loading ? null : () => _run(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : () => _run(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_image != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_image!, height: 200, fit: BoxFit.cover),
              ),

            if (_loading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 8),
              const Center(child: Text('Reading bubbles…')),
            ],

            if (_error != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Text('Read failed: $_error',
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            ],

            if (_answers != null) ..._buildResult(_answers!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResult(StudentAnswers a) {
    final pretty = const JsonEncoder.withIndent('  ').convert(a.toJson());

    return [
      const SizedBox(height: 24),

      // Summary line covering the three evaluation cases.
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _stat('Answered', a.answeredCount, Colors.blueAccent),
          _stat('Unattempted', a.unattemptedQuestions.length, Colors.grey),
          _stat('Invalid', a.invalidQuestions.length, Colors.redAccent),
          _stat('Total', a.totalCount, Colors.black54),
        ],
      ),
      const SizedBox(height: 20),

      _partBlock('Part - I', a.part1),
      const SizedBox(height: 16),
      _partBlock('Part - II', a.part2),
      const SizedBox(height: 24),

      const Text('Structured result',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          pretty,
          style: const TextStyle(
              fontFamily: 'monospace', color: Colors.greenAccent, fontSize: 13),
        ),
      ),
    ];
  }

  Widget _stat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text('$label: $value',
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _partBlock(String title, Map<String, String?> answers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: answers.entries.map((e) => _bubbleChip(e.key, e.value)).toList(),
        ),
      ],
    );
  }

  Widget _bubbleChip(String q, String? value) {
    late Color color;
    late String text;

    if (value == null) {
      color = Colors.grey;
      text = '$q = —';
    } else if (value == StudentAnswers.invalidFlag) {
      color = Colors.redAccent;
      text = '$q = INVALID';
    } else {
      color = Colors.blueAccent;
      text = '$q = $value';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    );
  }
}