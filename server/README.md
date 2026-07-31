# 妙记语音解析服务

`server` 是妙记 iOS 客户端的受信任后端。它验证 Supabase 登录态、把录音暂存到私有 Storage，并通过阿里云 DashScope 将一段 M4A 语音转换为结构化账目。Supabase Secret Key 和 DashScope API Key 只允许出现在服务端。

本地联调使用本机 Flask 和线上 Supabase，不需要启动本地 Supabase：

```text
iOS ── Mac Flask :8000 ── 线上 Supabase Auth / Storage
                    └──── DashScope

iOS ───────────────────── 线上 Supabase Auth / Postgres（账本同步）
```

模拟器把 `MIAOJI_API_BASE_URL` 配置为 `http://127.0.0.1:8000`；真机改用
Mac 的 Bonjour `.local` 主机名并与 Mac 保持在同一局域网。客户端的
`SUPABASE_URL` 始终指向线上 HTTPS 项目，只有语音 API 指向本机 Flask。

## 接口

| 方法 | 路径 | 鉴权 | 说明 |
| --- | --- | --- | --- |
| `GET` | `/`、`/healthz` | 无 | 健康检查，返回 `{ "status": "ok" }` |
| `POST` | `/upload-audio` | Supabase Bearer Token | 接收 `multipart/form-data` 的 `file` 字段，仅支持不超过 25 MB 的 `.m4a` |
| `POST` | `/parse-audio-expenses` | Supabase Bearer Token | 解析当前用户刚上传的录音，并在请求结束时删除临时音频 |

受保护接口需要请求头：

```text
Authorization: Bearer <SUPABASE_ACCESS_TOKEN>
```

上传成功返回私有对象路径：

```json
{
  "bucket": "user-audio",
  "path": "<user-id>/2026/07/23/<random-id>.m4a"
}
```

解析请求示例：

```json
{
  "audio_path": "<user-id>/2026/07/23/<random-id>.m4a",
  "categories": [
    { "id": "food", "name": "餐饮" },
    { "id": "transport", "name": "交通" }
  ]
}
```

`audio_path` 必须以当前登录用户 ID 开头；分类数组不能为空、最多 100 项且 ID 不可重复。

## 本地运行

要求 Python 3.13（与 Docker 镜像一致）。首次运行时从仓库根目录执行：

```bash
python3 -m venv server/venv
server/venv/bin/pip install -r server/requirements.txt
cp server/.env.example server/.env
```

编辑 `server/.env`：

| 变量 | 必填 | 用途 |
| --- | --- | --- |
| `SUPABASE_URL` | 是 | 线上 Supabase 项目的 HTTPS URL |
| `SUPABASE_SECRET_KEY` | 是 | 服务端 Secret Key；禁止放入客户端或提交 Git |
| `DASHSCOPE_API_KEY` | 是 | 与接入地域一致的 DashScope API 凭据 |
| `DASHSCOPE_BASE_URL` | 建议 | 业务空间专属 OpenAI 兼容地址；未设置时暂时回退旧北京公共域名 |
| `DASHSCOPE_MODEL` | 否 | 多模态模型，默认 `qwen3.5-omni-plus` |
| `BUSINESS_TIMEZONE` | 否 | 相对日期换算时区，默认 `Asia/Shanghai` |

配置完成后，日常联调只需在仓库根目录启动开发服务：

```bash
make server-start
```

该命令固定监听 `0.0.0.0:8000`，并由 Flask 读取 `server/.env` 后连接线上
Supabase。生产部署仍应通过托管平台注入同名环境变量。

检查服务：

```bash
curl http://127.0.0.1:8000/healthz
```

## 测试

测试使用本地假 Supabase 和假 AI 响应，不会访问生产数据：

```bash
make server-test
```

## 模型迁移评测

同一批新录制的脱敏 M4A 可依次运行旧基线、Qwen3.5-Omni Plus 和 Flash，并自动汇总金额、笔数、分类、日期、非法输出、延迟与估算成本。清单格式、签名 URL 测试和上线门槛见 [`docs/qwen3.5-omni-migration-and-evaluation.md`](../docs/qwen3.5-omni-migration-and-evaluation.md)。

## Docker 部署

```bash
docker build -t miaoji-server server
docker run --rm -p 8000:8000 \
  --env-file server/.env \
  miaoji-server
```

容器使用非 root 用户运行 Gunicorn，默认监听 `$PORT`（镜像默认值为 `8000`）。生产环境应由平台 Secret 管理注入变量，并在负载均衡器或反向代理处启用 HTTPS。

## App Store 审核账号

审核账号由脚本交互式创建或修复，密码不会写入文件：

```bash
server/venv/bin/python server/scripts/manage_review_user.py superai@qq.com --status-only
server/venv/bin/python server/scripts/manage_review_user.py superai@qq.com
```

第二条命令会隐藏密码输入；如果账号已存在，会先请求确认再重置密码。审核凭据只填写到 App Store Connect。

## 安全与运维约束

- `user-audio` 必须是私有 Bucket；模型只能使用有效期 300 秒的签名 URL 读取录音。
- 解析接口无论成功或失败都会在 `finally` 中删除临时录音。仍建议为 Bucket 配置兜底生命周期清理策略。
- 不要在日志中记录 Bearer Token、音频内容、Secret Key 或完整用户账目。
- 客户端只使用 Supabase Publishable Key；`SUPABASE_SECRET_KEY` 仅属于本服务。
- 发布前至少验证健康检查、鉴权拒绝、25 MB 限制、跨用户路径拒绝、解析成功后的对象删除和生产 HTTPS。
