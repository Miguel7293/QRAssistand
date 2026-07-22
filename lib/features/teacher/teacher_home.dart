import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';
import 'course_sessions_screen.dart';

/// Teacher landing: list of the teacher's courses + create-course action.
class TeacherHome extends StatefulWidget {
  final Profile profile;
  const TeacherHome({super.key, required this.profile});

  @override
  State<TeacherHome> createState() => _TeacherHomeState();
}

class _TeacherHomeState extends State<TeacherHome> {
  late Future<List<Course>> _courses;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _courses = DataService.myCourses();
  }

  Future<void> _createCourse() async {
    final name = await _askText(context, 'Nuevo curso', 'Nombre del curso');
    if (name == null || name.trim().isEmpty) return;
    try {
      await DataService.createCourse(name.trim());
      setState(_reload);
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Docente · ${widget.profile.fullName}'),
        actions: [
          IconButton(
            onPressed: DataService.signOut,
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCourse,
        icon: const Icon(Icons.add),
        label: const Text('Curso'),
      ),
      body: FutureBuilder<List<Course>>(
        future: _courses,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final courses = snap.data!;
          if (courses.isEmpty) {
            return const Center(
              child: Text('Aun no tenes cursos.\nCrea uno con el boton +',
                  textAlign: TextAlign.center),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              itemCount: courses.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = courses[i];
                return ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.book)),
                  title: Text(c.name),
                  subtitle: Text('Codigo: ${c.code}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseSessionsScreen(course: c),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Small reusable text-input dialog.
Future<String?> askText(
        BuildContext context, String title, String hint) =>
    _askText(context, title, hint);

Future<String?> _askText(
    BuildContext context, String title, String hint) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Guardar')),
      ],
    ),
  );
}
