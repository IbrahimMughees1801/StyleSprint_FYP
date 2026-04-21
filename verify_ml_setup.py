"""
Complete ML Environment Verification Script
Run this after completing all installation steps
"""

import sys
from typing import Dict, List, Tuple

def print_header(title: str):
    """Print a formatted header"""
    print("\n" + "=" * 70)
    print(f"  {title}")
    print("=" * 70)

def check_python() -> bool:
    """Check Python installation"""
    print(f"\n✓ Python {sys.version.split()[0]}")
    return True

def check_package(package_name: str, display_name: str = None) -> Tuple[bool, str]:
    """Check if a package is installed and return version"""
    if display_name is None:
        display_name = package_name
    
    try:
        module = __import__(package_name)
        version = getattr(module, '__version__', 'unknown')
        print(f"✓ {display_name}: {version}")
        return True, version
    except ImportError:
        print(f"✗ {display_name}: NOT INSTALLED")
        return False, None

def check_torch_cuda() -> Dict:
    """Check PyTorch and CUDA setup"""
    try:
        import torch
        
        info = {
            'torch_version': torch.__version__,
            'cuda_available': torch.cuda.is_available(),
            'cuda_version': torch.version.cuda if torch.cuda.is_available() else None,
            'gpu_count': torch.cuda.device_count() if torch.cuda.is_available() else 0,
            'gpu_name': torch.cuda.get_device_name(0) if torch.cuda.is_available() else None,
            'gpu_memory_gb': torch.cuda.get_device_properties(0).total_memory / 1024**3 if torch.cuda.is_available() else 0
        }
        return info
    except ImportError:
        return None

def test_gpu_computation() -> bool:
    """Test actual GPU computation"""
    try:
        import torch
        if not torch.cuda.is_available():
            return False
        
        # Create tensors on GPU
        x = torch.rand(500, 500).cuda()
        y = torch.rand(500, 500).cuda()
        z = torch.matmul(x, y)
        
        # Verify result is on GPU
        return z.is_cuda
    except Exception as e:
        print(f"  Error: {e}")
        return False

def main():
    """Main verification function"""
    
    print_header("ML ENVIRONMENT VERIFICATION")
    
    # Track overall status
    issues = []
    warnings = []
    
    # Check Python
    print_header("1. PYTHON")
    check_python()
    
    # Check Core ML Libraries
    print_header("2. CORE ML LIBRARIES")
    
    packages_core = [
        ('torch', 'PyTorch'),
        ('torchvision', 'TorchVision'),
        ('torchaudio', 'TorchAudio'),
    ]
    
    for pkg, name in packages_core:
        success, version = check_package(pkg, name)
        if not success:
            issues.append(f"{name} not installed")
    
    # Check PyTorch CUDA
    print_header("3. GPU & CUDA")
    
    torch_info = check_torch_cuda()
    
    if torch_info is None:
        print("✗ PyTorch not installed")
        issues.append("PyTorch not installed - cannot check CUDA")
    else:
        print(f"\n✓ PyTorch version: {torch_info['torch_version']}")
        
        if torch_info['cuda_available']:
            print(f"✓ CUDA available: YES")
            print(f"✓ CUDA version: {torch_info['cuda_version']}")
            print(f"✓ GPU count: {torch_info['gpu_count']}")
            print(f"✓ GPU name: {torch_info['gpu_name']}")
            print(f"✓ GPU memory: {torch_info['gpu_memory_gb']:.2f} GB")
            
            # Memory warning for 4GB
            if torch_info['gpu_memory_gb'] <= 4.5:
                warnings.append(
                    f"Your GPU has {torch_info['gpu_memory_gb']:.2f}GB VRAM. "
                    "Use smaller batch sizes (4-8) and mixed precision training."
                )
            
            # Test computation
            print("\n  Testing GPU computation...")
            if test_gpu_computation():
                print("  ✓ GPU computation test PASSED")
            else:
                print("  ✗ GPU computation test FAILED")
                issues.append("GPU computation test failed")
        else:
            print("✗ CUDA available: NO")
            issues.append("CUDA not available - PyTorch will use CPU only (very slow)")
    
    # Check Computer Vision Libraries
    print_header("4. COMPUTER VISION LIBRARIES")
    
    packages_cv = [
        ('cv2', 'OpenCV'),
        ('PIL', 'Pillow'),
        ('skimage', 'scikit-image'),
    ]
    
    for pkg, name in packages_cv:
        success, version = check_package(pkg, name)
        if not success:
            issues.append(f"{name} not installed")
    
    # Check Data Science Libraries
    print_header("5. DATA SCIENCE LIBRARIES")
    
    packages_ds = [
        ('numpy', 'NumPy'),
        ('pandas', 'Pandas'),
        ('matplotlib', 'Matplotlib'),
        ('sklearn', 'scikit-learn'),
    ]
    
    for pkg, name in packages_ds:
        success, version = check_package(pkg, name)
        if not success:
            warnings.append(f"{name} not installed (recommended)")
    
    # Check Deep Learning Tools
    print_header("6. DEEP LEARNING TOOLS")
    
    packages_dl = [
        ('ultralytics', 'Ultralytics (YOLO)'),
        ('timm', 'Timm'),
        ('albumentations', 'Albumentations'),
    ]
    
    for pkg, name in packages_dl:
        success, version = check_package(pkg, name)
        if not success:
            warnings.append(f"{name} not installed (optional but recommended)")
    
    # Check Additional Tools
    print_header("7. ADDITIONAL TOOLS")
    
    packages_extra = [
        ('tqdm', 'tqdm'),
        ('tensorboard', 'TensorBoard'),
        ('mediapipe', 'MediaPipe'),
    ]
    
    for pkg, name in packages_extra:
        check_package(pkg, name)
    
    # Final Summary
    print_header("VERIFICATION SUMMARY")
    
    if not issues:
        print("\n🎉 SUCCESS! Your ML environment is fully configured!")
        print("\n✓ All critical packages installed")
        print("✓ GPU acceleration ready")
        print("✓ Ready for ML/CV development")
        
        if torch_info and torch_info['cuda_available']:
            print(f"\nYour GPU ({torch_info['gpu_name']}) is ready for training!")
    else:
        print("\n⚠️  ISSUES FOUND:")
        for i, issue in enumerate(issues, 1):
            print(f"  {i}. {issue}")
    
    if warnings:
        print("\n💡 RECOMMENDATIONS:")
        for i, warning in enumerate(warnings, 1):
            print(f"  {i}. {warning}")
    
    # Next Steps
    print_header("NEXT STEPS")
    
    if issues:
        print("\n1. Fix the issues listed above")
        print("2. Refer to ML_SETUP_GUIDE.md for installation instructions")
        print("3. Run this script again after fixing")
    else:
        print("\n1. ✓ Your environment is ready!")
        print("2. Start learning PyTorch: https://pytorch.org/tutorials")
        print("3. Try the test scripts: test_gpu.py, test_yolo.py, test_opencv.py")
        print("4. Explore YOLO detection: python -c \"from ultralytics import YOLO; YOLO('yolov8n.pt')\"")
        print("5. Check out ML_QUICK_START.md for daily workflow")
    
    print("\n" + "=" * 70)
    
    # Return status
    return len(issues) == 0

if __name__ == "__main__":
    try:
        success = main()
        sys.exit(0 if success else 1)
    except Exception as e:
        print(f"\n❌ Error running verification: {e}")
        print("Make sure you've activated your virtual environment!")
        sys.exit(1)
