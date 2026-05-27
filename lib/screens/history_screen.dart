import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scanned_code.dart';
import '../models/answer_key.dart';
import '../services/history_database.dart';

class HistoryScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const HistoryScreen({super.key, this.onBack});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<ScannedCode> _historyItems = [];

  @override
  void initState() {
    super.initState();
    _loadHistoryLogs();
  }

  Future<void> _loadHistoryLogs() async {
    final items = await HistoryDatabase.getItems();
    setState(() => _historyItems = items);
  }

  Future<void> _clearAll() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Wipe Logs?"),
        content: const Text("Would you like to clear all locally cached QR logs permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await HistoryDatabase.clearItems();
              Navigator.of(context).pop();
              _loadHistoryLogs();
            },
            child: const Text("Clear Logs", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
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
        title: Text("Scanned History Logs", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
              onPressed: _clearAll,
            )
        ],
      ),
      body: _historyItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_outlined, size: 80, color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 16),
            Text("No code scans catalogued yet", style: TextStyle(color: Colors.white30, fontSize: 14)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        itemCount: _historyItems.length,
        itemBuilder: (context, index) {
          final item = _historyItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(item.type == 'answer_key' ? Icons.quiz_rounded : (item.type == 'url' ? Icons.link : Icons.qr_code), color: Colors.blueAccent),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                item.studentName != null ? "Student: ${item.studentName} | ${item.dateTime}" : item.dateTime, 
                style: const TextStyle(color: Colors.white38, fontSize: 10)
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
              onTap: () => _showResultDetails(item),
            ),
          );
        },
      ),
    );
  }

  void _showResultDetails(ScannedCode code) {
    if (code.type == 'answer_key') {
      final key = AnswerKey.fromPayload(code.value);
      _showAnswerKeyDetails(key, code);
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131B2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(code.title, style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(code.value, style: GoogleFonts.spaceGrotesk(color: Colors.cyanAccent)),
            const SizedBox(height: 24),
            Row(
              children: [
                if (code.type == 'url')
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      onPressed: () async {
                        String rUrl = code.value.trim();
                        if (!rUrl.startsWith('http://') && !rUrl.startsWith('https://')) {
                          rUrl = "https://$rUrl";
                        }
                        await launchUrl(Uri.parse(rUrl), mode: LaunchMode.externalApplication);
                      },
                      child: const Text("Launch Browser", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white12),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Close", style: TextStyle(color: Colors.white70)),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  void _showAnswerKeyDetails(AnswerKey key, ScannedCode code) {
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
              
              if (code.studentName != null || code.studentRegNo != null)
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
                    _buildPartSection("Part - I", key.part1),
                    const SizedBox(height: 24),
                    _buildPartSection("Part - II", key.part2),
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
    );
  }

  Widget _buildPartSection(String title, Map<String, String> answers) {
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
}