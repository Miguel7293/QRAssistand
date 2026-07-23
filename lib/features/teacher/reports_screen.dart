import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';

/// Automatic attendance report for a session.
class ReportsScreen extends StatefulWidget {
  final ClassSession session;
  const ReportsScreen({super.key, required this.session});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late Future<List<AttendanceRecord>> _records;

  @override
  void initState() {
    super.initState();
    _records = DataService.sessionAttendance(widget.session.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reporte · ${widget.session.title}')),
      body: FutureBuilder<List<AttendanceRecord>>(
        future: _records,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final records = snap.data!;
          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Text('Asistentes: ${records.length}',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              if (records.isEmpty)
                const Expanded(
                  child:
                      Center(child: Text('Aún no hay registros de asistencia.')),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final r = records[i];
                      final t = r.createdAt.toLocal();
                      final hh = t.hour.toString().padLeft(2, '0');
                      final mm = t.minute.toString().padLeft(2, '0');
                      return ListTile(
                        leading: CircleAvatar(child: Text('${i + 1}')),
                        title: Text(r.studentName ?? r.studentId),
                        subtitle: Text('Hora: $hh:$mm'
                            '${r.distanceM != null ? ' · ${r.distanceM!.round()} m del aula' : ''}'),
                        trailing: const Icon(Icons.check_circle,
                            color: Colors.green),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
