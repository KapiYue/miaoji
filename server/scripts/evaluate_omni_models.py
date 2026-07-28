#!/usr/bin/env python3
import argparse
import base64
import json
import os
import sys
import time
from collections import Counter
from datetime import date
from pathlib import Path


REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
if str(REPOSITORY_ROOT) not in sys.path:
    sys.path.insert(0, str(REPOSITORY_ROOT))

from dotenv import load_dotenv
from openai import OpenAI

from server.omni import expense_prompt, normalize_entries, request_audio_expenses


load_dotenv(REPOSITORY_ROOT / "server" / ".env")


DEFAULT_MODELS = [
    "qwen-omni-turbo-0119",
    "qwen3.5-omni-plus",
    "qwen3.5-omni-flash",
]
MAX_BASE64_SOURCE_BYTES = 7_500_000


def parse_args():
    parser = argparse.ArgumentParser(
        description="Run the same labeled M4A recordings through multiple Qwen Omni models."
    )
    parser.add_argument("manifest", type=Path, help="JSON benchmark manifest")
    parser.add_argument(
        "--models", nargs="+", default=DEFAULT_MODELS, help="model IDs to compare"
    )
    parser.add_argument(
        "--base-url",
        default=os.getenv("DASHSCOPE_BASE_URL"),
        help="OpenAI-compatible API base URL (defaults to DASHSCOPE_BASE_URL)",
    )
    parser.add_argument(
        "--output-dir", type=Path, default=Path("server/evaluations/latest")
    )
    parser.add_argument("--pricing", type=Path, help="optional current price JSON")
    parser.add_argument("--repetitions", type=int, default=1)
    parser.add_argument("--timeout", type=float, default=180.0)
    return parser.parse_args()


def main():
    args = parse_args()
    api_key = os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        raise SystemExit("DASHSCOPE_API_KEY is required")
    if not args.base_url:
        raise SystemExit("DASHSCOPE_BASE_URL or --base-url is required")
    if args.repetitions < 1:
        raise SystemExit("--repetitions must be at least 1")

    manifest = load_manifest(args.manifest)
    prices = load_prices(args.pricing)
    client = OpenAI(
        api_key=api_key,
        base_url=args.base_url.rstrip("/"),
        timeout=args.timeout,
        max_retries=1,
    )
    signed_url_factory = make_signed_url_factory(manifest)
    runs = []

    for model in args.models:
        for benchmark_case in manifest["cases"]:
            for repetition in range(args.repetitions):
                print(
                    f"[{model}] {benchmark_case['id']} repetition {repetition + 1}/{args.repetitions}",
                    flush=True,
                )
                runs.append(
                    run_case(
                        client,
                        model,
                        benchmark_case,
                        manifest["categories"],
                        args.manifest.parent,
                        manifest["timezone"],
                        repetition,
                        signed_url_factory,
                    )
                )

    summary = summarize(runs, args.models, prices)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    write_jsonl(args.output_dir / "runs.jsonl", runs)
    write_json(args.output_dir / "summary.json", summary)
    (args.output_dir / "report.md").write_text(
        render_report(summary), encoding="utf-8"
    )
    print(f"Report: {(args.output_dir / 'report.md').resolve()}")


def load_manifest(path):
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError("manifest must be a JSON object")
    categories = data.get("categories")
    cases = data.get("cases")
    if not isinstance(categories, list) or not categories:
        raise ValueError("manifest categories must be a non-empty array")
    if not isinstance(cases, list) or not cases:
        raise ValueError("manifest cases must be a non-empty array")
    category_ids = set()
    for category in categories:
        if not isinstance(category, dict) or not category.get("id") or not category.get("name"):
            raise ValueError("each category requires id and name")
        if category["id"] in category_ids:
            raise ValueError("category ids must be unique")
        category_ids.add(category["id"])

    seen_case_ids = set()
    for benchmark_case in cases:
        validate_case(benchmark_case, category_ids)
        if benchmark_case["id"] in seen_case_ids:
            raise ValueError("case ids must be unique")
        seen_case_ids.add(benchmark_case["id"])
    return {
        "categories": categories,
        "cases": cases,
        "timezone": data.get("timezone", "Asia/Shanghai"),
        "storage_bucket": data.get("storage_bucket", "user-audio"),
        "supabase_url": data.get("supabase_url"),
    }


