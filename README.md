# PhotoLite

PhotoLite 是一个本地优先的照片分组滑动清理 App。它把照片随机分成一组一组处理，通过手势快速筛选，只有在每组结束后的二次确认里再次确认，才会真正删除照片。

## 项目结构

- `PhotoSwipeCleaner.xcodeproj`：原生 iPhone SwiftUI 版本，用于本地开发、TestFlight 和后续 App Store。
- `PhotoSwipeCleaner/`：iOS 原生版源码。
- `photolite_flutter/`：Flutter 跨平台版本，用于 Android、macOS、Windows。
- `docs/`：发布、安装和多平台开发说明。
- `scripts/`：本地打包脚本。

## 核心体验

- 左滑：下一张
- 右滑：上一张
- 上滑：标记删除
- 每组结束后进入二次确认，确认后才删除
- 删除确认页可以取消单张照片的删除选择
- 支持设置每组照片数量、照片时间范围、震动反馈等选项
- macOS 版支持方向键和 WASD 操作

## 平台状态

| 平台 | 状态 | 说明 |
| --- | --- | --- |
| iPhone | 原生 SwiftUI 版 | 用于本地开发、TestFlight 和后续 App Store |
| Android | Flutter 版 | 可本地构建 APK；公开分发前需要配置 release signing |
| macOS | Flutter 版 | 默认读取系统“照片”图库，也保留文件夹模式备用 |
| Windows | Flutter 版 | 工程已保留 Windows 目录，后续在 Windows 设备上构建安装包 |

## 隐私和安全

- 照片处理在本地完成，不上传服务器。
- 删除采用“滑动标记 -> 组末二次确认 -> 系统删除流程”的模式。
- iOS / macOS 使用系统相册权限。
- 桌面文件夹模式只处理用户主动选择的文件夹。
- 仓库不应提交本地构建产物、签名证书、Provisioning Profile、APK、DMG 或 Archive。

更详细的隐私说明见 `docs/PRIVACY.md`。

## 本地构建

### iPhone 原生版

用 Xcode 打开：

```bash
open PhotoSwipeCleaner.xcodeproj
```

然后选择真机运行，或通过 `Product > Archive` 准备 TestFlight / App Store 上传。

### Flutter 版

```bash
cd photolite_flutter
flutter pub get

# Android APK
flutter build apk --release

# macOS App
flutter build macos --release
```

也可以使用项目脚本生成本地安装包：

```bash
./scripts/build_flutter_android_apk.sh
./scripts/build_flutter_macos_dmg.sh
```

## 文档

- `docs/INSTALL.md`：用户安装说明。
- `docs/TESTFLIGHT_RELEASE.md`：iPhone TestFlight 发布清单。
- `docs/MULTIPLATFORM_RELEASE.md`：Flutter 跨平台开发和打包说明。
- `docs/PRIVACY.md`：隐私和本地处理说明。

## 开源协议

本项目使用 MIT License，见 `LICENSE`。

## 贡献

欢迎提交 issue 和 pull request。开始前请先阅读 `CONTRIBUTING.md`。
