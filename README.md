# Pathology foundation-model atlas

This project compares three released pathology slide representations, TITAN, Giga-SSL and Prov-GigaPath, for estimating cancer-specific tumour features from TCGA haematoxylin-and-eosin slides. A *cancer-endpoint pair* is one feature evaluated within one cancer, such as BRAF mutation in thyroid carcinoma or an RNA-derived immune signature in thymoma. Predictability here means statistical association in held-out TCGA patients under the specified model and validation design. It does not mean causal interpretation, assay replacement or clinical validity.

The primary matched analysis includes 8,241 patients from 30 cancers. The same 10,165 diagnostic-slide identifiers, outcome-labelled patients and nested cross-validation folds are used for all three representations. There are 2,963 eligible continuous and 426 eligible binary cancer-endpoint pairs. The complete outputs retain tested-negative and ineligible outcomes.

The study distinguishes direct genomic alterations, sequencing-derived burdens, computationally inferred immune fractions, RNA signatures and pathway scores, composite genomic-context scores and an H&E-derived TIL fraction. The TIL fraction remains in the complete atlas but is left out of the default summary of reference phenotypes derived independently of H&E. The [scope audit](provenance/analysis_scope_audit_v04.md) explains every analysis inclusion and exclusion rule.

## Analysis

Each patient contributes one mean-pooled slide vector per representation. Within a cancer-endpoint pair, one to 20 PLS components are selected inside the outer training data. Continuous models use inner out-of-fold prediction error for tuning and outer out-of-fold Q² for comparison. Binary PLS-LDA models use inner out-of-fold AUROC for tuning and outer out-of-fold AUROC for comparison. A binary class threshold is learned from training data only; PR-AUC, sensitivity, specificity, balanced accuracy, positive predictive value and negative predictive value are secondary metrics.

Q² of at least 0.20 and AUROC of at least 0.60 are pragmatic effect thresholds for navigating the catalogue. A crossing is not a discovery or a clinically validated model. The main comparison uses paired continuous effects, cancer- and endpoint-family-normalised summaries, alternative patient-fold partitions and sensitivity to grouping by TCGA tissue-source-site code. Complete codes are kept together in inner and outer grouped folds. The group code is a barcode-derived cohort variable, not a scanner or institution identifier. The [analysis protocol](provenance/matched_three_representation_protocol_v04.md) gives the exact statistical rules.

TITAN and Prov-GigaPath report pretraining corpora that excluded TCGA. Giga-SSL development used TCGA images, so the representation-learning stage may have seen evaluation slides, although downstream molecular labels are withheld by the patient-level cross-validation. The comparison therefore concerns the released slide representations and their upstream processing, not intrinsic foundation-model quality or image-unseen generalisation.

The current analysis uses R 4.6.0 and fastPLS 0.4 with the package's default rSVD controls. The exact computational snapshot is recorded in [software provenance](provenance/software_snapshot_20261021.md). No independent external cohort was evaluated.

## Outcomes and sources

- Protein-altering driver mutations from TCGA MC3 calls and the Bailey driver catalogue.
- Fusion calls and profiled-sample coverage from Gao et al.
- Microsatellite-instability scores from cBioPortal TCGA PanCancer Atlas records.
- Aneuploidy and genome-doubling variables from Taylor et al.
- Oncogenic-pathway alteration status from Sanchez-Vega et al.
- PanImmune immune, inflammatory and genomic-context phenotypes published by Thorsson et al. These include inferred fractions and signatures, not direct immune-cell counts.
- MSigDB Hallmark and focused glutathione and vitamin B6 pathway scores calculated from TCGA bulk RNA sequencing. These RNA-derived scores do not measure biochemical pathway flux.

[Source acquisition and checksums](provenance/SOURCES.md), the [outcome acquisition map](data/reference/outcome_source_acquisition_map.csv) and the generated endpoint dictionary document source modality, derivation, missingness and transformations.

## Reproduce

From the repository root:

```bash
Rscript R/00_bootstrap.R
Rscript R/run_all.R
```

`R/run_all.R` regenerates the matched benchmark, its internal sensitivity analyses, the model registry, the consensus summaries and the figures that do not require fitted-object access. It reruns the biological summary after grouped validation so that the figure cannot silently use an earlier grouped result. The pipeline uses checkpoints for computationally expensive validation. The submitted matched atlas is descriptive and does not assign permutation p-values or false-discovery-rate claims to threshold crossings. An optional complete-process permutation extension for all three representations can be started with `PATHOFM_RUN_PERMUTATIONS=true`; its partial checkpoints are not publication results. Do not combine checkpoints from different fastPLS versions or cohort definitions. Generated full-resolution tables are in `results/tables/`, held-out predictions in `results/predictions/`, figures in `figures/`, and source and method audits in `provenance/`.

The two COAD software demonstrations additionally require an authorised fitted-model collection. After installing that collection in PathoFMPred, `R/11b_multifoundation_coad_demo.R`, `R/19h_manuscript_prediction_displays.R` and `tools/build_multimodel_additional_reports.py` generate the displayed outputs; `tools/build_additional_file_4.py` assembles the machine-readable companion archive. `manuscript/build_documents.py` then builds the manuscript, Supplementary Material and cover letter from that result snapshot. The submitted example reports are supplied separately as Additional files 2 and 3, so readers do not need restricted coefficients to inspect them.

## PathoFMPred and model access

[PathoFMPred](https://github.com/tkcaccia/PathoFMPred) is an R package that validates representation-specific feature schemas, builds a patient-linked model collection from feature and outcome tables, and applies compatible cancer-specific research models. Its public MIT-licensed source package contains no fitted TCGA model collection or patient-level data. The package can use a separately obtained authorised model object, or users can construct one from their own matched tables.

Fitted TITAN-derived objects are restricted to the [private collaboration repository](https://github.com/tkcaccia/PathoFMPred-private) pending written clarification of upstream redistribution terms. Source-code licensing does not grant rights to redistribute upstream slide representations or downstream fitted objects. The source, registry, analysis results and fitted parameters must be considered separately.

The analysis repository is [tkcaccia/pathology-foundation-model-atlas](https://github.com/tkcaccia/pathology-foundation-model-atlas). It contains code and result metadata, not publicly redistributed TITAN fitted objects.
