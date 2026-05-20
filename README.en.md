<div align="center">
  <img src="PhotoSwipeCleaner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" width="96" alt="PhotoLite icon">
  <h1>PhotoLite</h1>
  <p>A local-first, gesture-driven photo review and cleanup app.</p>
  <p>
    <a href="README.md">简体中文</a>
    ·
    <a href="https://github.com/songjack152/PhotoLite/releases/tag/v1.0.0">Download 1.0.0</a>
    ·
    <a href="docs/INSTALL.md">Installation</a>
    ·
    <a href="docs/PRIVACY.md">Privacy</a>
  </p>
  <p>
    <img src="https://img.shields.io/github/v/release/songjack152/PhotoLite?label=release" alt="Release">
    <img src="https://img.shields.io/github/license/songjack152/PhotoLite" alt="License">
    <img src="https://img.shields.io/badge/platform-iPhone%20%7C%20Android%20%7C%20macOS%20%7C%20Windows-blue" alt="Platforms">
    <img src="https://img.shields.io/badge/privacy-local--first-34C759" alt="Local first">
  </p>
</div>

## Overview

PhotoLite helps you review and clean up a photo library quickly. It shuffles photos into small batches and lets you review them with simple gestures: swipe left for next photo, swipe right for previous photo, and swipe up to mark a photo for deletion. At the end of each batch, PhotoLite opens a second confirmation screen; photos are deleted only after explicit confirmation.

PhotoLite is useful for:

- People who want to clean up many photos quickly.
- Users who prefer local processing without uploading photos.
- Developers interested in photo permissions, gesture-based UI, SwiftUI, and cross-platform Flutter apps.

## Screenshots

The screenshots below are sample screens and do not include real user photos.

<p>
  <img src="docs/screenshots/review.svg" alt="PhotoLite photo review screen" width="220">
  <img src="docs/screenshots/confirm.svg" alt="PhotoLite deletion confirmation screen" width="220">
  <img src="docs/screenshots/settings.svg" alt="PhotoLite settings screen" width="220">
</p>

<p>
  <img src="docs/screenshots/macos.svg" alt="PhotoLite macOS screen" width="680">
</p>

## Downloads and Versions

Latest version: `1.0.0`

| Platform | Package | Status |
| --- | --- | --- |
| Android | `PhotoLite-Android-preview.apk` | Preview build available |
| macOS | `PhotoLite-macOS-release.dmg` | Preview build available |
| iPhone | Run with Xcode, then distribute with TestFlight or App Store | Source available |
| Windows | No installer yet | Project files included |

Download:

[PhotoLite 1.0.0 Release](https://github.com/songjack152/PhotoLite/releases/tag/v1.0.0)

See [docs/INSTALL.md](docs/INSTALL.md) for detailed installation instructions.

## Features

- Batch-based photo review, defaulting to 10 photos per batch.
- Swipe left for next photo, swipe right for previous photo, swipe up to mark for deletion.
- Second confirmation screen before deletion.
- Ability to unselect individual photos on the confirmation screen.
- Photo metadata display, including date, dimensions, file size, and available location information.
- Optional date-range filtering, such as recent month, three months, half year, one year, or five years.
- Optional haptic feedback on supported mobile devices.
- Keyboard support on macOS, including arrow keys and WASD.
- Local-first design with no backend service.

## Deletion Safety

PhotoLite is designed to reduce accidental deletion:

1. Gestures only review photos; they do not delete immediately.
2. Swiping up only adds a photo to the pending deletion list.
3. Each batch ends with a second confirmation screen.
4. Individual photos can be unselected before deletion.
5. Final deletion is performed through platform APIs or local file handling.

Keep an external backup before cleaning important photos.

## Privacy

PhotoLite is local-first:

- Photos, thumbnails, EXIF, and location data are not uploaded.
- No backend service is included.
- Photo metadata is used only for local display and filtering.
- The repository does not include signing keys, provisioning profiles, keystores, local build outputs, APKs, DMGs, or archives.

See [docs/PRIVACY.md](docs/PRIVACY.md) for more detail.

## Project Structure

```text
PhotoSwipeCleaner.xcodeproj       Native iPhone SwiftUI project
PhotoSwipeCleaner/                iOS source code
photolite_flutter/                Flutter app for Android, macOS, and Windows
docs/                             Installation, privacy, and release notes
scripts/                          Local packaging scripts
```

## Build From Source

### iPhone Native App

Requirements:

- macOS
- Xcode
- An Apple Developer account for device distribution, TestFlight, or App Store release

```bash
open PhotoSwipeCleaner.xcodeproj
```

Run on a device from Xcode, or use Product > Archive for TestFlight/App Store preparation.

### Flutter App

Requirements:

- Flutter SDK
- Android Studio and Android SDK for Android builds
- Xcode for macOS/iOS-related Flutter builds

```bash
cd photolite_flutter
flutter pub get
flutter run
```

Build Android:

```bash
flutter build apk --debug
flutter build apk --release
```

Build macOS:

```bash
flutter build macos --release
```

Project scripts:

```bash
./scripts/build_flutter_android_apk.sh
./scripts/build_flutter_macos_dmg.sh
```

Release signing material is intentionally not checked into the repository. Configure your own Android keystore, Apple signing team, Developer ID certificate, or store-managed signing outside the repo.

## AI-Assisted Development

PhotoLite was built with AI-assisted development. Product direction, interaction details, and testing feedback came from the user, while AI assistance was used for implementation, UI iteration, release documentation, and safety review.

The project still follows a normal engineering workflow: local builds, real-device testing, permission checks, second confirmation for deletion, and sensitive file scanning before publishing.

## Documentation

- [Installation](docs/INSTALL.md)
- [Privacy](docs/PRIVACY.md)
- [TestFlight release checklist](docs/TESTFLIGHT_RELEASE.md)
- [Multiplatform release notes](docs/MULTIPLATFORM_RELEASE.md)
- [Contributing](CONTRIBUTING.md)

## Contributing

Issues and pull requests are welcome. Before contributing, please make sure:

- Do not commit local photos, test media, or private data.
- Do not commit signing certificates, keystores, provisioning profiles, or `.env` files.
- Changes touching deletion flows must preserve the second confirmation step.

## License

PhotoLite is released under the [MIT License](LICENSE).
