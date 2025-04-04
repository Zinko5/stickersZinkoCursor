import 'package:flutter/material.dart';
import 'create_package_screen.dart';
import 'models/sticker_package.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickers Zinko',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<StickerPackage> _packages = [];
  final _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final prefs = await _prefs;
    final packagesJson = prefs.getStringList('packages') ?? [];
    setState(() {
      _packages = packagesJson
          .map((json) => StickerPackage.fromJson(jsonDecode(json)))
          .toList();
    });
  }

  Future<void> _savePackages() async {
    final prefs = await _prefs;
    final packagesJson = _packages
        .map((package) => jsonEncode(package.toJson()))
        .toList();
    await prefs.setStringList('packages', packagesJson);
  }

  void _addPackage(StickerPackage package) {
    setState(() {
      _packages.add(package);
    });
    _savePackages();
  }

  void _updatePackage(int index, StickerPackage package) {
    setState(() {
      _packages[index] = package;
    });
    _savePackages();
  }

  void _deletePackage(int index) {
    setState(() {
      _packages.removeAt(index);
    });
    _savePackages();
  }

  Future<void> _showDeleteConfirmation(int index) async {
    final package = _packages[index];
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text('¿Seguro que quieres borrar el paquete "${package.name}" - "${package.author}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (result == true) {
      _deletePackage(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Stickers Zinko'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bienvenido a Stickers Zinko',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Tus paquetes de stickers:',
              style: TextStyle(
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 10),
            if (_packages.isEmpty)
              const Text(
                'Aún no se han creado paquetes.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _packages.length,
                  itemBuilder: (context, index) {
                    final package = _packages[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Paquete: ${package.name}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Autor: ${package.author}',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.share),
                                      onPressed: () {
                                        // TODO: Implementar funcionalidad de compartir
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        final result = await Navigator.push<StickerPackage>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => CreatePackageScreen(
                                              packageToEdit: package,
                                            ),
                                          ),
                                        );
                                        if (result != null) {
                                          _updatePackage(index, result);
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => _showDeleteConfirmation(index),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: package.imagePaths.length > 3 ? 3 : package.imagePaths.length,
                                itemBuilder: (context, imageIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: Image.file(
                                      File(package.imagePaths[imageIndex]),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<StickerPackage>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CreatePackageScreen(),
                  ),
                );
                if (result != null) {
                  _addPackage(result);
                }
              },
              child: const Text('Crear Paquete'),
            ),
          ],
        ),
      ),
    );
  }
}
