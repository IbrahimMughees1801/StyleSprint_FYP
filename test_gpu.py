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
