# Quick Build Reference - Tablet Edition

## 🚀 Fastest Way to Build for Tablets

### Using the Build Script (Recommended):
```bash
cd mobile_app_flutter
./build-apk.sh          # macOS/Linux
build-apk.bat           # Windows
```

### Manual Build (One Command):
```bash
cd mobile_app_flutter
flutter build apk --split-per-abi --release
```

## 📦 Output Files

After building, find your APKs in:
```
mobile_app_flutter/build/app/outputs/flutter-apk/
```

**Files generated (Tablet-optimized):**
- `app-arm64-v8a-release.apk` - **Modern ARM tablets** (35-45 MB)
- `app-armeabi-v7a-release.apk` - Older ARM tablets (30-40 MB)
- `app-x86_64-release.apk` - **Intel Chromebooks** (40-50 MB)
- `app-x86-release.apk` - Older Intel tablets (35-45 MB)
- `app-release.apk` - Universal (works on all tablets, 100-120 MB)

## 📱 Install on Tablet

### Via USB (ADB):
```bash
# Check tablet architecture
adb shell getprop ro.product.cpu.abi

# Install appropriate APK
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Via File Transfer:
1. Copy APK to tablet
2. Open file manager
3. Tap APK file
4. Install

## 🎯 Which APK for Which Tablet?

### Android Tablets:
- **Modern tablets (Samsung, Lenovo, Xiaomi)**: `app-arm64-v8a-release.apk`
- **Older tablets (Amazon Fire, older Samsung)**: `app-armeabi-v7a-release.apk`

### Chromebooks:
- **Modern Chromebooks (Intel)**: `app-x86_64-release.apk`
- **Older Chromebooks**: `app-x86-release.apk`
- **ARM Chromebooks**: `app-arm64-v8a-release.apk`

### Not Sure?
- **Use**: `app-release.apk` (universal - works on all tablets)

## 🔧 Troubleshooting

### Build fails?
```bash
cd mobile_app_flutter
flutter clean
flutter pub get
flutter build apk --split-per-abi --release
```

### Can't install on Chromebook?
- Enable "Install apps from unknown sources" in Settings
- Try x86_64 APK
- Use universal APK as fallback

## 📊 Size Comparison

| Type | Size | Devices |
|------|------|---------|
| Split (arm64-v8a) | ~40 MB | Modern ARM tablets |
| Split (x86_64) | ~45 MB | Intel Chromebooks |
| Universal | ~110 MB | All tablets |

**Savings: ~65% smaller with splits!**

## 🎨 Tablet Features Enabled

- ✅ Large screen support (7-12 inch displays)
- ✅ Landscape & portrait orientation
- ✅ Split-screen mode support
- ✅ Chromebook compatibility
- ✅ Keyboard & mouse support
- ✅ Resizable windows

## 📚 More Info

See `TABLET_BUILD_GUIDE.md` for detailed tablet-specific instructions.
