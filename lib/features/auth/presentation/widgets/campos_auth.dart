import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Medidas y colores compartidos por inicio de sesión y registro.
abstract final class EstiloAuth {
  static const verde = Color(0xFF7DD279);
  static const alto = 54.0;
  /// Forma de píldora (como el diseño original) en campos y botones.
  static const radio = alto / 2;
  static const anchoMaximo = 420.0;

  static final _bordeRedondo = BorderRadius.circular(radio);

  static TextStyle texto(double tamano, {FontWeight peso = FontWeight.w500, Color? color}) =>
      GoogleFonts.quicksand(fontSize: tamano, fontWeight: peso, color: color ?? Colors.white);

  static OutlineInputBorder _borde(Color color, double grosor) => OutlineInputBorder(
        borderRadius: _bordeRedondo,
        borderSide: BorderSide(color: color, width: grosor),
      );
}

/// Campo de texto translúcido con bordes redondeados parejos.
///
/// Antes el tema global le ponía su propio relleno de esquinas más cerradas
/// dentro del recuadro, y las esquinas no coincidían. Aquí el borde y el
/// relleno los define el mismo `InputDecoration`.
class CampoAuth extends StatefulWidget {
  const CampoAuth({
    super.key,
    required this.controller,
    required this.etiqueta,
    required this.icono,
    this.esContrasena = false,
    this.teclado,
    this.accion = TextInputAction.next,
    this.autocompletar,
    this.alEnviar,
  });

  final TextEditingController controller;
  final String etiqueta;
  final IconData icono;
  final bool esContrasena;
  final TextInputType? teclado;
  final TextInputAction accion;
  final Iterable<String>? autocompletar;
  final VoidCallback? alEnviar;

  @override
  State<CampoAuth> createState() => _CampoAuthState();
}

class _CampoAuthState extends State<CampoAuth> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: widget.esContrasena && _oculto,
      keyboardType: widget.teclado,
      textInputAction: widget.accion,
      autofillHints: widget.autocompletar,
      onSubmitted: widget.alEnviar == null ? null : (_) => widget.alEnviar!(),
      cursorColor: EstiloAuth.verde,
      style: EstiloAuth.texto(16),
      decoration: InputDecoration(
        hintText: widget.etiqueta,
        hintStyle: EstiloAuth.texto(16, color: Colors.white60),
        hintMaxLines: 1,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.10),
        isDense: true,
        constraints: const BoxConstraints(minHeight: EstiloAuth.alto),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Icon(widget.icono, color: Colors.white70, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 52, minHeight: EstiloAuth.alto),
        suffixIcon: widget.esContrasena
            ? IconButton(
                tooltip: _oculto ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(
                  _oculto ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
                onPressed: () => setState(() => _oculto = !_oculto),
              )
            : null,
        border: EstiloAuth._borde(Colors.white.withValues(alpha: 0.28), 1),
        enabledBorder: EstiloAuth._borde(Colors.white.withValues(alpha: 0.28), 1),
        focusedBorder: EstiloAuth._borde(EstiloAuth.verde, 1.6),
      ),
    );
  }
}

/// Botón verde principal ("Iniciar sesión", "Crear cuenta").
class BotonAuth extends StatelessWidget {
  const BotonAuth({super.key, required this.texto, required this.cargando, required this.alTocar});

  final String texto;
  final bool cargando;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: EstiloAuth.alto,
      child: FilledButton(
        onPressed: cargando ? null : alTocar,
        style: FilledButton.styleFrom(
          backgroundColor: EstiloAuth.verde,
          disabledBackgroundColor: EstiloAuth.verde.withValues(alpha: 0.6),
          foregroundColor: const Color(0xFF0E1A12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EstiloAuth.radio)),
        ),
        child: cargando
            ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0E1A12)),
              )
            : Text(texto, style: EstiloAuth.texto(17, peso: FontWeight.w700, color: const Color(0xFF0E1A12))),
      ),
    );
  }
}

/// Logo de texto de Foodzy para las pantallas de acceso.
class LogoAuth extends StatelessWidget {
  const LogoAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'f∞dzy',
        maxLines: 1,
        style: GoogleFonts.quicksand(
          fontSize: 64,
          fontWeight: FontWeight.bold,
          color: const Color(0xFFE8F3D6),
          letterSpacing: -2.0,
        ),
      ),
    );
  }
}
