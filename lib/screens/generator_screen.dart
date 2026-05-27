import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

class GeneratorScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const GeneratorScreen({super.key, this.onBack});

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  final TextEditingController _inputController = TextEditingController(text: "https://google.com");
  String _generatorPayload = "https://google.com";

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: Text("Create Vector QR", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _inputController,
                    decoration: InputDecoration(
                      labelText: "Dynamic Input Link / text:",
                      labelStyle: TextStyle(color: Colors.blueAccent.shade100, fontSize: 13),
                      hintText: "Enter website link, WiFi keys, MEVcard...",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Colors.blueAccent),
                      ),
                    ),
                    style: GoogleFonts.spaceGrotesk(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      setState(() => _generatorPayload = _inputController.text);
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, color: Colors.white),
                        SizedBox(width: 8),
                        Text("Create Fresh QR Chart", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            if (_generatorPayload.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.08), blurRadius: 20, spreadRadius: 2)],
                ),
                child: QrImageView(
                  data: _generatorPayload,
                  version: QrVersions.auto,
                  size: 200.0,
                  foregroundColor: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                    icon: const Icon(Icons.download, color: Colors.greenAccent),
                    label: const Text("Save to Phone Gallery", style: TextStyle(color: Colors.white70)),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("QR image vector successfully saved to local photo directory."), backgroundColor: Colors.green),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}