#!/bin/bash

# Hiqma Mobile App - APK Build Script
# This script builds optimized APK files with split ABIs

set -e  # Exit on error

echo "🚀 Hiqma Mobile App - APK Builder"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Please run this script from the mobile_app_flutter directory."
    exit 1
fi

# Function to print colored output
print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Ask user what type of build they want
echo "Select build type:"
echo "1) Split APKs (Recommended - smaller files)"
echo "2) Universal APK (Single file for all devices)"
echo "3) App Bundle (For Google Play Store)"
echo "4) All of the above"
echo ""
read -p "Enter choice [1-4]: " choice

# Clean previous builds
print_step "Cleaning previous builds..."
flutter clean
print_success "Clean complete"

# Get dependencies
print_step "Getting dependencies..."
flutter pub get
print_success "Dependencies updated"

echo ""
print_step "Starting build process..."
echo ""

case $choice in
    1)
        print_step "Building split APKs..."
        flutter build apk --split-per-abi --release
        print_success "Split APKs built successfully!"
        ;;
    2)
        print_step "Building universal APK..."
        flutter build apk --release
        print_success "Universal APK built successfully!"
        ;;
    3)
        print_step "Building app bundle..."
        flutter build appbundle --release
        print_success "App bundle built successfully!"
        ;;
    4)
        print_step "Building split APKs..."
        flutter build apk --split-per-abi --release
        print_success "Split APKs built successfully!"
        
        echo ""
        print_step "Building app bundle..."
        flutter build appbundle --release
        print_success "App bundle built successfully!"
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac

echo ""
echo "=================================="
print_success "Build completed successfully! 🎉"
echo "=================================="
echo ""

# Show output locations and file sizes
if [ $choice -eq 1 ] || [ $choice -eq 4 ]; then
    echo "📦 Split APKs location:"
    echo "   build/app/outputs/flutter-apk/"
    echo ""
    
    if [ -d "build/app/outputs/flutter-apk" ]; then
        print_step "APK Files:"
        for apk in build/app/outputs/flutter-apk/*.apk; do
            if [ -f "$apk" ]; then
                size=$(du -h "$apk" | cut -f1)
                filename=$(basename "$apk")
                echo "   • $filename - $size"
            fi
        done
    fi
fi

if [ $choice -eq 2 ]; then
    echo "📦 Universal APK location:"
    echo "   build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    
    if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
        size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
        echo "   Size: $size"
    fi
fi

if [ $choice -eq 3 ] || [ $choice -eq 4 ]; then
    echo ""
    echo "📦 App Bundle location:"
    echo "   build/app/outputs/bundle/release/app-release.aab"
    echo ""
    
    if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
        size=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
        echo "   Size: $size"
    fi
fi

echo ""
print_warning "Note: For most modern Android devices, use app-arm64-v8a-release.apk"
echo ""

# Ask if user wants to install on connected device
read -p "Install on connected device? (y/n): " install_choice

if [ "$install_choice" = "y" ] || [ "$install_choice" = "Y" ]; then
    # Check if device is connected
    if ! adb devices | grep -q "device$"; then
        print_warning "No device connected via ADB"
        exit 0
    fi
    
    if [ $choice -eq 1 ] || [ $choice -eq 4 ]; then
        echo ""
        echo "Which APK to install?"
        echo "1) arm64-v8a (Modern 64-bit devices)"
        echo "2) armeabi-v7a (Older 32-bit devices)"
        echo "3) x86_64 (Intel devices/emulators)"
        echo "4) Universal (All devices)"
        read -p "Enter choice [1-4]: " apk_choice
        
        case $apk_choice in
            1) apk_file="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ;;
            2) apk_file="build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk" ;;
            3) apk_file="build/app/outputs/flutter-apk/app-x86_64-release.apk" ;;
            4) apk_file="build/app/outputs/flutter-apk/app-release.apk" ;;
            *) echo "Invalid choice"; exit 1 ;;
        esac
    else
        apk_file="build/app/outputs/flutter-apk/app-release.apk"
    fi
    
    if [ -f "$apk_file" ]; then
        print_step "Installing $(basename $apk_file)..."
        adb install -r "$apk_file"
        print_success "Installation complete!"
    else
        print_warning "APK file not found: $apk_file"
    fi
fi

echo ""
print_success "All done! 🚀"
