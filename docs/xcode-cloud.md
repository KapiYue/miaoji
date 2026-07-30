# Xcode Cloud

妙记使用 Xcode Cloud 在 `main` 分支收到代码提交后自动执行 iOS Archive。构建成功或失败时，Apple 会向当前 App Store Connect 账号关联的邮箱发送通知。

## 仓库内配置

- `client/MiaoJiAccout.xcodeproj/xcshareddata/xcschemes/MiaoJiAccout.xcscheme` 是云端 Archive 使用的共享 Scheme。
- `client/ci_scripts/ci_post_clone.sh` 在 Xcode Cloud 克隆代码后生成被 Git 忽略的 `client/MiaoJiConfig.xcconfig`。
- 脚本只接受 HTTPS 服务地址和 Supabase 项目地址；缺失或格式错误会让构建尽早失败。

## Xcode Cloud 工作流

工作流使用以下设置：

- Start Condition：`main` 分支的任意文件发生变化，并启用 Auto-cancel Builds。
- Action：Archive，平台为 iOS，Scheme 为 `MiaoJiAccout`，Distribution Preparation 为 None。
- Environment：Latest Release Xcode、Latest Release macOS。

在工作流 Environment Variables 中配置：

- `MIAOJI_API_BASE_URL`：线上妙记 API 的公开 HTTPS 地址。
- `SUPABASE_URL`：线上 Supabase 项目 HTTPS 地址。

不要把服务端 `SUPABASE_SECRET_KEY`、DashScope API key 或其他服务端密钥放进 Xcode Cloud 客户端工作流。当前 Cloud 工作流不注入 Supabase 客户端 key；如果后续需要分发启用 Supabase 直连能力的构建，应单独补充客户端 publishable/anon key，不能用服务端 secret key 代替。

## 邮件通知

App Store Connect 的 `Users and Access → 当前用户 → Xcode Cloud → Notifications` 中，将 Build Success 和 Build Failure 设为 All，并勾选 Email Associated with Apple Account。邮件会发送到该 Apple Account 的邮箱。
