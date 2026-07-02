import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

// ---------------------------------------------------------------------------
// Paleta de colores extraída del diseño HTML (Control Electoral)
// ---------------------------------------------------------------------------
class _AppColors {
  static const primary = Color(0xFF0D4671);
  static const primaryContainer = Color(0xFF2E5E8A);
  static const onPrimaryContainer = Color(0xFFB4D6FF);
  static const secondary = Color(0xFF0062A0);
  static const secondaryContainer = Color(0xFF48A8FD);
  static const onSecondaryContainer = Color(0xFF003C65);
  static const background = Color(0xFFF7F9FB);
  static const outline = Color(0xFF72777F);
  static const outlineVariant = Color(0xFFC2C7D0);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF42474F);
  static const error = Color(0xFFBA1A1A);
  static const white = Color(0xFFFFFFFF);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _cedulaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedRole;

  static const _roles = [
    'coordinador_provincial',
    'coordinador_recinto',
    'veedor',
  ];

  @override
  void dispose() {
    _cedulaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          LoginRequested(
            cedula: _cedulaController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
            selectedRole: _selectedRole,
          ),
        );
  }

  // ---------------------------------------------------------------------
  // Estilo compartido de los campos de texto, imitando el input-focus del
  // HTML (borde redondeado, ícono prefijo y realce de color al enfocar).
  // ---------------------------------------------------------------------
  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(
        color: _AppColors.onSurfaceVariant,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
      prefixIcon: Icon(icon, color: _AppColors.outline, size: 22),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.transparent,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      border: border(_AppColors.outlineVariant),
      enabledBorder: border(_AppColors.outlineVariant),
      focusedBorder: border(_AppColors.primary, width: 2),
      errorBorder: border(_AppColors.error),
      focusedErrorBorder: border(_AppColors.error, width: 2),
      errorStyle: const TextStyle(color: _AppColors.error, fontSize: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: _AppColors.error,
              ),
            );
          } else if (state is AuthRequiresPasswordChange) {
            context.go('/change-password');
          } else if (state is AuthAuthenticated) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sesión iniciada correctamente'),
                backgroundColor: Colors.green,
              ),
            );
            final route = switch (state.usuario.rol) {
              'coordinador_provincial' => '/provincial',
              'coordinador_recinto' => '/recinto',
              'veedor' => '/veedor',
              _ => '/login',
            };
            context.go(route);
          }
        },
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ---------------------------------------------
                            // Identidad de marca (icono + título + subtítulo)
                            // ---------------------------------------------
                            Center(
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: _AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.how_to_vote,
                                  size: 34,
                                  color: _AppColors.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Control Electoral',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sistema de Escrutinio Ecuador',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: _AppColors.onSurfaceVariant
                                    .withOpacity(0.8),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ---------------------------------------------
                            // Tarjeta blanca con el formulario
                            // ---------------------------------------------
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _AppColors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _AppColors.outlineVariant,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _cedulaController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(
                                      color: _AppColors.onSurface,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Número de Cédula',
                                      icon: Icons.badge_outlined,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingrese su cédula';
                                      }
                                      if (value.trim().length != 10) {
                                        return 'La cédula debe tener 10 dígitos';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    style: const TextStyle(
                                      color: _AppColors.onSurface,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Correo Electrónico',
                                      icon: Icons.mail_outline,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingrese su correo electrónico';
                                      }
                                      if (!value.contains('@')) {
                                        return 'Ingrese un correo válido';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),
                                  DropdownButtonFormField<String>(
                                    value: _selectedRole,
                                    icon: const Icon(
                                      Icons.expand_more,
                                      color: _AppColors.outline,
                                    ),
                                    style: const TextStyle(
                                      color: _AppColors.onSurface,
                                      fontSize: 14,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Rol en el Proceso',
                                      icon: Icons.manage_accounts_outlined,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'coordinador_provincial',
                                        child: Text('Coordinador Provincial'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'coordinador_recinto',
                                        child: Text('Coordinador de Recinto'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'veedor',
                                        child: Text('Veedor'),
                                      ),
                                    ],
                                    onChanged: (v) =>
                                        setState(() => _selectedRole = v),
                                    validator: (v) => v == null
                                        ? 'Seleccione un rol'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    style: const TextStyle(
                                      color: _AppColors.onSurface,
                                    ),
                                    decoration: _fieldDecoration(
                                      label: 'Contraseña',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: _AppColors.outline,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Ingrese su contraseña';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 4),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: _AppColors.secondary,
                                        padding: EdgeInsets.zero,
                                        minimumSize: const Size(0, 32),
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: () =>
                                          context.push('/forgot-password'),
                                      child: const Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: 56,
                                    child: FilledButton(
                                      onPressed: state is AuthLoading
                                          ? null
                                          : _onLogin,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _AppColors.primary,
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor:
                                            _AppColors.primary
                                                .withOpacity(0.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        elevation: 1,
                                      ).copyWith(
                                        overlayColor:
                                            WidgetStateProperty.all(
                                          _AppColors.secondaryContainer
                                              .withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Text(
                                        'Iniciar Sesión',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // ---------------------------------------------
                            // Pie de página
                            // ---------------------------------------------
                            const SizedBox(height: 32),
                            Text(
                              'Consejo Nacional Electoral del Ecuador\n'
                              '© 2024 Todos los derechos reservados',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: _AppColors.outline,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                if (state is AuthLoading)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: _AppColors.primary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}