import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_notify.dart';
import '../profile/profile_screen.dart';
import 'scan_screen.dart';

/// Student home — Classroom-style: enrolled courses, attendance charts, and a
/// prominent action to scan the class QR.
class StudentHome extends StatefulWidget {
  final Profile profile;
  const StudentHome({super.key, required this.profile});

  @override
  State<StudentHome> createState() => _StudentHomeState();
}

class _StudentHomeState extends State<StudentHome> {
  late Future<List<CourseSummary>> _summary;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = DataService.myCourseSummary();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _summary;
  }

  Future<void> _joinCourse() async {
    final code = await _askCode();
    if (code == null || code.trim().isEmpty) return;
    try {
      final name = await DataService.joinCourse(code.trim());
      _snack('Te uniste a "$name"', ok: true);
      setState(_reload);
    } catch (e) {
      _snack(_clean('$e'));
    }
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
    setState(_reload);
  }

  Future<String?> _askCode() {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unirme a un curso'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pide a tu docente el codigo del curso.'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Ej. 7K2M9A',
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, c.text),
              child: const Text('Unirme')),
        ],
      ),
    );
  }

  String _clean(String e) {
    final m = RegExp(r'message: ([^,)]+)').firstMatch(e);
    return m != null ? m.group(1)!.trim() : e.replaceAll('Exception:', '').trim();
  }

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    if (ok) {
      AppNotify.success(context, m);
    } else {
      AppNotify.error(context, m);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _joinCourse,
        icon: const Icon(Icons.add),
        label: const Text('Unirme a curso'),
      ),
      body: RefreshIndicator(
        color: AppColors.garnet,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            _header(),
            SliverToBoxAdapter(
              child: FutureBuilder<List<CourseSummary>>(
                future: _summary,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snap.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error: ${snap.error}'),
                    );
                  }
                  final courses = snap.data!;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatsRow(courses: courses),
                        const SizedBox(height: 20),
                        if (courses.isNotEmpty) ...[
                          _sectionTitle('Asistencia por curso'),
                          const SizedBox(height: 12),
                          _AttendanceChart(courses: courses),
                          const SizedBox(height: 24),
                        ],
                        _sectionTitle('Mis cursos'),
                        const SizedBox(height: 12),
                        if (courses.isEmpty)
                          _emptyCourses()
                        else
                          ...courses.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _CourseCard(summary: c),
                              )),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 20,
          left: 20,
          right: 20,
          bottom: 28,
        ),
        decoration: const BoxDecoration(
          gradient: AppColors.garnetGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hola,',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 14)),
                      Text(
                        widget.profile.fullName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ProfileScreen(profile: widget.profile))),
                  borderRadius: BorderRadius.circular(24),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    child: Text(
                      _initials(widget.profile.fullName),
                      style: const TextStyle(
                          color: AppColors.garnet,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Prominent scan action
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _openScanner,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.garnet.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.garnet, size: 28),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Registrar asistencia',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: AppColors.ink)),
                            Text('Escanea el QR de tu clase',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink));

  Widget _emptyCourses() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Column(
          children: [
            Icon(Icons.school_outlined, size: 48, color: AppColors.muted),
            SizedBox(height: 12),
            Text('Aun no estas en ningun curso',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('Toca "Unirme a curso" e ingresa el codigo del docente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts[0].characters.first + parts[1].characters.first)
        .toUpperCase();
  }
}

class _StatsRow extends StatelessWidget {
  final List<CourseSummary> courses;
  const _StatsRow({required this.courses});

  @override
  Widget build(BuildContext context) {
    final totalSessions =
        courses.fold<int>(0, (s, c) => s + c.totalSessions);
    final totalAttended = courses.fold<int>(0, (s, c) => s + c.attended);
    final pct =
        totalSessions == 0 ? 0 : ((totalAttended / totalSessions) * 100).round();

    return Row(
      children: [
        _stat('$pct%', 'Asistencia global', Icons.trending_up_rounded,
            AppColors.garnet),
        const SizedBox(width: 12),
        _stat('${courses.length}', 'Cursos', Icons.menu_book_rounded,
            AppColors.gold),
      ],
    );
  }

  Widget _stat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(value,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: color)),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceChart extends StatelessWidget {
  final List<CourseSummary> courses;
  const _AttendanceChart({required this.courses});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: BarChart(
        BarChartData(
          maxY: 100,
          alignment: BarChartAlignment.spaceAround,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (v) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 25,
                reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 10)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= courses.length) return const SizedBox();
                  final code = courses[i].courseCode;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(code.isEmpty ? '—' : code,
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < courses.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: courses[i].ratePct.toDouble(),
                  width: 22,
                  borderRadius: BorderRadius.circular(6),
                  gradient: const LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.garnet, AppColors.garnetLight],
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseSummary summary;
  const _CourseCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.garnetGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(summary.courseName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Codigo: ${summary.courseCode}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text('${summary.ratePct}%',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: AppColors.garnet)),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.rate,
              minHeight: 8,
              backgroundColor: Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Text('${summary.attended} de ${summary.totalSessions} clases',
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
