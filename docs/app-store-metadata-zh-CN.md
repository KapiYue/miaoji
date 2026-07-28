# 妙记 AI 账本 App Store Connect 填写卡

更新日期：2026-07-23

这份卡片参考词鲸项目的填写方式，按 App Store Connect 当前页面分区整理。`可直接填写` 的内容已经与妙记当前代码和素材核对；`待本人确认` 涉及产品命名、真实身份或发行选择；`提交阻塞` 表示在送审前必须完成。

## 一、1.0 Prepare for Submission

### 简体中文商品页


| 字段                         | 可填写内容                                       | 状态                                                    |
| -------------------------- | ------------------------------------------- | ----------------------------------------------------- |
| Promotional Text           | 说一句或手动输入，快速记下每笔收支。分类预算、趋势统计和可选云同步，让日常账目更清楚。 | 可直接填写，43 个字符                                          |
| Description                | 见下方完整文案                                     | 可直接填写，少于 4000 个字符                                     |
| Keywords                   | `收支,支出,收入,预算,财务,流水,账单,日常开销,个人理财,分类分析,现金流`   | 可直接填写，UTF-8 共 97 bytes                                |
| Support URL                | `https://miaoji.joy-coder.com/support`      | **提交阻塞**：妙记 App 备案申请中；备案通过并恢复域名解析后，验证无需登录且 HTTPS 正常再填 |
| Marketing URL              | 留空                                          | 可选项；官网正式上线后可改填 `https://miaoji.joy-coder.com/`        |
| Version                    | `1.0`                                       | 与工程 `MARKETING_VERSION = 1.0` 一致                      |
| Copyright                  | `2026 Zhang Jing`                           | 已确认该主体及拼写继续适用                                         |
| Routing App Coverage File  | 留空                                          | 妙记不是地图导航 App，不上传 `.geojson`                           |
| What’s New in This Version | 不填写                                         | 首个版本没有此字段；后续更新版本才需要填写                                 |


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

### Previews and Screenshots

当前 Target 已支持 iPhone 与 iPad，`TARGETED_DEVICE_FAMILY = "1,2"`。App Preview 视频首版留空；两种设备分别上传下面 9 张真实应用截图。前 6 张讲清“进入语音记账 → 录音 → AI 拆分 → 核对草稿 → 统一保存”的完整过程，后 3 张继续展示统计、历史和数据管理：


| 顺序与商品页短标题          | 功能重点                                | 画面中的虚构演示数据                                                  | iPhone / iPad 文件                                                         |
| ------------------ | ----------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| 01 **说一句，多笔账一起记**  | 首页语音入口、本月概览、今日概览、最近记录与预算执行。         | 本月支出 `¥3,025.90`、较上月 `-9.4%`、预算执行 `42%`；当天 4 笔合计 `¥170.80`。 | `iphone-6.5/01-home.png` / `ipad-13/01-home.png`                         |
| 02 **打开语音记账**      | 说明 AI 会识别金额和用途并整理明细，展示示例和开始录音按钮。    | 示例固定为“午餐 45 元，打车 28 元，买水果 16.5 元”。                          | `iphone-6.5/01a-voice-ready.png` / `ipad-13/01a-voice-ready.png`         |
| 03 **连续说出多笔消费**    | 正在聆听状态，可结束本次录音。                     | 本次演示实际结果使用“午餐 45 元、打车 28 元”。                                | `iphone-6.5/01b-voice-recording.png` / `ipad-13/01b-voice-recording.png` |
| 04 **AI 自动理解并拆分**  | 录音结束后的 AI 解析状态，明确展示处理过程。            | 不连接生产服务，由安全截图状态复现。                                          | `iphone-6.5/01c-voice-analyzing.png` / `ipad-13/01c-voice-analyzing.png` |
| 05 **保存前逐条核对**     | AI 已拆分两笔明细，可核对金额、标题、分类与时间后统一保存。     | 午餐 `¥45` 归入餐饮，打车 `¥28` 归入交通，合计 `¥73`。                       | `iphone-6.5/01d-voice-drafts.png` / `ipad-13/01d-voice-drafts.png`       |
| 06 **两笔一起记入账本**    | 统一保存后回到首页，两笔语音账目出现在最近记录。            | 最近记录新增午餐 `¥45`、打车 `¥28`，备注来源为 AI 语音解析。                      | `iphone-6.5/01e-voice-saved.png` / `ipad-13/01e-voice-saved.png`         |
| 07 **分类与趋势，消费更明白** | 月/季/年切换、近七个月支出趋势、分类圆环占比、平均每笔和记录数。   | 本月 `19` 笔、平均每笔 `¥159.26`；购物 `¥1,481.10`、占 `48.9%`。          | `iphone-6.5/02-statistics.png` / `ipad-13/02-statistics.png`             |
| 08 **想找哪笔，马上定位**   | 标题/分类/备注搜索、快捷筛选、按日期汇总和账目时间线。        | 今天 `4` 笔合计 `¥170.80`，昨天 `2` 笔合计 `¥239.50`。                  | `iphone-6.5/03-history.png` / `ipad-13/03-history.png`                   |
| 09 **同步可选，数据由你管理** | 本地优先、可选云同步、多币种、深浅主题、预算提醒、月度预算和分类管理。 | 本地模式、人民币 `CNY`、月度总预算 `¥7,200`。                              | `iphone-6.5/04-settings.png` / `ipad-13/04-settings.png`                 |


