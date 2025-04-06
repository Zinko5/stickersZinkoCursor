import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'models/sticker_package.dart';

class CreatePackageScreen extends StatefulWidget {
  final StickerPackage? packageToEdit;
  
  const CreatePackageScreen({super.key, this.packageToEdit});

  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  final _packageNameController = TextEditingController();
  final _authorNameController = TextEditingController();
  List<XFile> _selectedImages = [];

  @override
  void initState() {
    super.initState();
    if (widget.packageToEdit != null) {
      _packageNameController.text = widget.packageToEdit!.name;
      _authorNameController.text = widget.packageToEdit!.author;
      _selectedImages = widget.packageToEdit!.imagePaths.map((path) => XFile(path)).toList();
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _createPackage() {
    final packageName = _packageNameController.text.trim();
    final authorName = _authorNameController.text.trim();
    
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar al menos una imagen')),
      );
      return;
    }

    final package = StickerPackage(
      name: packageName.isEmpty ? ' ' : packageName,
      author: authorName.isEmpty ? ' ' : authorName,
      imagePaths: _selectedImages.map((image) => image.path).toList(),
    );

    Navigator.pop(context, package);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.packageToEdit != null ? 'Editar Paquete' : 'Crear Nuevo Paquete'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _packageNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Paquete',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _authorNameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Autor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _pickImages,
              child: const Text('Seleccionar Imágenes'),
            ),
            const SizedBox(height: 16),
            if (_selectedImages.isNotEmpty)
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Image.file(
                                File(_selectedImages[index].path),
                                fit: BoxFit.cover,
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _createPackage,
                      child: Text(widget.packageToEdit != null ? 'Guardar Cambios' : 'Crear Paquete'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _packageNameController.dispose();
    _authorNameController.dispose();
    super.dispose();
  }
}