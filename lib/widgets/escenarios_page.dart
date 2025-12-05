import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
  class _EscenariosPageState extends State<EscenariosPage> 
      with SingleTickerProviderStateMixin{

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

  late AnimationController _titleController;
  late Animation<double> _titleScale;

  bool _backPressed = false;

  @override
  void initState() {
    super.initState();

    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      )..repeat(reverse: true);

    _titleScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(
        parent: _titleController, 
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }


  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground( //Tema de animacion que viene desde el main
        child:  Column(
          children: [
            const SizedBox(height: 40),

//------------------BOTON DE REGRESAR----------------------
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left:16),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _backPressed = true),
                  onTapUp: (_) {
                    setState(() => _backPressed = false);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const MyApp()),
                    );
                  },
                  onTapCancel: () => setState(() => _backPressed = false),
                  child: AnimatedScale(
                    scale: _backPressed ? 0.92 : 1.0, 
                    duration: const Duration(milliseconds: 120),
                    child: ScaleTransition(
                      scale: Tween(
                        begin: 1.0, 
                        end: 1.07).animate(
                          CurvedAnimation(
                            parent: _titleController, 
                            curve: Curves.easeInOut,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.cyanAccent, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.cyanAccent.withOpacity(0.9),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const[
                                Icon(Icons.arrow_back, color: Colors.cyanAccent),
                                SizedBox(width: 8),
                                Text(
                                   "REGRESAR",
                                   style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        blurRadius: 16,
                                        color: Colors.cyanAccent,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),  
                  ),
                ),
          

            const SizedBox(height: 10),

//-----------------TITULO DE ESCENARIO-------------------------
            AnimatedBuilder(
              animation: _titleController, 
              builder: (_, _) {
                final glow = 5 + (_titleController.value * 15);

                return Text(
                  "SELECCIONA UN ESCENARIO",
                  style: GoogleFonts.pressStart2p(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.blueAccent,
                        blurRadius: glow,
                      ),
                    ]
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

//----------------SELECCION DE ESCENARIO----------------
          
            Expanded(
              child: PageView.builder(
                controller: PageController(viewportFraction: 0.55),
                  itemCount: escenarios.length,
                  onPageChanged: (i) => setState(() => tappedIndex = i),
                  itemBuilder: (context, index) {
                    final escenario = escenarios[index];
                    final isCenter = tappedIndex == index;

                      return GestureDetector(
                        onTap: () async {
                           final result = await Navigator.push(
                            context,
                           MaterialPageRoute(
                              builder: (_) => GamePage(
                                carAsset: widget.carAsset,
                                startingCoins: widget.startingCoins,
                                escenario: escenario['image']!,
                              ),
                            ),
                          );
                          Navigator.pop(context, result);
                        },

                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,

                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001) //profundidad
                              ..rotateY(isCenter ? 0 : (index < tappedIndex ? 0.35 : -0.35)), //perspectiva

                              child: AnimatedScale(
                                duration: const Duration(milliseconds: 300),
                                scale: isCenter ? 1.1 : 0.8,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),

                                decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: isCenter
                                        ? Colors.cyanAccent.withOpacity(0.7)
                                        : Colors.black.withOpacity(0.3),
                                    blurRadius: isCenter ? 30 : 10,
                                  ),
                                ],
                                  image: DecorationImage(
                                    image: AssetImage(escenario['image']!),
                                    fit: BoxFit.cover,
                                  ), 
                                ),
                               
                                child: Container(
                                  decoration: BoxDecoration(
                                   borderRadius: BorderRadius.circular(20),
                                   gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                    ],
                                  ), 
                                ),
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.all(12),

                                child: Text(
                                  escenario['name']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24, 
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.cyanAccent, blurRadius: 20
                                      ),
                                    ],
                                  ),
                                ),
                              ),    
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ),
          ]
        ),
      ),
    );
  }
}
    