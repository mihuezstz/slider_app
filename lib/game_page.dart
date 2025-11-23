import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; //  Para teclado

/// Pantalla principal de juego.
/// Recibe el asset del carro que eligió el usuario.
class GamePage extends StatefulWidget {
  final String carAsset;

  const GamePage({
    super.key,
    required this.carAsset,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

/// Modelo de obstáculo / power-up
class _Obstacle {
  final String assetPath;
  final int lane; // carril donde está (0..laneCount-1)
  double y; // posición vertical en px (centro de la imagen)
  final double width;
  final double height;
  final bool isPowerUp; // true = gasolina

  _Obstacle({
    required this.assetPath,
    required this.lane,
    required this.y,
    required this.width,
    required this.height,
    this.isPowerUp = false,
  });
}

class _GamePageState extends State<GamePage> {
  // 🔹 Número de carriles
  static const int laneCount = 3;

  // 🔹 Estado del jugador
  int playerLane = 1; // 0 = izq, laneCount-1 = der

  // 🔹 Obstáculos / powerups en pantalla
  final List<_Obstacle> _obstacles = [];
  final Random _random = Random();

  // 🔹 Loop del juego
  Timer? _gameLoopTimer;
  double _spawnTimer = 0.0;
  double _spawnInterval = 1.8; // segundos (modo fácil)
  double _scrollSpeed = 260; // px por segundo

  // 🔹 Para tamaño / colisión (se actualiza en build)
  double _screenHeight = 0;
  double _laneWidth = 0;
  double _roadLeft = 0;
  double _carWidth = 0;
  double _carHeight = 0;
  double _playerY = 0;

  bool _isGameOver = false;

  // 🔹 GASOLINA (0.0 a 1.0)
  double _fuel = 1.0;
  final double _fuelConsumptionPerSecond = 0.02; // 2% por segundo aprox.
  final double _fuelPickupAmount = 0.30; // 30% por gasolinera

  // 🔹 Teclado
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startLoop();

    // Pedir foco para escuchar teclado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _startLoop() {
    _gameLoopTimer?.cancel();
    _isGameOver = false;
    _obstacles.clear();
    _spawnTimer = 0.0;

    // Restablecer gasolina al reiniciar
    _fuel = 1.0;

    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (timer) {
        // ~60 FPS -> 0.016 segundos por frame
        _updateGame(0.016);
      },
    );
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateGame(double dt) {
    if (_isGameOver || _screenHeight == 0) return;

    // 🔻 Consumir gasolina
    _fuel -= _fuelConsumptionPerSecond * dt;
    if (_fuel <= 0) {
      _fuel = 0;
      _onOutOfFuel();
      return;
    }

    // Mover obstáculos / powerups hacia abajo
    for (final o in _obstacles) {
      o.y += _scrollSpeed * dt;
    }

    // Eliminar los que ya salieron de pantalla
    _obstacles.removeWhere((o) => o.y - o.height / 2 > _screenHeight + 50);

    // Spawn de nuevos obstáculos / powerups
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnObstacle();
    }

    // Verificar colisiones
    _checkCollisions();

    // Actualizar UI
    if (mounted) {
      setState(() {});
    }
  }

  void _spawnObstacle() {
    if (_laneWidth == 0 || _screenHeight == 0) return;

    // 🔹 1) Evitar demasiados obstáculos en pantalla al mismo tiempo
    // Contamos solo los que ya son visibles (alguna parte está dentro de la pantalla)
    final visibleObstacles = _obstacles.where((o) {
      final top = o.y - o.height / 2;
      final bottom = o.y + o.height / 2;
      return bottom > 0 && top < _screenHeight;
    }).length;

    // Si ya hay 1 obstáculo visible, no generamos otro todavía
    if (visibleObstacles >= 1) {
      return;
    }

    // 🔹 2) Elegir tipo de obstáculo
    final int type = _random.nextInt(4); // 0..3
    String asset;
    double width;
    double height;

    final carWidth = _laneWidth / 1.1;
    final carHeight = carWidth * 2;

    switch (type) {
      case 0: // bache 1:1
        asset = 'assets/obstaculos/bache.png';
        final size = _laneWidth * 0.7;
        width = size;
        height = size;
        break;
      case 1: // mancha de aceite 1:1
        asset = 'assets/obstaculos/manchaaceite.png';
        final size = _laneWidth * 0.7;
        width = size;
        height = size;
        break;
      case 2: // cono 1:0.5 aprox (más alto que ancho)
        asset = 'assets/obstaculos/cono.png';
        width = _laneWidth * 0.4;
        height = width * 1.5;
        break;
      case 3: // carro enemigo negro 2:1 (como tu carro)
      default:
        asset = 'assets/obstaculos/negro_car.png';
        width = carWidth * 0.9;
        height = carHeight * 0.9;
        break;
    }

    // Posición inicial arriba de la pantalla
    final double yStart = -height;

    // Carril aleatorio
    final lane = _random.nextInt(laneCount);

    _obstacles.add(
      _Obstacle(
        assetPath: asset,
        lane: lane,
        y: yStart,
        width: width,
        height: height,
      ),
    );
  }


  // ---------- HITBOX POR TIPO DE OBSTÁCULO / POWERUP ----------

  double _obstacleHitboxFactor(String assetPath, bool isPowerUp) {
    if (isPowerUp) {
      // hitbox un poco más grande para que sea fácil tomarlo
      return 0.35;
    }

    if (assetPath.contains('bache')) {
      // bache: redondo y pequeño
      return 0.28;
    } else if (assetPath.contains('mancha')) {
      // mancha de aceite: muy plana
      return 0.22;
    } else if (assetPath.contains('cono')) {
      // cono: más alto
      return 0.35;
    } else if (assetPath.contains('negro_car')) {
      // carro enemigo: similar al jugador
      return 0.30;
    }

    // default
    return 0.30;
  }

  void _checkCollisions() {
    if (_laneWidth == 0 || _carHeight == 0) return;

    // 🔹 Hitbox del jugador (reducido)
    const double playerFactor = 0.30;
    final double playerTop = _playerY - _carHeight * playerFactor;
    final double playerBottom = _playerY + _carHeight * playerFactor;

    // Recorremos de atrás hacia adelante para poder remover
    for (int i = _obstacles.length - 1; i >= 0; i--) {
      final o = _obstacles[i];

      if (o.lane != playerLane) continue;

      // 🔹 Hitbox vertical según el tipo de obstáculo / powerup
      final double factor = _obstacleHitboxFactor(o.assetPath, o.isPowerUp);
      final double obstacleTop = o.y - o.height * factor;
      final double obstacleBottom = o.y + o.height * factor;

      final bool overlapVertically =
          obstacleBottom > playerTop && obstacleTop < playerBottom;

      if (!overlapVertically) continue;

      if (o.isPowerUp) {
        // ✅ Tomó gasolinera
        _obstacles.removeAt(i);
        _fuel += _fuelPickupAmount;
        if (_fuel > 1.0) _fuel = 1.0;
      } else {
        // ☠️ Chocó con obstáculo
        _onCrash();
        break;
      }
    }
  }

  void _onCrash() {
    _isGameOver = true;
    _gameLoopTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: const Text('Chocaste con un obstáculo.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  playerLane = 1;
                });
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // volver al menú
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  void _onOutOfFuel() {
    _isGameOver = true;
    _gameLoopTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sin gasolina'),
          content: const Text('Te quedaste sin combustible.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  playerLane = 1;
                });
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // volver al menú
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  void _moveLeft() {
    setState(() {
      if (playerLane > 0) playerLane--;
    });
  }

  void _moveRight() {
    setState(() {
      if (playerLane < laneCount - 1) playerLane++;
    });
  }

  // ⌨️ Manejo de teclas
  void _handleKey(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.keyA) {
      _moveLeft();
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      _moveRight();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Juego'),
        backgroundColor: Colors.grey.shade800,
      ),
      body: RawKeyboardListener(
        focusNode: _focusNode,
        onKey: _handleKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _screenHeight = constraints.maxHeight;

            // Ancho de carretera (70% de la pantalla)
            final roadWidth = constraints.maxWidth * 0.7;
            _laneWidth = roadWidth / laneCount;

            // Tamaño del carro (2:1, carril 1.1x más ancho que el carro)
            _carWidth = _laneWidth / 1.1;
            _carHeight = _carWidth * 2;

            // Posición horizontal de la carretera
            _roadLeft = (constraints.maxWidth - roadWidth) / 2;

            // Y del jugador (80% de la altura de pantalla)
            _playerY = constraints.maxHeight * 0.8;

            return Stack(
              children: [
                // Fondo
                Container(color: Colors.grey.shade900),

                // Carretera
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: roadWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      border: Border.all(color: Colors.white30, width: 2),
                    ),
                  ),
                ),

                // Líneas de carril
                for (int i = 1; i < laneCount; i++)
                  Positioned(
                    left: _roadLeft + i * _laneWidth - 2,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 4,
                      color: Colors.white24,
                    ),
                  ),

