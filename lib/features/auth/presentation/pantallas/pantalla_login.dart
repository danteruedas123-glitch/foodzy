import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/core/nube.dart';
import 'package:foodzy/features/auth/presentation/pantallas/pantalla_registro.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/auth/presentation/widgets/campos_auth.dart';
import 'package:foodzy/features/auth/presentation/widgets/fondo_auth.dart';

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _recuperarContrasena() async {
    final controlador = TextEditingController(text: _emailController.text.trim());
    final correo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: TextField(
          controller: controlador,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Tu correo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controlador.text.trim()),
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    if (correo == null || correo.isEmpty) return;
    try {
      await ref.read(authProvider.notifier).recuperarContrasena(correo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Te enviamos un correo para restablecer la contraseña.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _handleGoogle() async {
    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).loginConGoogle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa correo y contraseña.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authProvider.notifier).login(email, password);
      if (mounted) {
        final nombre = email.split('@').first;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Bienvenido a Foodzy, $nombre!'),
            backgroundColor: const Color(0xFF7DD279),
          ),
        );
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

  void _abrirRegistro() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PantallaRegistro(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A120D),
      body: Stack(
        children: [
          const FondoAuth(),
          SafeArea(child: _buildLoginForm(context)),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: EstiloAuth.anchoMaximo),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LogoAuth(),
                const SizedBox(height: 40),
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
                  accion: TextInputAction.done,
                  autocompletar: const [AutofillHints.password],
                  alEnviar: _handleLogin,
                ),
                if (Nube.disponible)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _recuperarContrasena,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      child: Text(
                        '¿Olvidaste tu contraseña?',
                        style: EstiloAuth.texto(14, peso: FontWeight.w600, color: Colors.white70),
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 14),
                const SizedBox(height: 12),
                BotonAuth(
                  texto: 'Iniciar sesión',
                  cargando: _isLoading,
                  alTocar: _handleLogin,
                ),
                if (Nube.disponible) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: EstiloAuth.texto(14, color: Colors.white60)),
                      ),
                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.25))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: EstiloAuth.alto,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _handleGoogle,
                      icon: const Icon(Icons.account_circle_outlined, size: 22),
                      label: Text(
                        'Continuar con Google',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: EstiloAuth.texto(16, peso: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(EstiloAuth.radio),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text.rich(
                  TextSpan(
                    text: '¿No tienes cuenta? ',
                    style: EstiloAuth.texto(14, color: Colors.white70),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _abrirRegistro,
                          child: Text(
                            'Regístrate',
                            style: EstiloAuth.texto(14, peso: FontWeight.w700, color: EstiloAuth.verde)
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
    );
  }
}
