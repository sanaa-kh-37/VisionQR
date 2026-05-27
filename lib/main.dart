import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/dashboard_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/history_screen.dart';
import 'screens/generator_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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

// ====================== SPLASH SCREEN ======================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

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
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.blueAccent.withOpacity(0.4)),
                      strokeWidth: 2,
                    ),
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.blueAccent.withOpacity(0.2),
                          width: 1.5),
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
              const SizedBox(height: 48),
              const SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: Color(0xFF1E293B),
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ====================== HOME SCREEN ======================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final GlobalKey<ScannerScreenState> _scannerKey =
  GlobalKey<ScannerScreenState>();

  void _navigate(int index) {
    setState(() => _currentIndex = index);
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context); // close drawer
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      DashboardScreen(
        scaffoldKey: _scaffoldKey,
        onNavigateToScan: () => setState(() => _currentIndex = 1),
        onNavigateToHistory: () => setState(() => _currentIndex = 2),
        onNavigateToCreate: () => setState(() => _currentIndex = 3),
        onPickFromGallery: () {
          setState(() => _currentIndex = 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scannerKey.currentState?.pickAndDecodeCode();
          });
        },
      ),
      ScannerScreen(
        key: _scannerKey,
        isScanning: _currentIndex == 1,
        onBack: () => setState(() => _currentIndex = 0),
      ),
      HistoryScreen(onBack: () => setState(() => _currentIndex = 0)),
      GeneratorScreen(onBack: () => setState(() => _currentIndex = 0)),
    ];

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() => _currentIndex = 0);
      },
      child: Scaffold(
        key: _scaffoldKey,
        // ====================== DRAWER (SIDEBAR) ======================
        drawer: Drawer(
          backgroundColor: const Color(0xFF131B2E),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drawer Header
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded,
                            color: Colors.blueAccent, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        "VisionQR",
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                // Nav Items
                _drawerItem(
                  icon: Icons.home_rounded,
                  label: "Home",
                  index: 0,
                  currentIndex: _currentIndex,
                  onTap: () => _navigate(0),
                ),
                _drawerItem(
                  icon: Icons.qr_code_scanner_rounded,
                  label: "Scan",
                  index: 1,
                  currentIndex: _currentIndex,
                  onTap: () => _navigate(1),
                ),
                _drawerItem(
                  icon: Icons.history_edu_rounded,
                  label: "History",
                  index: 2,
                  currentIndex: _currentIndex,
                  onTap: () => _navigate(2),
                ),
                _drawerItem(
                  icon: Icons.add_box_rounded,
                  label: "Create",
                  index: 3,
                  currentIndex: _currentIndex,
                  onTap: () => _navigate(3),
                ),

                const Spacer(),
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    "VisionQR v1.0.0",
                    style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                        fontFamily: GoogleFonts.inter().fontFamily),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required int index,
    required int currentIndex,
    required VoidCallback onTap,
  }) {
    final bool isSelected = index == currentIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.blueAccent : Colors.white54,
          size: 22,
        ),
        title: Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: isSelected ? Colors.blueAccent : Colors.white70,
            fontWeight:
            isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Colors.blueAccent.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: onTap,
      ),
    );
  }
}