- 公共根目录：`docs/assets/app-store-connect/zh-Hans/`；
- iPhone：1284 × 2778 PNG，符合截图中 App Store Connect 的 6.5 英寸栏位；旧的 1320 × 2868 文件不上传到该栏位；
- iPad：2064 × 2752 PNG，上传到 13 英寸栏位；App 支持 iPad 时该设备族截图必填；
- 截图使用上述统一的 7,200 元预算和完全虚构的收支、趋势数据，浅色模式，不连接生产环境；所有金额在首页、统计、历史和设置之间保持一致；
- 02–06 使用安全截图状态和完全虚构的语音结果，不申请麦克风权限、不连接审核账号，也不调用生产语音 API；
- App Store Connect 每个设备栏位最多 3 个 App Preview 和 10 张截图，本项目首版上传 9 张截图。

生成、尺寸校验和人工验收方法见 `docs/app-store-screenshot-guide.md`。

### Build 与发布方式


| 项目                | 填写或处理                                                                          |
| ----------------- | ------------------------------------------------------------------------------ |
| Bundle ID         | `com.joy-coder.miaoji`，与当前工程一致                                                 |
| Version / Build   | `1.0 (1)`；重新上传二进制前递增 Build                                                     |
| 最低系统              | iOS 18.0                                                                       |
| 支持设备              | iPhone 与 iPad；已为常用页面增加 iPad 双栏/网格布局                                            |
| Build             | 生产配置完成后通过 Xcode Organizer 上传；等待 Processing 完成后在 1.0 页选择该构建                     |
| Export Compliance | 当前仅使用系统 HTTPS/TLS，工程设置 `ITSAppUsesNonExemptEncryption = NO`；按最终二进制确认“不使用非豁免加密” |
| Version Release   | 首版建议 `Manually release this version`，审核通过后手动发布                                 |
| Phased Release    | 首版不适用；后续更新再考虑分阶段发布                                                             |


当前 `MIAOJI_API_BASE_URL` 仍为局域网 HTTP 地址 `192.168.5.109:8000`。生产语音 API 等备案通过并恢复域名解析后启用；选择送审 Build 前必须替换为审核设备可访问的生产 HTTPS 服务，并在 iPhone 与 iPad 真机完成语音记账验证。

## 二、App Review Information

此区域位于 **1.0 Prepare for Submission** 页面靠下位置，不是左侧只显示提交记录与审核消息的 **App Review** 页面。


| 字段               | 填写内容                | 状态                                           |
| ---------------- | ------------------- | -------------------------------------------- |
| Contact Name     | `张静`                | 参考词鲸项目已确认信息，提交前复核                            |
| Contact Email    | `zdjoey@126.com`    | 参考词鲸项目已确认信息，提交前复核                            |
| Contact Phone    | `+86 158 6711 6034` | 已确认继续适用；审核期间保持可接听                            |
| Sign-in required | 勾选                  | 手动记账无需登录，但完整测试语音和云同步需要登录                     |
| Username         | `superai@qq.com`    | **已完成**：固定密码和完整流程已验证                         |
| Password         | 填写该审核账号的固定密码        | **已完成**：只填 App Store Connect，不写入仓库、截图或 Notes |
| Notes            | 使用下方文案              | 审核账号已就绪；生产 API 和公开页面恢复后可直接填写                 |


