# 🌾 Crop Classification - Quick Setup Guide

## Prerequisites
- Flutter SDK installed
- Python 3.x installed
- Android SDK (for Android deployment)

## 5-Minute Setup

### Step 1: Install Flutter Dependencies
```bash
cd /path/to/pmfby-app-master
flutter pub get
```

### Step 2: Setup Offline Model (Optional but Recommended)
```bash
# Install Python dependencies
pip install tensorflow numpy

# Convert model
python3 convert_model_to_tflite.py
```
✅ Creates `assets/models/mobilenet_best.tflite` (~12-15 MB)

### Step 3: Configure Vision API (For Online Mode)
```bash
# Start the Vision API server
cd vision
export GOOGLE_API_KEY='your-gemini-api-key-here'
pip install -r requirements.txt
python app.py
```

✅ Server runs on `http://localhost:5001`

### Step 4: Update API URL in App
Edit `lib/src/services/crop_classification_service.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:5001/api';
```

Replace `YOUR_SERVER_IP` with:
- `localhost` (for emulator on same machine)
- `10.0.2.2` (for Android emulator)
- Your computer's IP address (for physical device)

### Step 5: Build & Run
```bash
# For development/testing
flutter run

# For production APK
flutter build apk --release

# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

## 🎯 Testing the Feature

1. **Launch App** → Login with demo credentials
2. **Dashboard** → Look for "Crop Classification" button (purple icon)
3. **Test Online Mode:**
   - Ensure WiFi/Mobile Data is ON
   - Select multiple crop images
   - Tap "Analyze Crops"
   - View AI-powered results

4. **Test Offline Mode:**
   - Turn OFF internet (Airplane mode)
   - Select Corn/Rice/Wheat images
   - Tap "Analyze Crops"
   - View TFLite model results

## ⚡ Quick Commands

```bash
# Complete automated setup
./setup_crop_classification.sh

# Just model conversion
python3 convert_model_to_tflite.py

# Just Flutter dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK
flutter build apk --release
```

## 🔍 Verify Setup

### Check 1: Assets
```bash
ls assets/models/
# Should show: class_names.json, mobilenet_best.tflite (after conversion)
```

### Check 2: Dependencies
```bash
flutter pub get
# Should complete without errors
```

### Check 3: Vision API (Optional)
```bash
curl http://localhost:5001/api/health
# Should return: {"status":"healthy",...}
```

## 🎨 Feature Location in App

```
Dashboard
   └── Quick Actions Grid
         └── "Crop Classification" 🟣
               ├── Online Mode (AI-powered)
               │     ├── Crop Type Classification
               │     └── Disease Detection
               └── Offline Mode (TFLite)
                     └── Limited Classes (11)
```

## 📝 Important Files

| File | Purpose |
|------|---------|
| `lib/src/features/crop_classification/crop_classification_screen.dart` | Main UI |
| `lib/src/services/crop_classification_service.dart` | Online API |
| `lib/src/services/offline_crop_classification_service.dart` | Offline TFLite |
| `assets/models/mobilenet_best.tflite` | Offline model |
| `assets/models/class_names.json` | Class labels |

## ⚠️ Common Issues

### Issue 1: "Failed to load model"
**Solution**: Run model conversion script
```bash
python3 convert_model_to_tflite.py
```

### Issue 2: "Connection failed"
**Solution**: 
- Check Vision API server is running
- Update API URL in service file
- Verify network connectivity

### Issue 3: "Low confidence results"
**Solution**:
- Upload 3-5 images instead of 1
- Ensure good lighting in photos
- Capture from different angles

### Issue 4: Dependencies error
**Solution**:
```bash
flutter clean
flutter pub get
```

## 🌐 Supported Classes (Offline Mode)

### Corn (Maize)
- Common Rust
- Gray Leaf Spot
- Healthy
- Northern Leaf Blight

### Rice
- Brown Spot
- Healthy
- Leaf Blast
- Neck Blast

### Wheat
- Brown Rust
- Healthy
- Yellow Rust

**Total: 11 classes**

## 📚 Documentation

- **IMPLEMENTATION_SUMMARY.md** - Complete implementation details
- **CROP_CLASSIFICATION_FEATURE.md** - Full feature documentation
- **MODEL_CONVERSION.md** - Model conversion guide
- **CROP_CLASSIFICATION_HINDI.md** - Hindi quick reference

## 🚀 Ready to Go!

After completing setup:
1. ✅ Flutter dependencies installed
2. ✅ TFLite model converted (optional)
3. ✅ Vision API configured (optional)
4. ✅ API URL updated
5. ✅ App built and ready

Launch the app and test the "Crop Classification" feature!

---

**Questions?** Check the detailed documentation files or troubleshooting sections.

**Need help?** Review CROP_CLASSIFICATION_FEATURE.md for comprehensive guidance.
