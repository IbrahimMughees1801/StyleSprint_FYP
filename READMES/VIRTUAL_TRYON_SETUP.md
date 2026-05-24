# Virtual Try-On Integration Guide

This guide explains how to set up and use the Virtual Try-On feature in your StyleSprint Flutter app.

## Architecture Overview

```
┌─────────────────┐         HTTP API          ┌─────────────────┐
│                 │  ────────────────────────► │                 │
│  Flutter App    │                            │  FastAPI Server │
│  (Mobile)       │  ◄────────────────────────  │  (Python)       │
│                 │    JSON Response + Images  │                 │
└─────────────────┘                            └─────────────────┘
                                                        │
                                                        ▼
                                          ┌──────────────────────────┐
                                          │  ML Models Pipeline:     │
                                          │  • YOLO Detection        │
                                          │  • FastSAM Segmentation  │
                                          │  • DensePose             │
                                          │  • OpenPose              │
                                          │  • Graphonomy            │
                                          └──────────────────────────┘
```

## Setup Instructions

### 1. Backend Setup (Python/FastAPI)

#### Prerequisites
- Python 3.8+ installed
- CUDA-capable GPU (recommended for performance)
- All model weights downloaded

#### Step 1: Install Dependencies

```bash
cd backend
pip install -r requirements.txt
```

#### Step 2: Configure Model Paths

Edit `backend/api_server.py` and update the `CONFIG` dictionary with your actual paths:

```python
CONFIG = {
    "yolo_weights": "path/to/your/best.pt",
    "fastsam_model": "path/to/your/FastSAM-s.pt",
    "densepose_cfg": "path/to/densepose_rcnn_R_50_FPN_s1x.yaml",
    "densepose_weights": "path/to/model_final_162be9.pkl",
    "openpose_root": "path/to/openpose",
    "graphonomy_repo": "path/to/Graphonomy",
    "graphonomy_weights": "path/to/inference.pth",
    "temp_dir": "./temp_uploads",
    "output_dir": "./results"
}
```

#### Step 3: Download Model Weights

You'll need to download:
1. **YOLO weights** - For clothing detection
2. **FastSAM weights** - For segmentation
3. **DensePose weights** - From detectron2 model zoo
4. **OpenPose** - Download binaries for Windows
5. **Graphonomy weights** - For human parsing

#### Step 4: Start the Backend Server

```bash
cd backend
python api_server.py
```

The server will start at `http://localhost:8000`

You can view API documentation at: `http://localhost:8000/docs`

### 2. Flutter App Setup

#### Step 1: Install Dependencies

```bash
flutter pub get
```

#### Step 2: Configure API Endpoint

Edit `lib/services/virtual_tryon_service.dart` and update the base URL:

```dart
// For local development (emulator/physical device on same network)
static const String baseUrl = 'http://YOUR_LOCAL_IP:8000';

// Example:
// static const String baseUrl = 'http://192.168.1.100:8000';

// For production:
// static const String baseUrl = 'https://your-backend-domain.com';
```

**Finding your local IP (Windows):**
```bash
ipconfig
# Look for "IPv4 Address" under your active network adapter
```

