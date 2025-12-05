import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_profile.dart';

class PlayerService {
  static const _playersKey = 'players_data';

  PlayerProfile? _current;
  String? _currentId; // nombre normalizado (minúsculas y sin espacios)

  PlayerProfile get currentPlayer {
    if (_current == null) {
      throw Exception('No hay jugador cargado');
    }
    return _current!;
  }

  String _normalizeName(String raw) => raw.trim().toLowerCase();

  // ==========================
  // CARGAR / CREAR JUGADOR
  // ==========================
  Future<void> loadPlayer(String rawName) async {
    final id = _normalizeName(rawName);
    _currentId = id;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_playersKey);

    Map<String, dynamic> playersMap = {};
    if (jsonStr != null) {
      playersMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    }

    if (playersMap.containsKey(id)) {
      // Jugador existente
      _current = PlayerProfile.fromJson(
          playersMap[id] as Map<String, dynamic>);
    } else {
      // Jugador nuevo
      final profile = PlayerProfile.initial(id);
      playersMap[id] = profile.toJson();
      _current = profile;
      await prefs.setString(_playersKey, jsonEncode(playersMap));
    }
  }

  Future<void> _save() async {
    if (_currentId == null || _current == null) return;

    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_playersKey);

    Map<String, dynamic> playersMap = {};
    if (jsonStr != null) {
      playersMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    }

    playersMap[_currentId!] = _current!.toJson();
    await prefs.setString(_playersKey, jsonEncode(playersMap));
  }

  // ==========================
  // MONEDAS
  // ==========================
  Future<void> addCoins(int amount) async {
    currentPlayer.coins += amount;
    await _save();
  }

  int get coins => currentPlayer.coins;

  // (Esto tienda)
  bool isCarOwned(String carId) => currentPlayer.ownedCars.contains(carId);

  Future<void> unlockCar(String carId) async {
    currentPlayer.ownedCars.add(carId);
    await _save();
  }

  Future<void> selectCar(String carId) async {
    if (!isCarOwned(carId)) return;
    currentPlayer.selectedCarId = carId;
    await _save();
  }

  String get selectedCarId => currentPlayer.selectedCarId;
}