Notes：

> 妙记无需登录即可使用本地手动记账、预算、统计、历史记录和 CSV 导出。云同步与语音记账需要登录，审核账号和密码已填写在上方 Sign-in Information。
>
> 建议审核路径：
>
> 1. 打开“设置 → 云同步 → 登录并开启云同步”，选择“邮箱密码”，使用上方审核账号登录；
> 2. 首次登录前勾选隐私政策/用户协议同意项与境外云服务传输单独同意项；
> 3. 回到首页，打开“语音输入”，允许麦克风权限并说“午餐 45 元，打车 28 元”；
> 4. App 会生成两笔待确认草稿，可在保存前修改金额、标题和分类；
> 5. 在统计和历史页面查看已保存账目。
>
> 账号可在“设置 → 云同步 → 永久删除账号与数据”中永久删除。删除不可撤销，请不要删除长期审核账号；如需验证删除功能，请使用备用账号或联系我们创建临时账号。
>
> 本版本支持 iPhone 和 iPad，当前所有功能免费，没有 App 内购买、订阅、广告或跨 App 跟踪。语音与 AI 生成结果可能不准确，App 始终要求用户确认后再保存。

审核期间必须保持生产 API、Supabase、阿里云百炼、`superai@qq.com` 审核账号和公开支持页面在线。建议另备一个等价账号；备用凭据同样只填 App Store Connect，不写入仓库。

## 三、App Information

### 基础信息


| 字段                 | 建议值                                       | 状态                                                                    |
| ------------------ | ----------------------------------------- | --------------------------------------------------------------------- |
| App Name           | `妙记 AI 账本`                                | 与备案申请名称一致；当前 App Store Connect 显示“妙记AI账本”，备案通过后应按批准名称逐字统一，并同步核对二进制显示名 |
| Subtitle           | `语音记账与预算统计`                               | 可直接填写，9 个字符                                                           |
| Privacy Policy URL | `https://miaoji.joy-coder.com/privacy`    | **提交阻塞**：备案通过并恢复域名解析后，验证页面无需登录、HTTPS 正常且内容属于妙记再填                      |
| Primary Language   | Chinese (Simplified)                      | 建议保持                                                                  |
| Bundle ID          | `com.joy-coder.miaoji`                    | 与当前工程一致，上传 Build 后不可更改                                                |
| SKU                | 已创建 App 记录则保持现有值；尚未创建可用 `miaoji-ios-2026` | **待本人确认**：SKU 创建后不可更改，仅用于内部识别                                         |
| Primary Category   | Finance（财务）                               | 建议                                                                    |
| Secondary Category | Utilities（工具）                             | 建议                                                                    |
| Content Rights     | 选择“不包含、展示或访问第三方内容”                        | 当前 App 处理用户自己的账目和录音，不向用户分发第三方内容；若未来加入第三方文章、行情或其他内容需重答                 |
| Made for Kids      | 不选择                                       | 产品不专门面向儿童                                                             |
| License Agreement  | Apple Standard EULA                       | 当前不需要自定义 EULA                                                         |


App Store 名称最多 30 个字符、副标题最多 30 个字符；最终名称是否可用只能以创建或保存 App Store Connect 记录时的校验结果为准。

### Age Ratings

在 **App Information → Age Ratings → Edit** 打开用户截图中的七步问卷。按当前 1.0 功能逐项填写如下：


