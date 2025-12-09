# Crop Classification Feature Integration

## Overview

This document describes the newly integrated crop classification and health analysis feature in the PMFBY mobile app. The feature intelligently switches between online AI-powered analysis and offline TFLite model-based classification based on internet connectivity.

## Features Implemented

### 1. **Dual Mode Classification**
- **Online Mode (AI-Powered)**: Uses the Vision API (Gemini) for comprehensive crop type and disease detection
  - Supports all crop types
  - Provides detailed health assessment
  - Treatment recommendations
  - Growth stage analysis
  
- **Offline Mode (Limited)**: Uses TFLite MobileNet model for basic classification
  - Supports 11 classes: Corn, Rice, and Wheat diseases
  - Works without internet connectivity
  - Lightweight model (~12-15 MB)

### 2. **Batch Processing**
- Upload multiple images of the same crop at once
- Processes all images and calculates averaged results
- Shows agreement percentage across images
- More accurate predictions through ensemble analysis

### 3. **Smart Classification Modes**
- **Crop Type Classification**: Identifies the type of crop
- **Disease Detection**: Analyzes crop health, detects diseases, and suggests treatments

### 4. **Multi-language Support**
All UI text is fully localized in:
- English, Hindi, Punjabi, Marathi, Gujarati, Tamil, Telugu, Kannada, Malayalam, Bengali, and more

## Files Created/Modified

### New Files
1. **`lib/src/services/crop_classification_service.dart`**
   - Online API service for crop and disease classification
   - Batch processing support
   - Handles Vision API integration

2. **`lib/src/services/offline_crop_classification_service.dart`**
   - Offline TFLite inference service
   - MobileNet model wrapper
   - Limited to 11 disease classes

3. **`lib/src/features/crop_classification/crop_classification_screen.dart`**
   - Complete UI for crop classification
   - Image selection and capture
   - Results display
   - Connectivity status indicator

4. **`convert_model_to_tflite.py`**
   - Script to convert Keras H5 model to TFLite format
   - Optimizes for mobile deployment

5. **`MODEL_CONVERSION.md`**
   - Detailed guide for model conversion
   - Troubleshooting steps

### Modified Files
1. **`lib/main.dart`**
   - Added `/crop-classification` route
   - Imported crop classification screen

2. **`lib/src/features/dashboard/presentation/dashboard_screen.dart`**
   - Added "Crop Classification" button in quick actions grid
   - New icon and navigation handler

3. **`lib/src/localization/app_localizations.dart`**
   - Added `cropClassification` section with all UI strings
   - Multi-language support for all labels

4. **`pubspec.yaml`**
   - Added `tflite_flutter: ^0.11.0` dependency
   - Added `assets/models/` to assets section

5. **`assets/models/`**
   - Added `class_names.json` (11 crop disease classes)
   - Ready for `mobilenet_best.tflite` model file

## API Configuration

### Vision API Setup
Update the base URL in `crop_classification_service.dart`:

```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5001/api';
```

### Starting the Vision API Server

```bash
cd vision
export GOOGLE_API_KEY='your-gemini-api-key'
python app.py
```

The server will run on `http://localhost:5001`

## Model Conversion

To enable offline mode, convert the MobileNet model:

```bash
pip install tensorflow numpy
python3 convert_model_to_tflite.py
```

This creates `assets/models/mobilenet_best.tflite`

See **MODEL_CONVERSION.md** for detailed instructions.

## Usage Flow

### For Farmers:

1. **Open App** → Navigate to Dashboard
2. **Tap "Crop Classification"** button (purple icon with insights symbol)
3. **Check Connection Status**:
   - Green = Online (AI-powered, all crops supported)
   - Orange = Offline (Limited to Corn, Rice, Wheat)
4. **Select Images**:
   - Tap "Pick from Gallery" for multiple images
   - Tap "Capture" to take photos with camera
5. **Choose Mode** (Online only):
   - Crop Type Classification
   - Disease Detection
6. **Analyze**: Tap "Analyze Crops" button
7. **View Results**:
   - Crop type / Health status
   - Confidence percentage
   - Agreement across images
   - Full description and recommendations

### Batch Processing Benefits:
- Upload 3-5 images of the same crop from different angles
- System analyzes all and provides averaged result
- Higher confidence through consensus
- More accurate disease detection

## Important Notes

### Offline Mode Limitations:
⚠️ **Limited to 11 classes only:**
- Corn: Common Rust, Gray Leaf Spot, Healthy, Northern Leaf Blight
- Rice: Brown Spot, Healthy, Leaf Blast, Neck Blast
- Wheat: Brown Rust, Healthy, Yellow Rust

The app displays a notice when in offline mode to inform users about these limitations.

### Online Mode Requirements:
- Active internet connection
- Vision API server running
- Gemini API key configured

## Dependencies

New dependencies added:
```yaml
tflite_flutter: ^0.11.0  # For offline TFLite inference
```

Existing dependencies used:
```yaml
image_picker: ^1.1.2     # Image selection
connectivity_plus: ^6.1.0 # Connectivity detection
http: ^1.2.0             # API calls
image: ^4.3.0            # Image processing
```

## Architecture

```
┌─────────────────────────────────────┐
│  Crop Classification Screen         │
│  (User Interface)                   │
└──────────────┬──────────────────────┘
               │
               ├─── Checks Connectivity
               │
       ┌───────┴───────┐
       │               │
   Online          Offline
       │               │
       ▼               ▼
┌──────────────┐  ┌─────────────────┐
│ Vision API   │  │ TFLite Service  │
│ (Gemini)     │  │ (MobileNet)     │
└──────────────┘  └─────────────────┘
       │               │
       ▼               ▼
┌──────────────────────────────────┐
│  Result Processing & Display     │
│  (Batch averaging, UI update)    │
└──────────────────────────────────┘
```

## Testing

### Test Online Mode:
1. Ensure internet connectivity
2. Start Vision API server
3. Select multiple crop images
4. Verify AI-powered analysis results

### Test Offline Mode:
1. Disable internet/airplane mode
2. Ensure TFLite model is in assets
3. Select images of Corn/Rice/Wheat
4. Verify local inference works

### Test Batch Processing:
1. Select 3-5 images of same crop
2. Analyze and check agreement percentage
3. Verify averaged results make sense

## Troubleshooting

**Issue**: "No internet connection" but WiFi is on
- Check `ConnectivityService` is properly initialized
- Verify actual internet access (not just WiFi connection)

**Issue**: Offline mode not working
- Ensure `mobilenet_best.tflite` exists in `assets/models/`
- Run model conversion script
- Check `pubspec.yaml` includes models in assets

**Issue**: Vision API connection failed
- Verify API server is running
- Check firewall/network settings
- Update `baseUrl` in service file

**Issue**: Low confidence in results
- Use more images (3-5 recommended)
- Ensure images are clear and well-lit
- Capture from different angles

## Future Enhancements

- [ ] Add more crop types to offline model
- [ ] Implement caching for repeated classifications
- [ ] Add history of past classifications
- [ ] Export results as PDF report
- [ ] Real-time camera classification
- [ ] Integration with crop insurance claims

## Credits

- **Online Classification**: Google Gemini Vision API
- **Offline Model**: MobileNet V2 trained on crop disease dataset
- **UI Framework**: Flutter with Material Design
- **Localization**: 15+ Indian languages supported

---

**Note**: Make sure to run `flutter pub get` after adding the changes, and convert the model to TFLite format before testing offline mode.
