import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Pantalla principal de juego.2
/// Recibe el asset del carro que eligió la persona usuaria.
class GamePage extends StatefulWidget {
  // Asset del carro seleccionado en la pantalla principal.
  final String carAsset;

  // Monedas con las que empieza la partida (las que ya tiene el jugador).
  final int startingCoins;

  // Callback para reportar cuántas monedas se ganaron en la corrida.
  final ValueChanged<int>? onCoinsEarned;

  //Escenario seleccionado
  final String escenario;

  const GamePage({
    super.key,
    required this.carAsset,
    this.startingCoins = 0,
    this.onCoinsEarned,
    required this.escenario,
  });

  @override
  State<GamePage> createState() => _GamePageState();
}

/// Obstáculo (bache, aceite, cono, carro enemigo)
class _Obstacle {
  final String assetPath;
  final int lane; // carril 0..2
  double y;       // centro en Y
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

/// Tipos de power up
enum PowerUpType { fuel, tire, coin }

/// Power up (gasolina, llanta, moneda)
class _PowerUp {
  final PowerUpType type;
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

  void _finishRunAndExit() {
    _gameLoopTimer?.cancel();             // detener loop
    widget.onCoinsEarned?.call(_coinsThisRun); // avisar cuántas monedas se ganaron
    Navigator.pop(context);               // regresar a la pantalla principal
  }

  // Carriles
  static const int laneCount = 3;

  // Estado del jugador
  int playerLane = 1;

  // Listas de entidades
  final List<_Obstacle> _obstacles = [];
  final List<_PowerUp> _powerUps = [];
  final Random _random = Random();

  // Loop del juego
  Timer? _gameLoopTimer;
  double _spawnTimer = 0.0;
  double _spawnInterval = 1.8; // más grande = más separados
  double _scrollSpeed = 260;   // velocidad de caída

  // Para cálculo de posiciones y colisiones
  double _screenHeight = 0;
  double _laneWidth = 0;
  double _roadLeft = 0;
  double _carWidth = 0;
  double _carHeight = 0;
  double _playerY = 0;

  bool _isGameOver = false;

  // Gasolina (0.0 a 1.0)
  double _fuel = 1.0;
  final double _fuelConsumptionPerSecond = 0.02;

  // Llantas de repuesto
  final int _maxTires = 3;
  int _spareTires = 3;

  // Créditos ($)
  // Cuando el jugador recoge una moneda
  int _coinsThisRun = 0; // monedas recolectadas en esta partida

  // Teclado
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _startLoop();
    // Para que el RawKeyboardListener reciba las teclas
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _gameLoopTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  /// Inicia / reinicia el loop del juego
  void _startLoop() {
    _gameLoopTimer?.cancel();
    _isGameOver = false;
    _obstacles.clear();
    _powerUps.clear();
    _spawnTimer = 0.0;

    _fuel = 1.0;
    _spareTires = _maxTires;
    // No reinicio monedas para que sientas progreso en las pruebas
    // Si quieres que se reinicien: comenta la siguiente línea.

    _coinsThisRun = 0;   // reinicia monedas de la corrida


    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (timer) => _updateGame(0.016),
    );
  }

  /// Actualiza el estado del juego cada frame
  void _updateGame(double dt) {
    if (_isGameOver || _screenHeight == 0) return;

    // Consumir gasolina
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

    // Mover power ups
    for (final p in _powerUps) {
      p.y += _scrollSpeed * dt;
    }

    // Limpiar fuera de pantalla
    _obstacles.removeWhere((o) => o.y - o.height / 2 > _screenHeight + 50);
    _powerUps.removeWhere((p) => p.y - p.height / 2 > _screenHeight + 50);

    // Generar nueva entidad (obstáculo / power up)
    _spawnTimer += dt;
    if (_spawnTimer >= _spawnInterval) {
      _spawnTimer = 0;
      _spawnEntity();
    }

    // Colisiones
    _checkObstacleCollisions();
    _checkPowerUpCollisions();

    if (mounted) {
      setState(() {});
    }

  }

  /// Decide qué generar: obstáculo, gasolina, llanta o moneda.
  void _spawnEntity() {
    if (_laneWidth == 0) return;

    final lane = _random.nextInt(laneCount);
    final roll = _random.nextDouble();

    // Probabilidades:
    // 0.00 - 0.65  -> obstáculo (65%)
    // 0.65 - 0.85  -> gasolina  (20%)
    // 0.85 - 0.95  -> llanta    (10%)
    // 0.95 - 1.00  -> moneda     (5%)
    if (roll < 0.65) {
      _spawnObstacle(lane);
    } else if (roll < 0.85) {
      _spawnPowerUp(lane, PowerUpType.fuel);
    } else if (roll < 0.95) {
      _spawnPowerUp(lane, PowerUpType.tire);
    } else {
      _spawnPowerUp(lane, PowerUpType.coin);
    }
  }

