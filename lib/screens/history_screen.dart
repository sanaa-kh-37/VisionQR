import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/scanned_code.dart';
import '../services/history_database.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

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
                child: Icon(item.type == 'url' ? Icons.link : Icons.qr_code, color: Colors.blueAccent),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.dateTime, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
              onTap: () => _showResultDetails(item),
            ),
          );
        },
      ),
    );
  }

  void _showResultDetails(ScannedCode code) {
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
}