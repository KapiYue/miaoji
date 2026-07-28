# 妙记项目交接文档

更新时间：2026-07-28（Asia/Shanghai）

## 先读结论

当前在做的是“妙记 AI 账本”首版 App Store 上架收尾，以及语音解析从旧 Qwen Omni 迁移到 Qwen3.5-Omni。代码、截图、上架填写文档和模型评测工具已经完成了大部分，但整个工作树尚未提交。现在不能直接归档送审：备案和公网生产服务仍未就绪，Release 校验还被临时绕过，真机语音链路也需要用当前代码再做一次端到端回归。

最后一个直接问题是：真机语音录音后长时间停在“正在上传”。已针对最可能的客户端原因完成修复（关闭 `waitsForConnectivity`、为局域网上传设置 15 秒请求超时、保留录音供重试、改进错误提示、识别 `.local` 主机名），单元测试已通过；但交接前本机 API 没有运行，因此尚未完成真机实测闭环。

## 仓库快照

- 仓库：`miaoji`
- 当前分支：`main`
- HEAD：`830ccfa feat: add deployable policy site and App Store submission checklist`
- `origin/main` 与 HEAD 相同。
- 工作树很脏：26 个已跟踪文件有修改，另有截图、评测器、文档等未跟踪文件；这些都是本轮工作成果，**不要 reset、checkout 或覆盖**。
- 所有改动目前都未暂存、未提交。
- 本文件 `HANDOFF.md` 也是新文件。

先运行：

```bash
git status --short
git diff --stat
```

## 已经完成的工作

### 1. iPhone / iPad 商品页和界面适配

- App Target 已从仅 iPhone 改为同时支持 iPhone 和 iPad：`TARGETED_DEVICE_FAMILY = "1,2"`。
- 首页、统计、历史、设置页加入 regular width 的双栏或网格布局，iPad 不再只是把手机页面居中放大。
- 截图演示数据重新整理：本月预算、首页、统计趋势、历史账目和设置页数据使用统一口径。
- 增加可重复的截图启动参数：
  - `--screenshot-demo-data`
  - `--screenshot-tab home|statistics|history|settings`
  - `--screenshot-voice-state ready|recording|analyzing|drafts|saved`
- 增加 `scripts/capture-app-store-screenshots.sh`，会构建 App、启动两台模拟器、固定状态栏并生成 18 张图片。
- 已生成两套共 18 张截图：
  - `docs/assets/app-store-connect/zh-Hans/iphone-6.5/`：9 张，全部为 1284 × 2778。
  - `docs/assets/app-store-connect/zh-Hans/ipad-13/`：9 张，全部为 2064 × 2752。
- 截图脚本当前默认模拟器：
  - `CiJing iPhone 14 Plus`：`EBE81B35-E9F3-46CD-9209-F8F02C924C0A`
  - `iPad Pro 13-inch (M5)`：`D1547B6D-B368-425C-8F81-7BEE5B76809C`
  - UUID 变化时用 `MIAOJI_IPHONE_SIMULATOR_ID` / `MIAOJI_IPAD_SIMULATOR_ID` 覆盖，不要直接假设别的机器也有相同 UUID。

### 2. App Store Connect 文档和隐私口径

- 大幅补充 `docs/app-store-metadata-zh-CN.md`，包括商品页、审核说明、App Privacy、年龄分级、Accessibility 和提交阻塞项。
- 更新 `docs/app-store-release-checklist.md`、`docs/app-store-screenshot-guide.md`、`docs/terms-of-service.md`，统一为 iPhone + iPad 首发。
- `PrivacyInfo.xcprivacy` 增加 Other User Content 声明；当前 App Privacy 口径为 5 类数据：Email Address、Other Financial Info、Other User Content、Audio Data、User ID，均用于 App Functionality、与账号关联、不跟踪。
- 审核账号使用 `superai@qq.com`；文档称账号和固定密码已验证。密码只能填到 App Store Connect，仓库中不得记录。
- 已确认首发包含中国大陆、DSA 选择 `non-trader`；中国大陆发行依赖 APP 备案，网站/API 域名也依赖对应备案和解析恢复。

### 3. Qwen3.5-Omni 迁移

- 服务端默认模型由 `qwen-omni-turbo-0119` 改为 `qwen3.5-omni-plus`。
- 新增 `DASHSCOPE_BASE_URL` 和 `BUSINESS_TIMEZONE` 配置；服务端验证 Endpoint 必须为 HTTPS、路径必须是 `/compatible-mode/v1`、Host 必须属于阿里云 Model Studio。
- 当前本地 `server/.env` 使用：
  - `DASHSCOPE_MODEL=qwen3.5-omni-plus`
  - 旧北京公共 Endpoint `https://dashscope.aliyuncs.com/compatible-mode/v1`
  - 生产部署应改为与 API Key 同地域的业务空间专属 `*.maas.aliyuncs.com` Endpoint。
