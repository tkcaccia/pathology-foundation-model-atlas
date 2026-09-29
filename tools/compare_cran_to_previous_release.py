#!/usr/bin/env python3
"""Compare the CRAN fastPLS rerun with the committed pre-rerun snapshot.

This is a diagnostic only. A zero numerical delta does not substitute for
provenance checks that each stage was actually recomputed under CRAN fastPLS.
"""

from __future__ import annotations

import csv
import io
import math
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SPECS = (
    ("results/tables/continuous_screen.csv",
     ("family", "tumor_type", "endpoint"),
     ("q2", "rmse", "spearman", "p_permutation", "q_value")),
    ("results/tables/binary_screen.csv",
     ("family", "tumor_type", "endpoint"),
     ("balanced_accuracy", "adjusted_balanced_accuracy", "auc",
      "p_permutation", "q_value")),
    ("results/tables/foundation_model_matched_screen.csv",
     ("foundation_model", "outcome_type", "family", "tumor_type", "endpoint"),
     ("q2", "auc", "balanced_accuracy", "pr_auc")),
)


def read_current(path: str) -> list[dict[str, str]]:
    with (ROOT / path).open(newline="", encoding="utf-8-sig") as handle:
        return list(csv.DictReader(handle))


def read_previous(path: str) -> list[dict[str, str]]:
    result = subprocess.run(
        ["git", "show", f"HEAD:{path}"], cwd=ROOT, check=True,
        capture_output=True, text=True,
    )
    return list(csv.DictReader(io.StringIO(result.stdout)))


def number(value: str | None) -> float:
    if value in (None, "", "NA", "NaN"):
        return math.nan
    try:
        return float(value)
    except ValueError:
        return math.nan


for path, fields, metrics in SPECS:
    before = read_previous(path)
    after = read_current(path)
    old = {tuple(row[field] for field in fields): row for row in before}
    new = {tuple(row[field] for field in fields): row for row in after}
    if len(old) != len(before) or len(new) != len(after):
        raise RuntimeError(f"Duplicate comparison key in {path}")
    print(f"{path}: previous={len(old)}, CRAN={len(new)}, "
          f"shared={len(old.keys() & new.keys())}")
    if old.keys() != new.keys():
        print(f"  keys added={len(new.keys() - old.keys())}, "
              f"removed={len(old.keys() - new.keys())}")
    for metric in metrics:
        if not all(metric in row for row in (before[0], after[0])):
            continue
        deltas = []
        missingness_changes = 0
        for key in old.keys() & new.keys():
            a, b = number(old[key].get(metric)), number(new[key].get(metric))
            if math.isnan(a) != math.isnan(b):
                missingness_changes += 1
            elif math.isfinite(a) and math.isfinite(b):
                deltas.append(abs(a - b))
        changed = sum(delta > 1e-12 for delta in deltas)
        maximum = max(deltas, default=0.0)
        print(f"  {metric}: changed={changed}, max_abs_delta={maximum:.9g}, "
              f"missingness_changes={missingness_changes}")
