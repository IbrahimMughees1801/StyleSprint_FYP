# ML Environment Setup Helper Script
# Save as: setup_ml_env.ps1
# Run: .\setup_ml_env.ps1

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ML Environment Setup Helper" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Check if virtual environment exists
if (Test-Path ".\ml_env\Scripts\Activate.ps1") {
    Write-Host "✓ Virtual environment found" -ForegroundColor Green
    
    # Activate virtual environment
    Write-Host "Activating virtual environment..." -ForegroundColor Yellow
    & .\ml_env\Scripts\Activate.ps1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Virtual environment activated`n" -ForegroundColor Green
        
        # Quick GPU check
        Write-Host "Checking GPU availability..." -ForegroundColor Yellow
        python -c "import torch; print('✓ GPU Available:', torch.cuda.is_available())" 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Environment ready for ML work!`n" -ForegroundColor Green
            
            Write-Host "Quick commands:" -ForegroundColor Cyan
            Write-Host "  python verify_ml_setup.py    - Full verification"
            Write-Host "  python test_gpu.py          - Test GPU"
            Write-Host "  python test_yolo.py         - Test YOLO"
            Write-Host "  pip list                    - List packages"
            Write-Host "  deactivate                  - Exit environment`n"
        } else {
            Write-Host "⚠ PyTorch not found. Have you installed it?" -ForegroundColor Yellow
            Write-Host "Run: pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`n" -ForegroundColor Yellow
        }
    } else {
        Write-Host "✗ Failed to activate environment" -ForegroundColor Red
        Write-Host "Try: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`n" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ Virtual environment not found" -ForegroundColor Red
    Write-Host "`nCreating virtual environment..." -ForegroundColor Yellow
    python -m venv ml_env
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Virtual environment created" -ForegroundColor Green
        Write-Host "`nNext steps:" -ForegroundColor Cyan
        Write-Host "1. Run this script again: .\setup_ml_env.ps1"
        Write-Host "2. Install PyTorch: pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118"
        Write-Host "3. Install other packages (see ML_SETUP_GUIDE.md)`n"
    } else {
        Write-Host "✗ Failed to create virtual environment" -ForegroundColor Red
        Write-Host "Make sure Python is installed and in PATH`n" -ForegroundColor Yellow
    }
}

Write-Host "========================================`n" -ForegroundColor Cyan
