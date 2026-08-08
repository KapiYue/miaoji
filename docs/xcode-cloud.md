# Xcode Cloud

妙记使用 Xcode Cloud 在 `main` 分支收到代码提交后自动执行 iOS Archive。构建成功或失败时，Apple 会向当前 App Store Connect 账号关联的邮箱发送通知。

## 仓库内配置

- `client/MiaoJiAccout.xcodeproj/xcshareddata/xcschemes/MiaoJiAccout.xcscheme` 是云端 Archive 使用的共享 Scheme。
- `client/MiaoJiConfig.xcconfig` 已纳入版本控制，只包含公开的客户端配置（API 地址、Supabase 项目地址和 publishable key）。本地和 Xcode Cloud 使用完全相同的这一份文件。
- `client/ci_scripts/ci_post_clone.sh` **不再生成**该文件，只校验它存在；缺失会让构建尽早失败。此前由环境变量重新生成的做法会静默漏掉 `SUPABASE_PUBLISHABLE_KEY`，导致云端归档的登录和云同步整体失效（见提交 `e1c024e`）。

## Xcode Cloud 工作流

工作流使用以下设置：

- Start Condition：`main` 分支的任意文件发生变化，并启用 Auto-cancel Builds。
- Action：Archive，平台为 iOS，Scheme 为 `MiaoJiAccout`，Distribution Preparation 为 None。
- Environment：Latest Release Xcode、Latest Release macOS。

工作流**不需要**配置 `MIAOJI_API_BASE_URL` 或 `SUPABASE_URL` 环境变量：全部客户端配置都来自版本控制的 `client/MiaoJiConfig.xcconfig`。若工作流中仍留有这两个变量，它们不会生效，建议删除以免误导。

不要把服务端 `SUPABASE_SECRET_KEY`、DashScope API key 或其他服务端密钥放进 Xcode Cloud 客户端工作流。客户端只使用 publishable/anon key，不能用服务端 secret key 代替。

## 邮件通知

App Store Connect 的 `Users and Access → 当前用户 → Xcode Cloud → Notifications` 中，将 Build Success 和 Build Failure 设为 All，并勾选 Email Associated with Apple Account。邮件会发送到该 Apple Account 的邮箱。
