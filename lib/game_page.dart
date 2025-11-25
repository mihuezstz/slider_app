import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Modelo de obstáculo
class _Obstacle {
  final String assetPath;
  final int lane; // carril (0..laneCount-1)
  double y; // posición vertical (centro)
  final double width;
  final double height;

  _Obstacle({
    required this.assetPath,
    required this.lane,
    required this.y,
    required this.width,
    required this.height,
  });
}

/// Tipo de power-up
enum _PowerUpType { fuel, tire }

/// Modelo de power-up
class _PowerUp {
  final _PowerUpType type;
  final String assetPath;
  final int lane;
  double y;
  final double width;
  final double height;

  _PowerUp({
    required this.type,
    required this.assetPath,
    required this.lane,
    required this.y,
    required this.width,
    required this.height,
  });
}

class _GamePageState extends State<GamePage> {
  // --- Parámetros de carretera / carriles ---
  static const int laneCount = 3;

  // --- Estado del jugador ---
  int playerLane = 1; // 0 izquierda, laneCount-1 derecha
  double _carWidth = 0;
  double _carHeight = 0;
  double _playerY = 0;

  // Llantas como “vidas”
  final int _maxTires = 3;
  int _tiresLeft = 3;

  // --- Obstáculos y power-ups ---
  final List<_Obstacle> _obstacles = [];
  final List<_PowerUp> _powerUps = [];
  final Random _random = Random();

  // --- Loop de juego ---
  Timer? _gameLoopTimer;
  double _scrollSpeed = 260; // px/s

  // Timers de spawn
  double _spawnObstacleTimer = 0.0;
  double _spawnObstacleInterval = 1.4; // segundos

  double _spawnFuelTimer = 0.0;
  double _spawnFuelInterval = 6.0; // un bidón ocasional

  double _spawnTireTimer = 0.0;
  double _spawnTireInterval = 10.0; // llanta ocasional

  // --- Tamaños calculados en build ---
  double _screenHeight = 0;
  double _laneWidth = 0;
  double _roadLeft = 0;

  bool _isGameOver = false;

  // --- Gasolina ---
  double _fuel = 1.0; // 0..1
  final double _fuelConsumptionPerSecond = 0.02;

  // Para evitar que un mismo frame cuente múltiples golpes
  bool _handledCollisionThisFrame = false;

  @override
  void initState() {
    super.initState();
    _startLoop();
  }

