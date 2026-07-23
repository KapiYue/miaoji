# 妙记 AI 账本 App Store Connect 填写卡

更新日期：2026-07-22

这份卡片参考词鲸项目的填写方式，按 App Store Connect 当前页面分区整理。`可直接填写` 的内容已经与妙记当前代码和素材核对；`待本人确认` 涉及产品命名、真实身份或发行选择；`提交阻塞` 表示在送审前必须完成。

## 一、1.0 Prepare for Submission

### 简体中文商品页

| 字段 | 可填写内容 | 状态 |
| --- | --- | --- |
| Promotional Text | 说一句或手动输入，快速记下每笔收支。分类预算、趋势统计和可选云同步，让日常账目更清楚。 | 可直接填写，43 个字符 |
| Description | 见下方完整文案 | 可直接填写，少于 4000 个字符 |
| Keywords | `收支,支出,收入,预算,财务,流水,账单,日常开销,个人理财,分类分析,现金流` | 可直接填写，UTF-8 共 97 bytes |
| Support URL | `https://miaoji.joy-coder.com/support` | **提交阻塞**：2026-07-22 实测域名尚无法解析；部署后再填 |
| Marketing URL | 留空 | 可选项；官网正式上线后可改填 `https://miaoji.joy-coder.com/` |
| Version | `1.0` | 与工程 `MARKETING_VERSION = 1.0` 一致 |
| Copyright | `2026 Zhang Jing` | 参考词鲸项目已确认的个人著作权主体；提交前确认继续使用该拼写 |
| Routing App Coverage File | 留空 | 妙记不是地图导航 App，不上传 `.geojson` |
| What’s New in This Version | 不填写 | 首个版本没有此字段；后续更新版本才需要填写 |

Description：

> 妙记 AI 账本是一款简洁、本地优先的个人记账应用。无需注册账号，即可使用手动记账、预算、统计和 CSV 导出；需要时，也可以登录开启跨设备云同步和语音记账。
>
> 【快速记下每笔收支】
> 记录收入或支出，填写金额、分类、日期和备注。常用分类与月度预算可以按自己的习惯调整。
>
> 【说一句，生成多笔记账草稿】
> 登录后说出“午餐 45 元，打车 28 元”，妙记会拆分为待确认的记账草稿。保存前可以逐项核对和修改，避免识别误差直接进入账本。
>
> 【看清预算与消费趋势】
> 首页汇总本月收支和预算进度，统计页展示分类占比与月度、季度和年度趋势，历史页帮助你快速回顾和查找每笔记录。
>
> 【本地优先，可选云同步】
> 不登录也能使用核心手动记账功能。开启云同步后，可在更换设备时恢复账本；应用会在开启前说明数据处理与跨境传输情况，并征求你的选择。
>
> 【数据由你管理】
> 支持导出 CSV、清除本机账目、退出云同步，以及在应用内永久删除账号和关联数据。妙记不接入广告 SDK，不进行跨应用跟踪，也不出售个人数据。
>
> 提示：语音识别和 AI 生成内容可能不准确，请在保存前核对。妙记是个人记录工具，不构成财务、投资、税务或法律建议。

### 截图

| 顺序 | 文件 | 展示重点 | 规格与状态 |
| --- | --- | --- | --- |
| 1 | `docs/assets/app-store-screenshots/01-home-zh-CN.png` | 语音与手动快速记账、本月概览 | 1320 × 2868、PNG、无透明通道，可直接上传到 iPhone 6.9 英寸栏位 |
| 2 | `docs/assets/app-store-screenshots/02-statistics-zh-CN.png` | 分类占比与消费趋势 | 同上 |
| 3 | `docs/assets/app-store-screenshots/03-history-zh-CN.png` | 可搜索的账目历史 | 同上 |
| 4 | `docs/assets/app-store-screenshots/04-settings-zh-CN.png` | 云同步、导出与隐私管理 | 同上 |

当前 Target 仅支持 iPhone，`TARGETED_DEVICE_FAMILY = 1`，因此首版不上传 iPad 截图。App Preview 视频留空；首版不是必需项。

### Build 与发布方式

| 项目 | 填写或处理 |
| --- | --- |
| Bundle ID | `com.joy-coder.miaoji`，与当前工程一致 |
| Version / Build | `1.0 (1)`；重新上传二进制前递增 Build |
| 最低系统 | iOS 18.0 |
| 支持设备 | 仅 iPhone |
| Build | 生产配置完成后通过 Xcode Organizer 上传；等待 Processing 完成后在 1.0 页选择该构建 |
| Export Compliance | 当前仅使用系统 HTTPS/TLS，工程设置 `ITSAppUsesNonExemptEncryption = NO`；按最终二进制确认“不使用非豁免加密” |
| Version Release | 首版建议 `Manually release this version`，审核通过后手动发布 |
| Phased Release | 首版不适用；后续更新再考虑分阶段发布 |

当前 `MIAOJI_API_BASE_URL` 仍为局域网 HTTP 地址 `192.168.5.109:8000`。选择送审 Build 前必须替换为审核设备可访问的生产 HTTPS 服务，并完成语音记账真机验证。

