# PhotoLite Flutter

这是 PhotoLite 的 Flutter 跨平台实现，用于 Android、macOS 和后续 Windows 版本。

根目录的 iPhone 原生版仍然保留，Flutter 版主要承担跨平台发布和桌面端能力。

## 当前能力

- Android：读取系统相册、滑动筛选、二次确认删除、分享、设置。
- macOS：默认读取系统“照片”图库，保留文件夹模式备用。
- macOS：支持鼠标拖动、方向键、WASD。
- Windows：工程结构已保留，后续在 Windows 设备上继续构建和验证。

## 开发

```bash
flutter pub get
flutter run
```

## 构建

```bash
# Android
flutter build apk --release

# macOS
flutter build macos --release
```

更多发布说明见根目录 `docs/`。
