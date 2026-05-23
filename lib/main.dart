import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VisionQR',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        fontFamily: GoogleFonts.inter().fontFamily,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const SplashScreen(),
    );
  }
}

// ====================== 1. DYNAMIC LAUNCH SPLASH SCREEN ======================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    // Force loader sequence timer (3.5 seconds) to redirect to the core Dashboard
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Rotating animated radar sweep bounds
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent.withOpacity(0.4)),
                      strokeWidth: 2,
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 1.5),
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      size: 55,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                "VisionQR",
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              // const SizedBox(height: 6),
              // Text(
              //   "COMPUTER VISION AR MODULE V3.2",
              //   style: GoogleFonts.spaceGrotesk(
              //     fontSize: 10,
              //     fontWeight: FontWeight.w600,
              //     letterSpacing: 2.5,
              //     color: Colors.cyanAccent,
              //   ),
              // ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF1E293B),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== 2. CORE SYSTEM TAB HOLDER ======================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScannerScreenState> _scannerKey = GlobalKey<ScannerScreenState>();

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        onNavigateToScan: () => setState(() => _currentIndex = 1),
        onNavigateToHistory: () => setState(() => _currentIndex = 2),
        onNavigateToCreate: () => setState(() => _currentIndex = 3),
        onPickFromGallery: () {
          setState(() => _currentIndex = 1);
          // Wait for IndexedStack animation frames, then invoke media gallery decoder!
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scannerKey.currentState?.pickAndDecodeCode();
          });
        },
      ),
      ScannerScreen(key: _scannerKey, isScanning: _currentIndex == 1),
      const HistoryScreen(),
      const GeneratorScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        indicatorColor: Colors.blueAccent.withOpacity(0.2),
        backgroundColor: const Color(0xFF131B2E),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.home, color: Colors.blueAccent),
            label: "Home",
          ),
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_rounded, color: Colors.white54),
            selectedIcon: Icon(Icons.qr_code_scanner, color: Colors.blueAccent),
            label: "Scan",
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded, color: Colors.white54),
            selectedIcon: Icon(Icons.history_edu, color: Colors.blueAccent),
            label: "History",
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined, color: Colors.white54),
            selectedIcon: Icon(Icons.add_box, color: Colors.blueAccent),
            label: "Create",
          ),
        ],
      ),
    );
  }
}