#### Step 3: Add Permissions

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.CAMERA"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>We need camera access to take your photo for virtual try-on</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to select your photo for virtual try-on</string>
```

#### Step 4: Run the App

```bash
flutter run
```

## Usage

### User Flow

1. **Navigate to Product Detail**: Open any product with virtual try-on enabled
2. **Click "Try This On"**: Tap the gradient button on the product image
3. **Upload Photo**: Select or take a full-body photo
4. **Process**: Wait 1-2 minutes for AI processing
5. **View Result**: See yourself wearing the product!

### Code Integration

The virtual try-on is integrated in `product_detail_screen.dart`:

```dart
// Open the virtual try-on dialog
showDialog(
  context: context,
  builder: (context) => VirtualTryOnDialog(
    productImageUrl: product.image,
    productName: product.name,
  ),
);
```

## API Endpoints

### POST `/api/tryon/upload`
Upload images as multipart/form-data

**Parameters:**
- `person_image`: File (JPG/PNG)
- `cloth_image`: File (JPG/PNG)

**Response:**
```json
{
  "success": true,
  "message": "Processing completed successfully",
  "session_id": "uuid-here",
  "result_image_url": "/api/tryon/result/uuid-here"
}
```

### POST `/api/tryon/process-base64`
Upload images as base64 strings

**Body:**
```json
{
  "session_id": "uuid-here",
  "person_image_base64": "base64-encoded-image",
  "cloth_image_base64": "base64-encoded-image"
}
```

### GET `/api/tryon/status/{session_id}`
Check processing status

**Response:**
```json
{
  "status": "completed",  // or "processing"
  "session_id": "uuid-here",
  "result_url": "/api/tryon/result/uuid-here"
}
```

### GET `/api/tryon/result/{session_id}`
Get the result image (returns image file)

### DELETE `/api/tryon/cleanup/{session_id}`
Clean up temporary files for a session

## Deployment Options

### Option 1: Local Server (Development)
- Run backend on your PC
- Connect Flutter app via local IP
- Good for testing and development

### Option 2: Cloud Server (Production)
Deploy to:
- **AWS EC2** with GPU instance
- **Google Cloud Platform** with AI Platform
- **Azure** with ML services
- **DigitalOcean** with GPU droplets

### Option 3: Docker Deployment

Create `backend/Dockerfile`:
```dockerfile
FROM python:3.9

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8000"]
```

Build and run:
```bash
docker build -t virtual-tryon-api .
docker run -p 8000:8000 virtual-tryon-api
```

## Troubleshooting

### Backend Issues

**Server won't start:**
- Check all model paths in CONFIG
- Verify all dependencies installed
- Check port 8000 is not in use

**Processing fails:**
- Verify model weights are correct versions
- Check image formats (should be JPG/PNG)
- Review server logs for specific errors

### Flutter App Issues

**Can't connect to server:**
- Verify baseUrl in `virtual_tryon_service.dart`
- Check firewall allows port 8000
- Use local IP address, not localhost (for physical devices)
- Ensure phone and PC on same network

**Image upload fails:**
- Check permissions in AndroidManifest.xml / Info.plist
- Verify image picker works independently
- Check image size (should resize to 768x1024)

## Performance Tips

1. **Use GPU**: Ensure CUDA is properly configured for faster processing
2. **Batch Processing**: Process multiple requests asynchronously
3. **Caching**: Cache preprocessed person images for faster subsequent tries
4. **Image Quality**: Balance between quality and processing time
5. **Model Optimization**: Use quantized or optimized model versions

## Security Considerations

1. **API Authentication**: Add token-based auth in production
2. **Rate Limiting**: Prevent abuse with rate limits
3. **HTTPS**: Use SSL certificates in production
4. **CORS**: Restrict origins in production
5. **File Upload Limits**: Set max file sizes
6. **Temporary File Cleanup**: Implement automatic cleanup jobs

## Future Enhancements

- [ ] Add real VITON model integration for final result
- [ ] Support multiple clothing items simultaneously
- [ ] Add pose adjustment/recommendation
- [ ] Implement result caching
- [ ] Add AR preview mode
- [ ] Support video try-on
- [ ] Batch processing for multiple outfits

## Support

For issues or questions:
1. Check server logs: `backend/temp_uploads/`
2. Review API docs: `http://localhost:8000/docs`
3. Test endpoints individually with Postman/Thunder Client
4. Check Flutter debug console for client-side errors

## Model Credits

- YOLO: Ultralytics
- FastSAM: CASIA-IVA-Lab
- DensePose: Facebook Research
- OpenPose: CMU Perceptual Computing Lab
- Graphonomy: Human parsing model
