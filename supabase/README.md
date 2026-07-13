# 妙记 Supabase 配置

1. 在 Supabase 项目的 SQL Editor 运行 `migrations/202607130001_create_account_snapshots.sql`。
2. 在 Authentication → Email Templates 中，把 **Confirm signup** 和 **Magic Link** 邮件正文都改为包含 `{{ .Token }}` 的验证码模板，分别覆盖新邮箱首次登录和已有账号再次登录。验证码长度由 Supabase Auth 配置决定，支持 6–10 位。
3. 在 `client/MiaoJiConfig.xcconfig` 填写：
   - `SUPABASE_URL`：项目 URL；URL 中的 `//` 要沿用现有 xcconfig 的 `$()/` 写法。
   - `SUPABASE_PUBLISHABLE_KEY`：Publishable key；旧项目也可以使用 anon key。
4. 不要把 `secret` 或 `service_role` key 放进 iOS 客户端。客户端请求使用用户 JWT，数据库通过 RLS 仅允许访问 `auth.uid()` 对应的账本。

首次登录时：如果云端没有账本，应用会把当前本地数据迁移到 Supabase；如果云端已有更新的账本，则下载到本机。后续修改会先写本地离线缓存，再自动同步云端。
