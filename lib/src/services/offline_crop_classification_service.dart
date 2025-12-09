import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service for offline crop classification using TFLite MobileNet model
/// Limited to 11 crop disease classes: 
/// Corn (Common Rust, Gray Leaf Spot, Healthy, Northern Leaf Blight)
/// Rice (Brown Spot, Healthy, Leaf Blast, Neck Blast)
/// Wheat (Brown Rust, Healthy, Yellow Rust)
class OfflineCropClassificationService {
  static const String modelPath = 'assets/models/mobilenet_best.tflite';
  static const String labelsPath = 'assets/models/class_names.json';
  
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _isInitialized = false;
  
  // Supported classes (limited in offline mode)
  static const List<String> supportedClasses = [
    'Corn___Common_Rust',
    'Corn___Gray_Leaf_Spot',
    'Corn___Healthy',
    'Corn___Northern_Leaf_Blight',
    'Rice___Brown_Spot',
    'Rice___Healthy',
    'Rice___Leaf_Blast',
    'Rice___Neck_Blast',
    'Wheat___Brown_Rust',
    'Wheat___Healthy',
    'Wheat___Yellow_Rust',
  ];
  
  /// Initialize the TFLite model
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load model
      _interpreter = await Interpreter.fromAsset(modelPath);
      debugPrint('✓ TFLite model loaded successfully');
      
      // Load labels, but enforce the known 11-class set to match model output
      _labels = supportedClasses;
      try {
        final labelsData = await rootBundle.loadString(labelsPath);
        final loaded = labelsData.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (loaded.length == supportedClasses.length) {
          _labels = loaded;
        }
      } catch (_) {
        // Fallback to bundled supportedClasses
      }
      debugPrint('✓ Labels loaded: ${_labels!.length} classes');
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('✗ Failed to initialize TFLite model: $e');
      rethrow;
    }
  }
  
  /// Classify multiple crop images in batch and return averaged results
  Future<OfflineClassificationResult> classifyBatch(List<File> images) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (images.isEmpty) {
      throw Exception('No images provided');
    }
    
    // Store all predictions
    Map<String, double> aggregatedScores = {};
    List<Map<String, double>> allPredictions = [];
    
    // Process each image
    for (final imageFile in images) {
      try {
        final predictions = await _classifySingleImage(imageFile);
        allPredictions.add(predictions);
        
        // Aggregate scores
        predictions.forEach((label, score) {
          aggregatedScores[label] = (aggregatedScores[label] ?? 0.0) + score;
        });
      } catch (e) {
        debugPrint('Error classifying image: $e');
        // Continue with other images
      }
    }
    
    if (allPredictions.isEmpty) {
      throw Exception('Failed to classify any images');
    }
    
    // Calculate average scores
    Map<String, double> averageScores = {};
    aggregatedScores.forEach((label, totalScore) {
      averageScores[label] = totalScore / allPredictions.length;
    });
    
    // Get top 3 predictions
    final sortedEntries = averageScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top3 = sortedEntries.take(3).toList();
    
    return OfflineClassificationResult(
      topClass: _formatClassName(top3[0].key),
      confidence: top3[0].value,
      top3Predictions: top3.map((e) => {
        'class': _formatClassName(e.key),
        'confidence': e.value,
      }).toList(),
      totalImages: images.length,
    );
  }
  
  /// Classify a single image
  Future<Map<String, double>> _classifySingleImage(File imageFile) async {
    // Read and preprocess image
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) {
      throw Exception('Failed to decode image');
    }
    
    // Resize to 224x224
    final resized = img.copyResize(image, width: 224, height: 224);
    
    // Convert to Float32List normalized [0, 1]
    final input = _imageToByteListFloat32(resized);
    
    // Prepare output buffer
    final output = List.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);
    
    // Run inference
    _interpreter!.run(input, output);
    
    // Get predictions
    Map<String, double> predictions = {};
    for (int i = 0; i < _labels!.length; i++) {
      predictions[_labels![i]] = output[0][i];
    }
    
    return predictions;
  }
  
  /// Convert image to 4D list normalized between 0 and 1 for TFLite input [1,224,224,3]
  List<List<List<List<double>>>> _imageToByteListFloat32(img.Image image) {
    final result = List.generate(
      1,
      (_) => List.generate(
        224,
        (_) => List.generate(
          224,
          (_) => List.generate(3, (_) => 0.0),
        ),
      ),
    );

    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        final pixel = image.getPixel(x, y);
        result[0][y][x][0] = pixel.r / 255.0;
        result[0][y][x][1] = pixel.g / 255.0;
        result[0][y][x][2] = pixel.b / 255.0;
      }
    }

    return result;
  }
  
  /// Format class name for display (convert from Crop___Disease format)
  String _formatClassName(String className) {
    return className
        .replaceAll('___', ' - ')
        .replaceAll('_', ' ');
  }
  
  /// Check if service is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get list of supported classes
  List<String> get supportedClassesList => supportedClasses;
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}

/// Result model for offline classification
class OfflineClassificationResult {
  final String topClass;
  final double confidence;
  final List<Map<String, dynamic>> top3Predictions;
  final int totalImages;
  
  OfflineClassificationResult({
    required this.topClass,
    required this.confidence,
    required this.top3Predictions,
    required this.totalImages,
  });
  
  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}
