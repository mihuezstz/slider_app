import 'package:flutter/material.dart';

class ShopPage extends StatefulWidget {
  final List<String> carAssets;
  final List<String> carNames;
  final List<int> carPrices;
  final int credits;
  final Set<int> ownedCarIndices;

  const ShopPage({
    super.key,
    required this.carAssets,
    required this.carNames,
    required this.carPrices,
    required this.credits,
    required this.ownedCarIndices,
  });

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late int _credits;
  late Set<int> _owned;

  @override
  void initState() {
    super.initState();
    _credits = widget.credits;
    _owned = {...widget.ownedCarIndices};
  }

  void _buyCar(int index) {
    if (_owned.contains(index)) return;

    final price = widget.carPrices[index];

    if (_credits < price) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes suficientes créditos')),
      );
      return;
    }

    setState(() {
      _credits -= price;
      _owned.add(index);
    });
  }

  void _closeShop() {
    Navigator.pop(
      context,
      ShopResult(
        newCredits: _credits,
        ownedCarIndices: _owned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _closeShop();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tienda de Carritos'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeShop,
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  'Créditos: $_credits',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        body: ListView.builder(
          itemCount: widget.carAssets.length,
          itemBuilder: (context, index) {
            final owned = _owned.contains(index);
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: ListTile(
                leading: Image.asset(widget.carAssets[index], width: 60),
                title: Text(widget.carNames[index]),
                subtitle: owned
                    ? const Text('Comprado', style: TextStyle(color: Colors.green))
                    : Text('Precio: ${widget.carPrices[index]} créditos'),
                trailing: owned
                    ? const Icon(Icons.check, color: Colors.green)
                    : ElevatedButton(
                  onPressed: () => _buyCar(index),
                  child: const Text('Comprar'),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ShopResult {
  final int newCredits;
  final Set<int> ownedCarIndices;

  ShopResult({
    required this.newCredits,
    required this.ownedCarIndices,
  });
}
