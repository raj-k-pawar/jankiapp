import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/api_client.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'booking_form_screen.dart';
import 'success_screen.dart';

/// A. Scan Ticket — the website's Check-In page: scan the QR (or type the
/// booking ID), review the booking, then confirm the check-in.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final TextEditingController _manual = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _camera.dispose();
    _manual.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    // Ignore codes while a ticket is being handled or another screen is on top
    if (_busy || ModalRoute.of(context)?.isCurrent != true) return;
    for (final code in capture.barcodes) {
      final value = code.rawValue?.trim() ?? '';
      if (value.isNotEmpty) {
        _lookup(value);
        return;
      }
    }
  }

  void _lookupManual() {
    final value = _manual.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Type the booking ID printed on the ticket, e.g. ENQ-00038.');
      return;
    }
    FocusScope.of(context).unfocus();
    _lookup(value);
  }

  Future<void> _lookup(String code) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    await _stopCamera();

    try {
      final res = await session.api.post('ticket/lookup', {'code': code});
      final enquiry = res['enquiry'];
      if (enquiry is! Map<String, dynamic>) throw ApiException('Booking not found. Check the QR/ID and try again.');
      final ticket = Ticket.fromJson(enquiry);
      final validity = res['validity'] is Map ? res['validity'] as Map : const {};

      if (!mounted) return;
      var open = validity['valid'] == true;
      if (!open) {
        open = await _askViewAnyway(ticket, validity['message'] is String ? validity['message'] as String : 'Not valid today.');
      }
      if (open && mounted) {
        _manual.clear();
        final result = await Navigator.of(context).push(
          MaterialPageRoute<BookingResult>(builder: (_) => BookingFormScreen.checkin(ticket: ticket)),
        );
        if (result != null && mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SuccessScreen(result: result, againLabel: 'Scan next ticket', againIcon: Icons.qr_code_scanner_rounded),
            ),
          );
        }
      }
    } on ApiException catch (e) {
      if (mounted && !e.unauthorized) setState(() => _error = e.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _startCamera();
      }
    }
  }

  /// The ticket is for another day — same "View anyway" choice as the website.
  Future<bool> _askViewAnyway(Ticket ticket, String message) async {
    final answer = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warn, size: 52),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
              ),
              const SizedBox(height: 8),
              Text(
                '${ticket.bookingId} · ${ticket.name} · ${ticket.batchName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14.5, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, false),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scan another ticket'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('View anyway')),
            ],
          ),
        ),
      ),
    );
    return answer == true;
  }

  Future<void> _stopCamera() async {
    try {
      await _camera.stop();
    } catch (_) {
      // camera was not running (no permission / not started yet)
    }
  }

  Future<void> _startCamera() async {
    try {
      await _camera.start();
    } catch (_) {
      // no camera permission — the on-screen message explains what to do
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Ticket'),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _camera,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: on ? 'Turn torch off' : 'Turn torch on',
                icon: Icon(on ? Icons.flash_on_rounded : Icons.flash_off_rounded),
                onPressed: () async {
                  try {
                    await _camera.toggleTorch();
                  } catch (_) {
                    // torch not available right now
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _camera,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) => _CameraProblem(error: error),
                ),
                const IgnorePointer(child: _ScanFrame()),
                if (_busy)
                  Container(
                    color: Colors.black54,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.gold),
                        SizedBox(height: 14),
                        Text('Checking ticket…', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) Notice.error(_error!),
                  const Text(
                    'No QR code? Enter the booking ID',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manual,
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.characters,
                          textInputAction: TextInputAction.search,
                          maxLength: 20,
                          onSubmitted: (_) => _lookupManual(),
                          decoration: const InputDecoration(
                            hintText: 'ENQ-00038',
                            counterText: '',
                            prefixIcon: Icon(Icons.confirmation_number_outlined, color: AppColors.leaf),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        child: FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(84, 54)),
                          onPressed: _busy ? null : _lookupManual,
                          child: const Text('Find'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rounded viewfinder with a hint underneath.
class _ScanFrame extends StatelessWidget {
  const _ScanFrame();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppColors.gold, width: 4),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(30)),
            child: const Text(
              'Point the camera at the ticket QR code',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_rounded, color: Colors.white70, size: 52),
          const SizedBox(height: 14),
          Text(
            denied
                ? 'Camera access is switched off for this app.\nAllow it in your phone\'s Settings, or type the booking ID below.'
                : 'The camera could not be started.\nYou can still type the booking ID below.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.45, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
