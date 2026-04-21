@echo off
echo ========================================
echo StyleSprint Virtual Try-On Server
echo Simplified Mode (No ML Models Required)
echo ========================================
echo.

echo Installing dependencies...
pip install -r requirements_simple.txt

echo.
echo Starting server...
echo Server will be available at: http://localhost:8000
echo API Documentation: http://localhost:8000/docs
echo.
echo Note: This is simplified overlay mode.
echo For full ML pipeline, get models from your friend.
echo.

python api_server_simple.py
pause
