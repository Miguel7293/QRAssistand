/// Plain data models mirroring the database tables.

class Profile {
  final String id;
  final String fullName;
  final String role; // 'teacher' | 'student'

  const Profile({required this.id, required this.fullName, required this.role});

  bool get isTeacher => role == 'teacher';

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        fullName: m['full_name'] as String? ?? 'Sin nombre',
        role: m['role'] as String? ?? 'student',
      );
}

class Course {
  final String id;
  final String name;
  final String code;
  final String teacherId;

  const Course({
    required this.id,
    required this.name,
    required this.code,
    required this.teacherId,
  });

  factory Course.fromMap(Map<String, dynamic> m) => Course(
        id: m['id'] as String,
        name: m['name'] as String,
        code: m['code'] as String,
        teacherId: m['teacher_id'] as String,
      );
}

class ClassSession {
  final String id;
  final String courseId;
  final String title;
  final DateTime sessionDate;
  final double? latitude;
  final double? longitude;
  final int radiusM;
  final bool isActive;

  const ClassSession({
    required this.id,
    required this.courseId,
    required this.title,
    required this.sessionDate,
    required this.latitude,
    required this.longitude,
    required this.radiusM,
    required this.isActive,
  });

  factory ClassSession.fromMap(Map<String, dynamic> m) => ClassSession(
        id: m['id'] as String,
        courseId: m['course_id'] as String,
        title: m['title'] as String,
        sessionDate: DateTime.parse(m['session_date'] as String),
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        radiusM: (m['radius_m'] as num?)?.toInt() ?? 50,
        isActive: m['is_active'] as bool? ?? true,
      );
}

/// Per-course attendance summary for a student (from student_course_summary).
class CourseSummary {
  final String courseId;
  final String courseName;
  final String courseCode;
  final int totalSessions;
  final int attended;

  const CourseSummary({
    required this.courseId,
    required this.courseName,
    required this.courseCode,
    required this.totalSessions,
    required this.attended,
  });

  double get rate => totalSessions == 0 ? 0 : attended / totalSessions;
  int get ratePct => (rate * 100).round();

  factory CourseSummary.fromMap(Map<String, dynamic> m) => CourseSummary(
        courseId: m['course_id'] as String,
        courseName: m['course_name'] as String,
        courseCode: m['course_code'] as String? ?? '',
        totalSessions: (m['total_sessions'] as num?)?.toInt() ?? 0,
        attended: (m['attended'] as num?)?.toInt() ?? 0,
      );
}

class AttendanceRecord {
  final String id;
  final String studentId;
  final String? studentName;
  final double? distanceM;
  final DateTime createdAt;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.distanceM,
    required this.createdAt,
  });

  factory AttendanceRecord.fromMap(Map<String, dynamic> m) => AttendanceRecord(
        id: m['id'] as String,
        studentId: m['student_id'] as String,
        studentName: (m['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?,
        distanceM: (m['distance_m'] as num?)?.toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