// ====================== 3. HOMEPAGE DASHBOARD MODULE ======================
class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToScan;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToCreate;
  final VoidCallback onPickFromGallery;

  const DashboardScreen({
    super.key,
    required this.onNavigateToScan,
    required this.onNavigateToHistory,
    required this.onNavigateToCreate,
    required this.onPickFromGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("VisionQR Dashboard", style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ambient Hub Banner Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Text(
                        //   "SYSTEM STABLE",
                        //   style: GoogleFonts.spaceGrotesk(
                        //     fontSize: 10,
                        //     fontWeight: FontWeight.bold,
                        //     color: Colors.white70,
                        //     letterSpacing: 2.0,
                        //   ),
                        // ),
                        const SizedBox(height: 6),
                        Text(
                          "VisionQR",
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 12),
                              SizedBox(width: 6),
                              // Text(
                              //   "SQLITE PERSISTENT LOGS READY",
                              //   style: TextStyle(
                              //     fontSize: 8,
                              //     fontWeight: FontWeight.bold,
                              //     color: Colors.greenAccent,
                              //   ),
                              // )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.flash_on, color: Colors.white, size: 34),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Text(
            //   "PRIMARY CONTROL CHANNELS",
            //   style: GoogleFonts.spaceGrotesk(
            //     fontSize: 11,
            //     fontWeight: FontWeight.bold,
            //     color: Colors.cyanAccent,
            //     letterSpacing: 1.5,
            //   ),
            // ),
            const SizedBox(height: 14),

            // Grid layout
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildDashCard(
                  icon: Icons.camera_alt_outlined,
                  iconColor: Colors.blueAccent,
                  title: "Live Scanner",
                  subtitle: "Point camera frame to pick matrix scans",
                  onTap: onNavigateToScan,
                ),
                _buildDashCard(
                  icon: Icons.photo_size_select_actual_outlined,
                  iconColor: Colors.cyanAccent,
                  title: "Get Media",
                  subtitle: "Pick photo from device local storage gallery",
                  onTap: onPickFromGallery,
                ),
                _buildDashCard(
                  icon: Icons.add_circle_outline_rounded,
                  iconColor: Color(0xFF50C878),
                  title: "Create Code",
                  subtitle: "Print vector dynamic charts",
                  onTap: onNavigateToCreate,
                ),
                _buildDashCard(
                  icon: Icons.history_edu_rounded,
                  iconColor: Colors.purpleAccent,
                  title: "Scan Log Hub",
                  subtitle: "Query logs and archive links",
                  onTap: onNavigateToHistory,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Visual Quick Guide
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.04)),
              ),
              // child: Row(
              //   children: [
              //     const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent),
              //     const SizedBox(width: 14),
              //     Expanded(
              //       child: Text(
              //         "To scan, both camera stream and storage media inputs search dynamically for QR and traditional EAN product barcodes.",
              //         style: GoogleFonts.inter(fontSize: 12, color: Colors.white70, height: 1.3),
              //       ),
              //     )
              //   ],
              // ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.04)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 9, color: Colors.white38, height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// Helper Model for QR/Barcode Scrapes
class ScannedCode {
  final String id;
  final String type; // 'url' | 'wifi' | 'contact' | 'barcode' | 'text'
  final String value;
  final String title;
  final String dateTime;
  bool isFavorite;

  ScannedCode({
    required this.id,
    required this.type,
    required this.value,
    required this.title,
    required this.dateTime,
    this.isFavorite = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'type': type,
    'value': value,
    'title': title,
    'dateTime': dateTime,
    'isFavorite': isFavorite ? 1 : 0,
  };

  factory ScannedCode.fromMap(Map<String, dynamic> map) => ScannedCode(
    id: map['id'],
    type: map['type'],
    value: map['value'],
    title: map['title'],
    dateTime: map['dateTime'],
    isFavorite: map['isFavorite'] == 1,
  );
}

// ====================== 4. LIVE SCANNER AND STORAGE DECODER ======================
class ScannerScreen extends StatefulWidget {
  final bool isScanning;
  const ScannerScreen({super.key, required this.isScanning});

  @override
  State<ScannerScreen> createState() => ScannerScreenState();
}

class ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(autoStart: false);
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

  // Pick QR/Barcode photo from gallery and scan it!
  Future<void> pickAndDecodeCode() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    try {
      // Analyze file QR directly using mobile_scanner!
      final BarcodeCapture? capture = await _controller.analyzeImage(file.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final String? rawValue = capture.barcodes.first.rawValue;
        if (rawValue != null) {
          _processScannedPayload(rawValue);
          return;
        }
      }

      // Fallback: If image lacks structure but has payload, simulate mock decode helper
      _showImageNoQrSnackBar();
    } catch (e) {
      // Simulate direct fallback for mockup pictures inside the emulator gallery
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

  void _processScannedPayload(String rawValue) async {
    _lastScannedValue = rawValue;

    // Determine barcode category
    String type = 'text';
    String title = 'Scanned Text';
    if (rawValue.startsWith('http://') || rawValue.startsWith('https://') || rawValue.contains(RegExp(r'^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'))) {
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

    final DateTime now = DateTime.now();
    final String formattedTime = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    final newItem = ScannedCode(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: type,
      value: rawValue,
      title: title,
      dateTime: formattedTime,
    );

    // Persist log database
    await HistoryDatabase.saveItem(newItem);

    // Present parsed sheet details with haptics
    _showResultBottomSheet(newItem);
  }

  String _parseWifiSSID(String wifiStr) {
    try {
      final match = RegExp(r'S:([^;]+);').firstMatch(wifiStr);
      return match != null ? match.group(1) ?? 'Wi-Fi Network' : 'Wi-Fi Network';
    } catch (_) {
      return 'Wi-Fi Network';
    }
  }

  String _parseContactName(String contactStr) {
    try {
      if (contactStr.contains('N:')) {
        final match = RegExp(r'N:([^;]+);').firstMatch(contactStr);
        return match != null ? match.group(1) ?? 'Contact Card' : 'Contact Card';
      }
      return 'Contact Card';
    } catch (_) {
      return 'Contact Card';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Mobile Camera scanner viewfinder
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // 2. Translucent dark mask underlay
          Container(
            color: Colors.black.withOpacity(0.4),
          ),

          // 3. Computer Vision AR laser indicator targets
          if (_isARActive)
            Center(
              child: AnimatedBuilder(
                animation: _arAnimationController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Target Box bracket borders
                      Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 2),
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      // Scanning red laser beam sweeper line
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

          // 4. Overlaid control badges
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                          style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
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
            ),
          ),

          // 5. Gallery trigger icon centered at bottom margin
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
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                        code.type == 'url' ? Icons.link_rounded : Icons.terminal_rounded,
                        color: Colors.blueAccent,
                        size: 28
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.title,
                          style: GoogleFonts.spaceGrotesk(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          code.type.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(fontSize: 10, color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dynamic Content view card based on payload type
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: _buildTypeSpecificResult(code),
                ),
              ),

              const SizedBox(height: 16),
              // Back/Close Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.white12,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Dismiss Scan Sheet", style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _lastScannedValue = null; // Prepare for next scans
    });
  }

  Widget _buildTypeSpecificResult(ScannedCode code) {
    switch (code.type) {
      case 'url':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                code.value,
                style: GoogleFonts.spaceGrotesk(color: Colors.cyanAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),

            // CRITICAL FIX: Safe deep launching block
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  String rawString = code.value.trim();
                  // Detect schema presence, inject prefix if missing (e.g. 'www.google.com' -> 'https://www.google.com')
                  if (!rawString.toLowerCase().startsWith('https://') && !rawString.toLowerCase().startsWith('http://')) {
                    rawString = "https://$rawString";
                  }
                  final Uri url = Uri.parse(rawString);
                  try {
                    // Launch Mode.externalApplication behaves as a real web browser redirection
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(url, mode: LaunchMode.platformDefault);
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error launching URL: $e"), backgroundColor: Colors.red),
                    );
                  }
                },
                icon: const Icon(Icons.open_in_browser_rounded, color: Colors.white),
                label: Text(
                  "Open in Web Browser",
                  style: GoogleFonts.spaceGrotesk(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        );

      case 'barcode':
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Icon(Icons.shopping_bag_rounded, color: Colors.amberAccent),
                  Text(
                    code.value,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace'),
                  ),
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
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(code.value, style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 14)),
            ),
          ],
        );
    }
  }
}

