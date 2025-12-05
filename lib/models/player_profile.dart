class PlayerProfile {
  final String name;         // nombre del jugador (normalizado o como lo manejen)
  int coins;                 // monedas acumuladas
  Set<String> ownedCars;     // ids de carritos comprados
  String selectedCarId;      // carrito equipado

  PlayerProfile({
    required this.name,
    required this.coins,
    required this.ownedCars,
    required this.selectedCarId,
  });

  factory PlayerProfile.initial(String name) {
    return PlayerProfile(
      name: name,
      coins: 0,
      ownedCars: {'starter'}, // carrito básico
      selectedCarId: 'starter',
    );
  }

  factory PlayerProfile.fromJson(Map<String, dynamic> json) {
    return PlayerProfile(
      name: json['name'] as String,
      coins: json['coins'] as int,
      ownedCars: Set<String>.from(json['ownedCars'] as List<dynamic>),
      selectedCarId: json['selectedCarId'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'coins': coins,
      'ownedCars': ownedCars.toList(),
      'selectedCarId': selectedCarId,
    };
  }
}
