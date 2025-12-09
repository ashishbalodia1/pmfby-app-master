#!/usr/bin/env python3
"""
Convert Keras H5 model to TFLite for mobile deployment
"""

import tensorflow as tf
import json
from pathlib import Path

# Paths
H5_MODEL_PATH = 'classification/models/mobilenet/mobilenet_best.h5'
TFLITE_MODEL_PATH = 'assets/models/mobilenet_best.tflite'
CLASS_NAMES_SRC = 'classification/models/class_names.json'
CLASS_NAMES_DST = 'assets/models/class_names.json'

def convert_to_tflite():
    """Convert H5 model to TFLite format"""
    print("Loading Keras model...")
    model = tf.keras.models.load_model(H5_MODEL_PATH)
    
    print("Converting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    # Optimization options
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    # Save the model
    Path(TFLITE_MODEL_PATH).parent.mkdir(parents=True, exist_ok=True)
    with open(TFLITE_MODEL_PATH, 'wb') as f:
        f.write(tflite_model)
    
    print(f"✓ TFLite model saved to: {TFLITE_MODEL_PATH}")
    print(f"  Model size: {len(tflite_model) / 1024 / 1024:.2f} MB")

def copy_class_names():
    """Copy class names JSON file"""
    Path(CLASS_NAMES_DST).parent.mkdir(parents=True, exist_ok=True)
    
    with open(CLASS_NAMES_SRC, 'r') as f:
        class_names = json.load(f)
    
    with open(CLASS_NAMES_DST, 'w') as f:
        json.dump(class_names, f, indent=2)
    
    print(f"✓ Class names copied to: {CLASS_NAMES_DST}")
    print(f"  Total classes: {len(class_names)}")

if __name__ == '__main__':
    try:
        convert_to_tflite()
        copy_class_names()
        print("\n✓ Conversion complete! Model ready for mobile deployment.")
    except Exception as e:
        print(f"✗ Error: {e}")
        import traceback
        traceback.print_exc()
