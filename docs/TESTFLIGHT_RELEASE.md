# PhotoLite TestFlight 发布清单

## 当前状态
- 已完成本地 iPhone Archive。
- 当前 Archive 路径：`build/PhotoLite.xcarchive`
- Bundle ID：`io.github.songjack152.PhotoLite`
- 版本号：`1.0.0 (1)`
- Xcode 里当前显示的是 `Personal Team`，这通常不够上传 TestFlight。

## 必要前提
- Apple Developer Program 账号
- App Store Connect 访问权限
- 账号已签署最新的 Apple Developer Agreement
- App Store Connect 里已创建对应的 App 记录

## 需要准备的内容
- App 名称：`PhotoLite`
- Bundle ID：当前 iOS 工程使用的 Bundle ID
- App 图标
- App 截图
- 简短描述
- 隐私政策链接
- 支持网址或联系邮箱

## 发布步骤
1. 在 App Store Connect 创建新 App。
2. 选择 `iOS` 平台，填写 App 名称、Primary Language、Bundle ID、SKU。
3. 在 Xcode 里用 `Product > Archive` 生成发布包。
4. 在 Organizer 里选择 `Distribute App > App Store Connect`。
5. 按向导上传到 App Store Connect。
6. 先创建内部测试。
7. 稳定后再开外部 TestFlight。

## 审核关注点
- 照片处理只在本地进行，不上传服务器。
- 删除前有组内二次确认。
- 用户可在二次确认页取消单张照片删除。
- 需要明确说明照片权限用途。

## 测试建议
- 先邀请 2 到 3 个测试用户验证安装和核心流程。
- 重点看授权流程、删除流程、误操作恢复感受。
- 如果 UI 或手势还会改，先继续用 TestFlight，不要急着正式上架。

## 你现在要做的事
1. 登录 App Store Connect。
2. 如果还没有 Apple Developer Program 会员，先完成订阅。
3. 创建 App 记录。
4. 回到 Xcode Organizer 重新点 `Distribute App`。
