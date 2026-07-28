import unittest

from server.scripts.evaluate_omni_models import choose_model, score_case, summarize


class EvaluationScoringTests(unittest.TestCase):
    def test_scores_unordered_entries_by_amount(self):
        expected = [
            {"amount": 45.6, "category_id": "food", "date": "2026-07-26"},
            {"amount": 28, "category_id": "transport", "date": "2026-07-27"},
        ]
        predicted = [
            {
                "amount": 28.0,
                "category_id": "transport",
                "date": "2026-07-27",
            },
            {
                "amount": 45.6,
                "category_id": "food",
                "date": "2026-07-26",
            },
        ]

        metrics = score_case(expected, predicted)

        self.assertTrue(metrics["amount_exact"])
        self.assertTrue(metrics["count_exact"])
        self.assertEqual(metrics["category_correct"], 2)
        self.assertEqual(metrics["date_correct"], 2)

    def test_empty_audio_case_is_scored_as_exact(self):
        metrics = score_case([], [])

        self.assertTrue(metrics["amount_exact"])
        self.assertTrue(metrics["count_exact"])
        self.assertEqual(metrics["expected_entries"], 0)

    def test_flash_is_selected_only_when_no_required_metric_is_worse(self):
        perfect = {
            "runs": 10,
            "successful_runs": 10,
            "amount_exact_rate": 1.0,
            "count_exact_rate": 1.0,
            "category_accuracy": 0.95,
            "date_accuracy": 0.9,
            "invalid_output_rate": 0.0,
        }
        same = dict(perfect)

        decision = choose_model(
            {"qwen3.5-omni-plus": perfect, "qwen3.5-omni-flash": same}
        )
        self.assertEqual(decision["model"], "qwen3.5-omni-flash")

        worse_flash = dict(same, date_accuracy=0.89)
        decision = choose_model(
            {
                "qwen3.5-omni-plus": perfect,
                "qwen3.5-omni-flash": worse_flash,
            }
        )
        self.assertEqual(decision["model"], "qwen3.5-omni-plus")

    def test_summary_includes_latency_and_cost(self):
        run = {
            "model": "qwen3.5-omni-plus",
            "latency_ms": 1000,
            "strict_valid": True,
            "usage": {"prompt_tokens": 100, "completion_tokens": 20},
            "metrics": {
                "amount_exact": True,
                "count_exact": True,
                "category_correct": 1,
                "date_correct": 1,
                "expected_entries": 1,
            },
        }

        summary = summarize(
            [run],
            ["qwen3.5-omni-plus"],
            {
                "qwen3.5-omni-plus": {
                    "input_per_million": 2,
                    "output_per_million": 4,
                }
            },
        )

        metrics = summary["models"]["qwen3.5-omni-plus"]
        self.assertEqual(metrics["p50_latency_ms"], 1000)
        self.assertEqual(metrics["estimated_cost_per_1000_calls"], 0.28)


if __name__ == "__main__":
    unittest.main()
