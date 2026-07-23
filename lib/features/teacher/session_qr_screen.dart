import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';

/// Displays a QR that rotates every [_rotateEvery] seconds. Each rotation
/// writes a fresh token to the DB with a short expiry, so a screenshot shared
/// after a few seconds is useless — the essence of the "QR dinamico" control.
class SessionQrScreen extends StatefulWidget {
  final ClassSession session;
  const SessionQrScreen({super.key, required this.session});

  @override
  State<SessionQrScreen> createState() => _SessionQrScreenState();
}

class _SessionQrScreenState extends State<SessionQrScreen> {
  static const int _rotateEvery = 10; // seconds

  Timer? _timer;
  String? _payload;
  int _secondsLeft = _rotateEvery;
  String? _error;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _rotate();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_secondsLeft <= 1) {
        _rotate();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _rotate() async {
    try {
      final token = await DataService.rotateToken(widget.session.id,
          ttlSeconds: _rotateEvery + 3);
      setState(() {
        _payload = jsonEncode({'s': widget.session.id, 't': token});
        _secondsLeft = _rotateEvery;
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Future<void> _closeSession() async {
    _timer?.cancel();
    try {
      await DataService.closeSession(widget.session.id);
      setState(() => _closed = true);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.session.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_closed) ...[
                const Icon(Icons.check_circle,
                    color: Colors.green, size: 80),
                const SizedBox(height: 16),
                const Text('Sesión cerrada.',
                    style: TextStyle(fontSize: 18)),
              ] else if (_error != null) ...[
                const Icon(Icons.error, color: Colors.red, size: 64),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _rotate, child: const Text('Reintentar')),
              ] else if (_payload == null) ...[
                const CircularProgressIndicator(),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 12)
                    ],
                  ),
                  child: QrImageView(
                    data: _payload!,
                    size: 260,
                  ),
                ),
                const SizedBox(height: 24),
                Text('El código cambia en $_secondsLeft s',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: _secondsLeft / _rotateEvery,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Muestra esta pantalla a la clase.\n'
                  'Cada estudiante escanea y su asistencia se valida por '
                  'ubicación y dispositivo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _closeSession,
                  icon: const Icon(Icons.stop),
                  label: const Text('Cerrar sesión de asistencia'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
