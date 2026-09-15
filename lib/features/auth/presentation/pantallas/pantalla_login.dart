import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foodzy/features/auth/presentation/pantallas/pantalla_registro.dart';
import 'package:foodzy/features/auth/presentation/providers/auth_provider.dart';
import 'package:foodzy/features/auth/presentation/widgets/video_background.dart';
import 'package:google_fonts/google_fonts.dart';

class PantallaLogin extends ConsumerStatefulWidget {
  const PantallaLogin({super.key});

  @override
  ConsumerState<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends ConsumerState<PantallaLogin> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureText = true;
  bool _videoFinished = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Fondo limpio infinito (Se reproduce completo y repite)
          const VideoBackground(
            assetPath: 'assets/videos/fondo_limpio.mp4',
            loop: true,
          ),

          // 2. Fondo de Video Original (Se corta a los 7s exactos)
          IgnorePointer(
            ignoring: _videoFinished,
            child: AnimatedOpacity(
              opacity: _videoFinished ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: VideoBackground(
                assetPath: 'assets/videos/login_video.mp4',
                stopAtDuration: const Duration(milliseconds: 7000), // Exactamente 7 segundos
                onVideoFinished: () {
                  if (mounted) {
                    setState(() {
                      _videoFinished = true;
                    });
                  }
                },
              ),
            ),
          ),

          // Capa oscura muy sutil para asegurar legibilidad
          Container(
            color: Colors.black.withValues(alpha: 0.2),
          ),

          // 3. Formulario (Aparece cuando termina el video original a los 7s)
          AnimatedOpacity(
            opacity: _videoFinished ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            child: _videoFinished ? _buildLoginForm(context) : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título Foodzy recreado con símbolo de infinito para que sea 100% transparente
            Text(
              'f∞dzy',
              style: GoogleFonts.quicksand(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFE8F3D6), // Tono verdoso/crema del logo original
                letterSpacing: -2.0,
              ),
            ),
            const SizedBox(height: 50),
            
            // Campo Usuario
            _buildVideoStyleTextField(
              controller: _emailController,
              hintText: 'Usuario',
              icon: Icons.person_outline,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            
            // Campo Password
            _buildVideoStyleTextField(
              controller: _passwordController,
              hintText: 'Contraseña',
              icon: Icons.lock_outline,
              isPassword: true,
            ),
            
            const SizedBox(height: 8),
            
            // Texto pequeño de registro alineado a la derecha
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const PantallaRegistro(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Regístrate aquí',
                  style: GoogleFonts.quicksand(
                    color: const Color(0xFF7DD279), // Verde brillante de tu mockup
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: const Color(0xFF7DD279),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botón Login Verde
            Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7DD279).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7DD279), // Verde del mockup
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Iniciar Sesión',
                        style: GoogleFonts.quicksand(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoStyleTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.quicksand(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.quicksand(color: Colors.white60),
          prefixIcon: Icon(icon, color: Colors.white70),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70,
                  ),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }
}
