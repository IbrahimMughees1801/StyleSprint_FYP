# Complete Machine Learning Setup Guide for Beginners
## Fashion Virtual Try-On Project - Windows with NVIDIA GTX 1650 Max-Q

---

## 📋 Table of Contents
1. [System Check](#step-1-system-check)
2. [Install Python](#step-2-install-python)
3. [Install CUDA Toolkit](#step-3-install-cuda-toolkit)
4. [Install cuDNN](#step-4-install-cudnn)
5. [Set Up Python Virtual Environment](#step-5-set-up-python-virtual-environment)
6. [Install PyTorch with GPU Support](#step-6-install-pytorch-with-gpu-support)
7. [Install Computer Vision Libraries](#step-7-install-computer-vision-libraries)
8. [Set Up VS Code](#step-8-set-up-vs-code)
9. [Verify GPU Setup](#step-9-verify-gpu-setup)
10. [Test Your Setup](#step-10-test-your-setup)

---

## Step 1: System Check

### What You Need to Know First
Your GTX 1650 Max-Q has **4GB VRAM**. This is enough for:
- ✅ Training small to medium models
- ✅ Fine-tuning pre-trained models
- ✅ YOLOv8/YOLOv5 models
- ✅ Image segmentation for fashion try-on
- ⚠️ Limited for very large models (you'll need to use smaller batch sizes)

### A. Check Your GPU
1. Press `Windows + R`, type `devmgmt.msc` and press Enter
2. Expand "Display adapters"
3. You should see "NVIDIA GeForce GTX 1650 Max-Q"
4. If you don't see it, update your drivers first

### B. Update NVIDIA Drivers (IMPORTANT!)
1. Go to: https://www.nvidia.com/Download/index.aspx
2. Select:
   - Product Type: GeForce
   - Product Series: GeForce 16 Series (Notebooks)
   - Product: GeForce GTX 1650 Max-Q
   - Operating System: Windows 10/11
3. Download and install the latest **Game Ready Driver**
4. **Restart your computer** after installation

---

## Step 2: Install Python

### Why This Version?
We'll use **Python 3.10** or **3.11** (recommended for PyTorch compatibility).

### Installation Steps

1. **Download Python:**
   - Go to: https://www.python.org/downloads/
   - Download **Python 3.10.11** or **Python 3.11.7** (stable versions)

2. **Install Python:**
   - Run the installer
   - ⚠️ **CRITICAL**: Check "**Add Python to PATH**" at the bottom
   - Click "Install Now"
   - Wait for installation to complete

3. **Verify Installation:**
   Open PowerShell (Windows + X, then select "PowerShell") and type:
   ```powershell
   python --version
   ```
   You should see: `Python 3.10.11` or `Python 3.11.7`

   Then type:
   ```powershell
   pip --version
   ```
   You should see something like: `pip 23.x.x from ...`

---

## Step 3: Install CUDA Toolkit

### What is CUDA?
CUDA is NVIDIA's technology that lets PyTorch use your GPU for training. Without it, PyTorch will only use your CPU (very slow!).

### Which Version?
Your GTX 1650 Max-Q supports **CUDA 11.8** or **CUDA 12.1**. We'll use **CUDA 11.8** for maximum compatibility.

### Installation Steps

1. **Download CUDA Toolkit 11.8:**
   - Go to: https://developer.nvidia.com/cuda-11-8-0-download-archive
   - Select:
     - Operating System: Windows
     - Architecture: x86_64
     - Version: 10 or 11
     - Installer Type: **exe (local)**
   - Download the file (about 3GB)

2. **Install CUDA:**
   - Run the downloaded installer
   - Choose "Express" installation
   - Wait 10-15 minutes (it's large)
   - Click Finish

3. **Verify Installation:**
   Close and reopen PowerShell (important!), then type:
   ```powershell
   nvcc --version
   ```
   You should see: `Cuda compilation tools, release 11.8, V11.8.xxx`

---

## Step 4: Install cuDNN

### What is cuDNN?
cuDNN is a library that speeds up deep learning operations on NVIDIA GPUs.

### Installation Steps

1. **Create NVIDIA Account:**
   - Go to: https://developer.nvidia.com/cudnn
   - Click "Download cuDNN"
   - Sign up/log in (it's free)

2. **Download cuDNN for CUDA 11.8:**
   - After logging in, find "cuDNN v8.9.7 for CUDA 11.x"
   - Download: "Local Installer for Windows (Zip)"

3. **Install cuDNN (Manual Copy):**
   
   a. **Extract the ZIP file** you downloaded
   
   b. You'll see folders: `bin`, `include`, `lib`
   
   c. **Copy files to CUDA directory:**
   
   Open File Explorer and navigate to:
   ```
   C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8
   ```
   
   Now copy:
   - All files from `cuDNN\bin\` → `CUDA\v11.8\bin\`
   - All files from `cuDNN\include\` → `CUDA\v11.8\include\`
   - All files from `cuDNN\lib\x64\` → `CUDA\v11.8\lib\x64\`
   
   (Choose "Replace" if asked)

4. **Add to System Path:**
   
   a. Press `Windows + R`, type `sysdm.cpl` and press Enter
   
   b. Go to "Advanced" tab → "Environment Variables"
   
   c. Under "System variables", find "Path" → Click "Edit"
   
   d. Click "New" and add:
   ```
   C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8\bin
   ```
   
   e. Click "New" again and add:
   ```
   C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v11.8\libnvvp
   ```
   
   f. Click "OK" on all windows

---

## Step 5: Set Up Python Virtual Environment

### What is a Virtual Environment?
It's like a separate Python workspace for your project. This prevents different projects from conflicting with each other.

### Create Virtual Environment

1. **Navigate to your project folder:**
   ```powershell
   cd C:\Users\muhdi\Desktop\fyp_app
   ```

2. **Create a virtual environment:**
   ```powershell
   python -m venv ml_env
   ```
   This creates a folder called `ml_env` with an isolated Python installation.

3. **Activate the virtual environment:**
   ```powershell
   .\ml_env\Scripts\Activate.ps1
   ```
   
   ⚠️ **If you get an error about execution policy:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   Then try activating again.

4. **You'll know it's active when you see:**
   ```
   (ml_env) PS C:\Users\muhdi\Desktop\fyp_app>
   ```

### Important Notes:
- **Always activate** your virtual environment before working on ML tasks
- To deactivate: type `deactivate`
- To activate later: `.\ml_env\Scripts\Activate.ps1`

---

## Step 6: Install PyTorch with GPU Support

### What is PyTorch?
PyTorch is the deep learning framework you'll use to build and train models.

### Installation Steps

**Make sure your virtual environment is active!** You should see `(ml_env)` in PowerShell.

1. **Install PyTorch with CUDA 11.8:**
   ```powershell
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
   ```
   
   This will take 5-10 minutes. It's downloading about 2-3GB of files.

2. **Wait for it to complete.** You'll see "Successfully installed torch..."

---

## Step 7: Install Computer Vision Libraries

Now let's install all the tools you need for computer vision and fashion try-on.

**Make sure `(ml_env)` is still active!**

### A. Essential Libraries

```powershell
# Upgrade pip first
pip install --upgrade pip

# Computer vision and image processing
pip install opencv-python opencv-contrib-python

# Data science essentials
pip install numpy pandas matplotlib seaborn

# Image processing
pip install Pillow scikit-image

# Scientific computing
pip install scipy

# Jupyter for experiments
pip install jupyter notebook ipykernel

# Progress bars (helpful for training)
pip install tqdm
```

### B. YOLO (for object detection)

```powershell
pip install ultralytics
```

This installs YOLOv8, the latest version. It's perfect for detecting clothing items!

### C. Additional ML Libraries

```powershell
# Machine learning utilities
pip install scikit-learn

# Model training utilities
pip install tensorboard

# Image augmentation (important for training)
pip install albumentations

# Human pose estimation (useful for try-on)
pip install mediapipe
```

### D. Fashion-Specific Tools

```powershell
# Segmentation models
pip install segmentation-models-pytorch

# Timm (pre-trained models)
pip install timm

# For working with clothing datasets
pip install requests gdown
```

---

## Step 8: Set Up VS Code

### A. Install VS Code Extensions

1. **Open VS Code**

2. **Install these extensions** (click Extensions icon on left, search and install):
   - **"Python"** by Microsoft (essential!)
   - **"Pylance"** by Microsoft (better code completion)
   - **"Jupyter"** by Microsoft (for notebooks)
   - **"autoDocstring"** - Python Docstring Generator
   - **"GitLens"** (optional, for version control)

### B. Configure VS Code to Use Your Virtual Environment

1. Open your project: `File → Open Folder` → Select `C:\Users\muhdi\Desktop\fyp_app`

2. Open Command Palette: Press `Ctrl + Shift + P`

3. Type: "Python: Select Interpreter"

4. Choose: `.\ml_env\Scripts\python.exe` (your virtual environment)

5. **Verify** in the bottom-right corner: you should see `3.10.11 ('ml_env': venv)` or similar

### C. Create a Workspace Settings File

Create a file `.vscode/settings.json` in your project with:

```json
{
    "python.defaultInterpreterPath": "${workspaceFolder}/ml_env/Scripts/python.exe",
    "python.terminal.activateEnvironment": true,
    "python.analysis.typeCheckingMode": "basic",
    "jupyter.notebookFileRoot": "${workspaceFolder}",
    "files.exclude": {
        "**/__pycache__": true,
        "**/*.pyc": true
    }
}
```

---

## Step 9: Verify GPU Setup

### Create a Test Script

1. **In VS Code**, create a new file: `test_gpu.py`

2. **Copy this code:**

```python
import torch
import sys

print("=" * 60)
print("CUDA & GPU VERIFICATION")
print("=" * 60)

# Python version
print(f"\n✓ Python version: {sys.version.split()[0]}")

# PyTorch version
print(f"✓ PyTorch version: {torch.__version__}")

# CUDA availability
print(f"\n✓ CUDA available: {torch.cuda.is_available()}")

if torch.cuda.is_available():
    print(f"✓ CUDA version: {torch.version.cuda}")
    print(f"✓ Number of GPUs: {torch.cuda.device_count()}")
    print(f"✓ GPU Name: {torch.cuda.get_device_name(0)}")
    print(f"✓ GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1024**3:.2f} GB")
    
    # Test GPU computation
    print("\n" + "=" * 60)
    print("TESTING GPU COMPUTATION")
    print("=" * 60)
    
    # Create a tensor on GPU
    x = torch.rand(1000, 1000).cuda()
    y = torch.rand(1000, 1000).cuda()
    
    # Perform computation
    z = torch.matmul(x, y)
    
    print("✓ Successfully created tensors on GPU")
    print("✓ Successfully performed matrix multiplication on GPU")
    print("\n🎉 YOUR GPU IS WORKING CORRECTLY!")
else:
    print("\n❌ CUDA is not available. Check your installation.")
    print("   - Make sure you installed PyTorch with CUDA support")
    print("   - Make sure CUDA Toolkit is installed")
    print("   - Make sure NVIDIA drivers are up to date")

print("=" * 60)
```

3. **Run the script:**
   - In VS Code terminal: `python test_gpu.py`
   - OR right-click in editor and select "Run Python File in Terminal"

### Expected Output (Success):

```
============================================================
CUDA & GPU VERIFICATION
============================================================

✓ Python version: 3.10.11
✓ PyTorch version: 2.1.0+cu118

✓ CUDA available: True
✓ CUDA version: 11.8
✓ Number of GPUs: 1
✓ GPU Name: NVIDIA GeForce GTX 1650 Max-Q
✓ GPU Memory: 4.00 GB

============================================================
TESTING GPU COMPUTATION
============================================================
✓ Successfully created tensors on GPU
✓ Successfully performed matrix multiplication on GPU

🎉 YOUR GPU IS WORKING CORRECTLY!
============================================================
```

---

## Step 10: Test Your Setup

### A. Test YOLO (Object Detection)

Create `test_yolo.py`:

```python
from ultralytics import YOLO
import torch

print("Testing YOLO setup...")
print(f"Using device: {'GPU' if torch.cuda.is_available() else 'CPU'}")

# Load a pre-trained YOLOv8 model
model = YOLO('yolov8n.pt')  # nano version (smallest, fastest)

print("✓ YOLO model loaded successfully!")
print(f"✓ Model is on: {next(model.model.parameters()).device}")

# The model will automatically download on first run
print("\n🎉 YOLO is ready to use!")
```

Run it:
```powershell
python test_yolo.py
```

### B. Test OpenCV

Create `test_opencv.py`:

```python
import cv2
import numpy as np

print(f"OpenCV version: {cv2.__version__}")

# Create a test image
test_img = np.zeros((100, 100, 3), dtype=np.uint8)
test_img[:,:] = (255, 0, 0)  # Blue image

# Test basic operations
gray = cv2.cvtColor(test_img, cv2.COLOR_BGR2GRAY)
blurred = cv2.GaussianBlur(test_img, (5, 5), 0)

print("✓ OpenCV is working correctly!")
print("✓ Can create and process images")
```

Run it:
```powershell
python test_opencv.py
```

### C. Create a Requirements File

Save your installed packages:

```powershell
pip freeze > requirements_ml.txt
```

This lets you recreate the environment later or on another machine:
```powershell
pip install -r requirements_ml.txt
```

---

## 🎯 Quick Reference Card

### Daily Workflow

1. **Open PowerShell in VS Code** (`Ctrl + Shift + \``)
2. **Navigate to project:**
   ```powershell
   cd C:\Users\muhdi\Desktop\fyp_app
   ```
3. **Activate environment:**
   ```powershell
   .\ml_env\Scripts\Activate.ps1
   ```
4. **Start coding!**

### Common Commands

```powershell
# Check if GPU is available
python -c "import torch; print(torch.cuda.is_available())"

# Check installed packages
pip list

# Install a new package
pip install package-name

# Update a package
pip install --upgrade package-name

# Deactivate environment
deactivate
```

### GPU Memory Management Tips

With 4GB VRAM, you'll need to be mindful:

1. **Use smaller batch sizes:**
   ```python
   batch_size = 8  # Start small, increase if it works
   ```

2. **Clear GPU cache when needed:**
   ```python
   import torch
   torch.cuda.empty_cache()
   ```

3. **Use mixed precision training:**
   ```python
   from torch.cuda.amp import autocast, GradScaler
   scaler = GradScaler()
   ```

4. **Use gradient accumulation:**
   ```python
   # Effectively increases batch size without more memory
   accumulation_steps = 4
   ```

---

## 🚨 Troubleshooting

### Problem: "CUDA out of memory"
**Solution:** 
- Reduce batch size
- Use smaller image sizes
- Close other GPU-using applications
- Clear GPU cache: `torch.cuda.empty_cache()`

### Problem: "torch.cuda.is_available() returns False"
**Solution:**
1. Reinstall PyTorch with CUDA:
   ```powershell
   pip uninstall torch torchvision torchaudio
   pip cache purge
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
   ```
2. Verify CUDA installation: `nvcc --version`
3. Update NVIDIA drivers

### Problem: "Cannot activate virtual environment"
**Solution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Problem: "Python not found" after installation
**Solution:**
1. Reinstall Python and CHECK "Add Python to PATH"
2. OR add manually to system PATH:
   - `C:\Users\muhdi\AppData\Local\Programs\Python\Python310`
   - `C:\Users\muhdi\AppData\Local\Programs\Python\Python310\Scripts`

---

## 📚 Next Steps

Now that your environment is set up, you can:

1. **Learn PyTorch basics** - Start with official tutorials: pytorch.org/tutorials
2. **Explore YOLO** - Try detecting objects in images
3. **Study fashion datasets** - Look into DeepFashion, Fashion-MNIST
4. **Build your virtual try-on pipeline:**
   - Human pose detection
   - Clothing segmentation
   - Image-to-image translation (try-on)

---

## 📖 Recommended Learning Resources

### For Absolute Beginners:
1. **Python for ML:** "Python Crash Course" by Eric Matthes
2. **Deep Learning:** Fast.ai course (free, practical)
3. **PyTorch:** "Deep Learning with PyTorch" by Eli Stevens

### Video Tutorials:
1. **PyTorch:** Official PyTorch tutorials on YouTube
2. **YOLO:** Ultralytics YOLO tutorials
3. **Computer Vision:** Stanford CS231n (free online)

### For Your Project:
1. **Virtual Try-On papers:** Search "VITON" on arxiv.org
2. **Fashion datasets:** DeepFashion2, ModaNet
3. **Human pose:** MediaPipe, OpenPose

---

## ✅ Success Checklist

Mark these off as you complete them:

- [ ] Python installed and in PATH
- [ ] NVIDIA drivers updated
- [ ] CUDA Toolkit 11.8 installed
- [ ] cuDNN installed and copied
- [ ] Virtual environment created
- [ ] Virtual environment activated
- [ ] PyTorch with CUDA installed
- [ ] All CV libraries installed
- [ ] VS Code configured
- [ ] GPU test passed (torch.cuda.is_available() = True)
- [ ] YOLO test passed
- [ ] OpenCV test passed

---

## 🎉 Congratulations!

You now have a professional ML environment ready for computer vision and fashion virtual try-on projects!

**Your GPU is ready to accelerate your models. Happy training! 🚀**

---

*Created for: Fashion Virtual Try-On Project*  
*System: Windows 10/11, NVIDIA GTX 1650 Max-Q (4GB)*  
*Date: February 2026*
