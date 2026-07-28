import json
import math
import re
from dataclasses import dataclass
from datetime import date
from typing import Optional


@dataclass(frozen=True)
class OmniResult:
    raw_text: str
    usage: Optional[dict]


def expense_prompt(categories, reference_date: date, timezone_name: str):
    category_json = json.dumps(categories, ensure_ascii=False, separators=(",", ":"))
    weekday = "一二三四五六日"[reference_date.weekday()]
    return f"""
你是一个中文记账助手。请完整理解音频，将其中每一笔支出拆成独立条目。
客户端可选分类如下：{category_json}
当前日期是 {reference_date.isoformat()}（星期{weekday}），时区是 {timezone_name}。

只输出 JSON 数组，不要 Markdown、解释或其他文字。每个数组元素必须严格包含：
{{"amount": 正数数字, "title": "简洁消费标题", "category_id": "分类id", "category_name": "分类名称", "date": "YYYY-MM-DD"}}

规则：
1. 音频提到多笔消费时返回多条，不能合并金额；只提到一笔则返回一条。
2. amount 只使用数字，单位默认为元；title 不包含金额。
3. category_id 和 category_name 必须来自给定分类中的同一项，选择语义最接近的一项。
4. 将“昨天”“上周五”等相对日期换算成明确日期；未提日期时使用当前日期。
5. 不要臆造音频中没有的消费；完全没有可识别的记账明细时返回 []。
""".strip()


def request_audio_expenses(client, model, audio_data, audio_format, prompt):
    completion = client.chat.completions.create(
        model=model,
        messages=[
            {
                "role": "user",
                "content": [
                    {
                        "type": "input_audio",
                        "input_audio": {"data": audio_data, "format": audio_format},
                    },
                    {"type": "text", "text": prompt},
                ],
            }
        ],
        modalities=["text"],
        max_tokens=2048,
        stream=True,
        stream_options={"include_usage": True},
    )
    return collect_stream(completion)


def collect_stream(completion):
    parts = []
    usage = None
    for chunk in completion:
        chunk_usage = getattr(chunk, "usage", None)
        if chunk_usage is not None:
            usage = _plain_object(chunk_usage)
        choices = getattr(chunk, "choices", None) or []
        for choice in choices:
            delta = getattr(choice, "delta", None)
            content = getattr(delta, "content", None)
            if isinstance(content, str):
                parts.append(content)
            elif isinstance(content, list):
                for item in content:
                    text = item.get("text") if isinstance(item, dict) else getattr(item, "text", None)
                    if isinstance(text, str):
                        parts.append(text)
    raw_text = "".join(parts).strip()
    if not raw_text:
        raise ValueError("empty AI response")
    return OmniResult(raw_text=raw_text, usage=usage)


def normalize_entries(
    raw_text, categories, *, recover_wrapped_json=True, strict_schema=False
):
    cleaned = raw_text.strip()
    if recover_wrapped_json:
        cleaned = re.sub(
            r"^```(?:json)?\s*|\s*```$", "", cleaned, flags=re.IGNORECASE
        )
    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError:
        if not recover_wrapped_json:
            raise
        start, end = cleaned.find("["), cleaned.rfind("]")
        if start < 0 or end <= start:
            raise
        value = json.loads(cleaned[start : end + 1])

    if not isinstance(value, list):
        raise ValueError("AI response must be an array")
    if len(value) > 50:
        raise ValueError("AI response contains too many entries")

    by_id = {item["id"]: item for item in categories}
    by_name = {item["name"].casefold(): item for item in categories}
    normalized = []
    for entry in value:
        if not isinstance(entry, dict):
            raise ValueError("expense entry must be an object")
        if strict_schema and set(entry) != {
            "amount",
            "title",
            "category_id",
            "category_name",
            "date",
        }:
            raise ValueError("expense entry must contain exactly the required fields")
        amount = entry.get("amount")
        title = entry.get("title")
        if (
            isinstance(amount, bool)
            or not isinstance(amount, (int, float))
            or not math.isfinite(amount)
            or amount <= 0
        ):
            raise ValueError("expense amount must be positive")
        if not isinstance(title, str) or not title.strip():
            raise ValueError("expense title is required")

        category = by_id.get(str(entry.get("category_id", "")).strip())
        if category is None:
            category_name = str(
                entry.get("category_name", entry.get("category", ""))
            ).strip().casefold()
            category = by_name.get(category_name)
        if category is None:
            raise ValueError("expense category is not in the client category list")
        if strict_schema and entry.get("category_name") != category["name"]:
            raise ValueError("expense category id and name do not match")

        expense_date = entry.get("date")
        if not isinstance(expense_date, str):
            raise ValueError("expense date is required")
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", expense_date.strip()) is None:
            raise ValueError("expense date must use YYYY-MM-DD")
        try:
            normalized_date = date.fromisoformat(expense_date.strip()).isoformat()
        except ValueError as exc:
            raise ValueError("expense date must use YYYY-MM-DD") from exc

        normalized.append(
            {
                "amount": round(float(amount), 2),
                "title": title.strip()[:100],
                "category_id": category["id"],
                "category_name": category["name"],
                "date": normalized_date,
            }
        )
    return normalized


def _plain_object(value):
    if isinstance(value, dict):
        return value
    model_dump = getattr(value, "model_dump", None)
    if callable(model_dump):
        return model_dump(mode="json")
    return None
