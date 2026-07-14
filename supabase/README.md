# 妙记 Supabase 配置

1. 按文件名顺序在 Supabase SQL Editor 运行 `migrations/` 中的迁移：
   - `202607130001_create_account_snapshots.sql`
   - `202607140002_secure_audio_and_account_deletion.sql`
   - `202607140003_record_privacy_consents.sql`
2. 在 Authentication → Email Templates 中，把 **Confirm signup** 和 **Magic Link** 邮件正文都改为包含 `{{ .Token }}` 的验证码模板，分别覆盖新邮箱首次登录和已有账号再次登录。验证码长度由 Supabase Auth 配置决定，支持 6–10 位。
3. 在 `client/MiaoJiConfig.xcconfig` 填写：
   - `SUPABASE_URL`：项目 URL；URL 中的 `//` 要沿用现有 xcconfig 的 `$()/` 写法。
   - `SUPABASE_PUBLISHABLE_KEY`：Publishable key；旧项目也可以使用 anon key。
4. 不要把 `secret` 或 `service_role` key 放进 iOS 客户端。客户端请求使用用户 JWT，数据库通过 RLS 仅允许访问 `auth.uid()` 对应的账本。
5. `user-audio` Bucket 必须保持为私有。生产 API 会使用服务端凭据写入以用户 ID 为前缀的临时对象，生成 5 分钟签名 URL 交给 AI 解析，并在每次解析尝试结束时删除对象。建议另外在 Supabase 或外部定时任务中配置“删除 24 小时前对象”的兜底清理。

登录或恢复会话时：如果云端已有账本，应用会优先下载并恢复该账号的完整数据；如果云端没有账本，则把当前本地数据迁移到 Supabase。后续修改会先写本地离线缓存，并标记为待上传；应用重启时只有这类尚未上传的修改可以覆盖云端，已完成同步的普通缓存不会反向覆盖 Supabase。

用户可在应用设置中执行“永久删除账号”。该操作调用 `delete_current_account()` 删除当前 Supabase Auth 用户，账本快照通过外键级联删除；客户端同时清除本机账本和登录凭据。

云登录前，应用会分别取得隐私政策/用户协议同意和向新加坡 Supabase 传输数据的单独同意；认证成功后将政策版本、协议版本、境外接收方和同意时间写入 `privacy_consents`。若记录失败，客户端会退出本次登录，不会继续同步。