## 二、App Review Information

此区域位于 **1.0 Prepare for Submission** 页面靠下位置，不是左侧只显示提交记录与审核消息的 **App Review** 页面。

| 字段 | 填写内容 | 状态 |
| --- | --- | --- |
| Contact Name | `张静` | 参考词鲸项目已确认信息，提交前复核 |
| Contact Email | `zdjoey@126.com` | 参考词鲸项目已确认信息，提交前复核 |
| Contact Phone | `+86 158 6711 6034` | 参考词鲸项目已确认信息，提交前确认审核期间可接听 |
| Sign-in required | 勾选 | 手动记账无需登录，但完整测试语音和云同步需要登录 |
| Username | `test1@126.com` | 仓库文档记录该账号已创建并确认邮箱；送审前重新验证 |
| Password | 填写该审核账号的固定密码 | **提交阻塞**：只填 App Store Connect，不写入仓库、截图或 Notes |
| Notes | 使用下方文案 | 生产服务和账号验证完成后可直接填写 |

Notes：

> 妙记无需登录即可使用本地手动记账、预算、统计、历史记录和 CSV 导出。云同步与语音记账需要登录，审核账号和密码已填写在上方 Sign-in Information。
>
> 建议审核路径：
> 1. 打开“设置 → 云同步 → 登录并开启云同步”，选择“邮箱密码”，使用上方审核账号登录；
> 2. 首次登录前勾选隐私政策/用户协议同意项与境外云服务传输单独同意项；
> 3. 回到首页，打开“语音输入”，允许麦克风权限并说“午餐 45 元，打车 28 元”；
> 4. App 会生成两笔待确认草稿，可在保存前修改金额、标题和分类；
> 5. 在统计和历史页面查看已保存账目。
>
> 账号可在“设置 → 云同步 → 永久删除账号与数据”中永久删除。删除不可撤销，请不要删除长期审核账号；如需验证删除功能，请使用备用账号或联系我们创建临时账号。
>
> 本版本仅支持 iPhone，当前所有功能免费，没有 App 内购买、订阅、广告或跨 App 跟踪。语音与 AI 生成结果可能不准确，App 始终要求用户确认后再保存。

审核期间必须保持生产 API、Supabase、阿里云百炼、审核账号和公开支持页面在线。建议再准备一个等价备用账号；现有文档记录 `test2@126.com` 尚未创建，创建后只把凭据填入 App Store Connect。

## 三、App Information

### 基础信息

| 字段 | 建议值 | 状态 |
| --- | --- | --- |
| App Name | `妙记AI账本` | **待本人确认**：推荐与安装后的显示名一致；若希望沿用短品牌名，可改为 `妙记`，但二者应统一 |
| Subtitle | `语音记账与预算统计` | 可直接填写，9 个字符 |
| Privacy Policy URL | `https://miaoji.joy-coder.com/privacy` | **提交阻塞**：域名和 HTTPS 生效、页面无需登录可访问后填写 |
| Primary Language | Chinese (Simplified) | 建议保持 |
| Bundle ID | `com.joy-coder.miaoji` | 与当前工程一致，上传 Build 后不可更改 |
| SKU | 已创建 App 记录则保持现有值；尚未创建可用 `miaoji-ios-2026` | **待本人确认**：SKU 创建后不可更改，仅用于内部识别 |
| Primary Category | Finance（财务） | 建议 |
| Secondary Category | Utilities（工具） | 建议 |
| Content Rights | 选择“不包含、展示或访问第三方内容” | 当前 App 处理用户自己的账目和录音，不向用户分发第三方内容；若未来加入第三方文章、行情或其他内容需重答 |
| Made for Kids | 不选择 | 产品不专门面向儿童 |
| License Agreement | Apple Standard EULA | 当前不需要自定义 EULA |

App Store 名称最多 30 个字符、副标题最多 30 个字符；最终名称是否可用只能以创建或保存 App Store Connect 记录时的校验结果为准。

### Age Ratings

按当前 1.0 功能如实回答：

- Parental Controls：No；Age Assurance：No；
- Unrestricted Web Access：No；App 不提供任意网页浏览器；
- User-Generated Content：No；账目只属于用户本人，不在用户之间广泛分发；
- Social Media、Messaging and Chat、Advertising：No；
- Medical or Treatment Information、Health or Wellness Topics：None；
- 暴力、色情、粗俗语言、恐怖、受控物质、赌博、模拟赌博、竞赛和 Loot Boxes：None；
- “Made for Kids”不勾选。

预计会得到最低年龄等级，但最终以 App Store Connect 根据完整问卷生成的各地区结果为准，不能手工固定为某一等级。

### App Encryption Documentation

当前客户端只调用 Apple 操作系统提供的 HTTPS/TLS 等标准加密能力，工程已经声明 `ITSAppUsesNonExemptEncryption = NO`。通常不需要上传加密文档；若最终二进制加入自研加密、VPN 或额外加密层，必须重新判断。

### App Store Regulations & Permits

