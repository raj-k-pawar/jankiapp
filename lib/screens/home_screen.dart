import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'booking_form_screen.dart';
import 'enquiry_screen.dart';
import 'scan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(BuildContext context) async {
    try {
      await session.refreshConfig();
    } on ApiException catch (e) {
      if (context.mounted && !e.unauthorized) showMessage(context, e.message, error: true);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need your username and password to use the app again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (yes == true) await session.logout();
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // Rebuilds when packages/prices are refreshed
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: session, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final config = session.config;
    final name = config?.user.name ?? '';
    final today = config?.today ?? DateTime.now();

    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.forest,
        onRefresh: () => _refresh(context),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.forestDark, AppColors.forest, AppColors.leaf],
                  ),
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 10, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '🌿  ${config?.siteName ?? 'Janki Agro Tourism'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Log out',
                              onPressed: () => _confirmLogout(context),
                              icon: const Icon(Icons.logout_rounded, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name.isEmpty ? 'Hello!' : 'Hello, $name',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800, height: 1.15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          prettyDateWithDay(today),
                          style: const TextStyle(color: Colors.white70, fontSize: 14.5, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
              sliver: SliverList.list(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'What would you like to do?',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.muted),
                    ),
                  ),
                  _ActionCard(
                    icon: Icons.qr_code_scanner_rounded,
                    title: 'Scan Ticket',
                    subtitle: 'Scan a guest\'s QR ticket and check them in',
                    colors: const [Color(0xFF1A4D2E), Color(0xFF2D7A4F)],
                    onTap: () => _open(context, const ScanScreen()),
                  ),
                  _ActionCard(
                    icon: Icons.directions_walk_rounded,
                    title: 'Walk-in Booking',
                    subtitle: 'Book a guest who has arrived at the counter',
                    colors: const [Color(0xFFB7791F), Color(0xFFE0A52E)],
                    onTap: () => _open(context, const BookingFormScreen.walkin()),
                  ),
                  _ActionCard(
                    icon: Icons.edit_calendar_rounded,
                    title: 'Take Enquiry',
                    subtitle: 'Record a booking enquiry for a future date',
                    colors: const [Color(0xFF1D5F7A), Color(0xFF2E8FA8)],
                    onTap: () => _open(context, const EnquiryScreen()),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Pull down to refresh packages and prices',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        borderRadius: BorderRadius.circular(24),
        elevation: 5,
        shadowColor: colors.first.withValues(alpha: 0.45),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 14, 22),
              child: Row(
                children: [
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.3, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
