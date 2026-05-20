# PhotoLite

[简体中文](README.md) | English

PhotoLite is a local-first photo review and cleanup app. It helps you go through a photo library in small batches, use simple gestures to decide what to keep, and confirm deletion before anything is removed.

The project currently contains a native SwiftUI iPhone app and a Flutter implementation for Android, macOS, and Windows.

## Downloads

The latest public preview build is available on the GitHub Releases page:

[Download PhotoLite 1.0.0](https://github.com/songjack152/PhotoLite/releases/tag/v1.0.0)

Available assets:

- `PhotoLite-Android-preview.apk`
- `PhotoLite-macOS-release.dmg`

Notes:

- The Android APK is a preview build signed with a temporary preview signing key. Future builds signed with a different key may require uninstalling the old preview build first.
- The macOS DMG is not Developer ID signed or notarized yet. macOS may require right-clicking the app and choosing Open.
- iPhone builds are not distributed through GitHub Releases. Use Xcode, TestFlight, or the App Store path.

## Features

- Batch-based photo review with adjustable batch size
- Gesture-first workflow:
  - swipe left for next photo
  - swipe right for previous photo
  - swipe up to mark for deletion
- Second confirmation screen before deletion
- Ability to unselect individual photos on the confirmation screen
- Photo metadata display, including date, dimensions, file size, and location when available
- Optional date-range filtering, such as recent month, three months, half year, one year, or five years
- Optional haptic feedback on supported mobile devices
- Keyboard support on macOS, including arrow keys and WASD
- Local-first privacy model with no backend service

## Core Workflow

PhotoLite reviews photos in adjustable batches:

1. Load photos from the platform photo library or a selected folder.
2. Shuffle and split photos into batches.
3. Review photos one by one with gestures.
4. Mark unwanted photos during the batch.
5. Review marked photos at the end of the batch.
6. Delete only after explicit confirmation.

The app is designed to reduce accidental deletion. A swipe only marks a photo; deletion requires a second confirmation step.

## Platform Status

| Platform | Implementation | Status |
| --- | --- | --- |
| iPhone | Native SwiftUI | Source available. Intended for local development, TestFlight, and future App Store distribution. |
| Android | Flutter | Preview APK available in Releases. Uses Android media/photo permissions. |
| macOS | Flutter | DMG available in Releases. Uses the system Photos library by default, with folder mode as a fallback. |
| Windows | Flutter | Project files are included. Packaging and full validation are still pending. |

## Installation

End-user installation steps are maintained in [docs/INSTALL.md](docs/INSTALL.md).

Short version:

- Android: download the preview APK from Releases and allow installation from the browser or file manager if Android asks.
- macOS: download the DMG from Releases, drag PhotoLite into Applications, then allow Photos access on first launch.
- iPhone: build from Xcode for local testing, or distribute through TestFlight/App Store when using an Apple Developer account.

## Privacy

PhotoLite is local-first:

- No backend service is included.
- Photos are not uploaded.
- Photo metadata is used only for local display and filtering.
- Deletion is performed through platform APIs or local file handling after user confirmation.
- The repository does not include signing keys, provisioning profiles, keystores, local build outputs, APKs, DMGs, or archives.

See [docs/PRIVACY.md](docs/PRIVACY.md) for more detail.

## Current Limitations

- Android preview builds are not signed with a long-term production key yet.
- macOS builds are not notarized yet, so the first launch may show a macOS security prompt.
- Windows packaging is present in source form, but an official Windows installer has not been published yet.
- Store distribution, automatic updates, and formal release signing are future work.

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
- An Apple Developer account for device distribution or TestFlight

Open the project:

```bash
open PhotoSwipeCleaner.xcodeproj
```

Run on a device from Xcode, or use Product > Archive for TestFlight/App Store preparation.

### Flutter App

Requirements:

- Flutter SDK
- Android Studio and Android SDK for Android builds
- Xcode for macOS/iOS-related Flutter builds

Install dependencies:

```bash
cd photolite_flutter
flutter pub get
```

Run locally:

```bash
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

## Safety Notes

PhotoLite is a photo cleanup tool, not a backup tool.

- Review the confirmation screen before deleting.
- Keep an external backup of important photos.
- On Android preview builds, future updates may require reinstalling if the signing key changes.
- On macOS, unsigned builds may show system security warnings.

## Documentation

- [Installation](docs/INSTALL.md)
- [Privacy](docs/PRIVACY.md)
- [TestFlight release checklist](docs/TESTFLIGHT_RELEASE.md)
- [Multiplatform release notes](docs/MULTIPLATFORM_RELEASE.md)
- [Contributing](CONTRIBUTING.md)

## Roadmap

- Stable Android signing and release workflow
- macOS Developer ID signing and notarization
- Windows packaging and validation
- More complete screenshots and demo media
- Stronger automated tests around deletion and confirmation flows

## Author

Maintained by [songjack152](https://github.com/songjack152).

## License

PhotoLite is released under the [MIT License](LICENSE).