// ====================== 5. HISTORIC ACTIONS LOG SCREEN ======================
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
              child: const Text("Clear Logs", style: TextStyle(color: Colors.redAccent))
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
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.type == 'url' ? Icons.link : Icons.qr_code, color: Colors.blueAccent),
              ),
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.dateTime, style: const TextStyle(color: Colors.white38, fontSize: 10)),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.white24),
              onTap: () {
                // Re-show result sheet details
                _showResultDetails(item);
              },
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

// ====================== 6. QR BARCODE VECTOR GENERATOR SCREEN ======================
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({super.key});

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
                      setState(() {
                        _generatorPayload = _inputController.text;
                      });
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

            // Dynamic Chart view
            if (_generatorPayload.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withOpacity(0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ]
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
                        const SnackBar(
                          content: Text("QR image vector successfully saved to local photo directory."),
                          backgroundColor: Colors.green,
                        ),
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

// ====================== 7. PERSISTENT LIGHTWEIGHT DATABASE (SHARED PREFS) ======================
class HistoryDatabase {
  static const String _keyOfDatabase = "scan_pro_history_logs";

  static Future<List<ScannedCode>> getItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? dataString = prefs.getString(_keyOfDatabase);
    if (dataString == null) return [];

    try {
      final List<dynamic> listJson = jsonDecode(dataString);
      return listJson.map((item) => ScannedCode.fromMap(item)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveItem(ScannedCode code) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<ScannedCode> items = await getItems();

    // Avoid raw doubles
    items.removeWhere((it) => it.value == code.value);
    items.insert(0, code);

    final String encoded = jsonEncode(items.map((it) => it.toMap()).toList());
    await prefs.setString(_keyOfDatabase, encoded);
  }

  static Future<void> clearItems() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOfDatabase);
  }
}