def validate_case(benchmark_case, category_ids):
    if not isinstance(benchmark_case, dict) or not benchmark_case.get("id"):
        raise ValueError("each case requires an id")
    sources = [key for key in ("file", "storage_path") if benchmark_case.get(key)]
    if len(sources) != 1:
        raise ValueError(f"case {benchmark_case['id']} requires exactly one of file or storage_path")
    if "file" in sources and Path(benchmark_case["file"]).suffix.lower() != ".m4a":
        raise ValueError(f"case {benchmark_case['id']} file must end in .m4a")
    try:
        date.fromisoformat(benchmark_case["reference_date"])
    except (KeyError, TypeError, ValueError) as exc:
        raise ValueError(f"case {benchmark_case['id']} requires reference_date YYYY-MM-DD") from exc
    expected = benchmark_case.get("expected")
    if not isinstance(expected, list):
        raise ValueError(f"case {benchmark_case['id']} expected must be an array")
    for entry in expected:
        if not isinstance(entry, dict):
            raise ValueError(f"case {benchmark_case['id']} expected entries must be objects")
        if not isinstance(entry.get("amount"), (int, float)) or entry["amount"] <= 0:
            raise ValueError(f"case {benchmark_case['id']} has an invalid expected amount")
        if entry.get("category_id") not in category_ids:
            raise ValueError(f"case {benchmark_case['id']} has an unknown expected category")
        try:
            date.fromisoformat(entry["date"])
        except (KeyError, TypeError, ValueError) as exc:
            raise ValueError(f"case {benchmark_case['id']} has an invalid expected date") from exc


def load_prices(path):
    if path is None:
        return {}
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("pricing must be a JSON object keyed by model ID")
    return value


def make_signed_url_factory(manifest):
    if not any(case.get("storage_path") for case in manifest["cases"]):
        return None
    supabase_url = manifest.get("supabase_url") or os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SECRET_KEY")
    if not supabase_url or not supabase_key:
        raise ValueError("storage_path cases require SUPABASE_URL and SUPABASE_SECRET_KEY")
    from supabase import create_client

    bucket = create_client(supabase_url, supabase_key).storage.from_(
        manifest["storage_bucket"]
    )

    def create(storage_path):
        result = bucket.create_signed_url(storage_path, 300)
        if isinstance(result, dict):
            url = result.get("signedURL") or result.get("signedUrl") or result.get("signed_url")
        else:
            url = getattr(result, "signed_url", None)
        if not isinstance(url, str) or not url.startswith("https://"):
            raise ValueError("Supabase returned an invalid signed URL")
        return url

    return create


def audio_input(benchmark_case, manifest_directory, signed_url_factory):
    if benchmark_case.get("storage_path"):
        if signed_url_factory is None:
            raise ValueError("signed URL support is not configured")
        return signed_url_factory(benchmark_case["storage_path"]), "signed_url"
    path = (manifest_directory / benchmark_case["file"]).resolve()
    if not path.is_file():
        raise ValueError(f"audio file does not exist: {path}")
    audio_bytes = path.read_bytes()
    if not audio_bytes:
        raise ValueError(f"audio file is empty: {path}")
    if len(audio_bytes) > MAX_BASE64_SOURCE_BYTES:
        raise ValueError(
            f"audio file is too large for the API's 10 MB Base64 limit: {path}"
        )
    encoded = base64.b64encode(audio_bytes).decode("ascii")
    return f"data:;base64,{encoded}", "base64"


