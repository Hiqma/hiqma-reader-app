@echo off
REM Hiqma Mobile App - APK Build Script (Windows)
REM This script builds optimized APK files with split ABIs

echo.
echo ================================
echo Hiqma Mobile App - APK Builder
echo ================================
echo.

REM Check if we're in the right directory
if not exist "pubspec.yaml" (
    echo Error: pubspec.yaml not found. Please run this script from the mobile_app_flutter directory.
    exit /b 1
)

REM Ask user what type of build they want
echo Select build type:
echo 1) Split APKs (Recommended - smaller files)
echo 2) Universal APK (Single file for all devices)
echo 3) App Bundle (For Google Play Store)
echo 4) All of the above
echo.
set /p choice="Enter choice [1-4]: "

REM Clean previous builds
echo.
echo [*] Cleaning previous builds...
call flutter clean
echo [+] Clean complete
echo.

REM Get dependencies
echo [*] Getting dependencies...
call flutter pub get
echo [+] Dependencies updated
echo.

echo [*] Starting build process...
echo.

if "%choice%"=="1" (
    echo [*] Building split APKs...
    call flutter build apk --split-per-abi --release
    echo [+] Split APKs built successfully!
) else if "%choice%"=="2" (
    echo [*] Building universal APK...
    call flutter build apk --release
    echo [+] Universal APK built successfully!
) else if "%choice%"=="3" (
    echo [*] Building app bundle...
    call flutter build appbundle --release
    echo [+] App bundle built successfully!
) else if "%choice%"=="4" (
    echo [*] Building split APKs...
    call flutter build apk --split-per-abi --release
    echo [+] Split APKs built successfully!
    echo.
    echo [*] Building app bundle...
    call flutter build appbundle --release
    echo [+] App bundle built successfully!
) else (
    echo Error: Invalid choice. Exiting.
    exit /b 1
)

echo.
echo ================================
echo [+] Build completed successfully!
echo ================================
echo.

REM Show output locations
if "%choice%"=="1" (
    echo APKs location: build\app\outputs\flutter-apk\
    echo.
    dir /b build\app\outputs\flutter-apk\*.apk 2>nul
) else if "%choice%"=="2" (
    echo APK location: build\app\outputs\flutter-apk\app-release.apk
) else if "%choice%"=="3" (
    echo App Bundle location: build\app\outputs\bundle\release\app-release.aab
) else if "%choice%"=="4" (
    echo APKs location: build\app\outputs\flutter-apk\
    echo App Bundle location: build\app\outputs\bundle\release\app-release.aab
    echo.
    dir /b build\app\outputs\flutter-apk\*.apk 2>nul
)

echo.
echo Note: For most modern Android devices, use app-arm64-v8a-release.apk
echo.
echo All done!
pause
