#!/bin/bash

# Crop Classification Feature Setup Script
echo "=================================="
echo "Crop Classification Setup"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Install Flutter dependencies
echo -e "${YELLOW}Step 1: Installing Flutter dependencies...${NC}"
flutter pub get
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Flutter dependencies installed${NC}"
else
    echo -e "${RED}✗ Failed to install Flutter dependencies${NC}"
    exit 1
fi
echo ""

# Step 2: Check for TFLite model
echo -e "${YELLOW}Step 2: Checking for TFLite model...${NC}"
if [ -f "assets/models/mobilenet_best.tflite" ]; then
    echo -e "${GREEN}✓ TFLite model found${NC}"
else
    echo -e "${YELLOW}⚠ TFLite model not found${NC}"
    echo "  Run: python3 convert_model_to_tflite.py"
    echo "  See MODEL_CONVERSION.md for details"
fi
echo ""

# Step 3: Check for class names
echo -e "${YELLOW}Step 3: Checking for class names...${NC}"
if [ -f "assets/models/class_names.json" ]; then
    echo -e "${GREEN}✓ Class names file found${NC}"
else
    echo -e "${RED}✗ Class names file missing${NC}"
    exit 1
fi
echo ""

# Step 4: Vision API Setup Instructions
echo -e "${YELLOW}Step 4: Vision API Setup${NC}"
echo "To enable online mode, start the Vision API server:"
echo ""
echo "  cd vision"
echo "  export GOOGLE_API_KEY='your-gemini-api-key'"
echo "  pip install -r requirements.txt"
echo "  python app.py"
echo ""
echo "Then update the API URL in:"
echo "  lib/src/services/crop_classification_service.dart"
echo ""

# Step 5: Build instructions
echo -e "${YELLOW}Step 5: Build the app${NC}"
echo "Run one of the following commands:"
echo ""
echo "  # For Android:"
echo "  flutter build apk"
echo ""
echo "  # For development/testing:"
echo "  flutter run"
echo ""

echo "=================================="
echo -e "${GREEN}Setup Complete!${NC}"
echo "=================================="
echo ""
echo "Next steps:"
echo "1. Convert model to TFLite (for offline mode)"
echo "2. Start Vision API server (for online mode)"
echo "3. Build and run the app"
echo ""
echo "See CROP_CLASSIFICATION_FEATURE.md for detailed documentation"
