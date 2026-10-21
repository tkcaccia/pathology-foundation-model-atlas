#!/usr/bin/env python3
"""Build the submission ZIP of model-level, machine-readable companions."""

from __future__ import annotations

import csv
import hashlib
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "manuscript" / "Additional_file_4_machine_readable_results.zip"
FILES = (
    "results/tables/foundation_model_matched_screen.csv",
    "results/tables/foundation_model_target_comparison.csv",
    "results/tables/foundation_model_pairwise_summary.csv",
    "results/tables/foundation_model_normalized_breadth_summary.csv",
    "results/tables/foundation_model_provenance_stratified_summary.csv",
    "results/tables/foundation_model_fold_stability_repeats.csv",
    "results/tables/foundation_model_tss_grouped_sensitivity.csv",
    "results/tables/foundation_model_binary_operating_rule_metrics.csv",
    "results/tables/endpoint_dictionary.csv",
    "results/tables/molecular_slide_linkage_audit.csv",
    "models/matched_v04/model_registry.csv",
    "results/tables/coad_pathofmpred_multifoundation_predictions.csv",
    "results/tables/coad_pathofmpred_multifoundation_binary_predictions.csv",
    "data/reference/outcome_source_acquisition_map.csv",
    "data/reference/literature_crosscheck_method.csv",
)


def main() -> None:
    missing = [name for name in FILES if not (ROOT / name).is_file()]
    if missing:
        raise FileNotFoundError("Missing companion files: " + ", ".join(missing))

    manifest_lines = ["relative_path,rows,sha256"]
    for name in FILES:
        content = (ROOT / name).read_bytes()
        with (ROOT / name).open(newline="", encoding="utf-8-sig") as handle:
            rows = sum(1 for _ in csv.DictReader(handle))
        manifest_lines.append(
            f"{name},{rows},{hashlib.sha256(content).hexdigest()}"
        )

    readme = """Additional file 4: selected machine-readable results

This ZIP accompanies the Journal of Translational Medicine submission. It
contains the 15 CSV files listed in MANIFEST.csv. All values describe internal
TCGA analyses; performance thresholds are descriptive, not clinical or
representation-specific multiplicity-controlled discoveries.

The matched-screen, target-comparison and paired-summary files provide the
three-representation benchmark. The provenance and endpoint-dictionary files
identify direct, inferred, RNA-derived and same-H&E reference phenotypes.
The fold-stability, grouped-sensitivity and binary-operating-rule files show
how estimates changed with partitions, tissue-source-site-code grouping and
classification rule. The two COAD files are research-software outputs for
TCGA-AA-A01F and TCGA-A6-A56B; some source labels for these patients were
used in final full-data fitting, so these rows are not held-out case validation.

No fitted model objects, patient-level embeddings, WSI pixels or source
molecular matrices are included. The public analysis repository provides the
complete result inventory and code. Its licence and upstream data terms are
separate from the PathoFMPred source-code licence.
"""

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with ZipFile(OUTPUT, "w", compression=ZIP_DEFLATED, compresslevel=9) as archive:
        archive.writestr("README.txt", readme)
        archive.writestr("MANIFEST.csv", "\n".join(manifest_lines) + "\n")
        for name in FILES:
            archive.write(ROOT / name, arcname=name)
    print(f"{OUTPUT} ({OUTPUT.stat().st_size:,} bytes; {len(FILES)} CSV files)")


if __name__ == "__main__":
    main()