| 卡片 | 当前处理 |
| --- | --- |
| Digital Services Act | 参考同一开发者的词鲸项目，当前填写 `non-trader`；如果妙记产生收入、广告、联盟营销或被作为商业活动提供，必须重新评估 |
| China Mainland ICP Filing Number | **待本人确认首发是否包含中国大陆及妙记自己的 App 备案进度**；词鲸的备案号不能复用。包含中国大陆时，取得妙记备案编号后填写，并确保 App 名称和主体完全一致 |
| Vietnam Game License | 不操作；妙记不是游戏 |
| Regulated Medical Devices | 不操作；妙记不是医疗设备，也不提供医疗或治疗信息 |
| Production / Sandbox Server URL | 留空；1.0 没有 App 内购买或订阅，不需要 App Store Server Notifications |
| App-Specific Shared Secret | 不创建；没有自动续期订阅收据场景 |

## 四、Pricing and Availability

| 项目 | 建议 |
| --- | --- |
| Price | Free（免费） |
| Distribution | Public — Available on the App Store |
| Regions | **待本人确认**；若选择中国大陆，妙记自己的 App 备案编号是上线前置条件 |
| Pre-Order | 首版不启用 |
| Release | 手动发布 |
| In-App Purchases / Subscriptions | 无，不创建任何商品 |

## 五、App Privacy 填写建议

App Privacy 必须同时覆盖 App 本身和生产环境第三方服务的数据处理。当前代码与隐私政策对应的保守填写如下，所有项目均为 **Linked to User = Yes**、**Used for Tracking = No**、用途仅选择 **App Functionality**：

| App Store Connect 数据类型 | 对应数据与原因 |
| --- | --- |
| Contact Info → Email Address | 邮箱登录、账号鉴权和恢复 |
| Financial Info → Other Financial Info | 收支金额、日期、分类、预算、币种和统计所需账本数据 |
| User Content → Other User Content | 用户自定义的账目标题、备注、分类名及其他自由文本会随云同步上传 |
| User Content → Audio Data | 用户主动提交的语音记账录音会临时上传并交给 AI 解析 |
| Identifiers → User ID | Supabase 账号标识，用于鉴权、同步和数据隔离 |

以下项目不能直接照抄，需要在生产部署完成后核对：

- 如果腾讯云、Supabase、反向代理或其他服务会保留可关联用户的 IP、请求日志、性能数据或错误诊断，按实际用途补充 Device ID、Coarse Location 或 Diagnostics 中的对应类型；
- 当前 `PrivacyInfo.xcprivacy` 已声明 Email Address、Other Financial Info、Audio Data 和 User ID，但尚未声明 `Other User Content`。由于云同步包含用户自由文本，提交前应让隐私清单、App Store 隐私标签和隐私政策三者一致；
- 若生产行为变化，例如接入崩溃分析、广告、归因 SDK 或将数据用于分析，必须重新填写，不能继续沿用“仅 App Functionality / 不追踪”。

Privacy Policy URL 必填；User Privacy Choices URL 首版可留空。App 内已经提供导出、清除记录、退出账号和永久删除账号入口。

## 六、App Accessibility

Accessibility Nutrition Labels 当前可先留空，不应只因为使用 SwiftUI 就声明支持。发布标签前应在 iPhone 上完成 VoiceOver、Voice Control、Larger Text、Dark Interface、Differentiate Without Color Alone、Sufficient Contrast 和 Reduced Motion 的完整常用任务测试。

当前界面中存在多处固定字号，未完成 200% Dynamic Type 验收前不要勾选 Larger Text。Accessibility URL 可留空。

## 七、提交前必须确认或完成

1. **App 名称**：使用与二进制一致的“妙记AI账本”，还是把二进制与商品页统一为“妙记”。
2. **中国大陆发行**：是否首发包含中国大陆；如包含，妙记自己的 App 备案是否已申请、备案名称是什么。
3. **公开 URL**：部署 `miaoji.joy-coder.com` 并验证 `/privacy`、`/support`、`/terms` 无需登录、HTTPS 正常、内容属于妙记。2026-07-22 实测该域名尚无法解析。
4. **生产语音 API**：把局域网 HTTP 地址替换为公网 HTTPS 地址，并用待上传 Release Build 真机验证。
5. **审核账号**：重新验证 `test1@126.com` 的固定密码与完整功能；创建并验证备用账号，密码只填 App Store Connect。
6. **隐私一致性**：确认生产日志保留策略，并处理 `Other User Content` 在隐私清单中的缺项。
7. **发行选择**：确认首发地区、DSA `non-trader` 状态、审核联系人电话和 Copyright 拼写仍然适用。

完成以上项目后，上传并选择正式 Build，在 1.0 页面保存全部信息，点击 **Add for Review** 创建 Draft Submission，再进入左侧 **App Review** 点击 **Submit for Review**。

## 八、Apple 官方字段限制与依据

- [App Information：名称与副标题限制、Bundle ID 和 SKU](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform Version Information：宣传文本、描述、关键词、审核资料和版本发布](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot Specifications：iPhone 截图尺寸](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App Privacy Details：数据类型、关联和追踪定义](https://developer.apple.com/app-store/app-privacy-details/)
- [Age Ratings Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
