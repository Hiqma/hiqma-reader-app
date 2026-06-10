# Hiqma Mobile App - APK Build Guide

## Overview
This guide explains how to build optimized APK files with split ABIs to reduce file size.

## What Are APK Splits?

APK splits allow you to generate separate APK files for different device architectures (ABIs):
- **armeabi-v7a**: 32-bit ARM devices (older phones)
- **arm64-v8a**: 64-bit ARM devices (most modern phones)
- **x86_64**: 64-bit Intel devices (emulators, some tablets)

Instead of one large APK containing all architectures, you get smaller APKs for each architecture.

## Build Configuration

The app is configured with the following optimizations:

### 1. **APK Splits** (Reduces size by ~60%)
- Separate APKs for each architecture
- Universal APK also generated as fallback

### 2. **Code Shrinking** (Reduces size by ~20-30%)
- Removes unused code
- Obfuscates code for security
- Optimizes bytecode

### 3. **Resource Shrinking** (Reduces size by ~10-15%)
- Removes unused resources
- Optimizes images and assets

## Build Commands

### Option 1: Build Split APKs (Recommended)
```bash
cd mobile_app_flutter
flutter build apk --split-per-abi --release
```

**Output Location:** `build/app/outputs/flutter-apk/`

**Generated Files:**
- `app-armeabi-v7a-release.apk` (~25-35 MB) - For older 32-bit devices
- `app-arm64-v8a-release.apk` (~30-40 MB) - For modern 64-bit devices
- `app-x86_64-release.apk` (~35-45 MB) - For Intel devices/emulators
- `app-release.apk` (~80-100 MB) - Universal APK (all architectures)

### Option 2: Build Universal APK (Single file for all devices)
```bash
cd mobile_app_flutter
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk` (~80-100 MB)

### Option 3: Build App Bundle (For Google Play Store)
```bash
cd mobile_app_flutter
flutter build appbundle --release
```

**Output:** `build/app/outputs/bundle/release/app-release.aab`

**Note:** App Bundles are smaller and Google Play automatically serves the right APK to each device.

## Which APK to Use?

### For Distribution:
- **Google Play Store**: Use App Bundle (`.aab`)
- **Direct Download**: Provide split APKs + universal APK
- **Single File**: Use universal APK (larger but works on all devices)

### For Testing:
- **Modern phones (2018+)**: Use `app-arm64-v8a-release.apk`
- **Older phones**: Use `app-armeabi-v7a-release.apk`
- **Emulators**: Use `app-x86_64-release.apk`
- **Unknown device**: Use `app-release.apk` (universal)

## Installation

### Install via ADB:
```bash
# Install specific architecture
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Or install universal
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Install via File Manager:
1. Copy APK to device
2. Open file manager
3. Tap APK file
4. Allow installation from unknown sources if prompted
5. Install

## Size Comparison

**Without Splits (Universal APK):**
- Single APK: ~80-100 MB

**With Splits:**
- arm64-v8a: ~30-40 MB (60% smaller!)
- armeabi-v7a: ~25-35 MB (65% smaller!)
- x86_64: ~35-45 MB (55% smaller!)

## Build Optimizations Applied

### 1. APK Splits
- Configured in `android/app/build.gradle.kts`
- Generates separate APKs per ABI
- Includes universal APK as fallback

### 2. Code Shrinking (ProGuard/R8)
- Enabled in release builds
- Removes unused code
- Obfuscates class/method names
- Rules defined in `proguard-rules.pro`

### 3. Resource Shrinking
- Automatically removes unused resources
- Optimizes drawable resources
- Reduces APK size

### 4. Native Library Filtering
- Only includes necessary architectures
- Excludes x86 (32-bit Intel) - rarely used

## Troubleshooting

### Build Fails with ProGuard Errors
If you encounter ProGuard/R8 errors, you can disable code shrinking temporarily:

Edit `android/app/build.gradle.kts`:
```kotlin
buildTypes {
    release {
        isMinifyEnabled = false  // Change to false
        isShrinkResources = false  // Change to false
    }
}
```

### APK Won't Install
- Check device architecture matches APK
- Enable "Install from unknown sources"
- Uninstall previous version first
- Use universal APK if unsure

### App Crashes After Release Build
- Check ProGuard rules in `proguard-rules.pro`
- Add keep rules for classes that use reflection
- Test with `flutter run --release` before building APK

## Advanced: Custom Build Variants

### Build with custom version:
```bash
flutter build apk --split-per-abi --build-name=1.0.1 --build-number=2
```

### Build with specific flavor:
```bash
flutter build apk --split-per-abi --flavor production
```

### Build with verbose output:
```bash
flutter build apk --split-per-abi --verbose
```

## Clean Build (If Issues Occur)

```bash
cd mobile_app_flutter
flutter clean
flutter pub get
flutter build apk --split-per-abi --release
```

## Signing APK for Production

For production releases, you should sign your APK with a release keystore:

1. Create a keystore (one-time setup)
2. Configure signing in `android/app/build.gradle.kts`
3. Build with release signing

See Flutter documentation for detailed signing instructions:
https://docs.flutter.dev/deployment/android#signing-the-app

## Summary

**Quick Build Command:**
```bash
cd mobile_app_flutter && flutter build apk --split-per-abi --release
```

**Output:** 3 optimized APKs + 1 universal APK in `build/app/outputs/flutter-apk/`

**Recommended:** Use `app-arm64-v8a-release.apk` for most modern Android devices.
