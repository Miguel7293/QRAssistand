import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/data_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_logo.dart';

/// Branded login + sign-up screen.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _fullName = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  String _role = 'student';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _fullName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_isSignUp) {
        await DataService.signUp(
          email: _email.text.trim(),
          password: _password.text,
          fullName: _fullName.text.trim(),
          role: _role,
        );
        // If email confirmation is on, there is no session yet: send the user
        // to the login form with a clear message instead of a raw error.
        if (Supabase.instance.client.auth.currentSession == null && mounted) {
          setState(() {
            _isSignUp = false;
            _error = null;
          });
          _snack('Cuenta creada. Ahora inicia sesion con tu correo.');
        }
      } else {
        await DataService.signIn(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } catch (e) {
      setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendly(Object e) {
    final s = e.toString();
    if (s.contains('over_email_send_rate_limit') || s.contains('after')) {
      return 'Demasiados intentos. Espera unos segundos y vuelve a probar.';
    }
    if (s.contains('Invalid login credentials')) {
      return 'Correo o contrasena incorrectos.';
    }
    if (s.contains('already registered') ||
        s.contains('User already registered')) {
      return 'Ese correo ya tiene una cuenta. Inicia sesion.';
    }
    if (s.contains('Password should be')) {
      return 'La contrasena debe tener al menos 6 caracteres.';
    }
    final m = RegExp(r'message: ([^,)]+)').firstMatch(s);
    return m != null ? m.group(1)!.trim() : 'Ocurrio un error. Intenta de nuevo.';
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m), backgroundColor: AppColors.garnet),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Branded header
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 36,
              bottom: 36,
            ),
            decoration: const BoxDecoration(
              gradient: AppColors.garnetGradient,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              children: [
                const AppLogo(size: 72),
                const SizedBox(height: 16),
                const Text(
                  'AsistenciaUNA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Control de asistencia con QR dinamico',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _isSignUp ? 'Crear cuenta' : 'Bienvenido de nuevo',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isSignUp
                          ? 'Registrate para empezar a usar el sistema.'
                          : 'Ingresa con tu correo institucional.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    if (_isSignUp) ...[
                      _label('Nombre completo'),
                      TextField(
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Ej. Miguel Angel Llusca',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _label('Correo'),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.mail_outline),
                        hintText: 'correo@est.unap.edu.pe',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _label('Contrasena'),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.lock_outline),
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                          tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                        ),
                      ),
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 20),
                      _label('Soy'),
                      const SizedBox(height: 4),
                      _RolePicker(
                        role: _role,
                        onChanged: (r) => setState(() => _role = r),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.danger, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppColors.danger)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_isSignUp ? 'Crear cuenta' : 'Ingresar'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? 'Ya tienes cuenta?'
                              : 'No tienes cuenta?',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        TextButton(
                          onPressed: _loading
                              ? null
                              : () => setState(() {
                                    _isSignUp = !_isSignUp;
                                    _error = null;
                                  }),
                          child: Text(
                            _isSignUp ? 'Inicia sesion' : 'Registrate',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.garnet),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: AppColors.ink)),
      );
}

class _RolePicker extends StatelessWidget {
  final String role;
  final ValueChanged<String> onChanged;
  const _RolePicker({required this.role, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _card('student', 'Estudiante', Icons.school_rounded),
        const SizedBox(width: 12),
        _card('teacher', 'Docente', Icons.co_present_rounded),
      ],
    );
  }

  Widget _card(String value, String label, IconData icon) {
    final selected = role == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.garnet.withValues(alpha: 0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.garnet : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: selected ? AppColors.garnet : AppColors.muted,
                  size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.garnet : AppColors.muted,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
