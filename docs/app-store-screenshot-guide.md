# App Store 截图与测试数据指南

首发范围：iPhone + iPad、简体中文、浅色模式。截图只能使用虚构账目，不显示审核邮箱、真实财务信息、通知或生产服务地址。

## 已内置的安全截图模式

启动参数 `--screenshot-demo-data` 会：

- 载入确定性的虚构人民币账目、收入和 7,200 元月预算；
- 使用更适合商品页展示的餐饮、交通、鲜花、居家等标题，以及当前月加前六个月组成的近七个月趋势数据；
- 禁用云同步服务，避免截图运行触碰生产数据；
- 禁止把演示数据写入普通用户偏好；
- 强制浅色模式，保证每次截图外观一致。

启动参数 `--screenshot-tab home|statistics|history|settings` 会直接打开指定页，避免自动化点击受不同设备布局影响。两个参数都只供测试和截图使用，正常启动不会出现演示数据入口。

启动参数 `--screenshot-voice-state ready|recording|analyzing|drafts|saved` 仅在同时启用 `--screenshot-demo-data` 时生效，用确定性的安全状态展示语音记账流程。它不会申请麦克风权限、连接审核账号或调用生产语音 API；草稿和保存结果固定使用虚构的“午餐 45 元、打车 28 元”。

## App Store Connect 尺寸

| 栏位 | 本项目模拟器 | 纵向尺寸 | 输出目录 | 要求 |
| --- | --- | --- | --- | --- |
| iPhone 6.5 英寸 | CiJing iPhone 14 Plus | 1284 × 2778 | `docs/assets/app-store-connect/zh-Hans/iphone-6.5/` | 符合当前 6.5 英寸上传框；不要继续上传旧的 1320 × 2868 文件 |
| iPad 13 英寸 | iPad Pro 13-inch (M5) | 2064 × 2752 | `docs/assets/app-store-connect/zh-Hans/ipad-13/` | App 支持 iPad 时必填的最高规格栏位 |

Apple 当前也接受 iPhone 6.5 英寸的 1242 × 2688 和 iPad 13 英寸的 2048 × 2732 等兼容尺寸；本项目固定使用上表尺寸，减少混用。

## 推荐截图组

两种设备各上传以下 9 张，顺序保持一致：

1. `01-home.png`：**说一句，多笔账一起记**。展示首页语音入口、本月/今日概览和最近记录；
2. `01a-voice-ready.png`：**打开语音记账**。展示功能说明、语音示例和开始录音按钮；
3. `01b-voice-recording.png`：**连续说出多笔消费**。展示正在聆听状态和停止录音按钮；
4. `01c-voice-analyzing.png`：**AI 自动理解并拆分**。展示录音结束后的解析状态；
5. `01d-voice-drafts.png`：**保存前逐条核对**。展示“午餐 45 元、打车 28 元”两笔草稿；
6. `01e-voice-saved.png`：**两笔一起记入账本**。展示统一保存后最近记录中的午餐与打车；
7. `02-statistics.png`：**分类与趋势，消费更明白**。展示记录数、平均每笔、近七个月趋势和分类占比；
8. `03-history.png`：**想找哪笔，马上定位**。展示全文搜索、快捷筛选、日期汇总和账目时间线；
9. `04-settings.png`：**同步可选，数据由你管理**。展示本地优先、可选云同步、人民币、多主题、预算提醒和分类管理。

基础页面数据必须互相吻合：`¥3,025.90 ÷ ¥7,200 ≈ 42%`，首页当天 4 笔合计 `¥170.80`，统计页与设置页使用同一预算口径。语音流程中的两笔合计 `¥73.00`，保存完成页会在基础数据上增加这两笔。当前仓库保存的是应用真实界面原图，不在截图上覆盖可能遮挡内容的营销文字。

## 自动生成与校验

在仓库根目录运行：

```bash
./scripts/capture-app-store-screenshots.sh
```

脚本会完成以下工作：

1. 构建 iOS Simulator App；
2. 启动指定的 6.5 英寸 iPhone 和 13 英寸 iPad；
3. 将状态栏固定为 9:41、满电；
4. 逐页启动安全截图模式并输出 18 张 PNG（每种设备 9 张）；
5. 用 `sips` 校验每张图的像素尺寸，不符合规格时立即失败。

如本机模拟器 UUID 不同，可覆盖环境变量：

```bash
MIAOJI_IPHONE_SIMULATOR_ID=<iphone-uuid> \
MIAOJI_IPAD_SIMULATOR_ID=<ipad-uuid> \
./scripts/capture-app-store-screenshots.sh
```

## 人工验收

每张图逐项确认：

- iPhone 是 1284 × 2778，iPad 是 2064 × 2752，PNG 不含透明通道；
- iPad 使用双栏或网格充分利用宽度，没有把手机页面简单居中放大；
- 状态栏、中文、金额、小数、日期和币种显示正常，无截断、遮挡或弹窗；
- 不含真实姓名、邮箱、账号、通知、网络地址或财务数据；
- 截图与待提交构建的真实功能一致；
- 文案不承诺尚未实现的权益、识别准确率或“绝对安全”。

每种设备可以上传 1–10 张截图，App Preview 视频首版可留空。详见 Apple 的 [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications) 和 [Upload app previews and screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots)。
