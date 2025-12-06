// Reemplaza el import directo de dart:js por un import condicional
import 'src/env_io.dart' if (dart.library.html) 'src/env_web.dart' as web_env;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:slider_app/widgets/carousel_car.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slider_app/widgets/escenarios_page.dart';
import 'services/supabase_service.dart';
import 'widgets/draggable_car.dart';
import 'game_page.dart';
import 'package:slider_app/widgets/shop_page.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lista de carros disponibles (EN EL MISMO ORDEN QUE EN LA TIENDA)
const List<String> kCarAssets = [
  'assets/cars/bochito_car.png',
  'assets/cars/chevyblue_car.png',
  'assets/cars/tsuru_car.png',
  'assets/cars/police_car.png',
  'assets/cars/deportivo_car.png',
  'assets/cars/espacial_car.png',
  'assets/cars/hotdog_car.png',
  'assets/cars/motoPizza_car.png',
  'assets/cars/motoRobot_car.png',
  'assets/cars/norteño_car.png',
];

/// Nombres visibles de los carros (MISMO ORDEN)
const List<String> kCarNames = [
  'Bochito',
  'Chevy azul',
  'Tsuru',
  'Patrulla eléctrica',
  'Deportivo',
  'Carro espacial',
  'Hot dog móvil',
  'Moto pizza',
  'Moto robot',
  'Norteño',
];

/// Precios en créditos de cada carro
const List<int> kCarPrices = [
  0,   // Bochito: gratis
  20,
  30,
  40,
  50,
  60,
  70,
  80,
  90,
  100,
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Inicializar Supabase distinto para Web / Mobile
  if (kIsWeb) {
    // En web leemos las variables desde web/icons/config.js
    final web = web_env.getWebEnv();
    final url = web?['SUPABASE_URL'];
    final anon = web?['SUPABASE_ANON'];

    if (url == null || anon == null) {
      throw Exception('No se encontraron SUPABASE_URL / SUPABASE_ANON en config.js');
    }

    await Supabase.initialize(url: url, anonKey: anon);
  } else {
    // En móvil / escritorio: hardcodea las claves
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      debugPrint('⚠️ .env no encontrado en móvil, usando valores por defecto');
    }

    // Usa tus credenciales de Supabase reales
    const String url = 'https://itvumldppjrcnxagrydr.supabase.co';
    const String key = 'sb_publishable_Lp69CVXz7wZzHpDyLeoDXQ_us5lPeKY';

    if (url.isEmpty || key.isEmpty) {
      throw Exception('Faltan SUPABASE_URL / SUPABASE_ANON_KEY');
    }

    await Supabase.initialize(url: url, anonKey: key);
  }

  runApp(const MyApp());
}

//----------------TEMA ARCADE-------------------
ThemeData arcadeTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF090b1A),

  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF00E5FF),
    secondary: Color(0xFFB400FF),
    tertiary: Color(0xFFFF00F7),
  ),

  textTheme: TextTheme(
    headlineMedium: GoogleFonts.pressStart2p(
      fontSize: 18,
      color: Colors.white,
      shadows: [
        Shadow(
          color: Color(0xFF00E5FF),
          blurRadius: 12
        ),
      ],
    ),
    bodyLarge: GoogleFonts.vt323(
      fontSize: 24,
      color: Color(0xFFE9E9FF),
    ),
    bodyMedium: GoogleFonts.vt323(
      fontSize: 20,
      color: Colors.white70,
    ),
  ),
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Slider App',
      theme: arcadeTheme, //aqui se aplica el tema
      home: const MyHomePage(title: 'Slider App'),
    );
  }
}

//--------------------ANIMACION DEL BACKGROUND-----------------------

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground(
    {required this.child, Key? key}) : super(key : key);

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
      late AnimationController _controller;
      late Animation<Color?> _color1;
      late Animation<Color?> _color2;

      @override
      void initState() {
        super.initState();
        _controller = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
          )..repeat(reverse: true);

          _color1 = ColorTween(
            begin: Colors.cyanAccent.withOpacity(0.45),
            end: Colors.deepPurple.withOpacity(0.65),
          ).animate(_controller);

          _color2 = ColorTween(
            begin: Colors.blueAccent.withOpacity(0.35),
            end: Colors.pinkAccent.withOpacity(0.55),
          ).animate(_controller);
      }

      @override
      Widget build(BuildContext context) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_color1.value!, _color2.value!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  ),
                ),
                child: widget.child,
            );
          },
        );
      }
      @override
      void dispose() {
        _controller.dispose();
        super.dispose();
      }
    }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final SupabaseService _supabaseService;

  // Nombre del jugador
  final TextEditingController _nameController = TextEditingController();
  String _playerName = '';

  Set<int> _ownedCarIndices = {0}; // Bochito siempre desbloqueado
  bool _isCarOwned(int index) => _ownedCarIndices.contains(index);

  // Carro seleccionado
  int _selectedCarIndex = 0;

  // Créditos acumulados (monedas)
  int _credits = 0;

  // Para saber si ya se hizo sign-in del usuario de servicio
  bool _isSignedIn = false;

  // Layout vertical / horizontal para la pantalla principal
  bool _isVertical = true;

  //boton
  bool _isPressed = false;

  String get _selectedCarAsset =>
      kCarAssets[_selectedCarIndex.clamp(0, kCarAssets.length - 1)];
  
  //---------------------StartGame-----------------------

  void _startGame() async {
    // 🔹 Si el carro seleccionado NO está comprado, no dejamos jugar
    if (!_ownedCarIndices.contains(_selectedCarIndex)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este carro está bloqueado. Cómpralo primero en la tienda.'),
        ),
      );
      return;
    }

    if (_playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe tu nombre antes de jugar'),
        ),
      );
      return;
    }

    final int? coinsEarned = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => EscenariosPage(
          carAsset: _selectedCarAsset,
          startingCoins: _credits,
        ),
      ),
    );

    if (coinsEarned != null && coinsEarned > 0) {
      setState(() {
        _credits += coinsEarned;
      });
      await _saveCreditsToSupabase();
    }
  }

