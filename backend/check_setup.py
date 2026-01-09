"""
Helper script to set up the models folder from your friend's project.
Copy the models folder to backend/models/ and run this to verify setup.
"""

import os
import sys

def check_file_exists(path, description):
    """Check if a file or directory exists"""
    exists = os.path.exists(path)
    status = "✅" if exists else "❌"
    print(f"{status} {description}: {path}")
    return exists

def main():
    print("=" * 60)
    print("Virtual Try-On Backend Setup Checker")
    print("=" * 60)
    print()
    
    backend_dir = os.path.dirname(__file__)
    
    # Check Python version
    print("1. Python Environment:")
    print(f"   Python Version: {sys.version.split()[0]}")
    print()
    
    # Check models directory
    print("2. Models Directory:")
    models_dir = os.path.join(backend_dir, "models")
    
    required_files = [
        ("models/__init__.py", "Models package init"),
        ("models/yolo.py", "YOLO Detector"),
        ("models/SegmentationSam2.py", "FastSAM Inference"),
        ("models/DensePose.py", "DensePose Runner"),
        ("models/OpenPose.py", "OpenPose Runner"),
        ("models/ParseAgnostic.py", "Graphonomy Inference"),
        ("models/helper.py", "Helper functions"),
    ]
    
    all_exist = True
    for file_path, description in required_files:
        full_path = os.path.join(backend_dir, file_path)
        exists = check_file_exists(full_path, description)
        all_exist = all_exist and exists
    
    print()
    
    # Check weights directory
    print("3. Model Weights:")
    weights_dir = os.path.join(backend_dir, "..", "weights")
    
    weight_files = [
        ("best.pt", "YOLO weights"),
        ("FastSAM-s.pt", "FastSAM weights"),
        ("model_final_162be9.pkl", "DensePose weights"),
        ("inference.pth", "Graphonomy weights"),
    ]
    
    for file_name, description in weight_files:
        full_path = os.path.join(weights_dir, file_name)
        check_file_exists(full_path, description)
    
    print()
    
    # Check dependencies
    print("4. Python Dependencies:")
    try:
        import fastapi
        print(f"   ✅ FastAPI: {fastapi.__version__}")
    except ImportError:
        print("   ❌ FastAPI: Not installed")
        all_exist = False
    
    try:
        import cv2
        print(f"   ✅ OpenCV: {cv2.__version__}")
    except ImportError:
        print("   ❌ OpenCV: Not installed")
        all_exist = False
    
    try:
        import torch
        print(f"   ✅ PyTorch: {torch.__version__}")
    except ImportError:
        print("   ❌ PyTorch: Not installed")
        all_exist = False
    
    try:
        import PIL
        print(f"   ✅ Pillow: {PIL.__version__}")
    except ImportError:
        print("   ❌ Pillow: Not installed")
        all_exist = False
    
    print()
    print("=" * 60)
    
    if all_exist:
        print("✅ All requirements met! You can start the server:")
        print("   python api_server.py")
    else:
        print("❌ Some requirements are missing. Please:")
        print("   1. Copy models folder from your friend's project")
        print("   2. Download model weights")
        print("   3. Install dependencies: pip install -r requirements.txt")
    
    print("=" * 60)

if __name__ == "__main__":
    main()
