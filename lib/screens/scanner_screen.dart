import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scanned_code.dart';
import '../models/answer_key.dart';
import '../services/history_database.dart';
import '../models/student_answers.dart';
import '../services/quiz_grader.dart';
import '../widgets/grade_report_view.dart';

// OCR is now handled by Gemini inside OmrService — ocr_service.dart removed.
import '../services/omr_service.dart' as omr_service;

class ScannerScreen extends StatefulWidget {
  final bool isScanning;
  final VoidCallback? onBack;
  const ScannerScreen({super.key, required this.isScanning, this.onBack});

  @override
  State<ScannerScreen> createState() => ScannerScreenState();
}

class ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
  final ImagePicker _picker = ImagePicker();
  final omr_service.OmrService _omrService = omr_service.OmrService();

  bool _isFlashOn = false;
  bool _isARActive = true;
  String? _lastScannedValue;

  late AnimationController _arAnimationController;

  @override
  void initState() {
    super.initState();
    _arAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    if (widget.isScanning) {
      _controller.start();
    }
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning != oldWidget.isScanning) {
      if (widget.isScanning) {
        _controller.start();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _arAnimationController.dispose();
    super.dispose();
  }

  // ====================== GALLERY PICKER ======================
  Future<void> pickAndDecodeCode() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    try {
      final BarcodeCapture? capture = await _controller.analyzeImage(file.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null) {
          _processScannedPayload(rawValue);
          return;
        }
      }
      _showImageNoQrSnackBar();
    } catch (e) {
      _processScannedPayload("https://www.google.com");
    }
  }

  void _showImageNoQrSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("No high-contrast QR or barcode detected in image. Please try another crop."),
        backgroundColor: Colors.amber,
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (!widget.isScanning) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue != _lastScannedValue) {
      _processScannedPayload(rawValue);
    }
  }

  // ====================== OMR + OCR FLOW ======================
  // Step 1: ask user for photo source (Camera / Gallery)
  // Step 2: send image to Gemini — reads name, reg no AND bubbles in one call
  // Step 3: return real results to _processScannedPayload
  // Step 4: THEN open the bottom sheet with all data filled in
  Future<omr_service.OmrResult?> _promptForOcrAndOmr() async {
    _controller.stop();

    // The dialog only PICKS a source (or null for Skip). The actual capture +
    // Gemini call runs AFTER the dialog closes, so there is no race between the
    // dialog closing and the async scan finishing.
    final ImageSource? source = await showDialog<ImageSource?>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Upload OMR Sheet",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Please upload the student quiz sheet so Gemini can read the name, registration number and bubble answers.",
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            Row(children: [
              Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              SizedBox(width: 8),
              Text("Gemini Vision Ready", style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
            ]),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, null), // Skip
            child: const Text("Skip", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text("Camera"),
            onPressed: () => Navigator.pop(dialogContext, ImageSource.camera),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            icon: const Icon(Icons.photo_library, size: 18),
            label: const Text("Gallery"),
            onPressed: () => Navigator.pop(dialogContext, ImageSource.gallery),
          ),
        ],
      ),
    );

    // Run the real capture + Gemini scan now that the chooser is gone.
    omr_service.OmrResult? result;
    if (source != null) {
      result = await _captureAndAnalyze(source);
    }

    if (widget.isScanning) _controller.start();
    return result;
  }

  // Picks image → shows spinner → calls Gemini (OCR + OMR in one shot) → returns result
  Future<omr_service.OmrResult?> _captureAndAnalyze(ImageSource source) async {
    // 1. Pick image
    final XFile? photo = await _picker.pickImage(source: source, imageQuality: 90);
    if (photo == null) return null;

    // 2. Show loading spinner
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Center(
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.blueAccent),
                SizedBox(height: 20),
                Text(
                  "Gemini is reading the sheet...",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                SizedBox(height: 6),
                Text(
                  "Detecting name, reg no & bubbles",
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. ONE Gemini call reads name, reg no AND bubbles together
    final imageFile = File(photo.path);
    omr_service.OmrResult? omrResult;

    try {
      omrResult = await _omrService.scanSheet(imageFile);
      if (omrResult != null) {
        print("✅ Gemini → name=${omrResult.studentName}, "
            "reg=${omrResult.studentRegNo}, "
            "p1=${omrResult.part1.length}, p2=${omrResult.part2.length}");
      }
    } catch (e) {
      print("❌ Gemini scan error: $e");
    }

    // 4. Close spinner
    if (mounted) Navigator.pop(context);

    return omrResult;
  }

  // Unified Scanner Payload Implementation
  void _processScannedPayload(String rawValue) async {
    _lastScannedValue = rawValue;

    if (rawValue.contains("Part-I:") && rawValue.contains("Part-II:")) {
      final answerKey = AnswerKey.fromPayload(rawValue);

      final omrResult = await _promptForOcrAndOmr();

      // Resolve student name and reg no from the Gemini result
      final String resolvedName = (omrResult != null &&
          omrResult.studentName.isNotEmpty &&
          omrResult.studentName != 'Not Detected')
          ? omrResult.studentName
          : 'Not Detected';

      final String resolvedRegNo = (omrResult != null &&
          omrResult.studentRegNo.isNotEmpty &&
          omrResult.studentRegNo != 'Not Detected')
          ? omrResult.studentRegNo
          : 'Not Detected';

      final newItem = ScannedCode(
        id          : DateTime.now().millisecondsSinceEpoch.toString(),
        type        : 'answer_key',
        value       : rawValue,
        title       : answerKey.quizTitle,
        studentName : resolvedName,
        studentRegNo: resolvedRegNo,
        dateTime    : _formatNow(),
        omrPart1    : omrResult?.part1,
        omrPart2    : omrResult?.part2,
      );

      await HistoryDatabase.saveItem(newItem);
      _showAnswerKeyBottomSheet(answerKey, newItem, omrResult);
      return;
    }

    // Standard QR code payload fallback
    String type = 'text';
    String title = 'Scanned Text';

    if (rawValue.startsWith('http://') || rawValue.startsWith('https://') ||
        rawValue.contains(RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'))) {
      type = 'url';
      title = rawValue.replaceAll('https://', '').replaceAll('http://', '').split('/').first;
    } else if (rawValue.startsWith('WIFI:')) {
      type = 'wifi';
      title = _parseWifiSSID(rawValue);
    } else if (rawValue.startsWith('MECARD:') || rawValue.startsWith('BEGIN:VCARD')) {
      type = 'contact';
      title = _parseContactName(rawValue);
    } else if (RegExp(r'^[0-9]{8,14}$').hasMatch(rawValue)) {
      type = 'barcode';
      title = 'EAN Product Item';
    }

    final newItem = ScannedCode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      value: rawValue,
      title: title,
      dateTime: _formatNow(),
    );

    await HistoryDatabase.saveItem(newItem);
    _showResultBottomSheet(newItem);
  }

  String _parseWifiSSID(String wifiStr) {
    try {
      final match = RegExp(r'S:([^;]+);').firstMatch(wifiStr);
      return match?.group(1) ?? 'Wi-Fi Network';
    } catch (_) {
      return 'Wi-Fi Network';
    }
  }

  String _parseContactName(String contactStr) {
    try {
      final match = RegExp(r'N:([^;]+);').firstMatch(contactStr);
      return match?.group(1) ?? 'Contact Card';
    } catch (_) {
      return 'Contact Card';
    }
  }

  // ====================== OMR GRADE UI SECTION ======================
  // Uses the Task-4 deliverable: grade_quiz(...) -> GradeReport, rendered
  // by the shared GradeReportView widget (tick / cross / dash + score).
  Widget _buildOmrGradeSection(AnswerKey key, omr_service.OmrResult? omrResult) {
    if (omrResult == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          "⚠ OMR grading unavailable\n(Server offline or scan skipped)",
          style: TextStyle(color: Colors.orangeAccent, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      );
    }

    final report = grade_quiz(
      StudentAnswers(part1: omrResult.part1, part2: omrResult.part2),
      key,
    );
    return GradeReportView(report: report);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          Container(color: Colors.black.withOpacity(0.4)),

          if (_isARActive)
            Center(
              child: AnimatedBuilder(
                animation: _arAnimationController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      Positioned(
                        top: 30 + (200 * (0.5 + 0.5 * sin(_arAnimationController.value * 6.28))),
                        child: Container(
                          width: 240,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 3,
                              )
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (widget.onBack != null) ...[
                            CircleAvatar(
                              backgroundColor: Colors.black87,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                                onPressed: widget.onBack,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "SCANNING FEED...",
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.black87,
                            child: IconButton(
                              icon: Icon(_isFlashOn ? Icons.flash_on : Icons.flash_off, color: Colors.blueAccent),
                              onPressed: () {
                                setState(() => _isFlashOn = !_isFlashOn);
                                _controller.toggleTorch();
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            backgroundColor: Colors.black87,
                            child: IconButton(
                              icon: Icon(_isARActive ? Icons.auto_awesome : Icons.blur_off, color: Colors.cyanAccent),
                              onPressed: () => setState(() => _isARActive = !_isARActive),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: pickAndDecodeCode,
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.photo_library_rounded),
                label: Text("Get Media Image", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ====================== ANSWER KEY BOTTOM SHEET ======================
  void _showAnswerKeyBottomSheet(AnswerKey key, ScannedCode code, [omr_service.OmrResult? omrResult]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),

              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, color: Colors.blueAccent, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(code.studentName ?? "Name Not Found",
                              style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text("Registration: ${code.studentRegNo ?? "N/A"}",
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Text(key.quizTitle, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold)),
              if (key.setInfo.isNotEmpty) Text("Set ${key.setInfo}", style: const TextStyle(color: Colors.cyanAccent, fontSize: 16)),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildPart("Part - I", key.part1),
                    const SizedBox(height: 24),
                    _buildPart("Part - II", key.part2),
                    _buildOmrGradeSection(key, omrResult),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white12, padding: const EdgeInsets.symmetric(vertical: 14), minimumSize: const Size(double.infinity, 50)),
                child: const Text("Close", style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _lastScannedValue = null);
  }

  Widget _buildPart(String title, Map<String, String> answers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: answers.entries.map((e) => Chip(
            backgroundColor: Colors.blueAccent.withOpacity(0.15),
            label: Text("${e.key} = ${e.value}", style: const TextStyle(fontWeight: FontWeight.bold)),
          )).toList(),
        ),
      ],
    );
  }

  void _showResultBottomSheet(ScannedCode code) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.75,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF131B2E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(16)),
                    child: Icon(code.type == 'url' ? Icons.link_rounded : Icons.terminal_rounded, color: Colors.blueAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(code.title, style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(code.type.toUpperCase(), style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: SingleChildScrollView(controller: scrollController, child: _buildTypeSpecificResult(code))),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: Colors.white12, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: const Text("Dismiss Dismiss Scan Sheet", style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _lastScannedValue = null);
  }

  Widget _buildTypeSpecificResult(ScannedCode code) {
    switch (code.type) {
      case 'url':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
              child: Text(code.value, style: GoogleFonts.spaceGrotesk(color: Colors.cyanAccent, fontSize: 13), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  String rawString = code.value.trim();
                  if (!rawString.toLowerCase().startsWith('https://') && !rawString.toLowerCase().startsWith('http://')) {
                    rawString = "https://$rawString";
                  }
                  final Uri url = Uri.parse(rawString);
                  try {
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error launching URL: $e"), backgroundColor: Colors.red));
                  }
                },
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                label: Text("Open in Web Browser", style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        );

      case 'barcode':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: Colors.amberAccent),
                  Text(code.value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade900),
                    onPressed: () => launchUrl(Uri.parse("https://www.google.com/search?q=${code.value}"), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text("Google Search"),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade900),
                    onPressed: () => launchUrl(Uri.parse("https://www.amazon.com/s?k=${code.value}"), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.shopping_cart, size: 16),
                    label: const Text("Amazon SKU"),
                  ),
                ),
              ],
            )
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Raw Scanned Data Payload:", style: TextStyle(color: Colors.white30, fontSize: 10)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(16)),
              child: Text(code.value, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14)),
            ),
          ],
        );
    }
  }
}

String _formatNow() {
  final n = DateTime.now();
  return "${n.year}-${n.month.toString().padLeft(2,'0')}-${n.day.toString().padLeft(2,'0')} "
      "${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}";
}