| 步骤                               | 字段                                               | 选择                 |
| -------------------------------- | ------------------------------------------------ | ------------------ |
| Step 1 · Features                | Parental Controls                                | No                 |
|                                  | Age Assurance                                    | No                 |
|                                  | Unrestricted Web Access                          | No                 |
|                                  | User-Generated Content                           | No；私人账目不会向其他用户广泛分发 |
|                                  | Social Media                                     | No                 |
|                                  | Social Media Disabled for Users Under 13         | No；App 本身没有社交功能    |
|                                  | Messaging and Chat                               | No                 |
|                                  | Advertising                                      | No                 |
| Step 2 · Mature Themes           | Profanity or Crude Humor                         | None               |
|                                  | Horror/Fear Themes                               | None               |
|                                  | Alcohol, Tobacco, or Drug Use or References      | None               |
| Step 3 · Medical or Wellness     | Medical or Treatment Information                 | None               |
|                                  | Health or Wellness Topics                        | No                 |
| Step 4 · Sexuality or Nudity     | Mature or Suggestive Themes                      | None               |
|                                  | Sexual Content or Nudity                         | None               |
|                                  | Graphic Sexual Content and Nudity                | None               |
| Step 5 · Violence                | Cartoon or Fantasy Violence                      | None               |
|                                  | Realistic Violence                               | None               |
|                                  | Prolonged Graphic or Sadistic Realistic Violence | None               |
|                                  | Guns or Other Weapons                            | None               |
| Step 6 · Chance-Based Activities | Simulated Gambling                               | None               |
|                                  | Contests                                         | None               |
|                                  | Gambling                                         | No                 |
|                                  | Loot Boxes                                       | No                 |
| Step 7 · Additional Information  | Calculated Rating                                | 应显示 `4+`，与用户图 9 一致 |
|                                  | Age Categories and Override                      | `Not Applicable`   |
|                                  | Age Suitability URL                              | 留空（Optional）       |


不要选择 `Made for Kids` 或 `Override to Higher Age Rating`。保存前确认计算结果仍为 `4+`；Apple 会按地区和系统版本显示等效等级。

### App Encryption Documentation

当前客户端只调用 Apple 操作系统提供的 HTTPS/TLS 等标准加密能力，工程已经声明 `ITSAppUsesNonExemptEncryption = NO`。通常不需要上传加密文档；若最终二进制加入自研加密、VPN 或额外加密层，必须重新判断。

### App Store Regulations & Permits


| 卡片                               | 当前处理                                                                                  |
| -------------------------------- | ------------------------------------------------------------------------------------- |
| Digital Services Act             | 已确认当前填写 `non-trader`；如果妙记产生收入、广告、联盟营销或被作为商业活动提供，必须重新评估                                |
| China Mainland ICP Filing Number | 首发包含中国大陆；妙记自己的 App 备案申请中，备案名称为“妙记 AI 账本”。取得备案编号后填写，并逐字核对备案名称、App Store 名称、二进制显示名和备案主体 |
| Vietnam Game License             | 不操作；妙记不是游戏                                                                            |
| Regulated Medical Devices        | 不操作；妙记不是医疗设备，也不提供医疗或治疗信息                                                              |
| Production / Sandbox Server URL  | 留空；1.0 没有 App 内购买或订阅，不需要 App Store Server Notifications                               |
| App-Specific Shared Secret       | 不创建；没有自动续期订阅收据场景                                                                      |


## 四、Pricing and Availability


| 项目                               | 建议                                              |
| -------------------------------- | ----------------------------------------------- |
| Price                            | Free（免费）                                        |
| Distribution                     | Public — Available on the App Store             |
| Regions                          | 首发包含 China Mainland（中国大陆）；妙记自己的 App 备案编号是上线前置条件 |
| Pre-Order                        | 首版不启用                                           |
| Release                          | 手动发布                                            |
| In-App Purchases / Subscriptions | 无，不创建任何商品                                       |


## 五、App Privacy 填写建议

**用户图 10 就是正确位置。** 路径为 **Distribution → App Store → Trust & Safety → App Privacy**。它是 App 级信息，不在 1.0 Prepare for Submission 版本卡内，并同时适用于 iPhone 与 iPad。

操作顺序：

1. Privacy Policy URL 是独立的必填项；备案通过并恢复解析后，在 Privacy Policy 右侧点 **Edit**，填写并验证 `https://miaoji.joy-coder.com/privacy`；User Privacy Choices URL 首版留空；
2. 在 Data Collection 点 **Get Started** 或 **Edit**；
3. 图 1 的说明页继续下一步；Data Collection 第一问选择 **Yes, we collect data from this app**，然后点 **Next**；
4. 按图 2–8 所示的滚动页面，只勾选下表 5 个数据类型，逐个完成后续问题；
5. 全部保存并核对 Product Page Preview，然后现在即可点 **Publish**。未 Publish 的回答只是草稿；Publish 只确认 App Privacy 回答，不等于提交版本审核，也不受 App 备案进度影响。首版商品页尚未上线时，回答会在商品页上线后展示。

