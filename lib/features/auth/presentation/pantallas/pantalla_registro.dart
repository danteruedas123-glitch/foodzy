import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/auth/presentation/widgets/campos_auth.dart';
import 'package:foodzy/features/auth/presentation/widgets/fondo_auth.dart';

class PantallaRegistro extends ConsumerStatefulWidget {
  const PantallaRegistro({super.key});

  @override
  ConsumerState<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends ConsumerState<PantallaRegistro> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos.')),
      );
      return;
    }
    
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Las contraseñas no coinciden.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).register(name, email, password);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ref.read(authProvider).isAuthenticated
                ? '¡Cuenta creada! Bienvenido a Foodzy.'
                : 'Cuenta creada con éxito. Por favor, inicia sesión.'),
            backgroundColor: const Color(0xFF7DD279),
          ),
        );
        Navigator.of(context).pop(); // Regresar al login
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A120D),
      body: Stack(
        children: [
          const FondoAuth(),
          SafeArea(
            child: Stack(
              children: [
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: EstiloAuth.anchoMaximo),
                      child: AutofillGroup(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const LogoAuth(),
                            const SizedBox(height: 4),
                            Text(
                              'Crear cuenta',
                              textAlign: TextAlign.center,
                              style: EstiloAuth.texto(22),
                            ),
                            const SizedBox(height: 32),
                            CampoAuth(
                              controller: _nameController,
                              etiqueta: 'Nombre completo',
                              icono: Icons.person_outline,
                              teclado: TextInputType.name,
                              autocompletar: const [AutofillHints.name],
                            ),
                            const SizedBox(height: 14),
                            CampoAuth(
                              controller: _emailController,
                              etiqueta: 'Correo electrónico',
                              icono: Icons.mail_outline,
                              teclado: TextInputType.emailAddress,
                              autocompletar: const [AutofillHints.email],
                            ),
                            const SizedBox(height: 14),
                            CampoAuth(
                              controller: _passwordController,
                              etiqueta: 'Contraseña',
                              icono: Icons.lock_outline,
                              esContrasena: true,
                              autocompletar: const [AutofillHints.newPassword],
                            ),
                            const SizedBox(height: 14),
                            CampoAuth(
                              controller: _confirmPasswordController,
                              etiqueta: 'Confirmar contraseña',
                              icono: Icons.lock_reset_outlined,
                              esContrasena: true,
                              accion: TextInputAction.done,
                              autocompletar: const [AutofillHints.newPassword],
                              alEnviar: _handleRegister,
                            ),
                            const SizedBox(height: 28),
                            BotonAuth(
                              texto: 'Registrarse',
                              cargando: _isLoading,
                              alTocar: _handleRegister,
                            ),
                            const SizedBox(height: 24),
                            Text.rich(
                              TextSpan(
                                text: '¿Ya tienes una cuenta? ',
                                style: EstiloAuth.texto(14, color: Colors.white70),
                                children: [
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.baseline,
                                    baseline: TextBaseline.alphabetic,
                                    child: GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      child: Text(
                                        'Inicia sesión',
                                        style: EstiloAuth.texto(14,
                                                peso: FontWeight.w700, color: EstiloAuth.verde)
                                            .copyWith(
                                          decoration: TextDecoration.underline,
                                          decorationColor: EstiloAuth.verde,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Atrás, dentro del área segura (no queda debajo de la cámara).
                Positioned(
                  top: 4,
                  left: 4,
                  child: IconButton(
                    tooltip: 'Volver',
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 26),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