- 抽出 `server/omni.py`，生产接口和评测脚本共享同一套 Prompt、流式响应收集和 JSON 规范化逻辑。
- Omni 请求继续使用 `stream=True`、`modalities=["text"]`、M4A `format="m4a"`。这是兼容要求，不要随意改成非流式或 Realtime。
- 每笔 AI 账目现在强制带 `date: "YYYY-MM-DD"`：
  - Prompt 会传入当前业务日期、星期和时区；
  - 服务端严格验证日期；
  - iOS `AIParsedExpense` 解码日期；
  - 语音草稿使用模型解析出的日期，而不是一律用当天。
- Dockerfile 已把 `omni.py` 复制进镜像。
- 新增文档：`docs/qwen3.5-omni-migration-and-evaluation.md`。

### 4. 模型评测工具

- 新增 `server/scripts/evaluate_omni_models.py`、`server/test_evaluate_omni.py`、manifest 和价格模板。
- 评测指标包括金额完全匹配率、笔数匹配率、分类准确率、日期准确率、非法输出率、API 错误率、P50/P95 延迟和估算成本。
- 生产解析器可容忍 Markdown 包裹等输出；评测的“非法输出”刻意采用更严格口径，只接受直接输出的合法 JSON 数组。
- 本地已有忽略的评测数据和结果，不能提交：
  - `server/test-recordings/`：5 条合成 M4A。
  - `server/evaluation-manifest.json`。
  - `server/evaluations/synthetic-smoke-2026-07-27/`。
  - `server/evaluations/signed-url-smoke-2026-07-27/`。
- 已完成的小样本 Smoke 结果：
  - 5 条合成音频：Plus 和 Flash 的金额、笔数、分类、日期都是 100%，非法输出/API 错误都是 0%；Plus P50 约 1622 ms，Flash P50 约 925 ms。
  - 1 条 Supabase 私有对象签名 URL：两者准确指标都是 100%；Plus 约 3784 ms，Flash 约 5394 ms。
  - 自动器因此建议 Flash，但样本太少，**绝对不能据此直接切生产模型**。
- 尚无 `server/pricing.json`，所以没有成本结论。
- 旧模型基线没有出现在现有 Smoke 报告中；目前只实际比较了 Plus 和 Flash。

### 5. 真机“上传卡住”修复

- `MiaoJiInputService` 不再设置 `waitsForConnectivity = true`。该设置在 IP 变化、服务未启动或局域网不可达时会让 UI 长时间停在上传状态。
- 局域网请求超时改为 15 秒，公网请求为 45 秒；总 Resource Timeout 保持 150 秒。
- 局域网请求仍使用 ephemeral session，并清空代理配置。
- `.local` 主机名现在被识别为局域网开发地址。
- 错误文案会显示当前 Host，并提示检查服务启动、Mac 当前地址、同一 Wi-Fi、本地网络权限和 macOS 防火墙。
- 当前忽略的 `client/MiaoJiConfig.xcconfig` 指向 `http://qingmoudeMacBook-Pro.local:8000`。该文件含客户端环境配置，不要提交。

## 已完成的验证

### 交接前刚重新运行

后端：

```bash
server/venv/bin/python -m unittest server/test_app.py server/test_evaluate_omni.py
```

结果：16 个测试全部通过。测试 invalid timezone 时会故意打印一条 Flask error 日志，这是预期行为。

iOS：

```bash
xcodebuild test \
  -project client/MiaoJiAccout.xcodeproj \
  -scheme MiaoJiAccout \
  -destination 'platform=iOS Simulator,id=EBE81B35-E9F3-46CD-9209-F8F02C924C0A' \
  -derivedDataPath /tmp/miaoji-handoff-derived \
  CODE_SIGNING_ALLOWED=NO
```

结果：`** TEST SUCCEEDED **`。Swift 单元测试、UI 测试、截图 UI 测试和 Launch 测试均通过。运行中出现过 `DebuggerVersionStore` / UI Runner launch 的瞬时告警，但 Xcode 自动重试后成功，最终退出码为 0。

其他：

- `sh -n scripts/capture-app-store-screenshots.sh` 通过。
- 18 张截图像素尺寸全部符合目标规格。
- `git diff --check` 只报告 `docs/app-store-metadata-zh-CN.md` 文件末尾多一个空行；提交前顺手修掉。

## 当前卡点 / 未完成事项

### A. 真机语音链路还没用最新修复闭环

