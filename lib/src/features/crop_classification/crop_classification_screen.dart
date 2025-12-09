import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/crop_classification_service.dart';
import '../../services/offline_crop_classification_service.dart';
import '../../services/connectivity_service.dart';
import '../../providers/language_provider.dart';
import '../../localization/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

class CropClassificationScreen extends StatefulWidget {
  const CropClassificationScreen({super.key});

  @override
  State<CropClassificationScreen> createState() => _CropClassificationScreenState();
}

class _CropClassificationScreenState extends State<CropClassificationScreen> {
  final ImagePicker _picker = ImagePicker();
  final CropClassificationService _onlineService = CropClassificationService();
  final OfflineCropClassificationService _offlineService = OfflineCropClassificationService();
  
  List<File> _selectedImages = [];
  bool _isProcessing = false;
  dynamic _result;
  bool _isOnline = true;
  
  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _initializeOfflineService();
  }
  
  Future<void> _checkConnectivity() async {
    final connectivityService = context.read<ConnectivityService>();
    setState(() {
      _isOnline = connectivityService.isOnline;
    });
    
    // Listen to connectivity changes
    connectivityService.addListener(() {
      if (mounted) {
        setState(() {
          _isOnline = connectivityService.isOnline;
        });
      }
    });
  }
  
  Future<void> _initializeOfflineService() async {
    try {
      await _offlineService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize offline service: $e');
    }
  }
  
  @override
  void dispose() {
    _offlineService.dispose();
    super.dispose();
  }
  
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages = images.map((xFile) => File(xFile.path)).toList();
          _result = null; // Clear previous results
        });
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }
  
  Future<void> _captureImages() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
          _result = null;
        });
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    }
  }
  
  Future<void> _classifyImages() async {
    if (_selectedImages.isEmpty) {
      _showError('Please select or capture images first');
      return;
    }
    
    setState(() {
      _isProcessing = true;
      _result = null;
    });
    
    try {
      if (_isOnline) {
        // Use unified online analysis - one call for both crop and disease
        final result = await _onlineService.analyzeCropHealth(
          images: _selectedImages,
        );
        setState(() {
          _result = result;
        });
      } else {
        // Use offline TFLite model
        final result = await _offlineService.classifyBatch(_selectedImages);
        setState(() {
          _result = result;
        });
      }
    } catch (e) {
      _showError('Classification failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  void _clearImages() {
    setState(() {
      _selectedImages.clear();
      _result = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final lang = languageProvider.currentLanguage;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.get('cropClassification', 'title', lang),
          style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: const [],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            _buildConnectionStatusCard(lang),
            const SizedBox(height: 16),
            
            // Image Selection Section
            _buildImageSelectionSection(lang),
            const SizedBox(height: 16),
            
            // Selected Images Grid
            if (_selectedImages.isNotEmpty) ...[
              _buildSelectedImagesGrid(lang),
              const SizedBox(height: 16),
            ],
            
            // Classify Button
            if (_selectedImages.isNotEmpty && !_isProcessing)
              ElevatedButton.icon(
                onPressed: _classifyImages,
                icon: const Icon(Icons.analytics),
                label: Text(
                  AppStrings.get('cropClassification', 'classify_button', lang),
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            
            // Processing Indicator
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Processing images...'),
                  ],
                ),
              ),
            
            // Results Section
            if (_result != null) ...[
              const SizedBox(height: 24),
              _buildResultsSection(lang),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildConnectionStatusCard(String lang) {
    return Card(
      color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isOnline
                        ? AppStrings.get('cropClassification', 'online_mode', lang)
                        : AppStrings.get('cropClassification', 'offline_mode', lang),
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isOnline
                        ? AppStrings.get('cropClassification', 'online_desc', lang)
                        : AppStrings.get('cropClassification', 'offline_desc', lang),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSelectionSection(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppStrings.get('cropClassification', 'select_images', lang),
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: const Icon(Icons.photo_library),
                    label: Text(AppStrings.get('cropClassification', 'pick_images', lang)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _captureImages,
                    icon: const Icon(Icons.camera_alt),
                    label: Text(AppStrings.get('cropClassification', 'capture_image', lang)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectedImagesGrid(String lang) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${AppStrings.get('cropClassification', 'selected_images', lang)} (${_selectedImages.length})',
                  style: GoogleFonts.notoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearImages,
                  icon: const Icon(Icons.clear, size: 18),
                  label: Text(AppStrings.get('cropClassification', 'clear_all', lang)),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedImages.removeAt(index);
                            if (_selectedImages.isEmpty) {
                              _result = null;
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
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
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultsSection(String lang) {
    if (_result is CropHealthAnalysisResult) {
      return _buildUnifiedResults(_result as CropHealthAnalysisResult, lang);
    } else if (_result is OfflineClassificationResult) {
      return _buildOfflineResults(_result as OfflineClassificationResult, lang);
    }
    return const SizedBox.shrink();
  }
  
  Widget _buildUnifiedResults(CropHealthAnalysisResult result, String lang) {
    return Card(
      color: result.isHealthy ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header with icon
            Row(
              children: [
                Icon(
                  result.isHealthy ? Icons.check_circle : Icons.warning,
                  color: result.isHealthy ? Colors.green.shade700 : Colors.orange.shade700,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crop Health Analysis',
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${result.agreementCount}/${result.totalImages} images analyzed',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Crop Information Section
            Text(
              '🌾 Crop Information',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green.shade800,
              ),
            ),
            const SizedBox(height: 8),
            _buildResultRow('Crop Type', result.cropType),
            _buildResultRow('Growth Stage', result.growthStage),
            _buildResultRow('Identification Confidence', result.cropConfidencePercentage),
            
            const Divider(height: 24),
            
            // Health Status Section
            Text(
              '🏥 Health Status',
              style: GoogleFonts.notoSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: result.isHealthy ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
            const SizedBox(height: 8),
            _buildResultRow('Overall Health', result.healthStatus),
            _buildResultRow('Primary Issue', result.primaryIssue),
            if (result.hasDisease) ...[
              _buildResultRow('Disease Category', result.diseaseCategory),
              _buildResultRow('Severity', result.severity),
              _buildResultRow('Affected Area', result.affectedAreaPercentage),
              _buildResultRow('Affected Location', result.affectedLocation),
            ],
            _buildResultRow('Analysis Confidence', result.overallConfidencePercentage),
            
            // Symptoms
            if (result.symptoms.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '🔍 Observed Symptoms',
                style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...result.symptoms.map((symptom) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(symptom)),
                      ],
                    ),
                  )),
            ],
            
            // Treatment Recommendations
            if (result.hasDisease) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                title: Text(
                  '💊 Treatment Recommendations',
                  style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(result.treatmentRecommendations),
                  ),
                ],
              ),
            ],
            
            // Action Steps
            if (result.solutions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '✅ Recommended Actions',
                style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              ...result.solutions.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.green.shade700,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(entry.value)),
                        ],
                      ),
                    ),
                  )),
            ],
            
            // Notes
            if (result.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.notes,
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildOfflineResults(OfflineClassificationResult result, String lang) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.offline_bolt, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('cropClassification', 'offline_results', lang),
                        style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        '${result.totalImages} ${AppStrings.get('cropClassification', 'images_analyzed', lang)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppStrings.get('cropClassification', 'limited_classes_notice', lang),
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildResultRow(
              AppStrings.get('cropClassification', 'predicted_class', lang),
              result.topClass,
            ),
            _buildResultRow(
              AppStrings.get('cropClassification', 'confidence', lang),
              result.confidencePercentage,
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.get('cropClassification', 'top_predictions', lang),
              style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...result.top3Predictions.map((pred) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(pred['class']),
                    ),
                    Expanded(
                      flex: 2,
                      child: LinearProgressIndicator(
                        value: pred['confidence'],
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(Colors.blue.shade700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(pred['confidence'] * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
  
  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
