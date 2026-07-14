# Supabase 生产数据库迁移操作手册

适用项目：妙记生产 Supabase（Singapore）  
迁移文件：

1. `supabase/migrations/202607130001_create_account_snapshots.sql`
2. `supabase/migrations/202607140002_secure_audio_and_account_deletion.sql`
3. `supabase/migrations/202607140003_record_privacy_consents.sql`

## 执行前

1. 登录 Supabase Dashboard，确认左上角选中的是妙记的**生产项目**，地域为 Singapore。
2. 进入 **Project Settings → Database → Backups**，确认当前备份能力；如控制台支持手动备份，先创建备份。
3. 打开 **SQL Editor → New query**。先运行只读检查：

```sql
select
  to_regclass('public.account_snapshots') as account_snapshots,
  to_regclass('public.privacy_consents') as privacy_consents;
```

- 返回 `null`：尚未执行第一份迁移，按下文完整执行。
- 返回 `account_snapshots`：不要重复执行第一份迁移，先跳到“迁移后验证”，检查表、RLS、策略和触发器是否齐全。
- `privacy_consents` 返回非 `null`：不要重复执行第三份迁移。

> 第一份迁移不是可重复执行脚本，重复运行会报“relation already exists”。这不等同于数据丢失，不要通过删表来重试。

## 执行第一份迁移

1. 在本仓库打开 `supabase/migrations/202607130001_create_account_snapshots.sql`。
2. 完整复制到 SQL Editor，确认没有复制到 Markdown 标记。
3. 点击 **Run**，等待显示成功。
4. 如失败，保留完整错误文本并停止，不要继续第二份，也不要手工删表。

该迁移会创建 `public.account_snapshots`、外键、RLS、四条仅限本人数据的策略和更新时间触发器。

## 执行第二份迁移

1. 新建查询，完整复制 `supabase/migrations/202607140002_secure_audio_and_account_deletion.sql`。
2. 点击 **Run**。

该迁移会把 `user-audio` Storage Bucket 设置为私有、限制 25 MB 和 m4a 音频类型，并创建仅允许已登录用户删除自己账号的 `delete_current_account()` 函数。第二份脚本可安全重跑用于纠正 Bucket 配置。

## 执行第三份迁移

1. 新建查询，完整复制 `supabase/migrations/202607140003_record_privacy_consents.sql`。
2. 点击 **Run**。

该迁移会创建只允许账号本人写入和读取的 `privacy_consents` 表，记录隐私政策版本、用户协议版本、境外接收方和同意时间。它不是可重复执行脚本；表已存在时不要重跑。

## 迁移后验证

把以下只读 SQL 放入一个新查询运行：

```sql
select policyname, cmd, roles, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('account_snapshots', 'privacy_consents')
order by tablename, policyname;

select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relname in ('account_snapshots', 'privacy_consents')
order by c.relname;

select id, name, public, file_size_limit, allowed_mime_types
from storage.buckets
where id = 'user-audio';

select
  to_regprocedure('public.delete_current_account()') as delete_function,
  has_function_privilege('authenticated', 'public.delete_current_account()', 'execute') as authenticated_can_execute,
  has_function_privilege('anon', 'public.delete_current_account()', 'execute') as anon_can_execute;
```

期望结果：

- `account_snapshots` 和 `privacy_consents` 均启用 RLS，且各有 SELECT、INSERT、UPDATE、DELETE 四类本人数据策略；
- `user-audio.public = false`、`file_size_limit = 26214400`；
- 删除函数存在，`authenticated_can_execute = true`，`anon_can_execute = false`。

再到 **Storage** 页面确认 `user-audio` 显示为 Private，到 **Authentication → Users** 确认测试账号状态。不要在生产项目使用真实账目做验收。

## 创建审核账号

本机运行以下命令，密码会隐藏输入且不会写入仓库：

```bash
server/venv/bin/python server/scripts/manage_review_user.py test1@126.com
server/venv/bin/python server/scripts/manage_review_user.py test2@126.com
```

当前只读检查结果：`test1@126.com` 已存在且邮箱已确认；`test2@126.com` 尚未创建。脚本会为账号设置固定密码，并将邮箱确认为已验证。

## 回滚原则

不要为了“回滚”而直接删除 `account_snapshots`、`auth.users` 或 Storage Bucket。生产数据结构回滚必须先导出数据，再针对具体故障编写新的前向迁移。把 SQL Editor 的执行时间、执行人、文件名和结果记录到发布日志。