> 截图中的蓝色勾选是页面当前状态，不是本项目的最终答案。请取消 **Name、Phone Number、Physical Address、Coarse Location**；不要因为服务器接收网络请求就把它们保留为已收集数据。

### Data Collection 数据类型逐屏填写

App Privacy 必须同时覆盖 App 本身和生产环境第三方服务的数据处理。当前代码、`PrivacyInfo.xcprivacy`、隐私政策以及已确认的生产日志策略对应的最终选择如下：


| 截图位置      | 分类                               | 应勾选                               | 明确保持不勾选                                                                    |
| --------- | -------------------------------- | --------------------------------- | -------------------------------------------------------------------------- |
| 图 2       | Contact Info                     | **Email Address**                 | Name、Phone Number、Physical Address、Other User Contact Info                 |
| 图 3       | Health & Fitness                 | 无                                 | Health、Fitness                                                             |
| 图 3       | Financial Info                   | **Other Financial Info**          | Payment Info、Credit Info                                                   |
| 图 4       | Location                         | 无                                 | Precise Location、Coarse Location                                           |
| 图 4       | 其他                               | 无                                 | Sensitive Info、Contacts                                                    |
| 图 5       | User Content                     | **Audio Data、Other User Content** | Emails or Text Messages、Photos or Videos、Gameplay Content、Customer Support |
| 图 5–6     | 历史                               | 无                                 | Browsing History、Search History                                            |
| 图 6–7     | Identifiers                      | **User ID**                       | Device ID                                                                  |
| 图 6–7     | Purchases                        | 无                                 | Purchases                                                                  |
| 图 8       | Usage Data                       | 无                                 | Product Interaction、Advertising Data、Other Usage Data                      |
| 图 8 及页面底部 | Diagnostics                      | 无                                 | Crash Data、Performance Data、Other Diagnostic Data                          |
| 页面底部      | Surroundings / Body / Other Data | 无                                 | Environment Scanning、Hands、Head、Other Data                                 |


最终应当恰好选中 5 项：


| App Store Connect 数据类型                | 对应数据与原因                         |
| ------------------------------------- | ------------------------------- |
| Contact Info → Email Address          | 邮箱登录、账号鉴权和恢复                    |
| Financial Info → Other Financial Info | 收支金额、日期、分类、预算、币种和统计所需账本数据       |
| User Content → Other User Content     | 用户自定义的账目标题、备注、分类名及其他自由文本会随云同步上传 |
| User Content → Audio Data             | 用户主动提交的语音记账录音会临时上传并交给 AI 解析     |
| Identifiers → User ID                 | Supabase 账号标识，用于鉴权、同步和数据隔离      |


### 5 类数据后续问题统一答案

进入上述每一个已勾选的数据类型后，都按相同方式回答：


| 后续问题                                                                     | 选择                        |
| ------------------------------------------------------------------------ | ------------------------- |
| What are the purposes for which this data is used?                       | 只勾选 **App Functionality** |
| Is this data linked to the user’s identity?                              | **Yes**                   |
| Do you or your third-party partners use this data for tracking purposes? | **No**                    |


不要勾选 Third-Party Advertising、Developer’s Advertising or Marketing、Analytics、Product Personalization 或 Other Purposes。妙记没有广告、跨 App 跟踪或数据经纪用途。

当前一致性结论：

- 已确认当前项目、生产日志、代理和第三方服务不额外收集需要申报的诊断、IP 派生位置或设备标识，因此不勾选 Device ID、Coarse Location 或 Diagnostics；
- 当前 `PrivacyInfo.xcprivacy` 已同步声明 Email Address、Other Financial Info、Other User Content、Audio Data 和 User ID，与上述建议一致；
- 若生产部署或后续版本接入访问日志留存、崩溃分析、性能监控、广告或归因 SDK，必须按实际行为重新核对，不能继续沿用当前答案。

