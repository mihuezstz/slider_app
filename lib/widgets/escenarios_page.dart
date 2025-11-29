import 'package:flutter/material.dart';
import 'package:slider_app/game_page.dart';
import 'package:slider_app/main.dart';

//Page para seleccion de escenario
class EscenariosPage  extends StatelessWidget{
  final String carAsset; 
  final int startingCoins;

  const EscenariosPage({
    Key? key,
    required this.carAsset,
    required this.startingCoins,
  }) : super(key: key);

  //List de los escenarios disponibles
  final List<Map<String, String>> escenarios = const [
    {
      'name': 'Snow',
      'image': 'assets/escenarios/snow_Background.png',
    },
    {
      'name': 'Bosque',
      'image': 'assets/escenarios/bosque_Background.jpg',
    }
  ];

  @override 
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecciona una Escenario"),
        centerTitle: true,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1,
          ),
          itemCount: escenarios.length,
          itemBuilder: (context, index) {
            final escenario = escenarios[index];

            return GestureDetector(
              onTap: () {
                // Se manda al gamePage con el escenario selecccionado
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GamePage(
                      carAsset: carAsset,
                      startingCoins: startingCoins,
                      escenario: escenario['image']!,
                      ),
                    ),
                  );
                },
                child:  Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: AssetImage(escenario['image']!),
                      fit: BoxFit.cover,
                      ),
                  ),
                  child: Container(
                    alignment: Alignment.bottomCenter,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                    child: Text(
                      escenario['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 6,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            );
          },
      ),
    );
  }
}