//-------------METODO PARA EL BOTON-----------------
   Widget _buildArcadeButton() {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isPressed = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isPressed = false;
        });
        _startGame();
      },
      onTapCancel: () {
        setState(() {
          _isPressed = false;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        transform: Matrix4.identity()..scale(_isPressed ? 0.93 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.cyanAccent,
            width: 2,
          ),
          boxShadow: _isPressed
              ? []
              : [
                BoxShadow(
                  color: Colors.cyanAccent.withOpacity(0.9),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black,
                  Colors.blueAccent.withOpacity(0.35),
                ],
              ),
            ),
            child: SizedBox(
              width: 150,
            child: Center(
            child: Text(
              "JUGAR",
              style: GoogleFonts.pressStart2p(
                color: Colors.white,
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _signInServiceUser();
  }

  /// Hace sign-in con el usuario de servicio de Supabase (AUTH_EMAIL / AUTH_PASSWORD)
  Future<void> _signInServiceUser() async {
    try {
      await _supabaseService.signIn(
        email: dotenv.env['AUTH_EMAIL'] ?? '',
        password: dotenv.env['AUTH_PASSWORD'] ?? '',
      );
      setState(() {
        _isSignedIn = true;
      });
    } catch (e) {
      // Solo mostramos un snack si falla, pero el juego puede seguir sin Supabase
      debugPrint('Error al iniciar sesión en Supabase: $e');
    }
  }

  /// Carga créditos desde Supabase usando el nombre actual del jugador
  Future<void> _loadCreditsFromSupabase() async {
    if (!_isSignedIn || _playerName.isEmpty) return;

    final points = await _supabaseService.retrievePoints(
      playerName: _playerName,
    );

    if (points != null) {
      setState(() {
        _credits = points;
      });
    }
  }

  /// Guarda créditos en Supabase para el jugador actual
  Future<void> _saveCreditsToSupabase() async {
    if (!_isSignedIn || _playerName.isEmpty) return;

    await _supabaseService.checkAndUpsertPlayer(
      playerName: _playerName,
      score: _credits,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            tooltip: 'Tienda de carritos',
            onPressed: () async {
              // Abrir la tienda y esperar el resultado
              final result = await Navigator.push<ShopResult>(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopPage(
                    carAssets: kCarAssets,
                    carNames: kCarNames,
                    carPrices: kCarPrices,
                    credits: _credits,
                    ownedCarIndices: _ownedCarIndices,
                  ),
                ),
              );

              // Si la tienda regresa algo, actualizamos créditos y carritos comprados
              if (result != null) {
                setState(() {
                  _credits = result.newCredits;
                  _ownedCarIndices = result.ownedCarIndices;
                });

                // Guardar créditos actualizados en Supabase
                await _saveCreditsToSupabase();
              }
            },
          ),
        ],
      ),
      body: AnimatedBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _buildVerticalLayout(),
          ),
        ),
      ),
    );
  }

  /// Layout principal en orientación vertical
  Widget _buildVerticalLayout() {
    return Column(
      children: [

        const SizedBox(height: 10),

//---------------TITULO DEL JUEGO---------------
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.08),
          duration: const Duration(seconds: 5),
          curve: Curves.easeInOut,
          onEnd: () {
            //Para reiniciar animacion
            setState(() {});
          },
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
          child: Text(
                  "CAR SEMESTER RACE",
                  style: GoogleFonts.pressStart2p(
                    fontSize: 32,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.cyanAccent.withOpacity(0.8),
                      blurRadius: 10 + (value * 6),
                      ),
                    ],
                  ),
                ),
              );
            },
        ),  

        const SizedBox(height: 20),

//-----------------CARD DE CONFIGURACION-------------------
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.2),
                blurRadius: 20,
              ),
            ],
            gradient: LinearGradient(
              colors: [ 
                Colors.black.withOpacity(0.4),
                Colors.blueAccent.withOpacity(0.15),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  'Configuración',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 16),

                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nombre de jugador',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => 
                      _playerName = value.trim());
                  },     
                ),

                const SizedBox(height: 20),

//---------------INTEGRACIÓN DEL CARUSEL--------------------------
  
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.28,
        child: CarSelectorCasousel(
          selectedIndex: _selectedCarIndex,
          onSelect: (i) =>
              setState(() => _selectedCarIndex = i),
        ),
      ),

      const SizedBox(height: 10),

//------------NOMBRE DEL CARRO------------------
        Text(
          kCarNames[_selectedCarIndex],
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ), 

  const SizedBox(height: 16),

//--------------------CREDITOS-------------------
                Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 20),
                    const SizedBox(width: 4),
                    Text('Créditos: $_credits'),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Recargar créditos desde Supabase',
                      onPressed:
                      _playerName.isEmpty ? null : _loadCreditsFromSupabase,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

//-----------------PULSAR BOTON JUGAR SIN PLAYER---------------------
                SizedBox(
                  width: double.infinity,
                  child: _buildArcadeButton(),
                ),
              ],
            ),
          ),

        const Spacer(),

        Text(
          _playerName.isEmpty
                ? 'Escribe tu nombre para guardar tus créditos'
                : 'Jugador: $_playerName',
          style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
       }

}