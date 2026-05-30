import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardScreen extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback onNavigateToScan;
  final VoidCallback onNavigateToHistory;
  final VoidCallback onNavigateToCreate;
  final VoidCallback onPickFromGallery;
  final VoidCallback onNavigateToOmrDemo; // index 4
  final VoidCallback onNavigateToBatch;   // index 5

  const DashboardScreen({
    super.key,
    required this.scaffoldKey,
    required this.onNavigateToScan,
    required this.onNavigateToHistory,
    required this.onNavigateToCreate,
    required this.onPickFromGallery,
    required this.onNavigateToOmrDemo,
    required this.onNavigateToBatch,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Hamburger menu button — opens the drawer in HomeScreen
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          "VisionQR Dashboard",
          style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Card
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black38,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: Colors.greenAccent, size: 12),
                              SizedBox(width: 6),
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
                    child: const Icon(Icons.flash_on,
                        color: Colors.white, size: 34),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),

            // 6-card grid
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
                  iconColor: const Color(0xFF50C878),
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
                _buildDashCard(
                  icon: Icons.bubble_chart_rounded,
                  iconColor: Colors.tealAccent,
                  title: "OMR Demo",
                  subtitle: "Read a single bubble sheet and inspect answers",
                  onTap: onNavigateToOmrDemo,
                ),
                _buildDashCard(
                  icon: Icons.grading_rounded,
                  iconColor: Colors.orangeAccent,
                  title: "Batch Grading",
                  subtitle: "Grade many sheets and export a CSV report",
                  onTap: onNavigateToBatch,
                ),
              ],
            ),
            const SizedBox(height: 20),
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
                  style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white38,
                      height: 1.2),
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