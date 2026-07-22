import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_models.dart';

/// Single entry point for all backend (Supabase) operations.
class DataService {
  static final SupabaseClient _db = Supabase.instance.client;

  // ---- Auth --------------------------------------------------------------

  static User? get currentUser => _db.auth.currentUser;

  static Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) async {
    await _db.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': role},
    );
  }

  static Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _db.auth.signOut();

  static Future<Profile> myProfile() async {
    final id = currentUser!.id;
    final row =
        await _db.from('profiles').select().eq('id', id).single();
    return Profile.fromMap(row);
  }

  // ---- Courses (teacher) -------------------------------------------------

  static Future<List<Course>> myCourses() async {
    final rows = await _db
        .from('courses')
        .select()
        .eq('teacher_id', currentUser!.id)
        .order('created_at');
    return rows.map<Course>(Course.fromMap).toList();
  }

  static Future<Course> createCourse(String name) async {
    final code = _randomCode(6);
    final row = await _db
        .from('courses')
        .insert({
          'name': name,
          'code': code,
          'teacher_id': currentUser!.id,
        })
        .select()
        .single();
    return Course.fromMap(row);
  }

  // ---- Sessions (teacher) ------------------------------------------------

  static Future<ClassSession> createSession({
    required String courseId,
    required String title,
    required double latitude,
    required double longitude,
    required int radiusM,
  }) async {
    final row = await _db
        .from('class_sessions')
        .insert({
          'course_id': courseId,
          'title': title,
          'latitude': latitude,
          'longitude': longitude,
          'radius_m': radiusM,
          'is_active': true,
        })
        .select()
        .single();
    return ClassSession.fromMap(row);
  }

  /// Writes a fresh rotating token that expires [ttlSeconds] from now, and
  /// returns it. The teacher screen calls this on a timer; the QR shows it.
  static Future<String> rotateToken(String sessionId,
      {int ttlSeconds = 15}) async {
    final token = _randomCode(10);
    final expires = DateTime.now().toUtc().add(Duration(seconds: ttlSeconds));
    await _db.from('class_sessions').update({
      'rotating_token': token,
      'token_expires_at': expires.toIso8601String(),
    }).eq('id', sessionId);
    return token;
  }

  static Future<void> closeSession(String sessionId) async {
    await _db
        .from('class_sessions')
        .update({'is_active': false}).eq('id', sessionId);
  }

  // ---- Reports (teacher) -------------------------------------------------

  static Future<List<AttendanceRecord>> sessionAttendance(
      String sessionId) async {
    final rows = await _db
        .from('attendance')
        .select('id, student_id, distance_m, created_at, profiles(full_name)')
        .eq('session_id', sessionId)
        .order('created_at');
    return rows.map<AttendanceRecord>(AttendanceRecord.fromMap).toList();
  }

  // ---- Enrollments & summary (student) -----------------------------------

  /// Joins a course by its public code.
  static Future<String> joinCourse(String code) async {
    final result =
        await _db.rpc('join_course', params: {'p_code': code});
    final map = Map<String, dynamic>.from(result as Map);
    return map['course_name'] as String;
  }

  /// Returns per-course attendance summary for the current student.
  static Future<List<CourseSummary>> myCourseSummary() async {
    final result = await _db.rpc('student_course_summary');
    final list = (result as List).cast<Map<String, dynamic>>();
    return list.map(CourseSummary.fromMap).toList();
  }

  // ---- Attendance (student) ----------------------------------------------

  /// Calls the server-side validation function. All three checks (token, GPS,
  /// device) run in Postgres; the client cannot bypass them.
  static Future<Map<String, dynamic>> registerAttendance({
    required String sessionId,
    required String token,
    required double lat,
    required double lng,
    required String deviceId,
  }) async {
    final result = await _db.rpc('register_attendance', params: {
      'p_session_id': sessionId,
      'p_token': token,
      'p_lat': lat,
      'p_lng': lng,
      'p_device_id': deviceId,
    });
    return Map<String, dynamic>.from(result as Map);
  }

  // ---- helpers -----------------------------------------------------------

  static final _rng = Random.secure();
  static String _randomCode(int n) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(n, (_) => chars[_rng.nextInt(chars.length)]).join();
  }
}
