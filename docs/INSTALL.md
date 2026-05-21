# PhotoLite 安装说明

## iPhone
当前 iPhone 版不通过 GitHub Release 提供安装包。iOS 不能像 Android APK 一样让普通用户直接下载安装，面向他人测试或公开发布时应使用 TestFlight 或 App Store。

### 给自己开发测试

1. 安装完整 Xcode。
2. 用 Xcode 打开 `PhotoSwipeCleaner.xcodeproj`。
3. 连接 iPhone，并在 Xcode 顶部选择这台设备。
4. 设置自己的 Apple Account 和 Bundle Identifier。
5. 点击 Run 安装到自己的 iPhone。

这种方式适合开发调试，不适合发给普通用户安装。免费 Apple Account 安装的开发版通常有时间限制，且每台设备都需要单独处理。

### 给其他人测试

1. 用户先在 App Store 安装 `TestFlight`。
2. 开发者加入 Apple Developer Program，并在 App Store Connect 创建 App。
3. 开发者用 Xcode Archive 上传构建到 App Store Connect。
4. 如果是外部测试用户，构建需要通过 Apple 的 Beta App Review。
5. 开发者在 App Store Connect 里添加测试用户，或生成 TestFlight 公开链接。
6. 用户点邀请链接，在 TestFlight 里安装 `PhotoLite`。
7. 第一次打开时允许照片权限。

### 正式发布

正式面向公众发布时，需要通过 App Store Connect 提交 App Store 审核。审核通过后，用户才能像普通 App 一样从 App Store 安装。

简要结论：

- 自己测试：Xcode 真机运行。
- 外部测试：TestFlight。
- 公开发布：App Store。
- GitHub Release：不提供 iPhone 安装包。

## Android
GitHub Release 提供 Android preview APK。

预览版安装：

1. 从 GitHub Release 下载 `PhotoLite-Android-preview.apk`。
2. 首次安装时，Android 可能要求允许“安装未知来源应用”。
3. 安装完成后打开 PhotoLite。
4. 第一次打开时允许照片/媒体权限。

当前 APK 使用 preview signing key。后续如果切换正式 release signing key，Android 设备可能需要先卸载旧 preview 版本再安装新版。

本地调试构建：

1. 进入 `photolite_flutter/`。
2. 运行 `flutter build apk --debug` 或 `flutter build apk --release`。
3. 如果要长期公开分发，请配置独立 release signing key，或使用 Google Play 签名。

## macOS
GitHub Release 提供 DMG 预览版安装包。

1. 从 GitHub Release 下载 `PhotoLite-macOS-release.dmg`。
2. 打开 DMG，把 App 拖到 Applications。
3. 当前 DMG 未做 Developer ID 签名和 notarization。如果 macOS 提示来自未认证开发者，可以右键 App 选择“打开”。
4. 第一次打开时允许照片权限。
5. 默认使用系统“照片”图库；也可以切换到文件夹模式。

## Windows
Windows 版当前支持文件夹模式，需要在 Windows 机器上构建安装包或压缩包。

当前使用方式：

1. 安装 Flutter SDK、Visual Studio 2022，并勾选 Desktop development with C++。
2. 进入 `photolite_flutter/`。
3. 运行 `flutter build windows --release`。
4. 构建结果位于 `photolite_flutter/build/windows/x64/runner/Release/`。
5. 运行 `PhotoLite.exe`，首次使用时选择照片文件夹。

也可以在仓库根目录的 Windows PowerShell 中运行：

```powershell
.\scripts\build_flutter_windows_zip.ps1
```

脚本会生成 `release/PhotoLite-Windows-release.zip`。

说明：

- Windows 版默认使用文件夹模式，不直接读取系统“照片”应用图库。
- 删除前仍会进入二次确认页。
- 确认删除后，优先移动到 Windows 回收站；如果回收站能力不可用，会退回到所选文件夹下的 `.photolite_trash`。
- 早期未签名版本可能出现 SmartScreen 提示。
