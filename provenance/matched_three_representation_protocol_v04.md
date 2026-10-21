# Matched three-representation analysis protocol

This protocol governs the TCGA comparison of TITAN, Giga-SSL and Prov-GigaPath slide representations using fastPLS 0.4. It describes the scientific comparison; the software provenance manifest records the exact implementation revision separately.

## Population and input

Use the intersection of diagnostic primary-tumour slide identifiers present in all three released resources. Aggregate repeated slide vectors within each patient by the arithmetic mean, using exactly the same slide identifiers in each representation. Retain a patient only when all three representations contain at least one shared slide. Analyse one patient-level row per outcome. A comparison using each resource's full available slide set is a sensitivity analysis, not the primary estimate.

## Outcomes

Use the same source-defined continuous and binary outcomes, transformations, missingness rules and eligibility thresholds for every representation. The outcome-labelled patients for a cancer-endpoint pair must be identical across representations. Do not equate a computationally inferred immune score with a directly measured immune-cell assay. The H&E-derived TIL Regional Fraction is retained as a same-modality outcome but omitted from the default non-H&E reference-phenotype summary.

## Prediction and comparison

R's Mersenne-Twister random-number algorithm, Inversion normal generator and Rejection sampling are fixed before fold construction and fitting. This makes a numeric seed identify the same partitions in sequential and parallel execution.

Use identical outer and inner patient folds, seeds, 1 to 20 PLS components, fastPLS numerical defaults and training-only preprocessing for all representations. Select components for a continuous outcome by pooled inner out-of-fold squared error. Select components for a binary outcome by pooled inner out-of-fold AUROC. Use outer out-of-fold Q² and AUROC as the primary paired comparison statistics. Learn any binary decision threshold from inner out-of-fold training scores only. Report PR-AUC and its prevalence reference, sensitivity, specificity, balanced accuracy, PPV and NPV as secondary metrics. Describe Q² at least 0.20 and AUROC at least 0.60 as pragmatic effect-threshold crossings, not significance boundaries.

## Statistical evidence

The primary matched atlas is a descriptive comparison of held-out Q² and AUROC. Its effect-threshold crossings do not receive permutation p-values or false-discovery-rate qualification. The same decision applies to all three representations. An optional, separately identified inferential extension can apply complete-process permutations and the same multiplicity families to all three representations, retaining every eligible task in each correction denominator. That extension must repeat fold construction, inner component selection, outer fitting and prediction after each patient-label permutation, use matched permutation indices across representations, and report Monte Carlo uncertainty. Results from a partial permutation run must not be presented as completed inference.

## Robustness

Use the same alternative partitions and tissue-source-site-code-grouped folds for all three representations on an outcome set defined without reference to one representation alone. Keep grouped inner folds intact by code. Compare grouped estimates with matched-random folds of the same test-set sizes and binary class counts. Flag sparse or single-class grouped folds. Report the number of outcome-labelled patients, positive cases, contributing codes and realized folds.

## Interpretation

The primary experiment compares released slide representations under one specified PLS-based downstream probe. The released models differ in pretraining data, preprocessing, resolution and embedding construction. Giga-SSL used TCGA images during representation learning; this cannot be made equivalent to the reported TCGA-free pretraining cohorts of TITAN and Prov-GigaPath by changing downstream cross-validation. Report this upstream exposure difference without implying molecular-label leakage. No internal TCGA analysis is external validation.