                // Obstáculos / powerups
                for (final o in _obstacles)
                  Positioned(
                    left:
                    _roadLeft + (o.lane + 0.5) * _laneWidth - o.width / 2,
                    top: o.y - o.height / 2,
                    width: o.width,
                    height: o.height,
                    child: Image.asset(
                      o.assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Carro del jugador
                Positioned(
                  left: _roadLeft +
                      (playerLane + 0.5) * _laneWidth -
                      _carWidth / 2,
                  top: _playerY - _carHeight / 2,
                  width: _carWidth,
                  height: _carHeight,
                  child: Image.asset(
                    widget.carAsset,
                    fit: BoxFit.contain,
                  ),
                ),

                // 🔹 HUD: Barra de gasolina
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_gas_station,
                              color: Colors.orangeAccent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Gasolina',
                            style: TextStyle(
                              color: Colors.grey.shade100,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(_fuel * 100).clamp(0, 100).toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: Colors.grey.shade200,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _fuel.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: Colors.grey.shade700,
                          valueColor:
                          const AlwaysStoppedAnimation<Color>(
                            Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Controles izquierda/derecha
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'left',
                    onPressed: _moveLeft,
                    child: const Icon(Icons.arrow_left),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'right',
                    onPressed: _moveRight,
                    child: const Icon(Icons.arrow_right),
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