Privacy Policy URL 仍是送审必填项；App Privacy 数据回答可以现在 Publish，但备案通过并恢复 `miaoji.joy-coder.com` 解析、确认 `/privacy` 可公开访问前，不得提交版本审核。App 内已经提供导出、清除记录、退出账号和永久删除账号入口。若上线前数据实践变化，应修改并再次 Publish。

## 六、App Accessibility

**用户图 11 也是正确位置。** 路径为 **Distribution → App Store → Trust & Safety → App Accessibility**。它不是版本页字段，且无障碍声明按设备族分别管理。

当前操作建议：

1. 点 **Get Started**；
2. Select Device 中勾选 **iPhone** 和 **iPad**，不要勾选 Apple Watch，然后点 **Save**；
3. 分别进入 Add iPhone Support 和 Add iPad Support；
4. 两种设备都选择“支持至少一项功能”，功能列表中只勾选 **Dark Interface**；浅色模式没有单独的 Accessibility Nutrition Label；
5. VoiceOver、Voice Control、Larger Text、Differentiate Without Color Alone、Sufficient Contrast 和 Reduced Motion 均不在 1.0 的开发与声明范围，本期不要勾选，也不列为送审前测试阻塞项；
6. 分别确认 iPhone/iPad 在深色模式下可以完成下列常用任务，然后保存为 Draft；
7. Apple 只允许为已经有 live version 的设备发布无障碍标签，因此首版上线前不能 Publish。1.0 上线后，再为 iPhone 和 iPad 发布 **Dark Interface** 标签。

**验收结论：已完成。** iPhone 与 iPad 均已按 Dark Interface 验收首次启动、手动新增/编辑/删除账目、首页预算、统计、历史与搜索、设置与分类管理、登录和云同步、语音记账草稿、CSV 导出及账号退出/删除；深色背景下文字、图标、输入框、图表、弹窗、遮罩和禁用状态均可辨认，切回浅色模式显示正常。Accessibility URL 首版留空。

## 七、提交前必须确认或完成

1. **[进行中] 中国大陆发行**：已确认首发包含中国大陆；妙记自己的 App 备案申请中，备案名称为“妙记 AI 账本”。取得备案编号后填入 App Store Connect，并将备案名称、App Store 商品页名称和二进制显示名逐字统一，同时核对备案主体。
2. **[等待备案] 公开 URL**：备案通过并恢复 `miaoji.joy-coder.com` 解析后，验证 `/privacy`、`/support`、`/terms` 无需登录、HTTPS 正常且内容属于妙记。
3. **[等待备案] 生产语音 API**：备案通过后把局域网 HTTP 地址替换为公网 HTTPS 地址，并用待上传 Release Build 在 iPhone 与 iPad 真机验证。
4. **[已完成] 审核账号**：`superai@qq.com` 和固定密码已完成完整流程验证；密码只填 App Store Connect。建议另备等价账号。
5. **[已完成] 隐私一致性**：已确认当前项目无额外诊断、IP 派生位置或设备信息收集；按本卡只申报 5 类数据。生产配置变化时重新核对。
6. **[已完成] 无障碍声明**：iPhone/iPad 已完成 Dark Interface 常用任务验收；其余无障碍功能不在 1.0 声明范围。首版上线前已保存 Draft，1.0 上线后再发布两种设备的 Dark Interface 标签。
7. **[已确认] 发行选择**：首发包含中国大陆、DSA 使用 `non-trader`，审核联系人电话 `+86 158 6711 6034` 和 Copyright `2026 Zhang Jing` 继续适用。

完成以上项目后，上传并选择正式 Build，在 1.0 页面保存全部信息，点击 **Add for Review** 创建 Draft Submission，再进入左侧 **App Review** 点击 **Submit for Review**。

## 八、Apple 官方字段限制与依据

- [App Information：名称与副标题限制、Bundle ID 和 SKU](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Platform Version Information：宣传文本、描述、关键词、审核资料和版本发布](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [Screenshot Specifications：iPhone 与 iPad 截图尺寸](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [App Privacy Details：数据类型、关联和追踪定义](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage App Privacy：保存、Publish 与商品页展示](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Age Ratings Values and Definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/)
- [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [Manage Accessibility Nutrition Labels：草稿与发布条件](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/manage-accessibility-nutrition-labels)

