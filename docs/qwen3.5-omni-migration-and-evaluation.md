# Qwen3.5-Omni 迁移与语音记账评测

## 结论与上线门槛

生产默认模型先使用 `qwen3.5-omni-plus` 建立迁移基准。同一批录音再运行 `qwen3.5-omni-flash`：只有当 Flash 的金额完全匹配率、消费笔数匹配率、分类准确率和日期准确率均不低于 Plus，且非法输出率不高于 Plus 时，才把生产环境的 `DASHSCOPE_MODEL` 切换为 Flash；否则继续使用 Plus。

语音记账是“完整文件上传后解析”的单轮任务，不需要为了迁移改为 Realtime。旧的 `qwen-omni-turbo-0119` 只作为迁移前基线，不作为新的上线候选。

阿里云当前说明：Qwen3.5-Omni Plus 与 Flash 均支持非实时 HTTP（OpenAI 兼容）音频处理；旧 Qwen-Omni-Turbo 已停止更新。官方要求 Omni 使用流式响应，本项目保持 `stream=True` 和仅文本输出。

- [Qwen-Omni 模型与调用方式](https://help.aliyun.com/zh/model-studio/qwen-omni)
- [语音识别模型选型](https://help.aliyun.com/zh/model-studio/asr-model/)
- [地域与接入域名](https://help.aliyun.com/zh/model-studio/regions/)

## 生产配置

服务端配置如下：

```dotenv
DASHSCOPE_API_KEY=<北京地域 API Key>
DASHSCOPE_BASE_URL=https://<WorkspaceId>.cn-beijing.maas.aliyuncs.com/compatible-mode/v1
DASHSCOPE_MODEL=qwen3.5-omni-plus
BUSINESS_TIMEZONE=Asia/Shanghai
```

API Key、业务空间专属域名和模型必须属于同一地域。代码仍允许旧的 `dashscope.aliyuncs.com` 域名作为过渡兼容项，但生产环境应使用业务空间专属域名；后者是阿里云推荐方式，且具有更高的超时上限和更好的网络隔离。

模型输出的每笔消费现在都必须包含 `date: "YYYY-MM-DD"`。服务端将当前业务日期、星期和时区放进提示词，用它换算“昨天”“上周五”等相对日期；iOS 客户端会把该日期带入可编辑草稿。

## 准备 50～100 条新录音

只录制或合成新的脱敏数据，不复用真实账本。测试集应覆盖：

- iPhone 真机生成的 44.1 kHz、单声道、128 kbps AAC/M4A；
- 1 笔、多笔和没有消费内容；
- 整数、小数、中文数字、相似金额；
- 明确日期、未说日期、“昨天”“上周五”；
- 相似分类、口语化用途、简称；
- 安静、背景噪声、远距离、语速较快、较长录音；
- 至少 5 条使用 Supabase 私有对象签名 URL，验证模型能在 300 秒有效期内拉取音频。

复制评测清单模板：

```bash
cp server/evaluation-manifest.example.json server/evaluation-manifest.json
mkdir -p server/test-recordings
```

本地文件用 `file`，评测器会按阿里云官方 Base64 形式提交，并明确传 `format: "m4a"`：

```json
{
  "id": "ios-m4a-001",
  "file": "test-recordings/001.m4a",
  "reference_date": "2026-07-27",
  "tags": ["ios", "aac", "decimal", "relative-date"],
  "expected": [
    { "amount": 12.5, "category_id": "food", "date": "2026-07-26" }
  ]
}
```

签名 URL 用 `storage_path`。评测器会在每个模型调用前重新生成 300 秒 URL，避免依次运行三个模型时复用过期 URL：

```json
{
  "id": "signed-url-001",
  "storage_path": "benchmark/001.m4a",
  "reference_date": "2026-07-27",
  "tags": ["signed-url", "noise"],
  "expected": []
}
```

包含本地音频、私有 Storage 路径和生成报告的目录都已加入 `.gitignore`。不要把录音、签名 URL、模型原始输出或价格文件提交到仓库。

## 运行三模型评测

先在 `server/pricing.json` 填入百炼控制台当日显示的每百万输入、输出 Token 价格。模板中的 `null` 必须替换为实际数字；价格单位由团队统一，例如全部使用人民币。

```bash
cp server/pricing.example.json server/pricing.json
server/venv/bin/python server/scripts/evaluate_omni_models.py \
  server/evaluation-manifest.json \
  --pricing server/pricing.json \
  --output-dir server/evaluations/2026-07-27
```

默认依次运行：

1. `qwen-omni-turbo-0119`（旧基线）；
2. `qwen3.5-omni-plus`；
3. `qwen3.5-omni-flash`。

可用 `--models` 只重跑指定模型，用 `--repetitions 3` 观察同一录音的输出波动。生成文件包括：

- `runs.jsonl`：逐次调用的原始输出、规范化结果、Token、耗时和错误；
- `summary.json`：机器可读汇总和自动选型；
- `report.md`：金额、笔数、分类、日期、非法输出、API 错误、P50/P95 延迟和每千次估算成本。

“非法输出”采用严格口径：模型输出必须直接是合法 JSON 数组。即使生产解析器可以从 Markdown 代码块或解释文字中恢复 JSON，该次调用仍计为非法输出，以暴露模型输出稳定性问题。

## 上线检查

1. Plus 的所有测试调用完成，且没有 API 拉取 M4A 或签名 URL 错误。
2. Flash 与 Plus 使用完全相同的录音、标签、参考日期、分类和提示词。
3. 查看失败明细，不只看平均值；尤其检查漏拆多笔、金额小数、相对日期和相似分类。
4. 按自动结论选择模型，再人工复核差异样本。
5. 从百炼控制台核对实际账单。音频换算 Token 数只用于理解用量，不能替代不同模型的实时单价。
6. 灰度期间保留 Plus 配置作为快速回退值；不要切换到 Realtime 或旧 Qwen3 快照。
