# PhotoLite 安装说明

## iPhone
当前 iPhone 版建议通过 TestFlight 或 App Store 分发。GitHub Release 暂不提供 iOS 安装包。

1. 用户先在 App Store 安装 `TestFlight`。
2. 开发者在 App Store Connect 里添加测试用户或生成公开测试链接。
3. 用户点邀请链接，进入 TestFlight 安装 `PhotoLite`。
4. 第一次打开时允许照片权限。

不建议用 Xcode 真机安装作为公开分发方式。Xcode 真机安装适合开发调试，不适合普通用户安装。

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
Windows 版本还在准备中。

1. 后续会在 Windows 机器上构建 `.exe` 或 `.msix`。
2. 早期版本可能出现 SmartScreen 提示。
3. Windows 首版会优先使用文件夹模式。
