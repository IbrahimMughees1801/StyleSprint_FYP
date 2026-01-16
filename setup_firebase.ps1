# FlutterFire Setup Script for Windows
# Run this from your project root directory

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  FlutterFire Setup Script" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check if Node.js is installed
Write-Host "Step 1: Checking Node.js installation..." -ForegroundColor Yellow
if (Get-Command node -ErrorAction SilentlyContinue) {
    $nodeVersion = node --version
    Write-Host "✓ Node.js is installed: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Node.js is NOT installed!" -ForegroundColor Red
    Write-Host "  Download from: https://nodejs.org/" -ForegroundColor Yellow
    Write-Host ""
    exit
}

# Check if Firebase CLI is installed
Write-Host ""
Write-Host "Step 2: Checking Firebase CLI..." -ForegroundColor Yellow
if (Get-Command firebase -ErrorAction SilentlyContinue) {
    $firebaseVersion = firebase --version
    Write-Host "✓ Firebase CLI is installed: $firebaseVersion" -ForegroundColor Green
} else {
    Write-Host "✗ Firebase CLI is NOT installed" -ForegroundColor Red
    Write-Host "  Installing Firebase CLI..." -ForegroundColor Yellow
    npm install -g firebase-tools
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Firebase CLI installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to install Firebase CLI" -ForegroundColor Red
        exit
    }
}

# Check if FlutterFire CLI is installed
Write-Host ""
Write-Host "Step 3: Checking FlutterFire CLI..." -ForegroundColor Yellow
if (Get-Command flutterfire -ErrorAction SilentlyContinue) {
    $flutterfireVersion = flutterfire --version
    Write-Host "✓ FlutterFire CLI is installed: $flutterfireVersion" -ForegroundColor Green
} else {
    Write-Host "✗ FlutterFire CLI is NOT installed" -ForegroundColor Red
    Write-Host "  Installing FlutterFire CLI..." -ForegroundColor Yellow
    dart pub global activate flutterfire_cli
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ FlutterFire CLI installed successfully!" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to install FlutterFire CLI" -ForegroundColor Red
        Write-Host "  You may need to add Dart pub global bin to your PATH" -ForegroundColor Yellow
        Write-Host "  Path: $env:LOCALAPPDATA\Pub\Cache\bin" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "  Setup Complete!" -ForegroundColor Green
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run: firebase login" -ForegroundColor White
Write-Host "2. Run: flutterfire configure" -ForegroundColor White
Write-Host "3. Follow the prompts to set up Firebase" -ForegroundColor White
Write-Host "4. Enable Email/Password auth in Firebase Console" -ForegroundColor White
Write-Host "5. Create Firestore database" -ForegroundColor White
Write-Host ""
Write-Host "Ready to configure Firebase? (Y/N)" -ForegroundColor Yellow
$response = Read-Host

if ($response -eq "Y" -or $response -eq "y") {
    Write-Host ""
    Write-Host "Logging into Firebase..." -ForegroundColor Yellow
    firebase login
    
    Write-Host ""
    Write-Host "Configuring FlutterFire..." -ForegroundColor Yellow
    flutterfire configure
    
    Write-Host ""
    Write-Host "✓ Firebase configuration complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Don't forget to:" -ForegroundColor Yellow
    Write-Host "1. Uncomment 'import firebase_options.dart' in lib/main.dart" -ForegroundColor White
    Write-Host "2. Update Firebase.initializeApp() with options parameter" -ForegroundColor White
    Write-Host "3. Enable Email/Password in Firebase Console" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "You can run the configuration manually with:" -ForegroundColor Yellow
    Write-Host "  firebase login" -ForegroundColor White
    Write-Host "  flutterfire configure" -ForegroundColor White
}

Write-Host ""
