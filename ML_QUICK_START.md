# ML Environment Quick Start Guide
# Run this after completing the full setup

## Start Here Every Time You Work on ML

### 1. Open PowerShell in VS Code
Press: `Ctrl + Shift + \``

### 2. Navigate to Project (if not already there)
```powershell
cd C:\Users\muhdi\Desktop\fyp_app
```

### 3. Activate Virtual Environment
```powershell
.\ml_env\Scripts\Activate.ps1
```

You should see `(ml_env)` appear in your terminal.

### 4. Verify GPU (Quick Check)
```powershell
python -c "import torch; print('GPU Available:', torch.cuda.is_available())"
```

Should return: `GPU Available: True`

---

## Installation Order (For Reference)

Follow this exact order:

1. ✅ Update NVIDIA Drivers
2. ✅ Install Python 3.10/3.11 (with PATH!)
3. ✅ Install CUDA Toolkit 11.8
4. ✅ Install cuDNN 8.9.7 (copy files manually)
5. ✅ Create virtual environment: `python -m venv ml_env`
6. ✅ Activate environment: `.\ml_env\Scripts\Activate.ps1`
7. ✅ Install PyTorch: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`
8. ✅ Install libraries: See [ML_SETUP_GUIDE.md](ML_SETUP_GUIDE.md) Step 7
9. ✅ Run tests: `python test_gpu.py`

---

## Essential Commands

### Check Installation
```powershell
# Python version
python --version

# Pip version
pip --version

# CUDA version
nvcc --version

# GPU status (after activating env)
python test_gpu.py
```

### Package Management
```powershell
# List installed packages
pip list

# Install package
pip install package-name

# Install specific version
pip install package-name==1.2.3

# Uninstall package
pip uninstall package-name

# Save environment
pip freeze > requirements_ml.txt

# Restore environment
pip install -r requirements_ml.txt
```

### Run Test Scripts
```powershell
# Test GPU
python test_gpu.py

# Test YOLO
python test_yolo.py

# Test OpenCV
python test_opencv.py
```

---

## Common Issues & Quick Fixes

### "torch.cuda.is_available() returns False"
```powershell
# Reinstall PyTorch with CUDA
pip uninstall torch torchvision torchaudio
pip cache purge
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### "Cannot activate virtual environment"
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### "CUDA out of memory"
```python
# In your Python code:
import torch
torch.cuda.empty_cache()

# Or reduce batch size:
batch_size = 4  # Start small
```

### "ModuleNotFoundError"
```powershell
# Make sure environment is activated (you see (ml_env))
# Then install the missing package
pip install missing-package-name
```

---

## Your System Specs

- **GPU:** NVIDIA GTX 1650 Max-Q
- **VRAM:** 4GB
- **CUDA:** 11.8
- **Python:** 3.10 or 3.11
- **PyTorch:** 2.x with CUDA support

### Memory-Friendly Settings for Your GPU

```python
# Recommended settings for 4GB VRAM

# Batch sizes
batch_size = 8  # For training
inference_batch_size = 16  # For prediction

# Image sizes  
img_size = 640  # YOLO default, works well
# img_size = 416  # Use this if 640 causes OOM errors

# Training tips
- Use mixed precision training (AMP)
- Enable gradient accumulation
- Use data augmentation (reduces need for large batches)
- Consider freezing backbone layers initially
```

---

## Useful Links

- **PyTorch Docs:** https://pytorch.org/docs/stable/index.html
- **YOLO Ultralytics:** https://docs.ultralytics.com/
- **OpenCV Docs:** https://docs.opencv.org/4.x/
- **Your Full Guide:** [ML_SETUP_GUIDE.md](ML_SETUP_GUIDE.md)

---

## Sample Training Template

Save this as `train_template.py`:

```python
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from tqdm import tqdm

# Check GPU
device = 'cuda' if torch.cuda.is_available() else 'cpu'
print(f"Using device: {device}")

if device == 'cuda':
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    print(f"Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")

# Training loop template
def train_one_epoch(model, train_loader, optimizer, criterion, device):
    model.train()
    running_loss = 0.0
    
    for batch_idx, (data, target) in enumerate(tqdm(train_loader)):
        data, target = data.to(device), target.to(device)
        
        optimizer.zero_grad()
        output = model(data)
        loss = criterion(output, target)
        loss.backward()
        optimizer.step()
        
        running_loss += loss.item()
        
        # Clear cache every 10 batches (helps with 4GB VRAM)
        if batch_idx % 10 == 0:
            torch.cuda.empty_cache()
    
    return running_loss / len(train_loader)

# Your code here
```

---

## Next Steps After Setup

1. **Learn PyTorch basics** (1-2 weeks)
   - Tensors, autograd, neural networks
   - Official tutorials: pytorch.org/tutorials

2. **Experiment with YOLO** (1 week)
   - Object detection on sample images
   - Fine-tune on custom dataset

3. **Study fashion try-on papers** (ongoing)
   - VITON, CP-VTON, VITON-HD
   - Available on arxiv.org

4. **Build your pipeline** (your project!)
   - Human pose detection
   - Clothing segmentation  
   - Virtual try-on model

---

*Keep this file handy as your quick reference!*
