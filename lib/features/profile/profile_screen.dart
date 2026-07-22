import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/data_service.dart';
import '../../theme/app_theme.dart';

/// Simple profile screen: identity, role, and sign-out.
class ProfileScreen extends StatelessWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final email = DataService.currentUser?.email ?? '—';
    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 46,
                  backgroundColor: AppColors.garnet,
                  child: Text(
                    _initials(profile.fullName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                Text(profile.fullName,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.isTeacher ? 'Docente' : 'Estudiante',
                    style: const TextStyle(
                        color: AppColors.garnetDark,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _tile(Icons.mail_outline, 'Correo', email),
          const SizedBox(height: 12),
          _tile(Icons.badge_outlined, 'ID de usuario',
              profile.id.substring(0, 8)),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () async {
              await DataService.signOut();
              if (context.mounted) Navigator.of(context).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesion'),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.garnet),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12)),
                Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
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
