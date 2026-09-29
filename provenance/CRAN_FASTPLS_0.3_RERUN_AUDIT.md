# CRAN fastPLS 0.3 rerun audit

The full analysis was rebuilt with the CRAN source release of fastPLS 0.3.
The downloaded `fastPLS_0.3.tar.gz` source archive has SHA-256
`e752ed28dcbaf162d8e622d3c7dc436b315ef4b767c06db2ae8b29cbbfa7b51f`.
The preceding analysis used the GitHub 0.3 build at commit
`b518f75285c387632c2443a0c0989d75c9dcda48`. Its checkpoints were moved
to the ignored, recoverable `rerun_archive/fastpls_github_20260929/checkpoints`
directory before the new run.

The analysis uses 1 to 20 PLS components, patient-level outer and inner folds,
and the fastPLS 0.3 rSVD defaults of 32 oversampling vectors and five power
iterations. The inherited `C.UTF-8` locale is unavailable on this Mac and
caused an encoding warning before the screening stage. That preliminary
process was stopped, the old checkpoints remained archived, and the complete
run was restarted under the valid `en_US.UTF-8` locale. This was an environment
locale issue, not a fastPLS numerical error. The
project-local package reports version 0.3 and `Repository: CRAN`.

The rebuilt screens comprise 3,174 continuous and 459 binary eligible
cancer-endpoint pairs. Their Q2, RMSE, Spearman and balanced-accuracy estimates
match the preceding Git build exactly on keyed comparisons. Permutation and
matched-representation metrics were checked separately after completion.

During the 999-permutation stage, two worker starts emitted `OMP: Warning #179:
Function Can't set size of /tmp file failed`. The [OpenMP runtime source](https://github.com/llvm/llvm-project/blob/main/openmp/runtime/src/kmp_runtime.cpp)
shows that this warning is generated when resizing its temporary registration
file fails and that the runtime then has an environment-variable fallback.
The R workers continued. At the first post-warning check, the 355 completed
continuous permutation p-values and exceedance counts still matched the
previous build exactly. The cause of the temporary-file warning is not yet
established and it is not attributed to a fastPLS fitting defect. It remains
on the release watch list until the complete run passes its result audit.

The first six-worker permutation pass stopped after 766 of 874 effect-gated
jobs had completed 999 permutations. Two checkpoint temporary files could not
be opened because the local APFS data volume reported no free space. All
completed checkpoints remained intact, and no incomplete temporary files were
left in the checkpoint directory. Available space returned after the worker
processes exited, which suggests transient process-associated storage rather
than growth of saved checkpoints, but the exact allocation remains unproven.
The rerun was resumed from the preserved checkpoints with two workers and the
same numerical settings to reduce concurrent temporary-file demand. This is
a storage/runtime failure, not evidence of a fastPLS numerical defect.
On resume, R warned that `data.table` and `future` had been built under R
4.6.1 while this process used R 4.6.0. The packages loaded and the checkpoint
stage continued; these are dependency-build warnings, not fastPLS errors. All
874 effect-gated 999-permutation jobs completed under the CRAN build. The
pipeline then entered its eight separately locked 9,999-permutation target
refinements. No additional fastPLS numerical error occurred in the completed
999-permutation stage.

The release-order audit found that the runner previously installed the private
PathoFMPred package after copying individual fitted objects but before
rebuilding its three consolidated collection objects. This could have left
the two COAD illustrations using an older collection despite a refreshed
registry. The runner now rebuilds the collections before installation. The
collections, installation, demonstrations and figures were explicitly repeated
and checked against the refreshed registry.

Release checks completed after the full run:

- Verified all permutation, repeated-validation, matched-representation and
  tissue-source-site outputs were regenerated under the CRAN build.
- Rebuilt figures, manuscript, supplement, the two COAD reports and both
  PathoFMPred model collections from the same result snapshot.
- Rebuilt and inspected the public and private packages and their reference
  manuals; ran `R CMD check --as-cran` on both.
- Checked registry keys, model hashes, public-release licensing boundary,
  manuscript numbers, figure captions, supplementary references and release
  asset hashes before publishing.

Final status: the numerical run and local release audits passed. A keyed comparison with the preceding GitHub 0.3 build found zero changed initial-screen Q2, RMSE, Spearman, balanced accuracy, permutation p-values and q-values, and zero changed matched-screen Q2, AUROC, balanced accuracy or PR-AUC values across 10,167 representation-task rows. All three fitted collections and both package sources were rebuilt. Public and private `R CMD check --as-cran` each returned 0 errors, 0 warnings and only the `New submission` note. The manuscript, figures, supplementary material and two patient reports were regenerated and audited.

The release audit found one project-specific provenance defect: the completed CRAN matched-screen metrics were initially written to a component-suffixed file while the canonical table retained the previous Git commit identifier. The numerical values were identical. The runner now promotes the complete CRAN screen, out-of-fold predictions and summary to canonical filenames after aggregation; downstream operating metadata, summaries, registry and manuscript were regenerated. The heavy fold-stability and grouped-code fits were not repeated a second time after this metadata-only correction because they had already used CRAN fastPLS and identical numerical inputs. Their checkpoint source fingerprints may still identify the earlier metadata-file hash. This is disclosed rather than claimed as a separate second numerical computation.

No confirmed fastPLS numerical defect was observed. The full defect and improvement report is `FASTPLS_CRAN_0.3_OBSERVATIONS.md`.
