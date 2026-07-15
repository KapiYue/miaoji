# App Store 截图与测试数据指南

首发范围：仅 iPhone、简体中文、浅色模式。截图只能使用虚构账目，不显示审核邮箱、真实财务信息或真实通知。

## 已内置的安全截图模式

启动参数 `--screenshot-demo-data` 会：

- 载入一组确定性的虚构人民币账目和 6,800 元月预算；
- 禁用云同步服务，避免截图运行触碰生产数据；
- 禁止把演示数据写入普通用户偏好；
- 强制使用浅色模式，保证每次截图外观一致。

不要把“截图模式”做成 App 内可见入口。它仅供 UI 测试启动参数使用，正常启动不会加载虚构数据。

## 推荐截图组

使用 iPhone 17 Pro Max 模拟器生成 6.9 英寸截图，首发上传以下 4 张：

1. 首页：`一眼看清本月收支`；
2. 统计：`分类与趋势，消费更明白`；
3. 历史：`每一笔记录都可追溯`；
4. 设置：`云同步与隐私，数据由你管理`。

如要增加第 5 张语音草稿，应使用预置的虚构草稿，不要在截图时调用真实百炼接口。截图装饰标题可以后期置于画布安全区，但不能改变或伪造实际功能界面。

## 自动生成原始截图

在仓库根目录运行：

```bash
xcodebuild test \
  -project client/MiaoJiAccout.xcodeproj \
  -scheme MiaoJiAccout \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=26.5' \
  -only-testing:MiaoJiAccoutUITests/MiaoJiAccoutUITests/testCaptureAppStoreScreenshots \
  -resultBundlePath /tmp/MiaoJiScreenshots.xcresult
```

导出测试附件：

```bash
xcrun xcresulttool export attachments \
  --path /tmp/MiaoJiScreenshots.xcresult \
  --output-path docs/assets/app-store-screenshots
```

UI 测试会以 `zh-Hans` / `zh_CN` 启动并生成 `01-home`、`02-statistics`、`03-history`、`04-settings` 四张 PNG。

仓库已生成并验收一组原始截图，位于 `docs/assets/app-store-screenshots/`，文件名依次为 `01-home-zh-CN.png`、`02-statistics-zh-CN.png`、`03-history-zh-CN.png` 和 `04-settings-zh-CN.png`。

## 人工验收

每张图逐项确认：

- 尺寸是 App Store Connect 当前接受的 6.9 英寸 iPhone 尺寸；
- PNG 不含透明通道；
- 状态栏、中文、金额、小数、日期和币种显示正常；
- 不含真实姓名、邮箱、账号、通知、网络地址或财务数据；
- 截图与待提交构建的真实界面一致；
- 文案不承诺尚未实现的免费权益、精确识别率或“绝对安全”。

App Store Connect 每种设备尺寸允许 1–10 张截图。当前 Target 已改为仅 iPhone，因此首发不需要 iPad 截图；如以后恢复 iPad 支持，必须重新做布局回归并补齐 iPad 商品页截图。
