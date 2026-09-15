import 'dart:math';
import 'package:flutter/material.dart';

class FloatingFruitsBackground extends StatefulWidget {
  const FloatingFruitsBackground({super.key});

  @override
  State<FloatingFruitsBackground> createState() => _FloatingFruitsBackgroundState();
}

class _FloatingFruitsBackgroundState extends State<FloatingFruitsBackground> with TickerProviderStateMixin {
  late List<_FloatingFruit> _fruits;
  final int _numberOfFruits = 40; // Más pétalos para el efecto
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _fruits = List.generate(_numberOfFruits, (index) => _createFruit(index));
  }

  _FloatingFruit _createFruit(int index) {
    // Iconos de hojas y pétalos
    final icons = [
      Icons.eco, 
      Icons.local_florist,
      Icons.spa,
      Icons.favorite, // Corazón como pétalo redondo
    ];
    
    // Colores del video
    final colors = [
      const Color(0xFFFFD700), // Amarillo/Dorado
      const Color(0xFFFF4081), // Rosa
      const Color(0xFFE53935), // Rojo
      const Color(0xFF1E88E5), // Azul
      const Color(0xFF43A047), // Verde
      const Color(0xFFFFFFFF), // Blanco
    ];
    
    final icon = icons[_random.nextInt(icons.length)];
    final color = colors[_random.nextInt(colors.length)];
    
    // Posición inicial aleatoria
    final double startX = _random.nextDouble();
    // Iniciar arriba, más distribuidos para que no caigan todos a la vez
    final double startY = -0.5 - _random.nextDouble() * 2.0; 

    // Duración de la animación cayendo
    final int durationMs = 8000 + _random.nextInt(12000); 

    final controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Animación de rotación lenta
    final rotationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 3000 + _random.nextInt(4000)),
    )..repeat();

    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.reset();
        controller.forward();
      }
    });

    return _FloatingFruit(
      icon: icon,
      color: color,
      startX: startX,
      startY: startY,
      controller: controller,
      rotationController: rotationController,
      size: 15 + _random.nextDouble() * 15,
      opacity: 0.4 + _random.nextDouble() * 0.4, 
    );
  }

  @override
  void dispose() {
    for (var fruit in _fruits) {
      fruit.controller.dispose();
      fruit.rotationController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Stack(
      children: _fruits.map((fruit) {
        return AnimatedBuilder(
          animation: fruit.controller,
          builder: (context, child) {
            // Movimiento hacia abajo (cayendo)
            final currentY = size.height * fruit.startY + (fruit.controller.value * size.height * 2.0);
            // Pequeño movimiento en ola (sinusoidal) en el eje X
            final currentX = size.width * fruit.startX + sin(fruit.controller.value * pi * 6) * 30;

            return Positioned(
              left: currentX,
              top: currentY,
              child: AnimatedBuilder(
                animation: fruit.rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: fruit.rotationController.value * 2 * pi,
                    child: child,
                  );
                },
                child: Icon(
                  fruit.icon,
                  size: fruit.size,
                  color: fruit.color.withValues(alpha: fruit.opacity),
                ),
              ),
            );
          },
        );
      }).toList(),
    );
  }
}

class _FloatingFruit {
  final IconData icon;
  final Color color;
  final double startX;
  final double startY;
  final AnimationController controller;
  final AnimationController rotationController;
  final double size;
  final double opacity;

  _FloatingFruit({
    required this.icon,
    required this.color,
    required this.startX,
    required this.startY,
    required this.controller,
    required this.rotationController,
    required this.size,
    required this.opacity,
  });
}
