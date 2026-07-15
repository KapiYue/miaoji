# 妙记 App Store 上架清单

更新日期：2026 年 7 月 14 日

## 当前结论

仓库内的主要代码级上架项已经补齐：隐私清单、麦克风用途说明、App 图标、动态版本号、应用内隐私政策入口、账号永久删除、Release 配置拦截、语音 API 鉴权、私有临时录音与清理、生产容器以及后端/iOS 测试。

以下三项仍必须由发布账号持有人完成，当前配置不允许直接归档上传：

1. 把 `personal.MiaoJiAccout.test1` 换成已经在 Apple Developer 注册的正式 Bundle ID。
2. 把 `MIAOJI_API_BASE_URL` 从局域网 HTTP 地址换成已部署、可从公网访问的 HTTPS 地址。
3. 在 Supabase 生产项目执行新增迁移，并创建可交给 App Review 的固定邮箱密码测试账号。

工程中的 `Validate App Store Release Configuration` 构建阶段会在 Release 构建时自动阻止上述错误配置。

## 一、开发者账号和标识符

1. 加入 Apple Developer Program，并确认账号协议没有待处理项。
2. 创建 **Explicit App ID**，例如 `com.yourcompany.miaoji`。Bundle ID 一经发布不应再更改；Apple 要求 App ID 与 Xcode Target 完全一致：[Register an App ID](https://developer.apple.com/help/account/identifiers/register-an-app-id/)。
3. 在 Xcode 的 MiaoJiAccout Target → Signing & Capabilities 选择正确 Team、保持自动签名并填入正式 Bundle ID。
4. 首发建议 `MARKETING_VERSION = 1.0.0`、`CURRENT_PROJECT_VERSION = 1`；每次重新上传必须递增 Build。

## 二、部署生产后端和 Supabase

1. 按 `docs/supabase-migration-guide.md` 在生产 Supabase 项目依次执行并验证三份 SQL；生产写入前先确认项目和备份。
2. 确认 `user-audio` Bucket 为 **Private**、上限 25 MB，并配置额外任务清理 24 小时前对象。
3. 按 `server/Dockerfile` 部署 API，将 `SUPABASE_URL`、`SUPABASE_SECRET_KEY`、`DASHSCOPE_API_KEY` 和 `DASHSCOPE_MODEL` 放入平台 Secret 管理。`SUPABASE_SECRET_KEY` 必须使用仅服务端保存的 `sb_secret_...` Key。
4. 在 Supabase Auth → SMTP Settings 配置自有 SMTP 和发信域名；默认邮件服务仅向项目团队成员邮箱发信且限额极低，不能用于用户验证码或 App Store 审核。
5. 配置公网域名、TLS、`/healthz` 健康检查、每账号/每 IP 限流、告警，以及不记录录音/令牌正文的日志策略。
6. 将 `client/MiaoJiConfig.xcconfig` 的 API 地址换成生产 HTTPS 域名。客户端只能保留 Supabase Publishable/anon key。
7. 在真机验证验证码、密码登录、语音解析、失败重试、退出和永久删除账号。
8. 在 Supabase 创建两个已确认邮箱且设置固定密码的审核账号，放入少量虚构账目。可分别运行 `server/venv/bin/python server/scripts/manage_review_user.py <审核邮箱>`，密码仅在本机终端隐藏输入；凭据只填 App Store Connect，不提交到 Git。

## 三、隐私、协议和合规

1. 用真实运营主体、联系地址、适用法域、服务器地区和第三方服务条款审阅并完善 `privacy-policy.md`、`terms-of-service.md` 和 `support.md`。
2. 将页面部署到稳定、无需登录即可访问的 HTTPS 网站。计划地址为 `miaoji.joy-codex.com`；域名转入腾讯云、ICP 备案和页面部署完成后，再写入最终配置。
3. App Store Connect → App Privacy 填写隐私政策 URL，并按当前代码声明：Email Address、Other Financial Info、Audio Data、User ID；用途均为 App Functionality、与账号关联、不用于 Tracking。Apple 要求同时申报第三方合作方的数据实践：[Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)、[App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)。
4. 应用已为 `UserDefaults` 声明 CA92.1。Apple 要求 Required Reason API 带准确理由：[Required Reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。
5. 应用支持创建账号，因此必须在 App 内删除整个账号及关联数据；本项目已提供入口：[Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)。
6. `ITSAppUsesNonExemptEncryption = NO` 已设置，表示仅使用系统 HTTPS/钥匙串等豁免加密且没有自研或非豁免加密。功能变化后要重新判断：[Export compliance](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)。
7. 如选择中国大陆商店，需要为“妙记”完成 APP 备案并取得 APP 备案号；`miaoji.joy-codex.com` 同时承载支持页面/API 时还要另行完成网站备案，只有 APP 备案不能直接开站。缺失或不匹配会导致无法在中国大陆上架：[App statuses and ICP](https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/)。不具备材料时先取消中国大陆可用性。
8. Supabase 项目位于新加坡，邮箱、账号标识、账本和语音临时文件会发生跨境传输。应用已在云登录前增加独立同意开关，并在登录后写入版本化的云端同意记录；发布前还需填写运营者实名、完成个人信息保护影响评估，并由专业人士确认适用的跨境传输条件。

## 四、创建 App Store Connect 记录

1. Apps → `+` → New App，填写 iOS、名称“妙记”、简体中文、正式 Bundle ID、内部 SKU。
2. App Information 填写名称/副标题、Finance 分类、Content Rights、年龄分级问卷、DSA 状态和地区合规信息。应用不能保持 Unrated。
3. Pricing and Availability 选择价格、地区和发布方式。收费 App 或 IAP 需要 Paid Apps Agreement 及税务/银行资料；免费 App 不需要 Paid Apps Agreement：[Agreements](https://developer.apple.com/help/app-store-connect/manage-agreements/sign-and-update-agreements/)。

## 五、商品页材料

1. 使用 `docs/app-store-metadata-zh-CN.md` 准备简体中文描述、关键词、宣传文本、支持 URL、隐私政策 URL、版权和更新说明。
2. 当前 Target 已改为仅 iPhone。按 `docs/app-store-screenshot-guide.md` 在 iPhone 17 Pro Max 生成简体中文截图；首发不需要 iPad 截图。Apple 允许界面一致时上传所需的最高分辨率截图并自动缩放：[Screenshots](https://developer.apple.com/help/app-store-connect/manage-app-information/upload-app-previews-and-screenshots/)。
3. 截图覆盖首页、统计、历史和设置；内置截图启动参数只会加载虚构账目，不连接云同步服务，也不会污染普通用户数据。
4. 名称、截图和描述中不要使用“专业版”等未实际提供的付费权益文案。

## 六、审核信息

在 App Review Information 填写联系人、电话、邮箱和以下说明：

```text
妙记可不登录使用本地手动记账。语音解析和云同步需要登录。

审核测试账号：<固定邮箱>
密码：<固定密码>

测试语音：设置 → 云同步 → 登录并开启云同步 → 邮箱密码；
登录后回首页打开语音记账，允许麦克风，说“午餐 45 元，打车 28 元”。

删除账号：设置 → 云同步 → 永久删除账号与数据。
删除不可撤销；如审核期间执行，请使用备用账号或联系我们重建。
```

Apple 要求提供可访问完整功能的有效演示账号和特殊配置说明：[App Review information](https://developer.apple.com/app-store/review/)。建议准备两个等价审核账号。

## 七、测试和上传

1. 运行后端测试：`server/venv/bin/python -m unittest server/test_app.py`。
2. Xcode 执行 Product → Test；至少覆盖一台大屏 iPhone、一台较小屏 iPhone 和项目声明的最低 iOS 系统。首发不支持 iPad，不应把 iPad 测试或截图列为提交要求。
3. TestFlight 重点回归：全新安装/升级/重装、离线与弱网、麦克风拒绝、超时和空结果、跨设备同步、账号删除、深浅色/横竖屏/动态字体/VoiceOver、CSV 导出。
4. 选择 Any iOS Device (arm64) → Product → Archive → Validate App，清除全部错误和需处理警告。
5. Distribute App → App Store Connect → Upload。Bundle ID、版本和 Build 决定构建归属，Build 必须唯一：[Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)。
6. 构建处理完成后选择 Build、完成出口合规等缺失字段，并先用 TestFlight 验证生产环境。
7. Add for Review → Draft Submission → Submit for Review：[Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)。

## 八、发布后

1. 监控 API 5xx、延迟、AI 成本、Supabase Auth/Storage 和崩溃，不记录用户账目、音频或令牌正文。
2. 持续确认账号删除、存储兜底清理和支持邮箱可用。
3. 每次更新递增 Build，重新核对隐私标签、政策、第三方 SDK、Required Reason API 和审核账号。
