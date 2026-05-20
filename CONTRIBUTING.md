# Contributing to PhotoLite

感谢你愿意改进 PhotoLite。

## 开发原则

- 照片只在本地处理，不上传服务器。
- 任何删除动作都必须经过二次确认。
- UI 优先保持 Apple 风格：克制、清晰、低干扰。
- 不把本地构建产物、签名文件、测试安装包提交到仓库。

## 本地开发

### iPhone 原生版

```bash
open PhotoSwipeCleaner.xcodeproj
```

### Flutter 版

```bash
cd photolite_flutter
flutter pub get
flutter run
```

## 提交前检查

```bash
git status --short
cd photolite_flutter
flutter analyze
```

如果改动影响删除流程，请手动验证：

- 左滑下一张
- 右滑上一张
- 上滑标记删除
- 二次确认页取消单张删除
- 系统删除确认里取消时不会报错
