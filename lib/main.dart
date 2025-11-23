import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/supabase_service.dart';
import 'widgets/draggable_car.dart';
import 'game_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:js' as js; // para leer window.env en Web

///  Lista de carros disponibles
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

  if (kIsWeb) {
    // 🌐 WEB → leer variables desde web/icons/config.js
    final url = js.context['env']?['SUPABASE_URL'] as String?;
    final anon = js.context['env']?['SUPABASE_ANON'] as String?;

    if (url == null || anon == null) {
      throw Exception(
        'No se encontraron SUPABASE_URL o SUPABASE_ANON en window.env. '
            'Revisa tu config.js.',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anon,
    );
  } else {
    // 📱 ESCRITORIO / MÓVIL → usar .env normalmente
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
    return MaterialApp(
      title: 'Slider App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
  int _counter = 0;
  late final SupabaseService _supabaseService;
  bool _isSignedIn = false;
  bool _isVertical = true;

  ///  Carro seleccionado
  int _selectedCarIndex = 0;

  /// Obtiene el asset actual
  String get _selectedCarAsset =>
      kCarAssets[_selectedCarIndex.clamp(0, kCarAssets.length - 1)];

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _initializeData();
  }

  /// Abre la selección de carro
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

  ///  Inicia el juego con el carro seleccionado
  void _startGame() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GamePage(
          carAsset: _selectedCarAsset,
        ),
      ),
    );
  }

  ///  Cambia orientación
  void _toggleOrientation() {
    setState(() => _isVertical = !_isVertical);
  }

  /// Inicializa datos desde Supabase
  Future<void> _initializeData() async {
    if (!_isSignedIn) {
      await _supabaseService.signIn(
        email: dotenv.env['AUTH_EMAIL']!,
        password: dotenv.env['AUTH_PASSWORD']!,
      );

      final points = await _supabaseService.retrievePoints(
        playerName: 'Spongebob',
      );

      if (points != null) {
        setState(() {
          _counter = points;
          _isSignedIn = true;
        });
      }
    }
  }

  void _incrementCounter() {
    setState(() => _counter++);
    _supabaseService.checkAndUpsertPlayer(
      playerName: 'Spongebob',
      score: _counter,
    );
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
        child: _isVertical ? _buildVerticalLayout() : _buildHorizontalLayout(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  ///  Layout vertical
  Widget _buildVerticalLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        const Spacer(flex: 2),

        Column(
          children: [
            const Text('You have pushed the button this many times:'),
            const SizedBox(height: 20),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Carro: ${kCarNames[_selectedCarIndex]}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),

            /// 🔹 Botón JUGAR
            FilledButton.icon(
              onPressed: _startGame,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Jugar'),
            ),
          ],
        ),

        const Spacer(flex: 2),

        Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: DraggableCar(
            imagePath: _selectedCarAsset,
            width: 120,
            height: 70,
          ),
        ),
      ],
    );
  }

  ///  Layout horizontal
  Widget _buildHorizontalLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 20.0),
          child: DraggableCarHorizontal(
            imagePath: _selectedCarAsset,
            width: 60,
            height: 100,
          ),
        ),
        const Spacer(flex: 2),
        const Text('You have pushed the button this many times:'),
        const SizedBox(width: 20),
        Text(
          '$_counter',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const Spacer(flex: 2),
      ],
    );
  }
}

