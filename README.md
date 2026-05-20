# PhotoLite

简体中文 | [English](README.en.md)

PhotoLite 是一个本地优先的照片筛选和清理 App。它会把照片按组展示，用户通过手势快速浏览、标记不想保留的照片，并且只有在二次确认后才会真正删除。

当前仓库包含两个实现：

- 原生 SwiftUI iPhone 版
- Flutter 跨平台版，覆盖 Android、macOS，并保留 Windows 工程

## 版本

| 版本 | 平台 | 安装包 | 状态 |
| --- | --- | --- | --- |
| PhotoLite 1.0.0 | Android | `PhotoLite-Android-preview.apk` | 可下载预览版 |
| PhotoLite 1.0.0 | macOS | `PhotoLite-macOS-release.dmg` | 可下载预览版 |
| PhotoLite 1.0.0 | iPhone | 暂不提供 GitHub 安装包 | 源码可用，适合 Xcode / TestFlight / App Store |
| PhotoLite 1.0.0 | Windows | 暂未发布安装包 | 工程已保留，等待后续打包验证 |

## 下载

最新公开预览版在 GitHub Releases 页面：

[下载 PhotoLite 1.0.0](https://github.com/songjack152/PhotoLite/releases/tag/v1.0.0)

当前提供的安装包：

- `PhotoLite-Android-preview.apk`
- `PhotoLite-macOS-release.dmg`

注意：

- Android APK 使用临时 preview signing key 签名。后续如果切换正式签名，设备上可能需要先卸载旧预览版再安装新版。
- macOS DMG 目前还没有 Developer ID 签名和 notarization。macOS 首次打开时可能需要右键 App，然后选择“打开”。
- iPhone 安装包不通过 GitHub Release 分发。iPhone 版建议使用 Xcode 本机运行、TestFlight 或 App Store。

## 截图

以下为示例截图，不包含真实用户照片。

<p>
  <img src="docs/screenshots/review.svg" alt="PhotoLite 照片筛选界面" width="220">
  <img src="docs/screenshots/confirm.svg" alt="PhotoLite 二次确认界面" width="220">
  <img src="docs/screenshots/settings.svg" alt="PhotoLite 设置界面" width="220">
</p>

<p>
  <img src="docs/screenshots/macos.svg" alt="PhotoLite macOS 界面" width="680">
</p>

## 功能

- 按组筛选照片，支持调整每组照片数量
- 以手势为主的操作方式：
  - 左滑：下一张
  - 右滑：上一张
  - 上滑：标记删除
- 每组结束后进入二次确认页
- 二次确认页可以单独取消某一张照片的删除选择
- 展示照片信息，包括日期、分辨率、文件大小和可用的地点信息
- 支持照片时间范围筛选，例如近一个月、近三个月、近半年、近一年、近五年
- 支持移动端震动反馈
- macOS 版支持方向键和 WASD 操作
- 本地优先，没有后端服务

## 核心流程

PhotoLite 的删除流程强调避免误删：

1. 从系统相册或用户选择的文件夹读取照片。
2. 随机打乱照片，并按组进入筛选流程。
3. 用户通过手势逐张筛选。
4. 上滑只会把照片标记为待删除。
5. 每组结束后，用户在二次确认页重新检查待删除照片。
6. 只有用户明确确认后，App 才会调用系统删除能力或本地文件处理流程。

也就是说，滑动本身不会直接删除照片。

## 平台状态

| 平台 | 实现方式 | 当前状态 |
| --- | --- | --- |
| iPhone | 原生 SwiftUI | 源码已包含。适合本地开发、TestFlight 和后续 App Store 分发。 |
| Android | Flutter | Release 页面已提供 preview APK。使用 Android 媒体/照片权限。 |
| macOS | Flutter | Release 页面已提供 DMG。默认读取系统“照片”图库，同时保留文件夹模式。 |
| Windows | Flutter | 工程文件已包含。安装包和完整验证仍待完成。 |

## 开发方式

PhotoLite 采用 AI 协作开发完成，主要由用户提出产品方向、交互反馈和测试结果，再通过 AI 辅助进行代码实现、界面迭代、发布文档整理和安全检查。

项目仍然遵循正常软件工程流程：本地构建、真机测试、权限检查、删除流程二次确认、开源前敏感信息扫描。

## 安装

面向普通用户的安装步骤见 [docs/INSTALL.md](docs/INSTALL.md)。

简要说明：

- Android：从 Release 下载 APK，安装时按系统提示允许浏览器或文件管理器安装未知来源应用。
- macOS：从 Release 下载 DMG，把 PhotoLite 拖到 Applications，首次打开时允许照片权限。
- iPhone：开发测试可用 Xcode 真机运行；面向其他用户分发时走 TestFlight 或 App Store。

## 隐私

PhotoLite 是本地优先工具：

- 没有后端服务。
- 不上传照片。
- 照片元数据只用于本地展示和筛选。
- 删除只会在用户二次确认后，通过平台 API 或本地文件流程执行。
- 仓库不包含签名证书、Provisioning Profile、keystore、本地构建产物、APK、DMG 或 Archive。

详细说明见 [docs/PRIVACY.md](docs/PRIVACY.md)。

## 项目结构

```text
PhotoSwipeCleaner.xcodeproj       原生 iPhone SwiftUI 工程
PhotoSwipeCleaner/                iOS 原生版源码
photolite_flutter/                Android、macOS、Windows Flutter 版
docs/                             安装、隐私和发布说明
scripts/                          本地打包脚本
```

## 本地构建

### iPhone 原生版

环境要求：

- macOS
- Xcode
- 如需分发到设备、TestFlight 或 App Store，需要 Apple Developer 账号

打开工程：

```bash
open PhotoSwipeCleaner.xcodeproj
```

然后在 Xcode 中选择真机运行，或通过 Product > Archive 准备 TestFlight / App Store 上传。

### Flutter 版

环境要求：

- Flutter SDK
- Android Studio 和 Android SDK，用于 Android 构建
- Xcode，用于 macOS / iOS 相关 Flutter 构建

安装依赖：

```bash
cd photolite_flutter
flutter pub get
```

本地运行：

```bash
flutter run
```

构建 Android：

```bash
flutter build apk --debug
flutter build apk --release
```

构建 macOS：

```bash
flutter build macos --release
```

项目脚本：

```bash
./scripts/build_flutter_android_apk.sh
./scripts/build_flutter_macos_dmg.sh
```

正式发布所需的签名材料不会提交到仓库。请在仓库外配置自己的 Android keystore、Apple Team、Developer ID 证书或商店托管签名。

## 安全提醒

PhotoLite 是照片清理工具，不是备份工具。

- 删除前请认真检查二次确认页。
- 重要照片建议保留外部备份。
- Android 预览版后续如果更换签名，可能需要先卸载再安装。
- macOS 未签名版本可能显示系统安全提示。

## 文档

- [安装说明](docs/INSTALL.md)
- [隐私说明](docs/PRIVACY.md)
- [TestFlight 发布清单](docs/TESTFLIGHT_RELEASE.md)
- [跨平台发布说明](docs/MULTIPLATFORM_RELEASE.md)
- [贡献指南](CONTRIBUTING.md)

## 路线图

- 稳定的 Android 签名和发布流程
- macOS Developer ID 签名和 notarization
- Windows 安装包和完整验证
- 更完整的截图和演示素材
- 针对删除确认流程补充自动化测试

## 作者

由 [songjack152](https://github.com/songjack152) 维护。

## 开源协议

PhotoLite 使用 [MIT License](LICENSE)。
