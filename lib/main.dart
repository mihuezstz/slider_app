import 'dart:js' as js;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:slider_app/widgets/escenarios_page.dart';
import 'services/supabase_service.dart';
import 'widgets/draggable_car.dart';
import 'game_page.dart';

/// Lista de carros disponibles
const List<String> kCarAssets = [
  'assets/cars/bochito_car.png',
  'assets/cars/chevyblue_car.png',
  'assets/cars/tsuru_car.png',
  'assets/cars/police_car.png',
];

/// Nombres visibles de los carros
const List<String> kCarNames = [
  'Bochito',
  'Chevy azul',
  'Tsuru',
  'Patrulla eléctrica',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase distinto para Web / Mobile
  if (kIsWeb) {
    // En web leemos las variables desde web/icons/config.js
    final url = js.context['env']['SUPABASE_URL'] as String?;
    final anon = js.context['env']['SUPABASE_ANON'] as String?;

    if (url == null || anon == null) {
      throw Exception('No se encontraron SUPABASE_URL / SUPABASE_ANON en config.js');
    }

    await Supabase.initialize(url: url, anonKey: anon);
  } else {
    // En móvil / escritorio usamos el archivo .env
    await dotenv.load(fileName: ".env");

    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Slider App',
      theme: baseTheme.copyWith(
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 1,
        ),
      ),
      home: const MyHomePage(title: 'Slider App'),
    );
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

  // Carro seleccionado
  int _selectedCarIndex = 0;

  // Créditos acumulados (monedas)
  int _credits = 0;

  // Para saber si ya se hizo sign-in del usuario de servicio
  bool _isSignedIn = false;

  // Layout vertical / horizontal para la pantalla principal
  bool _isVertical = true;

  String get _selectedCarAsset =>
      kCarAssets[_selectedCarIndex.clamp(0, kCarAssets.length - 1)];

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

  /// Abre el selector de carro en un bottom sheet
  void _openCarSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            itemCount: kCarAssets.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedCarIndex;
              return ListTile(
                leading: SizedBox(
                  width: 60,
                  height: 60,
                  child: Image.asset(kCarAssets[index], fit: BoxFit.contain),
                ),
                title: Text(kCarNames[index]),
                trailing: isSelected
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() => _selectedCarIndex = index);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Cambia de layout vertical a horizontal en la pantalla principal
  void _toggleOrientation() {
    setState(() => _isVertical = !_isVertical);
  }

  /// Inicia el juego y recibe las monedas ganadas al salir
  Future<void> _startGame() async {
    if (_playerName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu nombre antes de jugar.')),
      );
      return;
    }

    // Cargar créditos previos (por si existen en Supabase)
    await _loadCreditsFromSupabase();

    final coinsEarned = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (context) => EscenariosPage(
          carAsset: _selectedCarAsset,
          startingCoins: 0,
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            tooltip: 'Seleccionar carro',
            onPressed: _openCarSelector,
          ),
          IconButton(
            icon: Icon(_isVertical ? Icons.swap_horiz : Icons.swap_vert),
            tooltip:
            _isVertical ? 'Cambiar a horizontal' : 'Cambiar a vertical',
            onPressed: _toggleOrientation,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _isVertical ? _buildVerticalLayout() : _buildHorizontalLayout(),
        ),
      ),
    );
  }

  /// Layout principal en orientación vertical
  Widget _buildVerticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo y texto superior
        Row(
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Image.asset('assets/logo_unison.png'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '4146 • Desarrollo de Aplicaciones Móviles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Configuración del jugador
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de jugador',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _playerName = value.trim();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Carro: '),
                    Text(
                      kCarNames[_selectedCarIndex],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _openCarSelector,
                      icon: const Icon(Icons.directions_car),
                      label: const Text('Cambiar carro'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      'Créditos: $_credits',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Recargar créditos desde Supabase',
                      onPressed:
                      _playerName.isEmpty ? null : _loadCreditsFromSupabase,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _startGame,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Jugar'),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Spacer(),

        // Carro draggable y logo abajo
        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DraggableCar(
                imagePath: _selectedCarAsset,
                width: 120,
                height: 70,
              ),
              const SizedBox(height: 12),
              Text(
                _playerName.isEmpty
                    ? 'Escribe tu nombre para guardar tus créditos'
                    : 'Jugador: $_playerName',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout principal en orientación horizontal
  Widget _buildHorizontalLayout() {
    return Row(
      children: [
        // Panel izquierdo: logo, configuración
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: Image.asset('assets/logo_unison.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '4146 • Desarrollo de Aplicaciones Móviles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de jugador',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _playerName = value.trim();
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Carro: '),
                          Text(
                            kCarNames[_selectedCarIndex],
                            style:
                            const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _openCarSelector,
                            icon: const Icon(Icons.directions_car),
                            label: const Text('Cambiar carro'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.monetization_on_outlined, size: 20),
                          const SizedBox(width: 4),
                          Text(
                            'Créditos: $_credits',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Recargar créditos desde Supabase',
                            onPressed: _playerName.isEmpty
                                ? null
                                : _loadCreditsFromSupabase,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startGame,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Jugar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 24),

        // Panel derecho: preview del carro
        Expanded(
          flex: 1,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DraggableCarHorizontal(
                imagePath: _selectedCarAsset,
                width: 60,
                height: 100,
              ),
              const SizedBox(height: 16),
              Text(
                _playerName.isEmpty
                    ? 'Escribe tu nombre para guardar tus créditos'
                    : 'Jugador: $_playerName',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
