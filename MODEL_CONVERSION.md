# Model Conversion Guide

## Converting MobileNet Model to TFLite

The offline classification feature requires the MobileNet model to be converted to TFLite format for use in the Flutter mobile app.

### Prerequisites

```bash
pip install tensorflow numpy
```

### Conversion Steps

1. **Run the conversion script:**
   ```bash
   python3 convert_model_to_tflite.py
   ```

   This will:
   - Load the Keras H5 model from `classification/models/mobilenet/mobilenet_best.h5`
   - Convert it to TFLite format with float16 optimization
   - Save the TFLite model to `assets/models/mobilenet_best.tflite`
   - Copy the class names JSON file

2. **Verify the output:**
   ```bash
   ls -lh assets/models/
   ```

   You should see:
   - `mobilenet_best.tflite` (approximately 12-15 MB)
   - `class_names.json`

### Alternative: Manual Conversion

If you need to convert the model manually:

```python
import tensorflow as tf

# Load model
model = tf.keras.models.load_model('classification/models/mobilenet/mobilenet_best.h5')

# Convert
converter = tf.lite.TFLiteConverter.from_keras_model(model)
converter.optimizations = [tf.lite.Optimize.DEFAULT]
converter.target_spec.supported_types = [tf.float16]
tflite_model = converter.convert()

# Save
with open('assets/models/mobilenet_best.tflite', 'wb') as f:
    f.write(tflite_model)
```

### Important Notes

- The class_names.json file has already been copied to `assets/models/`
- The TFLite model is required for **offline mode only**
- Online mode uses the Vision API (no model conversion needed)
- The model supports only 11 classes: Corn, Rice, and Wheat diseases

### Troubleshooting

**Error: "No module named 'tensorflow'"**
```bash
pip install tensorflow
```

**Model too large**
- The optimized TFLite model should be around 12-15 MB
- If larger, ensure float16 quantization is enabled

**Runtime errors in Flutter**
- Verify the model file exists in `assets/models/`
- Check that `pubspec.yaml` includes the models folder in assets
- Ensure `tflite_flutter` plugin is installed
