import 'package:flutter/material.dart';

/// Widget que muestra un coche arrastrable horizontalmente.
/// 
/// Permite al usuario mover el coche hacia la izquierda o derecha
/// mediante gestos de arrastre (mouse o toque táctil).
class DraggableCar extends StatefulWidget {
  /// Ruta de la imagen del coche
  final String imagePath;
  
  /// Ancho del coche
  final double width;
  
  /// Alto del coche
  final double height;

  const DraggableCar({
    super.key,
    required this.imagePath,
    this.width = 100,
    this.height = 60,
  });

  @override
  State<DraggableCar> createState() => _DraggableCarState();
}

class _DraggableCarState extends State<DraggableCar> {
  /// Posición horizontal del coche (offset desde el centro)
  double _xPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula los límites para que el coche no salga de la pantalla
        final maxWidth = constraints.maxWidth;
        final carHalfWidth = widget.width / 2;
        
        // Limita la posición entre los bordes
        final minX = -maxWidth / 2 + carHalfWidth;
        final maxX = maxWidth / 2 - carHalfWidth;

        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Actualiza la posición basándose en el delta del gesto
              _xPosition += details.delta.dx;
              
              // Asegura que el coche no salga de los límites
              _xPosition = _xPosition.clamp(minX, maxX);
            });
          },
          child: Container(
            width: maxWidth,
            height: widget.height + 20, // Espacio extra para padding
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(_xPosition, 0),
              child: Image.asset(
                widget.imagePath,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Widget que muestra un coche arrastrable verticalmente para el layout horizontal.
/// 
/// Permite al usuario mover el coche hacia arriba o abajo
/// mediante gestos de arrastre (mouse o toque táctil).
/// Se usa en la orientación horizontal de la aplicación.
class DraggableCarHorizontal extends StatefulWidget {
  /// Ruta de la imagen del coche
  final String imagePath;
  
  /// Ancho del coche
  final double width;
  
  /// Alto del coche
  final double height;

  const DraggableCarHorizontal({
    super.key,
    required this.imagePath,
    this.width = 60,
    this.height = 100,
  });

  @override
  State<DraggableCarHorizontal> createState() => _DraggableCarHorizontalState();
}

class _DraggableCarHorizontalState extends State<DraggableCarHorizontal> {
  /// Posición vertical del coche (offset desde el centro)
  double _yPosition = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula los límites para que el coche no salga de la pantalla
        final maxHeight = constraints.maxHeight;
        final carHalfHeight = widget.height / 2;
        
        // Limita la posición entre los bordes
        final minY = -maxHeight / 2 + carHalfHeight;
        final maxY = maxHeight / 2 - carHalfHeight;

        return GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              // Actualiza la posición basándose en el delta del gesto
              _yPosition += details.delta.dy;
              
              // Asegura que el coche no salga de los límites
              _yPosition = _yPosition.clamp(minY, maxY);
            });
          },
          child: Container(
            width: widget.width + 20, // Espacio extra para padding
            height: maxHeight,
            alignment: Alignment.center,
            child: Transform.translate(
              offset: Offset(0, _yPosition),
              child: Image.asset(
                widget.imagePath,
                width: widget.width,
                height: widget.height,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
