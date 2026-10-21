# fastPLS 0.4 runtime observations during atlas rerun

## Confirmed analysis-code issue, not a fastPLS defect

R's `future.apply::future_lapply(..., future.seed = TRUE)` selects the L'Ecuyer-CMRG random-number algorithm in workers. A sequential R session uses Mersenne-Twister by default. Consequently, the same numeric seed produced different patient-fold assignments for a small ACC genome-doubling test: TITAN outer AUROC was 0.4562963 under Mersenne-Twister and 0.5511111 under L'Ecuyer-CMRG. Input feature and outcome hashes were identical. This was an orchestration error in the atlas code. `R/utils.R` now pins Mersenne-Twister, Inversion normals and Rejection sampling before nested fitting and fold draws; grouped-fold construction and outcome permutations do the same. All affected analyses must be regenerated after this change. Numeric seeds alone are not sufficient provenance without the RNG algorithm.

## Unisolated compiled-path crash under concurrent processes

On macOS arm64 with 8 GiB RAM, R 4.6.0 and fastPLS 0.4, a one-off diagnostic process segfaulted inside the compiled `pls.single.cv` regression/classification path while a separate two-worker atlas run was active. The failing diagnostic used `future::plan(future::multicore, workers = 2)` and called `fit_binary_nested_auroc_once` for ACC genome doubling through `future.apply::future_lapply(..., future.seed = TRUE)`. The diagnostic simultaneously changed the RNG algorithm inside the worker. The same target had fitted successfully sequentially and in the main atlas. Memory pressure and forked-process interaction have not been ruled out; this event alone does not establish a fastPLS defect. Avoid running additional forked diagnostic jobs concurrently with the atlas until the crash is isolated without another active workload.

## Confirmed PathoFMPred inference bug

The new full-data binary artifact stores `class_labels` as a named character vector, whereas `predict_pathofmpred_object()` read it with `$positive` and `$negative`, which work for lists but not atomic vectors. The smoke test failed with `'$ operator is invalid for atomic vectors'`. Both public and private package variants now use `[["positive"]]` and `[["negative"]]`, and both test suites include a named-vector regression test. This was not a fastPLS issue.

## Expected rank truncation in small grouped folds

The tissue-source-site-code preflight completed for all three representations but warned that a requested 1-to-20 component path had only five estimable directions in one small grouped training fold. fastPLS 0.4 clamped requests above the effective rank and repeated the last estimable prediction for the higher prefixes. This is the documented finite-rank behavior, not a crash or evidence of a package defect. The grouped-fold adequacy and component-selection outputs retain the affected task information; requested components should not be mistaken for additional independent fitted directions in such folds.

## Confirmed atlas registry assembly bug

All 2,034 representation-specific final fits were saved, but `R/17b_fit_matched_resource_v04.R` initially used `data.table::fifelse()` with more than three arguments while assembling a text warning. The error was `unused argument ("")`. The script now uses `data.table::fcase()` for that multi-condition field, and the cached fits are being reused. This was an analysis-script bug, not a fastPLS failure.

## Package-behaviour conclusion pending final check

No other fastPLS 0.4 behaviour should be labelled defective until the complete rerun, sequential/parallel reproducibility check without concurrent workloads, and package tests finish. The exact fastPLS version and analysis settings are recorded in the software snapshot.
