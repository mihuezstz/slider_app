import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:slider_app/main.dart';

//--------------Widget del carusel-----------------

class CarSelectorCasousel extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onSelect;

  const CarSelectorCasousel({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  State<CarSelectorCasousel> createState() => _CarSelectorCarouselState();

}

class _CarSelectorCarouselState extends State<CarSelectorCasousel> {
  late final PageController _controller;
  double currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.selectedIndex,
      viewportFraction: 0.55,
    );
    _controller.addListener(() {
      setState(() => currentPage = _controller.page!); 
      });
    }

    @override
    Widget build(BuildContext context) {
      return LayoutBuilder(
        builder: (context, size)  {
          final isMobile = size.maxWidth < 600;

          return Container(
        height: isMobile ? 260 : 300,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A0F24), Color(0xFF1A1440)],
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withOpacity(0.25),
                blurRadius: 25, 
              )
            ],
          ),
        child: Stack(
          children: [
  
        //-----------------PAGE VIEW----------------------
        Positioned.fill(

        child: PageView.builder(
          controller: _controller,
          itemCount: kCarAssets.length,
          onPageChanged: widget.onSelect,
          itemBuilder: (context, index) {

            double dist= (index - currentPage).abs();
            bool isSelected = dist < 0.5;

            //double scale = isSelected ? 1.15 : 0.82;
            //double opacity = (1 - dist).clamp(0.0, 1.0);

            return AnimatedScale(
              scale: isSelected ? 1.2 : 0.85,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? Colors.cyanAccent
                        : Colors.white24,
                    width: isSelected ? 3.5 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? Colors.cyanAccent.withOpacity(0.7)
                          : Colors.blueAccent.withOpacity(0.15),
                      blurRadius: isSelected ? 40 : 20,
                      spreadRadius:  isSelected ? 3 : 1,
                    ),
                  ],
                  gradient: LinearGradient(
                    colors: isSelected
                    ? [
                      Colors.cyanAccent.withOpacity(0.12),
                      Colors.blue.withOpacity(0.5),
                    ]
                  : [
                     Colors.white.withOpacity(0.03),
                     Colors.deepPurple.withOpacity(0.05), 
                  ],
                ),
              ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        //----------IMAGEN DEL CARRITO-----------
                        Image.asset(
                          kCarAssets[index],
                          height: 120,
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                );
              }
           ),
        ),

          //----------BOTON IZQUIERDO----------
            Align(
              alignment: Alignment.centerLeft,
              child: _arcadeButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () {
                  int prev = (widget.selectedIndex - 1).clamp(0, kCarAssets.length -1);
                  _controller.animateToPage(prev,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOut,
                    );
                  widget.onSelect(prev);
                },
              ),
            ),
          //--------------BOTON DERECHO------------------
          Align(
            alignment: Alignment.centerRight,
            child: _arcadeButton(
              icon: Icons.arrow_forward_ios_rounded,
              onTap: () {
                int prev = (widget.selectedIndex + 1).clamp(0, kCarAssets.length - 1);
                _controller.animateToPage(prev,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  );
                widget.onSelect(prev);
                },
              ),
            ),
          ],
        ),
      );
    }
  );
}

  //Boton reutilizable (arcade)
  Widget _arcadeButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 55,
        height: 55,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.cyanAccent, width: 2),
          gradient: const LinearGradient(
            colors: [Colors.black, Color(0xFF092736)],
            ),
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withOpacity(0.7),
              blurRadius: 20,
              spreadRadius: 1,
            )
          ],
        ),

        child: Icon(icon, color: Colors.cyanAccent, size: 26),

      ),
    );
  }
}