def run_case(
    client,
    model,
    benchmark_case,
    categories,
    manifest_directory,
    timezone_name,
    repetition,
    signed_url_factory,
):
    started = time.perf_counter()
    record = {
        "model": model,
        "case_id": benchmark_case["id"],
        "repetition": repetition + 1,
        "tags": benchmark_case.get("tags", []),
        "expected": benchmark_case["expected"],
    }
    try:
        data, source = audio_input(
            benchmark_case, manifest_directory, signed_url_factory
        )
        prompt = expense_prompt(
            categories,
            date.fromisoformat(benchmark_case["reference_date"]),
            timezone_name,
        )
        result = request_audio_expenses(client, model, data, "m4a", prompt)
        record["latency_ms"] = round((time.perf_counter() - started) * 1000, 2)
        record["source"] = source
        record["raw_text"] = result.raw_text
        record["usage"] = result.usage
        try:
            strict_entries = normalize_entries(
                result.raw_text,
                categories,
                recover_wrapped_json=False,
                strict_schema=True,
            )
            record["strict_valid"] = True
            record["parsed"] = strict_entries
        except (ValueError, json.JSONDecodeError) as strict_error:
            record["strict_valid"] = False
            record["strict_error"] = str(strict_error)
            record["parsed"] = normalize_entries(result.raw_text, categories)
        record["metrics"] = score_case(benchmark_case["expected"], record["parsed"])
    except Exception as exc:
        record["latency_ms"] = round((time.perf_counter() - started) * 1000, 2)
        record["strict_valid"] = False
        record["error"] = f"{type(exc).__name__}: {exc}"
        record["parsed"] = None
        record["metrics"] = score_case(benchmark_case["expected"], [])
    return record


def score_case(expected, predicted):
    predicted = predicted or []
    expected_amounts = Counter(round(float(item["amount"]), 2) for item in expected)
    predicted_amounts = Counter(round(float(item["amount"]), 2) for item in predicted)
    pairs = align_entries(expected, predicted)
    return {
        "amount_exact": expected_amounts == predicted_amounts,
        "count_exact": len(expected) == len(predicted),
        "category_correct": sum(
            expected_item["category_id"] == predicted_item.get("category_id")
            for expected_item, predicted_item in pairs
        ),
        "date_correct": sum(
            expected_item["date"] == predicted_item.get("date")
            for expected_item, predicted_item in pairs
        ),
        "expected_entries": len(expected),
    }


def align_entries(expected, predicted):
    remaining = list(predicted)
    pairs = []
    for expected_item in expected:
        if not remaining:
            break

        def rank(predicted_item):
            amount_delta = abs(
                round(float(expected_item["amount"]), 2)
                - round(float(predicted_item.get("amount", 0)), 2)
            )
            return (
                amount_delta != 0,
                amount_delta,
                expected_item["category_id"] != predicted_item.get("category_id"),
                expected_item["date"] != predicted_item.get("date"),
            )

        selected = min(range(len(remaining)), key=lambda index: rank(remaining[index]))
        pairs.append((expected_item, remaining.pop(selected)))
    return pairs


def summarize(runs, model_order, prices):
    models = {}
    for model in model_order:
        model_runs = [run for run in runs if run["model"] == model]
        expected_entries = sum(
            run["metrics"]["expected_entries"] for run in model_runs
        )
        successful = [run for run in model_runs if "error" not in run]
        prompt_tokens = sum(usage_value(run.get("usage"), "prompt_tokens") for run in model_runs)
        completion_tokens = sum(
            usage_value(run.get("usage"), "completion_tokens") for run in model_runs
        )
        model_summary = {
            "runs": len(model_runs),
            "successful_runs": len(successful),
            "api_error_rate": ratio(len(model_runs) - len(successful), len(model_runs)),
            "amount_exact_rate": ratio(
                sum(run["metrics"]["amount_exact"] for run in model_runs), len(model_runs)
            ),
            "count_exact_rate": ratio(
                sum(run["metrics"]["count_exact"] for run in model_runs), len(model_runs)
            ),
            "category_accuracy": ratio(
                sum(run["metrics"]["category_correct"] for run in model_runs),
                expected_entries,
            ),
            "date_accuracy": ratio(
                sum(run["metrics"]["date_correct"] for run in model_runs), expected_entries
            ),
            "invalid_output_rate": ratio(
                sum(not run["strict_valid"] for run in model_runs), len(model_runs)
            ),
            "p50_latency_ms": percentile(
                [run["latency_ms"] for run in successful], 0.50
            ),
            "p95_latency_ms": percentile(
                [run["latency_ms"] for run in successful], 0.95
            ),
            "prompt_tokens": prompt_tokens,
            "completion_tokens": completion_tokens,
            "estimated_cost_per_1000_calls": estimated_cost_per_1000(
                model, prices, prompt_tokens, completion_tokens, len(model_runs)
            ),
        }
        models[model] = model_summary
    return {"models": models, "decision": choose_model(models)}


def usage_value(usage, key):
    if not isinstance(usage, dict):
        return 0
    value = usage.get(key, 0)
    return value if isinstance(value, (int, float)) else 0


