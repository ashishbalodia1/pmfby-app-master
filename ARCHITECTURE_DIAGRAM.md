# Crop Classification Architecture

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         PMFBY Mobile App                         │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Dashboard Screen                           │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  Quick Actions Grid                          │      │    │
│  │  │  [File Claim] [My Claims] [Schemes]         │      │    │
│  │  │  [Upload Status] [Crop Loss] [Calculator]   │      │    │
│  │  │  [Help Center] [🟣 Crop Classification]     │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │     Crop Classification Screen                         │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  Connection Status Card                      │      │    │
│  │  │  [🟢 Online / 🟠 Offline]                   │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  Image Selection                             │      │    │
│  │  │  [Pick from Gallery] [Capture with Camera]  │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  Selected Images Grid (3x3)                  │      │    │
│  │  │  [img1] [img2] [img3] [img4] [img5] ...     │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  │  ┌──────────────────────────────────────────────┐      │    │
│  │  │  [Analyze Crops Button]                      │      │    │
│  │  └──────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │     Connectivity Service                               │    │
│  │  • Check internet status                               │    │
│  │  • Listen to connectivity changes                      │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                    ┌─────────┴─────────┐                        │
│                    │                   │                        │
│                 Online              Offline                     │
│                    │                   │                        │
│                    ▼                   ▼                        │
│  ┌──────────────────────────┐  ┌──────────────────────┐       │
│  │ CropClassificationService│  │OfflineCropClassService│      │
│  │ (Vision API Integration) │  │ (TFLite Wrapper)      │      │
│  │ • Batch processing       │  │ • Local inference     │      │
│  │ • Result averaging       │  │ • 11 classes only     │      │
│  │ • HTTP requests          │  │ • Fast processing     │      │
│  └──────────────────────────┘  └──────────────────────┘       │
│                    │                   │                        │
└────────────────────┼───────────────────┼────────────────────────┘
                     │                   │
                     ▼                   ▼
    ┌────────────────────────┐  ┌──────────────────────┐
    │  Vision API Server     │  │  TFLite Model        │
    │  (Python/Flask)        │  │  (On-device)         │
    │                        │  │                      │
    │  ┌──────────────────┐  │  │  mobilenet_best.     │
    │  │ Gemini VLM       │  │  │  tflite              │
    │  │ (Google AI)      │  │  │  (~12-15 MB)         │
    │  └──────────────────┘  │  │                      │
    │                        │  │  class_names.json    │
    │  Endpoints:            │  │  (11 classes)        │
    │  /api/batch/crop       │  │                      │
    │  /api/batch/disease    │  └──────────────────────┘
    └────────────────────────┘
```

## Data Flow

### Online Mode (Batch Processing)

```
[User] → Selects 5 images
         ↓
[CropClassificationScreen] → Validates images
         ↓
[CropClassificationService] → Creates batch request
         ↓
[Vision API Server] → Processes each image with Gemini
         ↓
[Image 1] → {"crop": "Rice", "confidence": 0.95}
[Image 2] → {"crop": "Rice", "confidence": 0.92}
[Image 3] → {"crop": "Rice", "confidence": 0.98}
[Image 4] → {"crop": "Rice", "confidence": 0.94}
[Image 5] → {"crop": "Rice", "confidence": 0.96}
         ↓
[Service] → Calculates average
         ↓
{
  "cropType": "Rice",
  "confidence": 0.95,  // average
  "agreementCount": 5,  // all agreed
  "totalImages": 5
}
         ↓
[Screen] → Displays results with 95% confidence
```

### Offline Mode (Batch Processing)

```
[User] → Selects 3 images (Wheat crop)
         ↓
[CropClassificationScreen] → Validates images
         ↓
[OfflineCropClassificationService] → Loads TFLite model
         ↓
[TFLite Interpreter] → Processes each image
         ↓
[Image 1] → [0.1, 0.05, 0.02, ..., 0.85, 0.03]  // Wheat Healthy: 0.85
[Image 2] → [0.08, 0.03, 0.01, ..., 0.90, 0.02] // Wheat Healthy: 0.90
[Image 3] → [0.12, 0.06, 0.03, ..., 0.88, 0.04] // Wheat Healthy: 0.88
         ↓