- 交接时本机 8000 端口没有服务监听，`http://127.0.0.1:8000/healthz` 连接失败；所以不能据此判断新客户端修复是否有效。
- 在受限 shell 中 `.local` 名称也没有解析成功；这可能是执行环境限制，也可能是 mDNS 名称问题。必须从真机实际验证。
- 需要启动 Flask、重新安装/运行包含最新代码和 xcconfig 的 App，然后完整走一次：登录 → 录音 → 上传 → AI 解析 → 草稿 → 保存，并验证相对日期。

### B. 模型迁移评测不够上线决策

- 目标是 50～100 条新录制、脱敏、覆盖真实 iPhone 编码和噪声场景的 M4A；目前只有 5 条合成音频和 1 条签名 URL Smoke。
- 没有价格文件，没有每千次成本比较。
- 还需要重复运行观察波动，并人工复核失败样本。
- 在上述工作完成前，生产默认保持 `qwen3.5-omni-plus`。

### C. App Store 生产条件未就绪

- 妙记 APP 备案申请仍在进行；首发选择包含中国大陆。
- 备案完成前，`miaoji.joy-coder.com/privacy`、`/support`、`/terms` 和生产语音 API 还不能按送审要求最终验收。
- 客户端当前是局域网 HTTP 配置，不是审核设备可访问的生产 HTTPS API。
- Release Build Settings 中仍有 `MIAOJI_TEMPORARILY_SKIP_RELEASE_VALIDATION = YES`。这是临时真机调试绕过，不能用于 Archive、TestFlight 或送审。
- 仍需部署生产 API、配置自有 SMTP、生产限流/监控/日志策略，并用待提交 Build 在 iPhone 和 iPad 真机验证。

### D. 工作树尚未整理提交

- 当前大量相关改动横跨 UI、截图、上架资料、后端和评测器；没有 commit。
- 不要把本地录音、评测原始输出、签名 URL、价格、`.env` 或 `MiaoJiConfig.xcconfig` 提交。
- 提交前应逐个主题检查 diff；如果拆 commit，建议按“iPad/截图与上架资料”“Qwen3.5 日期链路与评测器”“局域网上传超时修复”拆分。

## 下一步计划（按顺序）

1. **先闭环真机上传问题**
   - 从仓库根目录运行：
     ```bash
     cd server
     venv/bin/flask --app app run --host 0.0.0.0 --port 8000
     ```
   - 另一个终端确认：
     ```bash
     curl http://127.0.0.1:8000/healthz
     ```
   - 在 iPhone Safari 访问 `http://qingmoudeMacBook-Pro.local:8000/healthz`。若 `.local` 不通，查 Mac 当前 Wi-Fi IPv4，并临时把 `client/MiaoJiConfig.xcconfig` 改为该地址。
   - 确认 iPhone 与 Mac 同一 Wi-Fi、系统设置里已允许妙记访问“本地网络”、macOS 防火墙没有拦截 Python/Flask。
   - 修改 xcconfig 后必须重新 Build/安装，不能只重启旧 App。
   - 完整测试语音输入和重试；服务关闭时应在约 15 秒内显示可操作错误，不应无限停在上传。

2. **扩大 Omni 评测**
   - 按 `docs/qwen3.5-omni-migration-and-evaluation.md` 准备 50～100 条脱敏录音。
   - 至少 5 条走 Supabase 私有对象签名 URL。
   - 从百炼控制台把同一币种、同一计价口径的实时价格写入本地 `server/pricing.json`。
   - Plus / Flash 使用完全相同数据和 Prompt，建议 `--repetitions 3`。
   - 人工看失败明细，再依据门槛决定是否从 Plus 切 Flash；不要只看自动结论或平均延迟。

3. **备案完成后部署生产环境**
   - 部署 `server/Dockerfile`，注入 `SUPABASE_URL`、`SUPABASE_SECRET_KEY`、`DASHSCOPE_API_KEY`、专属 `DASHSCOPE_BASE_URL`、最终 `DASHSCOPE_MODEL`、`BUSINESS_TIMEZONE`。
   - 验证公网 HTTPS `/healthz`，以及 Auth、私有 Storage、签名 URL、删除临时录音、限流、告警和日志脱敏。
   - 恢复并验证 `miaoji.joy-coder.com` 的隐私、支持、条款页面。
   - 配置 Supabase 自有 SMTP。

4. **准备 Release / TestFlight / 送审**
   - 把 `client/MiaoJiConfig.xcconfig` 改成生产 HTTPS API。
   - 从 Release 配置删除 `MIAOJI_TEMPORARILY_SKIP_RELEASE_VALIDATION = YES`。
   - 运行 Release build，必须看到校验通过，不能出现 skip warning。
   - 用最终构建在 iPhone + iPad 真机验证审核账号、语音、同步、账号删除、弱网、隐私页面和 CSV。
   - 再跑后端/iOS 测试、`git diff --check`、Archive → Validate → Upload。

