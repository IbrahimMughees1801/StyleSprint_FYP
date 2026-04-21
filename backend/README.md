# Backend - Virtual Try-On API

## 🚀 Quick Start (Current Working Version)

**Use This**: `python api_server_simple.py` ✅  
**Skip This**: `api_server.py` (needs ML models + has issues)

```bash
pip install -r requirements_simple.txt
python api_server_simple.py
```

---

## About

FastAPI-based REST API for virtual try-on processing using multiple ML models.

## Directory Structure

```
backend/
├── api_server.py           # Main FastAPI application
├── requirements.txt        # Python dependencies
├── check_setup.py         # Setup verification script
├── models/                # ML model wrappers (copy from friend's project)
│   ├── __init__.py
│   ├── yolo.py           # YOLO detector
│   ├── SegmentationSam2.py
│   ├── DensePose.py
│   ├── OpenPose.py
│   ├── ParseAgnostic.py
│   └── helper.py
├── temp_uploads/          # Temporary upload storage (auto-created)
└── results/               # Processing results (auto-created)
```

## Setup Steps

### 1. Copy Models Folder

Copy the `models/` folder from your friend's project to this directory:

```
backend/
└── models/
    ├── yolo.py
    ├── SegmentationSam2.py
    ├── DensePose.py
    ├── OpenPose.py
    ├── ParseAgnostic.py
    └── helper.py
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Download Model Weights

Create a `weights/` folder in the project root and download:

- **YOLO**: `best.pt` - Your custom YOLO model for clothing detection
- **FastSAM**: `FastSAM-s.pt` - From [FastSAM repo](https://github.com/CASIA-IVA-Lab/FastSAM)
- **DensePose**: `model_final_162be9.pkl` - From [Detectron2 Model Zoo](https://github.com/facebookresearch/detectron2/blob/main/projects/DensePose/doc/DENSEPOSE_IUV.md)
- **Graphonomy**: `inference.pth` - From [Graphonomy repo](https://github.com/Gaoyiminggithub/Graphonomy)

### 4. Install OpenPose

Download OpenPose binaries for Windows and update the path in `api_server.py`:

```python
CONFIG = {
    "openpose_root": r"path\to\openpose",
    # ... other configs
}
```

### 5. Configure Paths

Edit `api_server.py` and update all paths in the `CONFIG` dictionary (lines 28-38).

### 6. Verify Setup

```bash
python check_setup.py
```

This will check if all required files and dependencies are in place.

### 7. Start Server

```bash
python api_server.py
```

Server will start at: **http://localhost:8000**

API Documentation: **http://localhost:8000/docs**

## API Endpoints

### Health Check
```
GET /
```

### Upload Images (Multipart)
```
POST /api/tryon/upload
Content-Type: multipart/form-data

Form Data:
- person_image: file
- cloth_image: file
```

### Process Base64 Images
```
POST /api/tryon/process-base64
Content-Type: application/json

{
  "session_id": "uuid",
  "person_image_base64": "base64-string",
  "cloth_image_base64": "base64-string"
}
```

### Check Status
```
GET /api/tryon/status/{session_id}
```

### Get Result
```
GET /api/tryon/result/{session_id}
```

### Cleanup
```
DELETE /api/tryon/cleanup/{session_id}
```

## Processing Pipeline

1. **YOLO Detection** - Detect clothing in image
2. **FastSAM Segmentation** - Segment clothing from background
3. **DensePose** - Generate dense pose map of person
4. **OpenPose** - Extract body keypoints
5. **Graphonomy** - Human parsing (body part segmentation)
6. **Parse Agnostic** - Generate agnostic representation

## Configuration

Key settings in `api_server.py`:

```python
CONFIG = {
    "yolo_weights": "path/to/best.pt",
    "fastsam_model": "path/to/FastSAM-s.pt",
    "densepose_cfg": "path/to/densepose_config.yaml",
    "densepose_weights": "path/to/model_final.pkl",
    "openpose_root": "path/to/openpose",
    "graphonomy_repo": "path/to/Graphonomy",
    "graphonomy_weights": "path/to/inference.pth",
    "temp_dir": "./temp_uploads",
    "output_dir": "./results"
}
```

## Environment Variables

Optional environment variables:

```bash
# Set device (cpu or cuda)
export DEVICE=cuda

# Set port
export PORT=8000

# Set host
export HOST=0.0.0.0
```

## Testing

### Test with curl:

```bash
# Health check
curl http://localhost:8000/

# Upload test images
curl -X POST http://localhost:8000/api/tryon/upload \
  -F "person_image=@person.jpg" \
  -F "cloth_image=@cloth.jpg"
```

### Test with Python:

```python
import requests

# Upload images
with open('person.jpg', 'rb') as p, open('cloth.jpg', 'rb') as c:
    files = {
        'person_image': p,
        'cloth_image': c
    }
    response = requests.post('http://localhost:8000/api/tryon/upload', files=files)
    print(response.json())
```

## Troubleshooting

### Server won't start
- Check all paths in CONFIG are correct
- Verify model weights exist
- Check port 8000 is not in use: `netstat -ano | findstr :8000`

### Out of memory errors
- Reduce batch size
- Use CPU instead of GPU: `device='cpu'`
- Resize images to smaller dimensions

### Model loading fails
- Verify weight file paths
- Check weight file integrity
- Ensure correct model versions

### Processing is slow
- Use GPU: Install CUDA and cuDNN
- Optimize model parameters
- Reduce image resolution

## Performance

Typical processing time per image:
- **CPU**: 2-5 minutes
- **GPU (GTX 1080)**: 30-60 seconds
- **GPU (RTX 3090)**: 15-30 seconds

## Security Notes

For production deployment:

1. Add authentication middleware
2. Implement rate limiting
3. Use HTTPS with SSL certificates
4. Validate file uploads (size, type)
5. Set up CORS properly
6. Implement request timeouts
7. Add logging and monitoring

## Production Deployment

### Docker Deployment

```dockerfile
FROM python:3.9-cuda

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 8000

CMD ["uvicorn", "api_server:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Cloud Deployment

Recommended platforms:
- AWS EC2 with GPU
- Google Cloud AI Platform
- Azure ML
- DigitalOcean GPU Droplets

## Support

For issues:
1. Check server logs
2. Review API docs at `/docs`
3. Run `check_setup.py`
4. Check temp file permissions
