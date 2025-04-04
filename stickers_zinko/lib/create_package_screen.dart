import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'models/sticker_package.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:android_intent/android_intent.dart';
import 'package:path_provider/path_provider.dart';

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

  Future<void> _exportToWhatsApp() async {
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes seleccionar al menos una imagen')),
      );
      return;
    }

    try {
      // Verificar y solicitar permisos
      if (Platform.isAndroid) {
        // Para Android 10+ necesitamos permisos específicos
        if (await Permission.manageExternalStorage.isDenied) {
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Se necesitan permisos de almacenamiento para exportar los stickers'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }
      }

      final packageName = _packageNameController.text.trim().isEmpty ? ' ' : _packageNameController.text.trim();
      final authorName = _authorNameController.text.trim().isEmpty ? ' ' : _authorNameController.text.trim();
      
      // Obtener el directorio temporal para crear los archivos
      final tempDir = await getTemporaryDirectory();
      final packDir = Directory('${tempDir.path}/sticker_pack');
      
      if (await packDir.exists()) {
        await packDir.delete(recursive: true);
      }
      await packDir.create(recursive: true);

      // Función para convertir imagen a WebP
      Future<void> convertToWebP(String sourcePath, String targetPath) async {
        final result = await FlutterImageCompress.compressAndGetFile(
          sourcePath,
          targetPath,
          format: CompressFormat.webp,
          quality: 100,
          minWidth: 512,
          minHeight: 512,
          keepExif: false,
        );
        if (result == null) {
          throw Exception('Error al convertir la imagen a WebP');
        }
      }

      // Crear el archivo JSON de contenido
      final contentJson = {
        'android_play_store_link': '',
        'ios_app_store_link': '',
        'sticker_packs': [
          {
            'identifier': packageName.replaceAll(' ', '_').toLowerCase(),
            'name': packageName,
            'publisher': authorName,
            'tray_image_file': 'tray.webp',
            'publisher_email': '',
            'publisher_website': '',
            'privacy_policy_website': '',
            'license_agreement_website': '',
            'stickers': List.generate(
              _selectedImages.length,
              (index) => {
                'image_file': 'sticker_$index.webp',
                'emojis': ['😀'],
              },
            ),
          }
        ],
      };

      // Guardar el archivo JSON
      final contentFile = File('${packDir.path}/contents.json');
      await contentFile.writeAsString(jsonEncode(contentJson));

      // Copiar y convertir las imágenes a WebP
      for (var i = 0; i < _selectedImages.length; i++) {
        final image = _selectedImages[i];
        final targetFile = '${packDir.path}/sticker_$i.webp';
        await convertToWebP(image.path, targetFile);
      }

      // Copiar y convertir la primera imagen como imagen de bandeja
      if (_selectedImages.isNotEmpty) {
        final trayFile = '${packDir.path}/tray.webp';
        await convertToWebP(_selectedImages[0].path, trayFile);
      }

      // Crear el archivo ZIP (.wastickers)
      final encoder = ZipEncoder();
      final archive = Archive();
      
      final files = await packDir.list(recursive: true).toList();
      for (final file in files) {
        if (file is File) {
          final bytes = await file.readAsBytes();
          final relativePath = file.path.substring(packDir.path.length + 1);
          archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
        }
      }

      final zipBytes = encoder.encode(archive);
      if (zipBytes == null) {
        throw Exception('Error al crear el archivo ZIP');
      }

      // Guardar el archivo ZIP con extensión .wastickers
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      
      final wastickersFile = File('${downloadsDir.path}/${packageName.replaceAll(' ', '_')}.wastickers');
      await wastickersFile.writeAsBytes(zipBytes);

      // Limpiar archivos temporales
      await packDir.delete(recursive: true);

      // Mostrar mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Paquete de stickers guardado en la carpeta de Descargas. Compártelo con WhatsApp para usarlo.'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'COMPARTIR',
              onPressed: () async {
                final uri = Uri.parse('file://${wastickersFile.path}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _addStickersToWhatsApp() async {
    final packageName = _packageNameController.text.trim().isEmpty ? ' ' : _packageNameController.text.trim();
    final authority = 'com.zinko.stickers.provider';
    final intent = Intent()
      ..setAction('com.whatsapp.intent.action.ENABLE_STICKER_PACK')
      ..putExtra('sticker_pack_id', packageName.replaceAll(' ', '_').toLowerCase())
      ..putExtra('sticker_pack_authority', authority)
      ..putExtra('sticker_pack_name', packageName);
    try {
      startActivityForResult(intent, 200);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al añadir el paquete de stickers a WhatsApp'),
          duration: Duration(seconds: 3),
        ),
      );
    }
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

    // Crear el archivo JSON de stickers
    final stickersJson = {
      "sticker_packs": [
        {
          "identifier": packageName.replaceAll(' ', '_').toLowerCase(),
          "name": packageName,
          "publisher": authorName,
          "stickers": List.generate(
            _selectedImages.length,
            (index) => {
              "image_file": "sticker_$index.webp",
              "emojis": ["😀"],
            },
          ),
        }
      ]
    };

    // Guardar el archivo JSON en el almacenamiento interno
    _saveStickersJson(stickersJson);

    Navigator.pop(context, package);
  }

  Future<void> _saveStickersJson(Map<String, dynamic> stickersJson) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/stickers.json');
    await file.writeAsString(jsonEncode(stickersJson));
  }

  void _onExportButtonPressed() {
    _addStickersToWhatsApp();
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
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _createPackage,
                            child: Text(widget.packageToEdit != null ? 'Guardar Cambios' : 'Crear Paquete'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _onExportButtonPressed,
                            child: const Text('Exportar a WhatsApp'),
                          ),
                        ),
                      ],
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