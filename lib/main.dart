import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:gal/gal.dart'; // Import para sa pag-save sa Gallery

// Pang-manage ng Dark/Light Theme nang pabago-bago
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() {
  runApp(const IDPhotoEditorApp());
}

class IDPhotoEditorApp extends StatelessWidget {
  const IDPhotoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Pro ID Photo Editor',
          themeMode: currentMode,
          // Light Theme Settings
          theme: ThemeData(
            primarySwatch: Colors.teal,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light),
            useMaterial3: true,
          ),
          // Dark Theme Settings
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark),
            useMaterial3: true,
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _originalImage;
  File? _processedImage;
  bool _isLoading = false;
  bool _isSaving = false;
  String _selectedSize = '1x1';

  // Dinagdagan ang mga ID photo sizes dito
  final Map<String, Map<String, int>> _sizes = {
    '1x1': {'width': 300, 'height': 300},
    '1.5x1.5': {'width': 450, 'height': 450},
    '2x2': {'width': 600, 'height': 600},
    '2x3': {'width': 600, 'height': 900},
    '3x4': {'width': 900, 'height': 1200},
    'Passport Size (PH)': {'width': 413, 'height': 531},
    'Wallet Size': {'width': 300, 'height': 400},
  };

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _originalImage = File(pickedFile.path);
        _processedImage = null;
      });
    }
  }

  Future<void> _processIDPhoto() async {
    if (_originalImage == null) return;

    setState(() {
      _isLoading = true;
    });

    File imageToProcess = _originalImage!;
    final bytes = await imageToProcess.readAsBytes();
    final img.Image? baseImage = img.decodeImage(bytes);

    if (baseImage != null) {
      int targetWidth = _sizes[_selectedSize]!['width']!;
      int targetHeight = _sizes[_selectedSize]!['height']!;

      double targetRatio = targetWidth / targetHeight;
      int origWidth = baseImage.width;
      int origHeight = baseImage.height;
      double origRatio = origWidth / origHeight;

      int cropWidth, cropHeight, cropX, cropY;

      if (origRatio > targetRatio) {
        cropHeight = origHeight;
        cropWidth = (origHeight * targetRatio).round();
        cropX = ((origWidth - cropWidth) / 2).round();
        cropY = 0;
      } else {
        cropWidth = origWidth;
        cropHeight = (origWidth / targetRatio).round();
        cropX = 0;
        cropY = ((origHeight - cropHeight) / 2).round();
      }

      img.Image croppedImage = img.copyCrop(
        baseImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      img.Image resizedImage = img.copyResize(
        croppedImage,
        width: targetWidth,
        height: targetHeight,
      );

      final tempDir = Directory.systemTemp;
      final processedFile = File('${tempDir.path}/processed_id.png');
      await processedFile.writeAsBytes(img.encodePng(resizedImage));

      setState(() {
        _processedImage = processedFile;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveToGallery() async {
    if (_processedImage == null) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await Gal.putImage(_processedImage!.path);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Matagumpay na nai-save sa Gallery!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save image: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pro ID Photo Editor'),
        centerTitle: true,
        actions: [
          // Dark Mode / Light Mode Toggle Button
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            onPressed: () {
              themeNotifier.value = isDark ? ThemeMode.light : ThemeMode.dark;
            },
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // Inayos mula sa dating CenterAxisAlignment
          children: [
            // Preview Section
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Text('Original Image', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _originalImage != null
                            ? Image.file(_originalImage!, fit: BoxFit.cover) // Tinanggal ang sobrang tuldok
                            : const Center(child: Icon(Icons.image, size: 50)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      const Text('Processed ID', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _processedImage != null
                                ? Image.file(_processedImage!, fit: BoxFit.contain) // Tinanggal ang sobrang tuldok
                                : const Center(child: Icon(Icons.portrait, size: 50)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Image Picker Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Dropdown para sa mga Sizes
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Select ID Size:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    DropdownButton<String>(
                      value: _selectedSize,
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedSize = newValue;
                          });
                        }
                      },
                      items: _sizes.keys.map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons (Process at Save)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _originalImage == null || _isLoading ? null : _processIDPhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                child: const Text('Process ID Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _processedImage == null || _isSaving ? null : _saveToGallery,
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : const Text('Save to Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
