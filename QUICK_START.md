# Virtual Try-On - Quick Start Guide

## 🚀 Quick Setup (5 Minutes)

### 1. Backend Setup
```bash
# Navigate to backend folder
cd backend

# Install Python dependencies
pip install -r requirements.txt

# Update CONFIG paths in api_server.py (lines 28-38)
# Then start the server
python api_server.py
```

Server will run at: **http://localhost:8000**

### 2. Flutter Setup
```bash
# Install Flutter dependencies
flutter pub get

# Update API URL in lib/services/virtual_tryon_service.dart (line 11)
# Change to your local IP: http://192.168.X.X:8000

# Run the app
flutter run
```

### 3. Test It!
1. Open any product with "Try This On" button
2. Click the purple gradient button
3. Upload a photo
4. Wait ~1-2 minutes for processing
5. View your result!

---

## 📁 Files Created

### Backend (Python)
- `backend/api_server.py` - FastAPI server with ML pipeline
- `backend/requirements.txt` - Python dependencies

### Flutter (Dart)
- `lib/services/virtual_tryon_service.dart` - API client
- `lib/models/tryon_result.dart` - Data models
- `lib/widgets/virtual_tryon_dialog.dart` - UI dialog
- `lib/screens/product_detail_screen.dart` - Updated (integrated)

### Documentation
- `VIRTUAL_TRYON_SETUP.md` - Complete setup guide

---

## ⚡ Testing Without Full Setup

If you don't have all the ML models yet, you can test the UI:

1. Comment out the ML processing in `backend/api_server.py`:
```python
def process_virtual_tryon(person_image_path: str, cloth_image_path: str, session_id: str):
    # TODO: Add actual ML processing
    # For now, just return the person image as result
    return {
        "success": True,
        "result_path": person_image_path,
        "session_id": session_id
    }
```

2. This will let you test the upload/download flow without running models

---

## 🔧 Configuration Checklist

### Backend
- [ ] Python 3.8+ installed
- [ ] All dependencies installed (`pip install -r requirements.txt`)
- [ ] Model weights downloaded and paths configured
- [ ] Server running on port 8000

### Flutter
- [ ] Dependencies installed (`flutter pub get`)
- [ ] API URL configured with correct IP address
- [ ] Permissions added to AndroidManifest.xml / Info.plist
- [ ] App runs without errors

---

## 🌐 Finding Your Local IP

**Windows:**
```bash
ipconfig
# Look for IPv4 Address: 192.168.X.X
```

**Mac/Linux:**
```bash
ifconfig
# Look for inet: 192.168.X.X
```

Use this IP in Flutter: `http://192.168.X.X:8000`

---

## 📊 API Testing

Test the backend directly:

```bash
# Check if server is running
curl http://localhost:8000/

# Expected response:
# {"status":"running","service":"Virtual Try-On API","version":"1.0.0"}
```

Or visit **http://localhost:8000/docs** for interactive API documentation.

---

## 🐛 Common Issues

### "Server not available"
- ✅ Check backend is running
- ✅ Verify IP address in Flutter code
- ✅ Check firewall settings
- ✅ Ensure phone and PC on same WiFi

### "Processing failed"
- ✅ Check server logs for errors
- ✅ Verify model paths are correct
- ✅ Ensure model weights files exist

### "Permission denied"
- ✅ Add camera/storage permissions to AndroidManifest.xml
- ✅ Request permissions at runtime

---

## 📱 Production Deployment

For production, deploy backend to:
- AWS EC2 (with GPU)
- Google Cloud Platform
- Azure
- DigitalOcean

Update Flutter baseUrl to your domain:
```dart
static const String baseUrl = 'https://api.yourdomain.com';
```

---

## 🎯 Next Steps

1. ✅ Get basic setup working
2. Download and configure all ML models
3. Test with real images
4. Optimize processing time
5. Add authentication
6. Deploy to production

---

## 💡 Tips

- Start with small test images (768x1024)
- Use GPU for faster processing
- Cache results to avoid reprocessing
- Monitor server resources
- Set up automatic cleanup of temp files

---

## 📚 Resources

- Full Setup Guide: `VIRTUAL_TRYON_SETUP.md`
- API Docs: `http://localhost:8000/docs`
- FastAPI: https://fastapi.tiangolo.com/
- Flutter HTTP: https://pub.dev/packages/http
