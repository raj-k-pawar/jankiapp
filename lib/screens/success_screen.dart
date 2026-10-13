import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/format.dart';
import '../core/models.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

/// Shown after a check-in, walk-in or enquiry is saved: booking ID, ticket QR
/// and the same "View Ticket" / "Send on WhatsApp" actions as the website.
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.result, required this.againLabel, required this.againIcon, this.againBuilder});

  final BookingResult result;
  final String againLabel;
  final IconData againIcon;

  /// Screen to open for "do another one"; when null the previous screen
  /// (the scanner) is simply shown again.
  final WidgetBuilder? againBuilder;

  Uri? get _ticketUri {
    final uri = Uri.tryParse(result.ticketUrl);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http')) || uri.host.isEmpty) return null;
    return uri;
  }

  Future<void> _launch(BuildContext context, Uri uri) async {
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok && context.mounted) showMessage(context, 'Could not open the link on this phone.', error: true);
  }

  void _sendWhatsApp(BuildContext context) {
    final text = 'Hi ${result.name}! Your booking at Janki Agro Tourism is confirmed.\n'
        'Booking ID: ${result.bookingId}\nHere is your ticket: ${result.ticketUrl}';
    final number = mobilePattern.hasMatch(result.mobile) ? '91${result.mobile}' : '';
    _launch(context, Uri.https('wa.me', '/$number', {'text': text}));
  }

  void _again(BuildContext context) {
    final builder = againBuilder;
    if (builder == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: builder));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticketUri = _ticketUri;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(result.title),
        actions: [
          IconButton(
            tooltip: 'Home',
            icon: const Icon(Icons.home_rounded),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
          children: [
            Center(
              child: Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(color: AppColors.successSoft, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppColors.success, size: 46),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              result.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: result.bookingId));
                  showMessage(context, 'Booking ID copied');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: AppColors.forest, borderRadius: BorderRadius.circular(30)),
                  child: Text(
                    result.bookingId,
                    style: const TextStyle(color: AppColors.gold, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            if (ticketUri != null)
              SectionCard(
                child: Column(
                  children: [
                    QrImageView(
                      data: result.ticketUrl,
                      size: 200,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Guest can scan this to open their ticket',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            SectionCard(
              title: 'Booking summary',
              icon: Icons.receipt_long_rounded,
              child: Column(children: [for (final line in result.lines) KeyValueRow(line.key, line.value)]),
            ),
            if (ticketUri != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1FAF54)),
                onPressed: () => _sendWhatsApp(context),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send ticket on WhatsApp'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _launch(context, ticketUri),
                icon: const Icon(Icons.confirmation_number_rounded),
                label: const Text('View / print ticket'),
              ),
              const SizedBox(height: 10),
            ],
            FilledButton.icon(onPressed: () => _again(context), icon: Icon(againIcon), label: Text(againLabel)),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text('Back to home', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