def ratio(numerator, denominator):
    return round(numerator / denominator, 6) if denominator else None


def percentile(values, fraction):
    if not values:
        return None
    ordered = sorted(values)
    index = (len(ordered) - 1) * fraction
    lower = int(index)
    upper = min(lower + 1, len(ordered) - 1)
    weight = index - lower
    return round(ordered[lower] * (1 - weight) + ordered[upper] * weight, 2)


def estimated_cost_per_1000(model, prices, prompt_tokens, completion_tokens, runs):
    price = prices.get(model)
    if not isinstance(price, dict) or not runs:
        return None
    input_price = price.get("input_per_million")
    output_price = price.get("output_per_million")
    if not isinstance(input_price, (int, float)) or not isinstance(
        output_price, (int, float)
    ):
        return None
    total_cost = (
        prompt_tokens * input_price + completion_tokens * output_price
    ) / 1_000_000
    return round(total_cost / runs * 1000, 6)


def choose_model(models):
    plus = models.get("qwen3.5-omni-plus")
    flash = models.get("qwen3.5-omni-flash")
    if not plus or not flash:
        return {
            "model": None,
            "reason": "Plus and Flash must both be included before making a decision.",
        }
    if plus["successful_runs"] != plus["runs"] or flash["successful_runs"] != flash["runs"]:
        return {
            "model": None,
            "reason": "At least one Plus or Flash API call failed; rerun before deciding.",
        }
    accuracy_keys = [
        "amount_exact_rate",
        "count_exact_rate",
        "category_accuracy",
        "date_accuracy",
    ]
    if any(plus[key] is None or flash[key] is None for key in accuracy_keys):
        return {
            "model": None,
            "reason": "The benchmark has no labeled expense entries for one or more required accuracy metrics.",
        }
    flash_not_worse = all(flash[key] >= plus[key] for key in accuracy_keys)
    flash_output_not_worse = (
        flash["invalid_output_rate"] <= plus["invalid_output_rate"]
    )
    if flash_not_worse and flash_output_not_worse:
        return {
            "model": "qwen3.5-omni-flash",
            "reason": "Flash is not worse than Plus on all accuracy metrics or invalid output rate.",
        }
    return {
        "model": "qwen3.5-omni-plus",
        "reason": "Flash is worse than Plus on at least one required accuracy or output-validity metric.",
    }


def render_report(summary):
    lines = [
        "# Qwen Omni 语音记账评测报告",
        "",
        "| 模型 | 金额完全匹配 | 笔数匹配 | 分类准确率 | 日期准确率 | 非法输出率 | API 错误率 | P50 / P95 | 每千次估算成本 |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for model, metrics in summary["models"].items():
        lines.append(
            "| {model} | {amount} | {count} | {category} | {date} | {invalid} | {api_error} | {p50} / {p95} ms | {cost} |".format(
                model=model,
                amount=format_percent(metrics["amount_exact_rate"]),
                count=format_percent(metrics["count_exact_rate"]),
                category=format_percent(metrics["category_accuracy"]),
                date=format_percent(metrics["date_accuracy"]),
                invalid=format_percent(metrics["invalid_output_rate"]),
                api_error=format_percent(metrics["api_error_rate"]),
                p50=metrics["p50_latency_ms"] if metrics["p50_latency_ms"] is not None else "—",
                p95=metrics["p95_latency_ms"] if metrics["p95_latency_ms"] is not None else "—",
                cost=metrics["estimated_cost_per_1000_calls"]
                if metrics["estimated_cost_per_1000_calls"] is not None
                else "未提供价格",
            )
        )
    decision = summary["decision"]
    lines.extend(
        [
            "",
            "## 自动结论",
            "",
            f"建议模型：`{decision['model']}`" if decision["model"] else "暂不自动选型。",
            "",
            decision["reason"],
            "",
            "> 成本仅在提供当前百炼控制台价格文件时估算；不要仅按音频 Token 换算率判断账单。",
            "",
        ]
    )
    return "\n".join(lines)


def format_percent(value):
    return "—" if value is None else f"{value * 100:.2f}%"


def write_json(path, value):
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def write_jsonl(path, values):
    path.write_text(
        "".join(json.dumps(value, ensure_ascii=False) + "\n" for value in values),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
