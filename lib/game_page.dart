import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main.dart';

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
    Navigator.pop(context, _coinsThisRun);               // regresar a la pantalla principal

  }

  // Tiempo total sobrevivido en la partida (segundos)
  double _survivalTime = 0.0;

  // Cuántas monedas ya se han dado por tiempo (para no repetir)
  int _coinsFromTime = 0;

  // Carriles
  static const int laneCount = 3;

  // Estado del jugador
  int playerLane = 1;

  // Nueva: carril objetivo y posición X actual para animar movimiento suave
  int _targetLane = 1;
  double _playerX = 0.0; // left en px del carro (se interpola hacia target)
  final double _laneChangeSpeed = 200.0; // mayor = más rápido (ajusta a gusto)
  bool _positionsInitialized = false;

  // Listas de entidades
  final List<_Obstacle> _obstacles = [];
  final List<_PowerUp> _powerUps = [];
  final Random _random = Random();

  // Loop del juego
  Timer? _gameLoopTimer;
  double _spawnTimer = 0.0;
  double _spawnInterval = 1.8; // más grande = más separados
  double _scrollSpeed = 500;   // velocidad de caída

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

  // Nueva: flags para teclas presionadas (izquierda/derecha)
  bool _pressingLeft = false;
  bool _pressingRight = false;
  final double _lateralSpeed = 500.0; // velocidad de movimiento lateral

  //variables para tilt cuando se desplaza IZQ/DER
  double _prevPlayerX = 0.0;
  double _lastLateralVelocity = 0.0; // px/s
  final double _maxTilt = 0.3; // radianes

  // Debug: mostrar contornos de hitbox
  bool _showHitboxes = true;

  // Control: si true el coche se recentra (interpolación) cuando no se está moviendo.
  // Si false, al soltar la tecla el coche se queda en la posición X actual.
  bool _autoCenter = false;

  // Nueva: límites para la posición X del jugador
  double _minPlayerX = 0;
  double _maxPlayerX = 0;

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
    // Detenemos cualquier loop anterior
    _gameLoopTimer?.cancel();

    // Reset de estado básico
    _isGameOver = false;
    _obstacles.clear();
    _powerUps.clear();
    _spawnTimer = 0.0;

    // Recursos del jugador
    _fuel = 1.0;
    _spareTires = _maxTires;

    // Monedas y tiempo de ESTA partida
    _coinsThisRun = 0;     // monedas de la corrida actual
    _survivalTime = 0.0;   // tiempo que llevamos vivos
    _coinsFromTime = 0;    // cuántas monedas ya dimos por tiempo

    // Posición del carro
    playerLane = 1;
    _targetLane = 1;
    _positionsInitialized = false; // para re-inicializar _playerX en el próximo layout

    // Iniciar loop del juego (60 fps aprox)
    _gameLoopTimer = Timer.periodic(
      const Duration(milliseconds: 16),
          (timer) => _updateGame(0.016),
    );
  }


  /// Actualiza el estado del juego cada frame
  void _updateGame(double dt) {
    if (_isGameOver || _screenHeight == 0) return;

    // 🔹 1) Aumentar tiempo sobrevivido
    _survivalTime += dt;

// 🔹 2) Calcular cuántas monedas tocan por tiempo (1 moneda cada 10s)
    final int newCoinsFromTime = (_survivalTime ~/ 10); // división entera

// Si cruzamos un nuevo bloque de 10 segundos → dar monedas nuevas
    if (newCoinsFromTime > _coinsFromTime) {
      final diff = newCoinsFromTime - _coinsFromTime;
      _coinsFromTime = newCoinsFromTime;

      _coinsThisRun += diff;   // sumamos esas monedas a las monedas de la partida
    }


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

    // MOVIMIENTO LATERAL:
    // - Si se mantiene la tecla izquierda/derecha, mover continuamente con _lateralSpeed
    if (_laneWidth != 0 && _carWidth != 0) {
      if (_pressingLeft && !_pressingRight) {
        _playerX -= _lateralSpeed * dt;
      } else if (_pressingRight && !_pressingLeft) {
        _playerX += _lateralSpeed * dt;
      } else {
        // Si _autoCenter está activado, suavizar hacia target lane cuando no se presiona.
        // Si no, no hacemos recentering: el coche se queda donde lo soltaste.
        if (_autoCenter) {
          final double targetX = _roadLeft + (_targetLane + 0.5) * _laneWidth - _carWidth / 2;
          final double dx = targetX - _playerX;
          final double t = (dt * _laneChangeSpeed).clamp(0.0, 1.0);
          _playerX += dx * t;
        }
      }

      // Limitar dentro de la carretera
      _playerX = _playerX.clamp(_minPlayerX, _maxPlayerX);
    }

    // Calcular velocidad lateral para tilt
    _lastLateralVelocity = (dt > 0) ? ((_playerX - _prevPlayerX) / dt) : 0.0;
    _prevPlayerX = _playerX;

    // Colisiones: usar el carril actual derivado de la posición X
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

    // Hitbox del jugador (rectángulo)
    const double playerFactor = 0.30;
    final double playerTop = _playerY - _carHeight * playerFactor;
    final double playerBottom = _playerY + _carHeight * playerFactor;
    final double playerLeft = _playerX;
    final double playerRight = _playerX + _carWidth;

    // Recorremos de atrás hacia adelante para poder eliminar
    for (int i = _obstacles.length - 1; i >= 0; i--) {
      final o = _obstacles[i];

      // hitbox horizontal del obstáculo (basada en su posición en el road)
      final double obstacleLeft =
          _roadLeft + (o.lane + 0.5) * _laneWidth - o.width / 2;
      final double obstacleRight = obstacleLeft + o.width;

      final double factor = _obstacleHitboxFactor(o.assetPath);
      final double obstacleTop = o.y - o.height * factor;
      final double obstacleBottom = o.y + o.height * factor;

      final bool overlapHorizontally =
          obstacleRight > playerLeft && obstacleLeft < playerRight;
      final bool overlapVertically =
          obstacleBottom > playerTop && obstacleTop < playerBottom;

      if (overlapHorizontally && overlapVertically) {
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
    final List<_PowerUp> toRemove = [];

    // Hitbox del jugador (rectángulo)
    const double playerHitboxFactor = 0.35;
    final double playerTop = _playerY - _carHeight * playerHitboxFactor;
    final double playerBottom = _playerY + _carHeight * playerHitboxFactor;
    final double playerLeft = _playerX;
    final double playerRight = _playerX + _carWidth;

    for (final p in _powerUps) {
      // hitbox horizontal del powerup
      final double puLeft =
          _roadLeft + (p.lane + 0.5) * _laneWidth - p.width / 2;
      final double puRight = puLeft + p.width;

      final double puTop = p.y - p.height * 0.35;
      final double puBottom = p.y + p.height * 0.35;

      final bool overlapHorizontally =
          puRight > playerLeft && puLeft < playerRight;
      final bool overlapVertically =
          puBottom > playerTop && puTop < playerBottom;

      if (overlapHorizontally && overlapVertically) {
        if (p.type == PowerUpType.fuel) {
          _fuel += 0.35;
          if (_fuel > 1.0) _fuel = 1.0;
        } else if (p.type == PowerUpType.tire) {
          if (_spareTires < _maxTires) {
            _spareTires++;
          }
        } else if (p.type == PowerUpType.coin) {
          _coinsThisRun++;
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
                Navigator.pop(context, _coinsThisRun);
                setState(() => playerLane = 1);
                _startLoop();
              },
              child: const Text('Reintentar'),
            ),
            TextButton(
              onPressed: () {
                // Cerrar dialogo y terminar la partida
                Navigator.pop(context, _coinsThisRun);
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


  // Helper: carril actual basado en _playerX (0..laneCount-1)
  int get _currentPlayerLane {
    if (_laneWidth == 0) return playerLane;
    final double centerX = _playerX + _carWidth / 2;
    final double lanePos = ((centerX - _roadLeft) / _laneWidth);
    int lane = lanePos.round();
    if (lane < 0) lane = 0;
    if (lane > laneCount -1) lane = laneCount - 1;
    return lane;
  }

  /// Mover el carro un carril a la izquierda (ahora actualiza objetivo)
  void _moveLeft() {
    setState(() {
      if (_targetLane > 0) _targetLane--;
    });
  }

  /// Mover el carro un carril a la derecha (ahora actualiza objetivo)
  void _moveRight() {
    setState(() {
      if (_targetLane < laneCount - 1) _targetLane++;
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
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(image: AssetImage(widget.escenario),
          fit: BoxFit.cover,
          scale: 2.0,
          alignment: Alignment.center,
          ),
        ),
        child: Stack(
        children: [
        
       RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
              _pressingLeft = true;
            } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
              _pressingRight = true;
            }
          } else if (event is RawKeyUpEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
              _pressingLeft = false;
            } else if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
              _pressingRight = false;
            }
          }
        },
        // Funcion con el contenido del juego
        child: _buildGameContent(),
       ),
      ],
    ),
  ),
);

}
Widget _buildGameContent() {
        return LayoutBuilder(
          builder: (context, constraints) {
            _screenHeight = constraints.maxHeight;

            // Carretera ocupa 70% del ancho
            final roadWidth = constraints.maxWidth * 0.6;
            _laneWidth = roadWidth / laneCount;

            // Tamaño del carro
            _carWidth = _laneWidth / 1.1;
            _carHeight = _carWidth * 2;

            // Posición de la carretera
            _roadLeft = (constraints.maxWidth - roadWidth) / 2;

            // Posición vertical del carro (abajo)
            _playerY = constraints.maxHeight * 0.8;

            // Inicializar _playerX la primera vez (o después de reiniciar)
            if (!_positionsInitialized) {
              _playerX = _roadLeft + (playerLane + 0.5) * _laneWidth - _carWidth / 2;
              _targetLane = playerLane;
              _positionsInitialized = true;
            }

            // Actualizar límites para _playerX
            _minPlayerX = _roadLeft;
            _maxPlayerX = _roadLeft + roadWidth - _carWidth;

            return Stack(
              children: [  
                // Carretera
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: roadWidth,
                    height: constraints.maxHeight,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A3A3A),
                      border: Border(
                        left: BorderSide(color: Colors.white, width: 3),
                        right: BorderSide(color: Colors.white, width: 3),
                      ),
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
                      color: Colors.white70,
                    ),
                  ),

                // Obstáculos (sprites)
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

                // Contornos de hitbox de obstáculos (debug)
                //if (_showHitboxes)
                  //for (final o in _obstacles)
                    //Positioned(
                      //left: _roadLeft + (o.lane + 0.5) * _laneWidth - o.width / 2,
                      //top: o.y - o.height * _obstacleHitboxFactor(o.assetPath),
                      //width: o.width,
                      //height: o.height * _obstacleHitboxFactor(o.assetPath) * 2,
                      //child: IgnorePointer(
                        //child: Container(
                          //decoration: BoxDecoration(
                            //color: Colors.redAccent.withOpacity(0.08),
                            //border: Border.all(color: Colors.redAccent, width: 2),
                          //),
                        //),
                     // ),
                    //),

                // Power ups (sprites)
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

                // Contornos de hitbox de power ups (debug)
                //if (_showHitboxes)
                  //for (final p in _powerUps)
                    //Positioned(
                      //left: _roadLeft + (p.lane + 0.5) * _laneWidth - p.width / 2,
                      //top: p.y - p.height * 0.35,
                      //width: p.width,
                      //height: p.height * 0.35 * 2,
                      //child: IgnorePointer(
                        //child: Container(
                          //decoration: BoxDecoration(
                            //color: Colors.greenAccent.withOpacity(0.08),
                            //border: Border.all(color: Colors.greenAccent, width: 2),
                          //),
                        //),
                      //),
                   // ),

                // Carro del jugador (usar _playerX para movimiento suave)
                Positioned(
                  left: _playerX,
                  top: _playerY - _carHeight / 2,
                  width: _carWidth,
                  height: _carHeight,
                  child: Builder(
                    builder: (_) {
                      // tilt proporcional a la velocidad lateral (normalizada por _lateralSpeed)
                      final double norm = (_lateralSpeed == 0) ? 0.0 : (_lastLateralVelocity / _lateralSpeed);
                      double angle = (norm * _maxTilt).clamp(-_maxTilt, _maxTilt);
                      // opcional: añadir un pequeño tilt según el offset con respecto al centro del carril
                      final double centerOfCurrentLane = _roadLeft + (_currentPlayerLane + 0.5) * _laneWidth;
                      final double offset = ((_playerX + _carWidth / 2) - centerOfCurrentLane) / _laneWidth;
                      angle += (offset * _maxTilt * 0.25);
                      angle = angle.clamp(-_maxTilt, _maxTilt);

                      return Transform.rotate(
                        angle: angle,
                        alignment: Alignment.center,
                        child: Image.asset(
                          widget.carAsset,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),

                // Contorno de hitbox del jugador (debug)
                //if (_showHitboxes)
                  //Positioned(
                    //left: _playerX,
                    //top: _playerY - _carHeight * 0.30,
                    //width: _carWidth,
                    //height: _carHeight * 0.30 * 2,
                    //child: IgnorePointer(
                      //child: Container(
                        //decoration: BoxDecoration(
                          //color: Colors.blueAccent.withOpacity(0.06),
                          //border: Border.all(color: Colors.blueAccent, width: 2),
                        //),
                      //),
                    //),
                  //),

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