  /// Crea un obstáculo en el carril indicado
  void _spawnObstacle(int lane) {
    final carWidth = _laneWidth / 1.1;
    final carHeight = carWidth * 2;

    final int type = _random.nextInt(5);
    String asset;
    double width;
    double height;

    switch (type) {
      case 0: // bache
        asset = 'assets/obstaculos/bache.png';
        final size = _laneWidth * 0.7;
        width = size;
        height = size;
        break;
      case 1: // mancha de aceite
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
        asset = 'assets/obstaculos/negro_car.png';
        width = carWidth * 0.9;
        height = carHeight * 0.9;
        break;
      case 4: // Cartel Colosio (obstáculo especial)
        asset = 'assets/obstaculos/colosio_obstaculo.png';
        // Cartel cuadrado → tamaño medio del carril
        width = _laneWidth * 0.75;
        height = width * 1.0;
        break;
      default: // ruta de seguridad default necesario por las variables width y height
        asset = 'assets/obstaculos/bache.png';
        final size = _laneWidth * 0.6;
        width = size;
        height = size;
        break;

    }

    final yStart = -height;

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

  /// Crea un power up en el carril indicado
  void _spawnPowerUp(int lane, PowerUpType type) {
    String asset;
    double width;
    double height;

    switch (type) {
      case PowerUpType.fuel:
        asset = 'assets/powerups/gasolina_powerup.png';
        width = _laneWidth * 0.45;
        height = width * 1.2;
        break;
      case PowerUpType.tire:
        asset = 'assets/powerups/llanta_powerup.png';
        width = _laneWidth * 0.4;
        height = width * 1.0;
        break;
      case PowerUpType.coin:
        asset = 'assets/powerups/coin_powerup.png';
        width = _laneWidth * 0.35;
        height = width;
        break;
    }

    final yStart = -height;

    _powerUps.add(
      _PowerUp(
        type: type,
        assetPath: asset,
        lane: lane,
        y: yStart,
        width: width,
        height: height,
      ),
    );
  }

  /// Factor de hitbox por tipo de obstáculo (para no usar la imagen completa)
  double _obstacleHitboxFactor(String assetPath) {
    if (assetPath.contains('bache')) return 0.28;
    if (assetPath.contains('mancha')) return 0.22;
    if (assetPath.contains('cono')) return 0.35;
    if (assetPath.contains('negro_car')) return 0.30;
    else if (assetPath.contains('colosio_obstaculo')) {
      // Cartel: es cuadrado y centrado
      return 0.32;
    }

    return 0.30;
  }

  /// Colisión con obstáculos (baches, etc.)
  void _checkObstacleCollisions() {
    if (_laneWidth == 0 || _carHeight == 0) return;

    // Hitbox vertical del carro
    const double playerFactor = 0.30;
    final double playerTop = _playerY - _carHeight * playerFactor;
    final double playerBottom = _playerY + _carHeight * playerFactor;

    // Recorremos de atrás hacia adelante para poder eliminar
    for (int i = _obstacles.length - 1; i >= 0; i--) {
      final o = _obstacles[i];
      if (o.lane != playerLane) continue;

      final double factor = _obstacleHitboxFactor(o.assetPath);
      final double obstacleTop = o.y - o.height * factor;
      final double obstacleBottom = o.y + o.height * factor;

      final bool overlapVertically =
          obstacleBottom > playerTop && obstacleTop < playerBottom;

      if (overlapVertically) {
        _obstacles.removeAt(i);
        _applyObstacleHit();
        break;
      }
    }
  }

  /// Aplica el efecto de chocar contra un obstáculo
  void _applyObstacleHit() {
    // Cada golpe quita 1 llanta de repuesto.
    if (_spareTires > 0) {
      _spareTires -= 1;
      if (_spareTires <= 0) {
        _spareTires = 0;
        _onNoTires();
      }
    } else {
      // Si ya no había llantas, tratamos como choque directo.
      _onCrash();
    }
  }

  /// Colisiones con power ups (gasolina, llantas, monedas)
  void _checkPowerUpCollisions() {
    List<_PowerUp> toRemove = [];

    const double playerHitboxFactor = 0.35;
    final double playerTop = _playerY - _carHeight * playerHitboxFactor;
    final double playerBottom = _playerY + _carHeight * playerHitboxFactor;

    for (final p in _powerUps) {
      if (p.lane != playerLane) continue;

      final double top = p.y - p.height * 0.35;
      final double bottom = p.y + p.height * 0.35;

      final bool overlap = bottom > playerTop && top < playerBottom;

      if (overlap) {
        if (p.type == PowerUpType.fuel) {
          _fuel += 0.35;
          if (_fuel > 1.0) _fuel = 1.0;
        }
        else if (p.type == PowerUpType.tire) {
          if (_spareTires < _maxTires) {
            _spareTires++;
          }
        }
        else if (p.type == PowerUpType.coin) {
          _coinsThisRun++;               // <<--- AQUÍ SE SUMAN LAS MONEDAS
        }

        toRemove.add(p);
      }
    }

    _powerUps.removeWhere((p) => toRemove.contains(p));
  }


  /// Game over por choque "fuerte"
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
                // Cerrar dialogo, reiniciar estado y volver a empezar
                Navigator.pop(context);
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                // Cerrar dialogo y terminar la partida
                Navigator.pop(context);
                _finishRunAndExit();
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  /// Game over por quedarse sin gasolina
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
                // Cerrar dialogo, reiniciar estado y volver a empezar
                Navigator.pop(context);
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                // Cerrar dialogo y terminar la partida
                Navigator.pop(context);
                _finishRunAndExit();
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }

  /// Game over por quedarse sin llantas de repuesto
  void _onNoTires() {
    _isGameOver = true;
    _gameLoopTimer?.cancel();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Sin llantas de repuesto'),
          content: const Text('Ya no tienes llantas para seguir en la carretera.'),
          actions: [
            TextButton(
              onPressed: () {
                // Cerrar dialogo, reiniciar estado y volver a empezar
                Navigator.pop(context);
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                // Cerrar dialogo y terminar la partida
                Navigator.pop(context);
                _finishRunAndExit();
              },
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );
  }


  /// Mover el carro un carril a la izquierda
  void _moveLeft() {
    setState(() {
      if (playerLane > 0) playerLane--;
    });
  }

  /// Mover el carro un carril a la derecha
  void _moveRight() {
    setState(() {
      if (playerLane < laneCount - 1) playerLane++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Juego'),
        backgroundColor: Colors.grey.shade800,
      ),
      body:Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              widget.escenario,
              fit: BoxFit.cover,
            ),
          ),
    
       RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowLeft ||
                key == LogicalKeyboardKey.keyA) {
              _moveLeft();
            } else if (key == LogicalKeyboardKey.arrowRight ||
                key == LogicalKeyboardKey.keyD) {
              _moveRight();
            }
          }
        },
        // Funcion con el contenido del juego
        child: _buildGameContent(),
       ),
      ],
    ),
  );
}
Widget _buildGameContent() {
        return LayoutBuilder(
          builder: (context, constraints) {
            _screenHeight = constraints.maxHeight;

            // Carretera ocupa 70% del ancho
            final roadWidth = constraints.maxWidth * 0.7;
            _laneWidth = roadWidth / laneCount;

            // Tamaño del carro
            _carWidth = _laneWidth / 1.1;
            _carHeight = _carWidth * 2;

            // Posición de la carretera
            _roadLeft = (constraints.maxWidth - roadWidth) / 2;

            // Posición vertical del carro (abajo)
            _playerY = constraints.maxHeight * 0.8;

            return Stack(
              children: [
                // Fondo  (muestra escenario)
                Positioned.fill(
                  child: Image.asset(
                    widget.escenario,
                    fit: BoxFit.cover
                  ),
                ),

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

                // Líneas divisorias de carril
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
                    child: Image.asset(
                      o.assetPath,
                      fit: BoxFit.contain,
                    ),
                  ),

                // Power ups
                for (final p in _powerUps)
                  Positioned(
                    left: _roadLeft + (p.lane + 0.5) * _laneWidth - p.width / 2,
                    top: p.y - p.height / 2,
                    width: p.width,
                    height: p.height,
                    child: Image.asset(
                      p.assetPath,
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

                // HUD gasolina
                Positioned(
                  left: 16,
                  right: 16,
                  top: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_gas_station,
                            color: Colors.orangeAccent,
                            size: 20,
                          ),
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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.orangeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // HUD llantas + monedas
                Positioned(
                  left: 16,
                  right: 16,
                  top: 52,
                  child: Row(
                    children: [
                      // Llantas (iconos tipo "bolitas")
                      Text(
                        'Llantas:',
                        style: TextStyle(
                          color: Colors.grey.shade100,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      for (int i = 0; i < _maxTires; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.circle,
                            size: 10,
                            color: i < _spareTires
                                ? Colors.lightBlueAccent
                                : Colors.grey.shade600,
                          ),
                        ),

                      const Spacer(),

                      // Créditos / monedas
                      SizedBox(
                        height: 20,
                        child: Image.asset(
                          'assets/powerups/coin_powerup.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_coinsThisRun',
                        style: TextStyle(
                          color: Colors.yellow.shade300,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Botón izquierda
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'left',
                    onPressed: _moveLeft,
                    child: const Icon(Icons.arrow_left),
                  ),
                ),

                // Botón derecha
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
        );
  }
}
