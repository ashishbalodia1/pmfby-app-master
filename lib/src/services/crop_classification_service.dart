import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Unified result class for crop and disease classification
class CropHealthAnalysisResult {
  // Crop information
  final String cropType;
  final String growthStage;
  final double cropConfidence;
  
  // Health information
  final String healthStatus;
  final String primaryIssue;
  final String diseaseCategory;
  final String severity;
  final String affectedAreaPercentage;
  final List<String> symptoms;
  final String affectedLocation;
  
  // Treatment and solutions
  final String treatmentRecommendations;
  final List<String> solutions;
  
  // Metadata
  final int totalImages;
  final int agreementCount;
  final String notes;
  final String rawResponse;

  CropHealthAnalysisResult({
    required this.cropType,
    required this.growthStage,
    required this.cropConfidence,
    required this.healthStatus,
    required this.primaryIssue,
    required this.diseaseCategory,
    required this.severity,
    required this.affectedAreaPercentage,
    required this.symptoms,
    required this.affectedLocation,
    required this.treatmentRecommendations,
    required this.solutions,
    required this.totalImages,
    required this.agreementCount,
    required this.notes,
    required this.rawResponse,
  });

  String get cropConfidencePercentage => '${(cropConfidence * 100).toStringAsFixed(1)}%';
  double get overallConfidence => agreementCount / totalImages;
  String get overallConfidencePercentage => '${(overallConfidence * 100).toStringAsFixed(1)}%';
  bool get isHealthy => healthStatus.toLowerCase().contains('healthy');
  bool get hasDisease => !isHealthy && primaryIssue.toLowerCase() != 'none';
}

/// Service for unified crop and health classification using Gemini API
class CropClassificationService {
  // Get your API key from: https://makersuite.google.com/app/apikey
  // For production, store this securely (environment variables, secure storage)
  static const String geminiApiKey = 'AIzaSyDsHpiXf-yyrrDTjQb5NWcxJaKoRPxm2gE';
  static const String geminiApiUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';
  
  /// Analyze crop and health status for multiple images and return unified result
  Future<CropHealthAnalysisResult> analyzeCropHealth({
    required List<File> images,
    String? knownCropType,
  }) async {
    try {
      if (images.isEmpty) {
        throw Exception('No images provided');
      }

      List<Map<String, dynamic>> individualResults = [];
      for (int i = 0; i < images.length; i++) {
        debugPrint('Analyzing image ${i + 1}/${images.length}...');
        final result = await _analyzeSingleImage(
          images[i],
          knownCropType: knownCropType,
        );
        individualResults.add(result);
      }

      return _aggregateResults(individualResults);
    } catch (e) {
      debugPrint('Crop health analysis error: $e');
      rethrow;
    }
  }
  