5. **整理并提交代码**
   - 先修 `docs/app-store-metadata-zh-CN.md` 末尾多余空行和文档中的两处漂移：
     - 该文档仍写旧地址 `192.168.5.109:8000`，而当前本地配置已是 `.local` 主机名。
     - `server/README.md` 的本地示例使用 8000，而根 README 和客户端开发配置使用 8000；Docker 继续使用 8000 没问题，但本地文档需明确区分。
   - 再检查 `git status --short`，确保忽略文件没有被强行加入。

## 绝对不要再踩的坑

1. **不要在真机配置 `127.0.0.1` 或 `localhost`。** 真机上的回环地址指向 iPhone 自己，不是 Mac。用 Mac 的 `.local` 名称或当前局域网 IP。
2. **不要再为语音上传开启 `waitsForConnectivity`。** 服务未启动或地址变化时，它会让 UI 看起来永远卡在上传；当前设计应快速失败并允许用保留的本地录音重试。
3. **不要把“服务没启动”误诊为模型、Supabase 或 UI Bug。** 先查 `/healthz` 和 8000 端口，再查真机到 Mac 的网络路径。
4. **不要用带局域网 HTTP 地址或 Release skip 开关的构建归档送审。** 必须是公网 HTTPS，并删除 `MIAOJI_TEMPORARILY_SKIP_RELEASE_VALIDATION`。
5. **不要把 5 条合成音频的满分结果当作 Flash 上线依据。** 当前结论只是 Smoke；真实口音、背景噪声、长录音、多笔拆分和相对日期还没有足量覆盖。
6. **不要随意改掉 Omni 的流式调用。** 当前 Qwen Omni 兼容路径依赖 `stream=True`，只请求文本输出；本任务是完整 M4A 单轮解析，不需要迁到 Realtime。
7. **不要混用不同地域的 API Key、模型和 Endpoint。** 生产优先业务空间专属 `*.maas.aliyuncs.com/compatible-mode/v1`，三者必须同地域。
8. **不要让服务端和客户端的日期 Schema 不同步。** 现在 `date` 是必填；只更新一端会导致 502 或 iOS 解码失败。相对日期必须基于 `BUSINESS_TIMEZONE`。
9. **不要复用已过期的签名 URL。** 评测器会在每次模型调用前重新生成 300 秒 URL；生产也应保持 Bucket 私有，并在 `finally` 删除临时音频。
10. **不要提交敏感或本地评测材料。** 包括 `server/.env`、`client/MiaoJiConfig.xcconfig`、录音、`evaluation-manifest.json`、`pricing.json`、`evaluations/`、签名 URL、原始模型输出和审核账号密码。
11. **不要在报告或日志中直接复制 `runs.jsonl`。** 其中可能包含模型原始输出和短期签名 URL；只汇总去敏指标。
12. **不要重复执行不可幂等的 Supabase 迁移，也不要为“回滚”直接删表。** 先按 `docs/supabase-migration-guide.md` 做存在性检查；已有表时报错不等于数据丢失。
13. **不要把 iPad 支持再悄悄关掉。** 商品页、条款、截图和 Accessibility 已全部按 iPhone + iPad 对齐；若改变设备范围，要同步重做这些材料。
14. **不要再上传旧的 1320 × 2868 截图。** 当前固定使用 iPhone 6.5 英寸 1284 × 2778 和 iPad 13 英寸 2064 × 2752。
15. **不要把 Xcode 中途的 LLDB / UI Runner 重试日志当作最终失败。** 以最后的 `** TEST SUCCEEDED **` / `** TEST FAILED **` 和退出码为准。
16. **不要清理或覆盖当前 dirty worktree。** 所有未提交改动都应先审阅和保存；尤其不要运行 `git reset --hard` 或 `git checkout --`。

## 关键入口

- 上架总清单：`docs/app-store-release-checklist.md`
- App Store Connect 填写卡：`docs/app-store-metadata-zh-CN.md`
- 截图说明：`docs/app-store-screenshot-guide.md`
- 截图脚本：`scripts/capture-app-store-screenshots.sh`
- Qwen 迁移与评测：`docs/qwen3.5-omni-migration-and-evaluation.md`
- 后端说明：`server/README.md`
- 后端入口：`server/app.py`
- Omni 共用逻辑：`server/omni.py`
- 评测器：`server/scripts/evaluate_omni_models.py`
- iOS 语音服务：`client/MiaoJiAccout/MiaoJiInputService.swift`
- 语音草稿日期接入：`client/MiaoJiAccout/EntrySheetView.swift`
- Release 校验：`client/scripts/validate_release.sh`
- Supabase 迁移与审核账号：`docs/supabase-migration-guide.md`

