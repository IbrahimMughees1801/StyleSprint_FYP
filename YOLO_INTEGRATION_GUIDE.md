# YOLO Model Integration Guide

## 🎯 Quick Start - Integrate Your Trained YOLO Model

You've trained a YOLO model on Google Colab and have the `best.pt` file. Here's how to integrate it:

---

## Step 1: Place Your Model File

Copy your `best.pt` file from Colab to the weights folder:

```
fyp_app/
└── weights/
    └── best.pt  ← Place your trained model here
```

**To get the file from Colab:**

1. In your Colab notebook, run:
   ```python
   from google.colab import files
   files.download('runs/detect/train/weights/best.pt')
   ```

2. Or download from the Files panel in Colab (left sidebar)

3. Copy `best.pt` to: `c:\Users\muhdi\Desktop\fyp_app\weights\`

---

## Step 2: Test Your Model

Run the test script to verify it works:

```powershell
# Activate your virtual environment first
& .\.venv\Scripts\Activate.ps1

# Test the YOLO model
python test_yolo_custom.py
```

This will:
- Load your trained model
- Show model info (classes, parameters)
- Test it on a sample image (if provided)

---

## Step 3: Use in Backend API

The backend is already configured to use YOLO. Just update the path in `backend/api_server.py`:

**Current config (line 51):**
```python
"yolo_weights": r"C:\Users\FAST\VITON\weights\best.pt",  # ❌ Old path
```

**Updated config:**
```python
"yolo_weights": r"C:\Users\muhdi\Desktop\fyp_app\weights\best.pt",  # ✅ Your path
```

Or use a relative path:
```python
"yolo_weights": "../weights/best.pt",  # ✅ Relative to backend/
```

---

## Step 4: How It's Used in the Pipeline

Your YOLO model is used for **clothing detection** in the virtual try-on pipeline:

### Pipeline Flow:
```
User uploads photo
    ↓
[YOLO] ← Detects clothing items (shirt, pants, etc.)
    ↓
[FastSAM] ← Segments the detected clothing
    ↓
[DensePose] ← Maps body pose
    ↓
[OpenPose] ← Gets body keypoints
    ↓
[Warping] ← Aligns new clothes
    ↓
[Diffusion] ← Generates final try-on
```

### What Your YOLO Model Should Detect:

Typical classes for fashion virtual try-on:
- `upper_body` (shirts, jackets, etc.)
- `lower_body` (pants, skirts, etc.)
- `dresses`
- `shoes`

Make sure your model was trained on fashion/clothing data!

---

## Step 5: API Endpoints Using YOLO

### Endpoint: `/process-full` (Full Pipeline)

```python
# In your Flutter app or testing tool
POST http://localhost:8000/process-full

Body:
- person_image: (file) User's photo
- garment_image: (file) Clothing to try on
```

**What happens:**
1. YOLO detects clothing in both images
2. Pipeline processes the images
3. Returns final try-on result

### Endpoint: `/detect-clothing` (YOLO Only)

```python
POST http://localhost:8000/detect-clothing

Body:
- image: (file) Image to detect clothing in
```

**Response:**
```json
{
  "detections": [
    {
      "class": "upper_body",
      "confidence": 0.95,
      "bbox": [x, y, width, height]
    }
  ],
  "annotated_image": "base64_encoded_image"
}
```

---

## Common Issues & Fixes

### ❌ Model not found
**Error:** `FileNotFoundError: weights/best.pt`

**Fix:** Check the file path is correct
```python
import os
print(os.path.exists(r"C:\Users\muhdi\Desktop\fyp_app\weights\best.pt"))
# Should print: True
```

### ❌ Wrong input size
**Error:** `RuntimeError: Expected input size (640, 640)`

**Fix:** Your model expects specific image size. The API handles resizing automatically, but for testing:
```python
from ultralytics import YOLO

model = YOLO('weights/best.pt')
# Specify image size if needed
results = model.predict('test.jpg', imgsz=640)
```

### ❌ No detections
**Issue:** Model doesn't detect anything

**Fix:**
1. Check if your model was trained on similar images
2. Lower confidence threshold:
   ```python
   results = model.predict('test.jpg', conf=0.25)  # Lower from default 0.5
   ```
3. Verify classes match your training data

### ❌ CUDA/GPU issues
**Error:** `CUDA out of memory`

**Fix:** Force CPU mode:
```python
model = YOLO('weights/best.pt')
results = model.predict('test.jpg', device='cpu')
```

---

## Model Information

To check your model details:

```python
from ultralytics import YOLO

model = YOLO('weights/best.pt')

# Print model info
print(f"Classes: {model.names}")
print(f"Number of classes: {len(model.names)}")
print(f"Parameters: {sum(p.numel() for p in model.model.parameters())}")

# Test prediction
results = model.predict('test_image.jpg')
for r in results:
    print(f"Boxes: {r.boxes.data}")  # [x1, y1, x2, y2, conf, class]
```

---

## Next Steps

1. ✅ Place `best.pt` in `weights/` folder
2. ✅ Run `test_yolo_custom.py` to verify
3. ✅ Update path in `backend/api_server.py`
4. ✅ Start backend: `cd backend && python api_server_simple.py`
5. ✅ Test from Flutter app

---

## Performance Tips

### For Faster Inference:
- Use smaller model (YOLOv8n) if accuracy is acceptable
- Reduce image size in preprocessing
- Use GPU if available (`device='cuda'`)

### For Better Accuracy:
- Use larger model (YOLOv8m or YOLOv8l)
- Adjust confidence threshold based on your needs
- Ensure training data matches production images

---

## Training Tips (For Future Reference)

If you need to retrain or fine-tune:

```python
from ultralytics import YOLO

# Load a model
model = YOLO('yolov8n.pt')  # Start from pretrained

# Train on your data
model.train(
    data='your_dataset.yaml',
    epochs=100,
    imgsz=640,
    batch=16,
    device='0',  # GPU
    project='fashion_detection',
    name='experiment1'
)

# The best model will be saved as:
# runs/detect/experiment1/weights/best.pt
```

---

## Resources

- **Ultralytics Docs**: https://docs.ultralytics.com/
- **YOLO GitHub**: https://github.com/ultralytics/ultralytics
- **Fashion Datasets**: 
  - DeepFashion: http://mmlab.ie.cuhk.edu.hk/projects/DeepFashion.html
  - Fashion-MNIST: https://github.com/zalandoresearch/fashion-mnist

---

**Need Help?**

Check `test_yolo_custom.py` for examples or run the backend in debug mode to see detailed logs.
