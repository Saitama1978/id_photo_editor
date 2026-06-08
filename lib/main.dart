import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;

void main() {
  runApp(const IDPhotoEditorApp());
}

class IDPhotoEditorApp extends StatelessWidget {
  const IDPhotoEditorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pro ID Photo Editor',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
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
  String _selectedSize = '1x1';
  bool _removeBackground = false;

  final String _apiKey = "ILAGAY_ANG_REMOVE_BG_API_KEY_DITO";

  final Map<String, Map<String, int>> _sizes = {
    '1x1': {'width': 300, 'height': 300},
    '2x2': {'width': 600, 'height': 600},
    'Passport Size (PH)': {'width': 413, 'height': 531},
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

  Future<File?> _apiRemoveBackground(File imageFile) async {
    if (_apiKey == "ILAGAY_ANG_REMOVE_BG_API_KEY_DITO" || _apiKey.isEmpty) {
      debugPrint("Paalala: Walang inilagay na Remove.bg API Key.");
      return imageFile;
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.remove.bg/v1.0/removebg'),
      );
      request.headers['X-Api-Key'] = _apiKey;
      request.fields['size'] = 'auto';
      request.fields['bg_color'] = 'white'; 
      request.files.add(await http.MultipartFile.fromPath('image_file', imageFile.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseBytes = await response.stream.toBytes();
        final tempDir = Directory.systemTemp;
        final bgRemovedFile = File('${tempDir.path}/bg_removed.png');
        await bgRemovedFile.writeAsBytes(responseBytes);
        return bgRemovedFile;
      } else {
        debugPrint("API Error: ${response.statusCode}");
        return imageFile;
      }
    } catch (e) {
      debugPrint("Error removing background: $e");
      return imageFile;
    }
  }

  Future<void> _processIDPhoto() async {
    if (_originalImage == null) return;

    setState(() {
      _isLoading = true;
    });

    File imageToProcess = _originalImage!;

    if (_removeBackground) {
      File? bgResult = await _apiRemoveBackground(imageToProcess);
      if (bgResult != null) {
        imageToProcess = bgResult;
      }
    }

    final bytes = await imageToProcess.readAsBytes();
    final img.Image? baseImage = img.decodeImage(bytes);

    if (baseImage != null) {
      int targetWidth = _sizes[_selectedSize]!['width']!;
      int targetHeight = _sizes[_selectedSize]!['height']!;

      double targetRatio = targetWidth / targetHeight;
      double currentRatio = baseImage.width / baseImage.height;

      int cropWidth, cropHeight;
      int offsetX = 0, offsetY = 0;

      if (currentRatio > targetRatio) {
        cropHeight = baseImage.height;
        cropWidth = (baseImage.height * targetRatio).toInt();
        offsetX = (baseImage.width - cropWidth) ~/ 2;
      } else {
        cropWidth = baseImage.width;
        cropHeight = (baseImage.width / targetRatio).toInt();
        offsetY = (baseImage.height - cropHeight) ~/ 3.5; 
      }

      img.Image croppedImage = img.copyCrop(
        baseImage, 
        x: offsetX, 
        y: offsetY, 
        width: cropWidth, 
        height: cropHeight
      );

      img.Image resizedImage = img.copyResize(
        croppedImage, 
        width: targetWidth, 
        height: targetHeight
      );

      final tempDir = Directory.systemTemp;
      final processedFile = File('${tempDir.path}/final_id_photo.png');
      await processedFile.writeAsBytes(img.encodePng(resizedImage));

      setState(() {
        _processedImage = processedFile;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matagumpay na nagawa ang $_selectedSize ID photo!')),
      );
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart ID Photo Pro'),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_originalImage == null)
                      Container(
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[400]!),
                        ),
                        child: const Center(child: Text('Pumili ng larawan sa ibaba')),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Original w/ Guide', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.file(_originalImage!, height: 220, fit: BoxFit.cover),
                                    IgnorePointer(
                                      child: Container(
                                        height: 220,
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.teal.withOpacity(0.5), width: 2),
                                        ),
                                        child: Center(
                                          child: Container(
                                            width: 100,
                                            height: 140,
                                            decoration: BoxDecoration(
                                              border: Border.all(color: Colors.redAccent, width: 2, style: BorderStyle.solid),
                                              borderRadius: const BorderRadius.all(Radius.elliptical(100, 140)),
                                            ),
                                            child: const Align(
                                              alignment: Alignment.topCenter,
                                              child: Padding(
                                                padding: EdgeInsets.only(top: 5),
                                                child: Text('MUKHA', style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white70)),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('ID Result', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 5),
                                _processedImage != null
                                    ? Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.black, width: 1),
                                        ),
                                        child: Image.file(_processedImage!, height: 220),
                                      )
                                    : Container(
                                        height: 220,
                                        color: Colors.grey[300],
                                        child: const Center(child: Text('I-proseso muna')),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.image),
                          label: const Text('Gallery'),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera),
                          label: const Text('Camera'),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    SwitchListTile(
                      title: const Text('Auto-Remove Background (White BG)'),
                      subtitle: const Text('Kailangan ng Remove.bg API key sa code'),
                      value: _removeBackground,
                      activeColor: Colors.teal,
                      onChanged: (bool value) {
                        setState(() {
                          _removeBackground = value;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('Piliin ang Sukat:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 5),
                    DropdownButtonFormField<String>(
                      value: _selectedSize,
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: _sizes.keys.map((String size) {
                        return DropdownMenuItem<String>(value: size, child: Text(size));
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedSize = value!),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _originalImage != null ? _processIDPhoto : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('I-proseso ang ID Larawan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                  ],
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              color: Colors.grey[100],
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Developed by:',
                    style: TextStyle(fontSize: 11, color: Colors.grey, letterSpacing: 1.2),
                  ),
                  Text(
                    'Renante Fullo',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
