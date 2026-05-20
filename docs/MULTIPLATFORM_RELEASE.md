# PhotoLite 跨平台开发与打包说明

## 当前状态
- iPhone 原生版：继续维护，用于 TestFlight 和后续 App Store。
- Flutter 跨平台版：位于 `photolite_flutter/`。
- Flutter macOS 版：默认读取系统“照片”图库，同时保留“选择文件夹”模式备用。
- Flutter Android 版：已支持本地构建 APK；公开分发前需要配置 release signing。

## Flutter 版本目标
- Android：读取系统相册，滑动筛选，二次确认，通过系统能力删除。
- macOS：读取系统“照片”图库，滑动筛选，二次确认，通过系统能力删除；文件夹模式作为备用。
- Windows：选择文件夹，滑动筛选，二次确认，后续改为回收站或安装包分发。

## 环境要求
- Flutter SDK
- Android Studio + Android SDK（构建 APK 必需）
- Xcode（构建 iOS/macOS 必需）
- CocoaPods（Flutter iOS/macOS 插件构建建议安装）

## 构建命令
```bash
cd photolite_flutter
flutter pub get
flutter build macos --debug
flutter build apk --debug
```

如果本机缺 Android SDK，需先安装 Android Studio 并初始化 SDK。

## 重要安全策略
- 照片只在本地处理。
- 删除前必须经过二次确认。
- 系统删除确认被取消时，不应展示应用错误。
- 文件夹模式不要直接永久删除，应优先移动到系统废纸篓/回收站或安全回收目录。
- Android 不应使用 debug signing 发布正式安装包。
- Apple Developer Team ID、keystore、证书和 provisioning profile 不应提交到仓库。

## 后续要补的能力
- macOS/Windows 正式安装包签名。
- Windows 回收站移动能力。
- Windows 端完整验证。
