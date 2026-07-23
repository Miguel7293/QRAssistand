import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/data_service.dart';
import '../../services/device_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// Real-looking QR scanner: camera + framed cutout + animated scan line, then
/// runs the full attendance flow (token -> GPS -> device id -> server check).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _controller = MobileScannerController();
  late final AnimationController _anim;
  bool _processing = false;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    setState(() => _processing = true);
    await _controller.stop();

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final sessionId = data['s'] as String;
      final token = data['t'] as String;

      final pos = await LocationService.currentPosition();
      final deviceId = await DeviceService.deviceId();

      final result = await DataService.registerAttendance(
        sessionId: sessionId,
        token: token,
        lat: pos.latitude,
        lng: pos.longitude,
        deviceId: deviceId,
      );

      if (!mounted) return;
      await _showResult(
        success: true,
        message: 'Asistencia registrada correctamente.',
        detail: 'Distancia al aula: ${result['distance_m']} m',
      );
    } catch (e) {
      if (!mounted) return;
      await _showResult(success: false, message: _clean('$e'));
    }
  }

  String _clean(String e) {
    if (e.contains('FormatException') || e.contains('not a subtype')) {
      return 'Ese código no es un QR de asistencia válido.';
    }
    final match = RegExp(r'message: ([^,)]+)').firstMatch(e);
    if (match != null) return match.group(1)!.trim();
    return e.replaceAll('Exception:', '').trim();
  }

  Future<void> _showResult({
    required bool success,
    required String message,
    String? detail,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (success ? AppColors.success : AppColors.danger)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_rounded : Icons.close_rounded,
                color: success ? AppColors.success : AppColors.danger,
                size: 44,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              success ? 'Listo!' : 'No se pudo registrar',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (detail != null) ...[
              const SizedBox(height: 4),
              Text(detail,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // leave scanner
              },
              child: const Text('Aceptar'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),

          // Dark overlay with a transparent square cutout.
          LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.maxWidth * 0.72;
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                painter: _ScannerOverlayPainter(cutoutSide: side),
              );
            },
          ),

          // Frame corners + animated scan line.
          Center(
            child: LayoutBuilder(builder: (context, _) {
              final side = MediaQuery.of(context).size.width * 0.72;
              return SizedBox(
                width: side,
                height: side,
                child: Stack(
                  children: [
                    _corner(Alignment.topLeft),
                    _corner(Alignment.topRight),
                    _corner(Alignment.bottomLeft),
                    _corner(Alignment.bottomRight),
                    AnimatedBuilder(
                      animation: _anim,
                      builder: (context, _) => Align(
                        alignment: Alignment(0, (_anim.value * 2) - 1),
                        child: Container(
                          height: 2.5,
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppColors.gold.withValues(alpha: 0),
                              AppColors.gold,
                              AppColors.gold.withValues(alpha: 0),
                            ]),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.6),
                                  blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),

          // Top bar: back + torch.
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  const Text('Escanear QR',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  IconButton(
                    onPressed: () {
                      _controller.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                    icon: Icon(_torch ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          // Bottom instruction.
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Column(
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    color: Colors.white70, size: 28),
                const SizedBox(height: 8),
                Text(
                  'Apunta la cámara al código QR\nque muestra tu docente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14),
                ),
              ],
            ),
          ),

          if (_processing)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 20),
                    Text('Validando ubicación y dispositivo...',
                        style: TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner(Alignment a) {
    const c = AppColors.gold;
    const w = 3.0;
    final top = a.y < 0;
    final left = a.x < 0;
    return Align(
      alignment: a,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: c, width: w) : BorderSide.none,
            bottom:
                !top ? const BorderSide(color: c, width: w) : BorderSide.none,
            left:
                left ? const BorderSide(color: c, width: w) : BorderSide.none,
            right:
                !left ? const BorderSide(color: c, width: w) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Paints a translucent scrim with a clear rounded square in the center.
class _ScannerOverlayPainter extends CustomPainter {
  final double cutoutSide;
  _ScannerOverlayPainter({required this.cutoutSide});

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final cutout = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: cutoutSide,
        height: cutoutSide,
      ),
      const Radius.circular(24),
    );
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect),
      Path()..addRRect(cutout),
    );
    canvas.drawPath(path, scrim);
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter old) =>
      old.cutoutSide != cutoutSide;
}