[Service] → Averages predictions across all images
         ↓
{
  "topClass": "Wheat - Healthy",
  "confidence": 0.88,  // averaged
  "top3Predictions": [
    {"class": "Wheat - Healthy", "confidence": 0.88},
    {"class": "Wheat - Brown Rust", "confidence": 0.08},
    {"class": "Rice - Healthy", "confidence": 0.03}
  ],
  "totalImages": 3
}
         ↓
[Screen] → Displays results with progress bars
```

## Component Responsibilities

### UI Layer
- **CropClassificationScreen**: Main UI, image selection, results display
- **Dashboard**: Navigation entry point

### Service Layer
- **CropClassificationService**: Online API communication
- **OfflineCropClassificationService**: Local TFLite inference
- **ConnectivityService**: Network status monitoring

### Data Layer
- **Vision API**: Cloud-based AI analysis
- **TFLite Model**: On-device inference
- **Assets**: Model files and class labels

## State Management

```
CropClassificationScreen State:
├── _selectedImages: List<File>
├── _isProcessing: bool
├── _result: dynamic (CropClassificationResult | DiseaseClassificationResult | OfflineClassificationResult)
├── _isOnline: bool
└── _classificationMode: String ('crop' | 'disease')

ConnectivityService State:
└── isConnected: bool (reactive)
```

## API Endpoints

### Vision API (Online)

1. **Batch Crop Classification**
   - Endpoint: `POST /api/batch/crop`
   - Input: Multiple image files
   - Output: Array of crop predictions

2. **Batch Disease Classification**
   - Endpoint: `POST /api/batch/disease`
   - Input: Multiple image files
   - Output: Array of disease analyses

### TFLite Model (Offline)

- **Input**: Float32 tensor [1, 224, 224, 3] (normalized 0-1)
- **Output**: Float32 tensor [1, 11] (class probabilities)
- **Classes**: 11 (Corn, Rice, Wheat diseases)

## File Organization

```
pmfby-app-master/
├── lib/
│   └── src/
│       ├── features/
│       │   ├── crop_classification/
│       │   │   └── crop_classification_screen.dart
│       │   └── dashboard/
│       │       └── presentation/
│       │           └── dashboard_screen.dart
│       ├── services/
│       │   ├── crop_classification_service.dart
│       │   ├── offline_crop_classification_service.dart
│       │   └── connectivity_service.dart
│       └── localization/
│           └── app_localizations.dart
├── assets/
│   └── models/
│       ├── mobilenet_best.tflite (12-15 MB)
│       └── class_names.json
├── classification/
│   └── models/
│       └── mobilenet/
│           └── mobilenet_best.h5 (25 MB)
├── vision/
│   ├── app.py
│   ├── crop_classifier.py
│   ├── disease_classifier.py
│   └── vlm_wrapper.py
└── Documentation files...
```

## Performance Metrics

### Online Mode
- **Latency**: 2-5 seconds per image
- **Batch (5 images)**: 10-25 seconds
- **Accuracy**: High (90-95%+)
- **Classes**: Unlimited

### Offline Mode
- **Latency**: 100-300ms per image
- **Batch (5 images)**: 500-1500ms
- **Accuracy**: Good (85-90%)
- **Classes**: 11 only

## Security Considerations

1. **API Key Protection**: Gemini API key stored server-side
2. **Image Privacy**: Images not permanently stored
3. **Local Processing**: Offline mode keeps data on device
4. **HTTPS**: Use HTTPS for production API endpoints

## Scalability

### Horizontal Scaling
- Vision API server can be load-balanced
- Multiple Flask instances behind nginx

### Caching Strategy
- Cache frequent classification results
- Store model predictions locally
- Reduce API calls for same images

---

**Legend**:
- 🟢 Green = Online mode active
- 🟠 Orange = Offline mode active
- 🟣 Purple = Crop Classification feature icon
- ✅ = Completed/Success
- ⚠️ = Warning/Limitation
