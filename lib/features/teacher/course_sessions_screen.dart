import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../services/location_service.dart';
import '../../widgets/app_notify.dart';
import 'reports_screen.dart';
import 'session_qr_screen.dart';

/// Sessions of a single course + create-session flow.
class CourseSessionsScreen extends StatefulWidget {
  final Course course;
  const CourseSessionsScreen({super.key, required this.course});

  @override
  State<CourseSessionsScreen> createState() => _CourseSessionsScreenState();
}

class _CourseSessionsScreenState extends State<CourseSessionsScreen> {
  late Future<List<ClassSession>> _sessions;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _sessions = Supabase.instance.client
        .from('class_sessions')
        .select()
        .eq('course_id', widget.course.id)
        .order('created_at', ascending: false)
        .then((rows) =>
            rows.map<ClassSession>(ClassSession.fromMap).toList());
  }

  Future<void> _createSession() async {
    final title = await _askTitle();
    if (title == null || title.trim().isEmpty) return;

    setState(() => _creating = true);
    try {
      // Capture the classroom location from the teacher's phone.
      final pos = await LocationService.currentPosition();
      final session = await DataService.createSession(
        courseId: widget.course.id,
        title: title.trim(),
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusM: 50,
      );
      setState(_reload);
      if (!mounted) return;
      _openQr(session);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _openQr(ClassSession s) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SessionQrScreen(session: s)))
        .then((_) => setState(_reload));
  }

  void _openReport(ClassSession s) {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReportsScreen(session: s)));
  }

  Future<String?> _askTitle() {
    final controller = TextEditingController(
        text: 'Clase ${DateTime.now().day}/${DateTime.now().month}');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva sesión de clase'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Título / tema'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Crear y abrir QR')),
        ],
      ),
    );
  }

  void _snack(String m) {
    if (!mounted) return;
    AppNotify.error(context, m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.course.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createSession,
        icon: _creating
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_location_alt),
        label: const Text('Nueva clase'),
      ),
      body: FutureBuilder<List<ClassSession>>(
        future: _sessions,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final sessions = snap.data!;
          if (sessions.isEmpty) {
            return const Center(
              child: Text(
                  'Sin clases aún.\nCrea una con "Nueva clase".\n'
                  'Se usará la ubicación de tu teléfono como el aula.',
                  textAlign: TextAlign.center),
            );
          }
          return ListView.separated(
            itemCount: sessions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = sessions[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      s.isActive ? Colors.green : Colors.grey,
                  child: Icon(s.isActive ? Icons.play_arrow : Icons.stop,
                      color: Colors.white),
                ),
                title: Text(s.title),
                subtitle: Text(
                    '${s.sessionDate.day}/${s.sessionDate.month}/${s.sessionDate.year}'
                    ' · radio ${s.radiusM} m'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.qr_code),
                      tooltip: 'Mostrar QR',
                      onPressed: () => _openQr(s),
                    ),
                    IconButton(
                      icon: const Icon(Icons.list_alt),
                      tooltip: 'Reporte',
                      onPressed: () => _openReport(s),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
