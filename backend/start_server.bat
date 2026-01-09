@echo off
echo ========================================
echo Virtual Try-On Backend Server
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    pause
    exit /b 1
)

echo Python found: 
python --version
echo.

REM Check if we're in the backend directory
if not exist "api_server.py" (
    echo ERROR: api_server.py not found
    echo Please run this script from the backend directory
    pause
    exit /b 1
)

echo Checking dependencies...
python check_setup.py
echo.

echo ========================================
echo Starting FastAPI Server...
echo ========================================
echo.
echo Server will be available at:
echo   http://localhost:8000
echo.
echo API Documentation:
echo   http://localhost:8000/docs
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start the server
python api_server.py

pause