  /// Analyze a single image for crop type and health status
  Future<Map<String, dynamic>> _analyzeSingleImage(
    File imageFile, {
    String? knownCropType,
  }) async {
    try {
      // Read and encode image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      
      // Structured prompt with fixed JSON response format
      String prompt = '''You are an agricultural AI expert. Analyze this crop image and return ONLY valid JSON in this exact format:

{
  "crop_type": "single crop name (wheat|rice|corn|soybean|cotton|etc)",
  "growth_stage": "seedling|vegetative|flowering|mature|harvest_ready|unknown",
  "crop_confidence": 0.95,
  "health_status": "Healthy|Diseased|Stressed|Unknown",
  "primary_issue": "specific disease name or None",
  "disease_category": "fungal|bacterial|viral|pest|nutrient_deficiency|environmental_stress|healthy|unknown",
  "severity": "None|Mild|Moderate|Severe|Critical",
  "affected_area_pct": "0-100 or N/A",
  "symptoms": ["list 2-4 visible symptoms"],
  "affected_location": "leaves|stems|roots|fruits|flowers|multiple|whole_plant|unknown",
  "treatment_recommendations": "concise treatment paragraph (2-3 sentences)",
  "solutions": ["actionable step 1", "actionable step 2", "actionable step 3"],
  "notes": "any additional important observation"
}

Rules:
- Return ONLY valid JSON, no markdown, no extra text
- Provide exactly one crop type (most prominent)
- Be specific with disease names
- Solutions must be practical for farmers
- Use N/A for fields that don't apply''';

      if (knownCropType != null && knownCropType.isNotEmpty) {
        prompt = 'Expected Crop: $knownCropType\n\n$prompt';
      }

      // Prepare API request
      final uri = Uri.parse('$geminiApiUrl?key=$geminiApiKey');
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              {
                'inline_data': {
                  'mime_type': 'image/jpeg',
                  'data': base64Image,
                }
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.2,
          'topK': 32,
          'topP': 1,
          'maxOutputTokens': 2048,
          'stopSequences': [],
        }
      };

      // Send request
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Check if response was truncated
        if (data['candidates'] == null || data['candidates'].isEmpty) {
          throw Exception('No candidates in response');
        }
        
        final candidate = data['candidates'][0];
        final text = candidate['content']['parts'][0]['text'];
        
        // Check finish reason for truncation
        final finishReason = candidate['finishReason'];
        if (finishReason == 'MAX_TOKENS' || finishReason == 'RECITATION') {
          debugPrint('⚠️ Response truncated: $finishReason');
        }

        // Clean and parse JSON response
        String cleanedText = text.trim();
        
        // Remove markdown code blocks if present
        if (cleanedText.startsWith('```json')) {
          cleanedText = cleanedText.substring(7);
        } else if (cleanedText.startsWith('```')) {
          cleanedText = cleanedText.substring(3);
        }
        if (cleanedText.endsWith('```')) {
          cleanedText = cleanedText.substring(0, cleanedText.length - 3);
        }
        cleanedText = cleanedText.trim();
        
        // Try to fix incomplete JSON by adding closing braces
        if (!cleanedText.endsWith('}')) {
          debugPrint('⚠️ Incomplete JSON detected, attempting to fix...');
          // Count opening and closing braces
          int openBraces = '{'.allMatches(cleanedText).length;
          int closeBraces = '}'.allMatches(cleanedText).length;
          
          // Add missing closing braces
          for (int i = 0; i < (openBraces - closeBraces); i++) {
            cleanedText += '}';
          }
        }

        // Parse JSON
        Map<String, dynamic> parsed;
        try {
          final j = json.decode(cleanedText);
          if (j is Map) {
            parsed = Map<String, dynamic>.from(j);
          } else {
            throw Exception('Response is not a JSON object');
          }
        } catch (e) {
          debugPrint('❌ JSON parse error: $e\nCleaned text: $cleanedText');
          // Fallback: create minimal valid structure
          parsed = _createFallbackResult(text);
        }

        // Ensure all required fields exist with defaults
        parsed = _normalizeResult(parsed);
        parsed['raw_response'] = text;

        return {
          'success': true,
          'data': parsed,
        };
      } else {
        throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('Single image analysis error: $e');
      return {
        'success': false,
        'error': e.toString(),
        'data': _createErrorResult(),
      };
    }
  }
  
  /// Create a fallback result when JSON parsing fails
  Map<String, dynamic> _createFallbackResult(String text) {
    return {
      'crop_type': 'Unknown',
      'growth_stage': 'unknown',
      'crop_confidence': 0.5,
      'health_status': 'Unknown',
      'primary_issue': 'Unable to analyze',
      'disease_category': 'unknown',
      'severity': 'Unknown',
      'affected_area_pct': 'N/A',
      'symptoms': ['Analysis failed - please try again'],
      'affected_location': 'unknown',
      'treatment_recommendations': 'Unable to provide recommendations. Please consult an agricultural expert.',
      'solutions': ['Retake image in better lighting', 'Ensure crop is clearly visible', 'Consult local agricultural extension'],
      'notes': 'Analysis incomplete - raw response could not be parsed',
    };
  }

  /// Create error result structure
  Map<String, dynamic> _createErrorResult() {
    return {
      'crop_type': 'Error',
      'growth_stage': 'unknown',
      'crop_confidence': 0.0,
      'health_status': 'Error',
      'primary_issue': 'Analysis failed',
      'disease_category': 'unknown',
      'severity': 'Unknown',
      'affected_area_pct': 'N/A',
      'symptoms': ['System error occurred'],
      'affected_location': 'unknown',
      'treatment_recommendations': 'Unable to complete analysis. Please check your connection and try again.',
      'solutions': ['Check internet connection', 'Retry analysis', 'Contact support if problem persists'],
      'notes': 'System error during analysis',
    };
  }

  /// Normalize result to ensure all required fields exist
  Map<String, dynamic> _normalizeResult(Map<String, dynamic> result) {
    // Set defaults for missing fields
    result['crop_type'] ??= 'Unknown';
    result['growth_stage'] ??= 'unknown';
    result['crop_confidence'] ??= 0.7;
    result['health_status'] ??= 'Unknown';
    result['primary_issue'] ??= 'None';
    result['disease_category'] ??= 'unknown';
    result['severity'] ??= 'None';
    result['affected_area_pct'] ??= 'N/A';
    result['symptoms'] ??= [];
    result['affected_location'] ??= 'unknown';
    result['treatment_recommendations'] ??= 'No specific recommendations available.';
    result['solutions'] ??= [];
    result['notes'] ??= '';

    // Ensure types are correct
    if (result['symptoms'] is! List) {
      result['symptoms'] = [result['symptoms'].toString()];
    }
    if (result['solutions'] is! List) {
      result['solutions'] = [result['solutions'].toString()];
    }
    
    // Convert confidence to double
    if (result['crop_confidence'] is int) {
      result['crop_confidence'] = (result['crop_confidence'] as int).toDouble();
    } else if (result['crop_confidence'] is String) {
      result['crop_confidence'] = double.tryParse(result['crop_confidence']) ?? 0.7;
    }

    // Ensure symptoms and solutions are List<String>
    result['symptoms'] = (result['symptoms'] as List).map((e) => e.toString()).toList();
    result['solutions'] = (result['solutions'] as List).map((e) => e.toString()).toList();

    return result;
  }
  
  /// Aggregate multiple image analysis results into a unified result
  CropHealthAnalysisResult _aggregateResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      throw Exception('No results to aggregate');
    }

    final totalImages = results.length;
    int successCount = 0;
    
    // Collect data from successful analyses
    Map<String, int> cropCounts = {};
    Map<String, int> healthCounts = {};
    Map<String, int> diseaseCounts = {};
    List<double> confidences = [];
    List<String> allSymptoms = [];
    List<String> allSolutions = [];
    List<String> allTreatments = [];
    List<String> rawResponses = [];
    String mostCommonGrowthStage = 'unknown';
    String mostCommonCategory = 'unknown';
    String mostCommonSeverity = 'None';
    String mostCommonLocation = 'unknown';
    String mostCommonAffectedArea = 'N/A';
    String notes = '';

    for (var result in results) {
      if (result['success'] == true && result['data'] != null) {
        successCount++;
        final data = result['data'] as Map<String, dynamic>;
        
        // Count occurrences
        final crop = data['crop_type'] as String;
        cropCounts[crop] = (cropCounts[crop] ?? 0) + 1;
        
        final health = data['health_status'] as String;
        healthCounts[health] = (healthCounts[health] ?? 0) + 1;
        
        final disease = data['primary_issue'] as String;
        diseaseCounts[disease] = (diseaseCounts[disease] ?? 0) + 1;
        
        // Collect confidence scores
        if (data['crop_confidence'] is num) {
          confidences.add((data['crop_confidence'] as num).toDouble());
        }
        
        // Collect symptoms and solutions
        if (data['symptoms'] is List) {
          allSymptoms.addAll((data['symptoms'] as List).map((e) => e.toString()));
        }
        if (data['solutions'] is List) {
          allSolutions.addAll((data['solutions'] as List).map((e) => e.toString()));
        }
        
        // Collect treatment recommendations
        if (data['treatment_recommendations'] is String) {
          allTreatments.add(data['treatment_recommendations'] as String);
        }
        
        // Store other fields (use first occurrence or most common)
        if (mostCommonGrowthStage == 'unknown') {
          mostCommonGrowthStage = data['growth_stage'] as String? ?? 'unknown';
        }
        if (mostCommonCategory == 'unknown') {
          mostCommonCategory = data['disease_category'] as String? ?? 'unknown';
        }
        if (mostCommonSeverity == 'None') {
          mostCommonSeverity = data['severity'] as String? ?? 'None';
        }
        if (mostCommonLocation == 'unknown') {
          mostCommonLocation = data['affected_location'] as String? ?? 'unknown';
        }
        if (mostCommonAffectedArea == 'N/A') {
          mostCommonAffectedArea = data['affected_area_pct'] as String? ?? 'N/A';
        }
        
        // Collect raw responses
        if (data['raw_response'] is String) {
          rawResponses.add(data['raw_response'] as String);
        }
      }
    }

    // Determine most common values
    String finalCropType = _getMostCommon(cropCounts, 'Unknown');
    int cropAgreement = cropCounts[finalCropType] ?? 0;
    
    String finalHealthStatus = _getMostCommon(healthCounts, 'Unknown');
    int healthAgreement = healthCounts[finalHealthStatus] ?? 0;
    
    String finalDisease = _getMostCommon(diseaseCounts, 'None');
    
    // Calculate average confidence
    double avgConfidence = confidences.isNotEmpty
        ? confidences.reduce((a, b) => a + b) / confidences.length
        : 0.5;
    
    // Deduplicate and combine
    final uniqueSymptoms = allSymptoms.toSet().toList();
    final uniqueSolutions = allSolutions.toSet().toList();
    final combinedTreatment = allTreatments.isNotEmpty
        ? allTreatments.join(' ') 
        : 'No specific treatment recommendations available.';
    
    // Generate notes
    if (totalImages > 1) {
      notes = '$healthAgreement of $totalImages images showed $finalHealthStatus status. ';
      if (cropAgreement < totalImages) {
        notes += 'Some variation in crop identification detected. ';
      }
    }

    // Combine raw responses
    final combinedRawResponse = rawResponses.isNotEmpty
        ? rawResponses.join('\n\n--- Image ${rawResponses.indexOf(rawResponses.last) + 1} ---\n\n')
        : 'No response data available';

    return CropHealthAnalysisResult(
      cropType: finalCropType,
      growthStage: mostCommonGrowthStage,
      cropConfidence: avgConfidence,
      healthStatus: finalHealthStatus,
      primaryIssue: finalDisease,
      diseaseCategory: mostCommonCategory,
      severity: mostCommonSeverity,
      affectedAreaPercentage: mostCommonAffectedArea,
      symptoms: uniqueSymptoms,
      affectedLocation: mostCommonLocation,
      treatmentRecommendations: combinedTreatment,
      solutions: uniqueSolutions,
      totalImages: totalImages,
      agreementCount: healthAgreement,
      notes: notes.trim(),
      rawResponse: combinedRawResponse,
    );
  }

  /// Helper to find most common value in a count map
  String _getMostCommon(Map<String, int> counts, String defaultValue) {
    if (counts.isEmpty) return defaultValue;
    
    String mostCommon = defaultValue;
    int maxCount = 0;
    
    counts.forEach((key, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = key;
      }
    });
    
    return mostCommon;
  }
}