  void _startLoop() {
    _gameLoopTimer?.cancel();
    _isGameOver = false;
    _obstacles.clear();
    _powerUps.clear();

    _spawnObstacleTimer = 0.0;
    _spawnFuelTimer = 0.0;
    _spawnTireTimer = 0.0;

    _fuel = 1.0;
    _tiresLeft = _maxTires;

    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (timer) => _updateGame(0.016), // ~60 FPS
    );
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    super.dispose();
  }

  void _updateGame(double dt) {
    if (_isGameOver || _screenHeight == 0) return;

    _handledCollisionThisFrame = false;

    // Consumo de gasolina
    _fuel -= _fuelConsumptionPerSecond * dt;
    if (_fuel <= 0) {
      _fuel = 0;
      _onOutOfFuel();
      return;
    }

    // Mover obstáculos
    for (final o in _obstacles) {
      o.y += _scrollSpeed * dt;
    }
    _obstacles.removeWhere((o) => o.y - o.height / 2 > _screenHeight + 50);

    // Mover power-ups
    for (final p in _powerUps) {
      p.y += _scrollSpeed * dt;
    }
    _powerUps.removeWhere((p) => p.y - p.height / 2 > _screenHeight + 50);

    // Spawn obstáculos
    _spawnObstacleTimer += dt;
    if (_spawnObstacleTimer >= _spawnObstacleInterval) {
      _spawnObstacleTimer = 0;
      _spawnObstacle();
    }

    // Spawn power-up gasolina
    _spawnFuelTimer += dt;
    if (_spawnFuelTimer >= _spawnFuelInterval) {
      _spawnFuelTimer = 0;
      _spawnFuelPowerUp();
    }

    // Spawn power-up llanta
    _spawnTireTimer += dt;
    if (_spawnTireTimer >= _spawnTireInterval) {
      _spawnTireTimer = 0;
      _spawnTirePowerUp();
    }

    // Colisiones
    _checkObstacleCollisions();
    _checkPowerUpCollisions();

    if (mounted) {
      setState(() {});
    }
  }

  // -------------------- SPAWN --------------------

  void _spawnObstacle() {
    if (_laneWidth == 0) return;

    // Tipo de obstáculo
    final int type = _random.nextInt(4); // 0..3
    String asset;
    double width;
    double height;

    final carWidth = _laneWidth / 1.1;
    final carHeight = carWidth * 2;

    switch (type) {
      case 0: // bache
        asset = 'assets/obstaculos/bache.png';
        final size = _laneWidth * 0.7;
        width = size;
        height = size;
        break;
      case 1: // mancha aceite
        asset = 'assets/obstaculos/manchaaceite.png';
        final size = _laneWidth * 0.7;
        width = size;
        height = size;
        break;
      case 2: // cono
        asset = 'assets/obstaculos/cono.png';
        width = _laneWidth * 0.4;
        height = width * 1.5;
        break;
      case 3: // carro enemigo
      default:
        asset = 'assets/obstaculos/negro_car.png';
        width = carWidth * 0.9;
        height = carHeight * 0.9;
        break;
    }

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

  void _spawnFuelPowerUp() {
    if (_laneWidth == 0) return;

    final width = _laneWidth * 0.4;
    final height = width * 1.2;
    final yStart = -height;
    final lane = _random.nextInt(laneCount);

    _powerUps.add(
      _PowerUp(
        type: _PowerUpType.fuel,
        assetPath: 'assets/powerups/gasolina_powerup.png',
        lane: lane,
        y: yStart,
        width: width,
        height: height,
      ),
    );
  }

  void _spawnTirePowerUp() {
    if (_laneWidth == 0) return;

    final width = _laneWidth * 0.5;
    final height = width;
    final yStart = -height;
    final lane = _random.nextInt(laneCount);

    _powerUps.add(
      _PowerUp(
        type: _PowerUpType.tire,
        assetPath: 'assets/powerups/llanta_powerup.png',
        lane: lane,
        y: yStart,
        width: width,
        height: height,
      ),
    );
  }

  // -------------------- COLISIONES --------------------

  // Hitbox vertical del jugador
  double get _playerTop => _playerY - _carHeight * 0.30;
  double get _playerBottom => _playerY + _carHeight * 0.30;

  double _obstacleHitboxFactor(String assetPath) {
    if (assetPath.contains('bache')) return 0.28;
    if (assetPath.contains('mancha')) return 0.22;
    if (assetPath.contains('cono')) return 0.35;
    if (assetPath.contains('negro_car')) return 0.30;
    return 0.30;
  }

  void _checkObstacleCollisions() {
    if (_laneWidth == 0 || _carHeight == 0) return;
    if (_handledCollisionThisFrame) return;

    // Se hace copia para poder remover dentro del loop
    for (final o in List<_Obstacle>.from(_obstacles)) {
      if (o.lane != playerLane) continue;

      final factor = _obstacleHitboxFactor(o.assetPath);
      final obstacleTop = o.y - o.height * factor;
      final obstacleBottom = o.y + o.height * factor;

      final overlapVertically =
          obstacleBottom > _playerTop && obstacleTop < _playerBottom;

      if (overlapVertically) {
        _handledCollisionThisFrame = true;
        _onHitObstacle(o);
        break;
      }
    }
  }

  void _onHitObstacle(_Obstacle obstacle) {
    // Cada choque con obstáculo consume UNA llanta.
    if (_tiresLeft > 0) {
      _tiresLeft--;
    }

    _obstacles.remove(obstacle);

    if (_tiresLeft <= 0) {
      _tiresLeft = 0;
      _onNoTires();
    }
  }

  void _checkPowerUpCollisions() {
    if (_laneWidth == 0 || _carHeight == 0) return;

    for (final p in List<_PowerUp>.from(_powerUps)) {
      if (p.lane != playerLane) continue;

      final powerUpTop = p.y - p.height * 0.3;
      final powerUpBottom = p.y + p.height * 0.3;

      final overlapVertically =
          powerUpBottom > _playerTop && powerUpTop < _playerBottom;

      if (overlapVertically) {
        _applyPowerUp(p);
        _powerUps.remove(p);
      }
    }
  }

  void _applyPowerUp(_PowerUp p) {
    switch (p.type) {
      case _PowerUpType.fuel:
        _fuel += 0.35; // recarga parcial
        if (_fuel > 1.0) _fuel = 1.0;
        break;
      case _PowerUpType.tire:
        if (_tiresLeft < _maxTires) {
          _tiresLeft++;
        }
        break;
    }
  }

  // -------------------- GAME OVERS --------------------

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
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  void _onNoTires() {
    _isGameOver = true;
    _gameLoopTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sin llantas de repuesto'),
          content:
          const Text('Ya no tienes llantas para seguir en la carretera.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  // -------------------- CONTROLES --------------------

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

  // -------------------- UI --------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Juego'),
        backgroundColor: Colors.grey.shade800,
      ),
      body: RawKeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _moveLeft();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _moveRight();
            }
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            _screenHeight = constraints.maxHeight;

            final roadWidth = constraints.maxWidth * 0.7;
            _laneWidth = roadWidth / laneCount;

            _carWidth = _laneWidth / 1.1;
            _carHeight = _carWidth * 2;

            _roadLeft = (constraints.maxWidth - roadWidth) / 2;
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

                // Obstáculos
                for (final o in _obstacles)
                  Positioned(
                    left: _roadLeft + (o.lane + 0.5) * _laneWidth - o.width / 2,
                    top: o.y - o.height / 2,
                    width: o.width,
                    height: o.height,
                    child: Image.asset(o.assetPath, fit: BoxFit.contain),
                  ),

                // Power-ups
                for (final p in _powerUps)
                  Positioned(
                    left: _roadLeft + (p.lane + 0.5) * _laneWidth - p.width / 2,
                    top: p.y - p.height / 2,
                    width: p.width,
                    height: p.height,
                    child: Image.asset(p.assetPath, fit: BoxFit.contain),
                  ),

                // Carro del jugador
                Positioned(
                  left: _roadLeft +
                      (playerLane + 0.5) * _laneWidth -
                      _carWidth / 2,
                  top: _playerY - _carHeight / 2,
                  width: _carWidth,
                  height: _carHeight,
                  child: Image.asset(widget.carAsset, fit: BoxFit.contain),
                ),

                // HUD gasolina + llantas
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gasolina
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
                          const AlwaysStoppedAnimation(Colors.orangeAccent),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Llantas
                      Row(
                        children: [
                          const Icon(Icons.circle_outlined,
                              size: 18, color: Colors.white70),
                          const SizedBox(width: 8),
                          Text(
                            'Llantas:',
                            style: TextStyle(
                              color: Colors.grey.shade100,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            children: List.generate(_maxTires, (index) {
                              final filled = index < _tiresLeft;
                              return Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                                child: Icon(
                                  Icons.circle,
                                  size: 10,
                                  color: filled
                                      ? Colors.lightBlueAccent
                                      : Colors.grey.shade600,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Botones táctiles izquierda / derecha
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
