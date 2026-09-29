# fastPLS 0.3 (CRAN): project observations

This final log separates reproducible fastPLS defects from analysis-code and operating-environment failures.

## Exact software used

- Package: fastPLS 0.3, installed from the CRAN source archive on 29 September 2026.
- Source SHA-256: `e752ed28dcbaf162d8e622d3c7dc436b315ef4b767c06db2ae8b29cbbfa7b51f`.
- Analysis settings: CPU, rSVD, package defaults of 32 oversampling vectors and five power iterations, candidate component counts 1 through 20. The same settings were applied to all released representation pipelines.
- `fastPLS::has_metal()` returned `TRUE` in this installation. CPU execution was chosen for the atlas to keep the same backend across all representation pipelines; this is not evidence of a Metal failure.

## Confirmed fastPLS defects in this CRAN build

None observed in the completed project rerun. Regression and LDA nested-CV smoke tests completed, including constant-response and single-class behavior. Both rebuilt PathoFMPred packages passed `R CMD check --as-cran` with no error or warning. The only check note was `New submission`.

The completed phases include all 3,174 continuous and 459 binary TITAN initial screens, 874 effect-gated 999-permutation checks, eight 9,999-permutation refinements, 869 repeated TITAN refits, and the 3,389-task matched TITAN/Giga-SSL/Prov-GigaPath screen. The three-representation screen returned finite primary metrics for every eligible task. Alternative-partition, exact-common-slide, grouped-code, model-collection and package checks also completed. The keyed comparison to the preceding GitHub 0.3 build found zero changed values in initial Q2, RMSE, Spearman, balanced accuracy, permutation p and q fields, and zero changed matched-screen Q2, AUROC, balanced accuracy and PR-AUC fields across 10,167 representation-task rows. This is numerical agreement for those compared fields, not a claim that every file is byte-identical.

## Expected rank-limit warnings observed in grouped validation

The all-representation tissue-source-site-code analysis emitted many warnings of
the form `The component path is limited to rank 5; requests above this value use
5 internally, and returned prediction paths repeat the last estimable prefix.`
This arose in sparse grouped training folds when the requested path was 1:20.
It is the documented safe behavior, not a fit failure. All 971 union-crossing
tasks returned grouped results for all three representations. A deliberately
rerun first task, ACC genome doubling, produced identical checkpoint results,
fold audits and code-only estimates to its original CRAN run.

A minimal reproducer on the installed CRAN source build is:

```r
library(fastPLS)
set.seed(7)
x <- matrix(rnorm(12 * 6), 12, 6)
y <- factor(rep(c(0, 1), 6))
fit <- pls(x, y, ncomp = 1:20, classifier = "lda", fit = TRUE,
           rsvd_oversample = 32, rsvd_power = 5, seed = 7)
p <- predict(fit, x, raw_scores = TRUE)
stopifnot(identical(dim(p$LDA_scores), c(12L, 2L, 20L)),
          identical(p$LDA_scores[, , 6], p$LDA_scores[, , 20]))
```

The behavior is numerically sensible. The improvement opportunity is to make
the effective maximum rank available as a simple machine-readable field for
every fit and fold, and optionally coalesce the same rank-limit warning across
a nested-CV call. This would distinguish a requested component label from an
estimable direction without flooding a large screen with repeated warnings.

## Failures that are not fastPLS defects

- An earlier six-worker permutation run exhausted temporary disk space and stopped after 766 of 874 effect-gated jobs. This is an orchestration/storage failure. The run resumed from validated CRAN checkpoints with two workers; no numerical setting was changed.
- A previous repeated-continuous-validation error arose in our analysis helper, which extracted a scalar from a three-dimensional prediction array and recycled it across a held-out fold. The helper now drops singleton dimensions and asserts that one prediction exists per held-out patient. The error was not in fastPLS.
- Warnings that selected dependencies were built under R 4.6.1 while the process used R 4.6.0 concern the local R library, not a demonstrated fastPLS failure.
- The representative ridge scripts emitted aggregated R warnings. A targeted reproduction on the 44-patient DLBC any-fusion task identified the exact warning: `glmnet::cv.lognet` changed its unused internal `type.measure='auc'` summary to deviance because an inner fold contained fewer than ten observations. This occurred repeatedly across nested fits. The ridge scripts independently selected penalties from pooled inner held-out balanced accuracy or AUROC, so `cv.glmnet`'s internal summary was not the tuning objective. We explicitly set that unused summary to deviance and reran both ridge sensitivities. Their model-level, repeated-CV, summary and matched-probe CSV outputs were byte-for-byte identical to the pre-fix results. This was a `glmnet` fallback and a clarity defect in our analysis script, not a fastPLS defect.
- The matched-screen runner initially left the canonical filename pointing to prior metadata while writing the complete CRAN results to a component-suffixed filename. Numerical metrics were identical, but the provenance field was wrong. The runner now promotes the complete CRAN screen, out-of-fold predictions and summary to their canonical filenames after aggregation. The downstream binary operating metadata, summaries, registry and manuscript were regenerated. This was a release-provenance defect in this project, not a fastPLS defect.

## Potential improvements to discuss with fastPLS maintainers

These are proposals, not reproducible defects, and should not block the present analysis without new evidence:

1. Provide a short, stable machine-readable description of every nested-CV fallback at the prediction and fold level, including constant-response, single-class, truncated-prefix and non-estimable metric cases. The current analysis records and audits this information at the surrounding pipeline level.
2. Offer an optional resource-use diagnostic for parallel cross-validation that estimates temporary-disk requirements or supports an explicit scratch directory. This would help users avoid storage exhaustion on large endpoint atlases.
3. Include an end-to-end vignette for grouped outer and inner folds with pooled out-of-fold AUROC tuning, training-only operating-threshold selection and all requested component prefixes retained. The functions support these workflows; a canonical example would reduce implementation ambiguity.
4. Consider harmonizing the first two argument names of `pls()` (`Xtrain`,
   `Ytrain`) and `pls.single.cv()` (`Xdata`, `Ydata`), or add a prominent crosswalk
   in the documentation. A diagnostic call using `Xdata=` with `pls()` failed
   with `argument "Xtrain" is missing`; the correct call with positional inputs
   succeeded. This is an API usability issue, not a computational defect.

There is no corrective fastPLS code request from this rerun. The four items above are optional diagnostics and documentation improvements; none requires stopping or repeating the completed numerical analysis.
