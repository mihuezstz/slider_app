import 'package:flutter/material.dart';
import 'package:slider_app/game_page.dart';
import 'package:slider_app/main.dart';

//Page para seleccion de escenario
class EscenariosPage  extends StatefulWidget{
  final String carAsset; 
  final int startingCoins;

  const EscenariosPage({
    Key? key,
    required this.carAsset,
    required this.startingCoins,
  }) : super(key: key);

  @override
  State<EscenariosPage> createState() => _EscenariosPageState();
}
  //List de los escenarios disponibles
  class _EscenariosPageState extends State<EscenariosPage> {
    final List<Map<String, String>> escenarios = const [
    {
      'name': 'Anime',
      'image': 'assets/escenarios/anime_Background.jpg',
    },
    {
      'name': 'Bosque',
      'image': 'assets/escenarios/bosque_Background.jpg',
    },
    {
      'name': 'Ciudad Cartoon',
      'image': 'assets/escenarios/cartoon_Background.jpg',
    },
    {
      'name': 'Desierto',
      'image': 'assets/escenarios/desierto_Background.jpg',
    },
    {
      'name': 'Espacio',
      'image': 'assets/escenarios/espacio_Background.jpg',
    },
    {
      'name': 'Futurista',
      'image': 'assets/escenarios/futurista_Background.jpg',
    },
    {
      'name': 'Pixel Art',
      'image': 'assets/escenarios/pixelArt_Background.jpg',
    },
    {
      'name': 'Snow',
      'image': 'assets/escenarios/snow_Background.png',
    },

  ];

  int tappedIndex = -1;

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        //fondo
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF4B0082),
              Color(0xFF8A2BE2),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            ),
            ),
        child:  Column(
          children: [
            const SizedBox(height: 40),

            //Boton de regresar
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left:16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                  ),  
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Regresar"),
                  onPressed: (){
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyApp()),
                      );
                    },
                  ),
                ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Selecciona un Escenario",
              style: TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(color: Colors.black, blurRadius: 10),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.8
                  ),
                  itemCount: escenarios.length,
                  itemBuilder: (context, index) {
                    final escenario = escenarios[index];
                    final isPressed = tappedIndex == index;

                      return GestureDetector(
                        onTapDown: (_) => setState(() => tappedIndex = index),
                        onTapCancel: () => setState(() => tappedIndex = -1),
                        onTapUp: (_) {
                          setState(() => tappedIndex = -1);

                           Navigator.push(
                            context,
                           MaterialPageRoute(
                              builder: (_) => GamePage(
                                carAsset: widget.carAsset,
                                startingCoins: widget.startingCoins,
                                escenario: escenario['image']!,
                              ),
                            ),
                           );
                          },

                          child: AnimatedScale(
                            scale: isPressed ? 0.92 : 1.0, 
                            duration: const Duration(milliseconds: 150),

                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                                border:  Border.all(
                                  color: Colors.white.withOpacity(0.6),
                                  width: 2,
                                  ),
                                  image: DecorationImage(
                                    image: AssetImage(escenario['image']!),
                                    fit: BoxFit.cover,
                                  ), 
                                ),

                                child: Container(

                                  padding: const EdgeInsets.all(8),
                                  alignment: Alignment.bottomCenter,
                                  decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(18),

                                   gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ), 
                                ),

                                child: Text(
                                  escenario['name']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22, 
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 8,
                                        color: Colors.blueAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ),    
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    