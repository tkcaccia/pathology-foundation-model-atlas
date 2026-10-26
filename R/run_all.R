.libPaths(c(normalizePath(".Rlib", mustWork = FALSE), .libPaths()))
if (!requireNamespace("fastPLS", quietly = TRUE) ||
    as.character(packageVersion("fastPLS")) != "0.4") {
  stop("Install fastPLS 0.4 before running the atlas")
}
for (directory in c(
  "data/processed", "results/tables", "results/predictions",
  "results/figures", "results/reports", "models/matched_v04", "figures"
)) dir.create(directory, recursive = TRUE, showWarnings = FALSE)

run_r <- function(script) {
  message("Running ", script)
  status <- system2(file.path(R.home("bin"), "Rscript"), script)
  if (!identical(status, 0L)) stop("Atlas pipeline failed at ", script)
}
run_r_brca <- function() {
  script <- "R/16_compare_foundation_models.R"
  message("Running the BRCA TITAN/Giga-SSL extension with matched patients")
  status <- system2(
    file.path(R.home("bin"), "Rscript"), script,
    env = c("FMPRED_MODELS=TITAN,GigaSSL", "FMPRED_CANCERS=BRCA",
            "FMPRED_COHORT_MODE=common_patient", "FMPRED_MAX_COMPONENTS=20")
  )
  if (!identical(status, 0L)) stop("BRCA extension failed")
}
run_python <- function(script) {
  python <- Sys.which("python3")
  if (!nzchar(python)) stop("python3 is required for ", script)
  message("Running ", script)
  status <- system2(python, script)
  if (!identical(status, 0L)) stop("Atlas pipeline failed at ", script)
}

# Source files and pinned outcome definitions are documented in
# provenance/SOURCES.md. Downloading inputs is intentionally separate from
# model fitting so that this command never silently replaces source data.
scripts <- c(
  "R/01_build_patient_cohort.R",
  "R/01b_participant_characteristics.R",
  "R/02a_build_pathway_activity_targets.R",
  "R/02_build_nonmutation_targets.R",
  "R/03_build_mutation_targets.R",
  "R/02b_molecular_slide_linkage_audit.R",
  "R/15_build_foundation_model_cohorts.R",
  "R/15b_audit_common_slide_sets.R",
  "R/13_endpoint_dictionary_and_morphology.R",
  "R/16_compare_foundation_models.R",
  "R/18_summarise_foundation_model_comparison.R",
  "R/18c_summarise_evidence_maturity.R",
  "R/16d_foundation_model_fold_threshold_stability.R",
  "R/16e_foundation_model_tss_grouped_sensitivity.R",
  "R/19h_audit_grouped_fold_adequacy.R",
  # The biological synthesis in R/18 uses the grouped results, so refresh it
  # after those files exist rather than retaining a prior-run synthesis.
  "R/18_summarise_foundation_model_comparison.R",
  "R/19g_effect_partition_presentation.R",
  "R/16b_compare_foundation_models_exact_common_slide.R",
  "R/18b_summarise_exact_common_slide_sensitivity.R",
  "R/16c_audit_probe_dependence.R",
  "R/19k_binary_operating_sensitivity_v04.R",
  "R/17b_fit_matched_resource_v04.R",
  "R/20_patient_overlap_venn.R",
  "R/07_source_manifest.R"
)
start <- Sys.getenv("PATHOFM_START_SCRIPT", unset = "")
if (nzchar(start)) {
  position <- match(start, scripts)
  if (is.na(position)) stop("Unknown PATHOFM_START_SCRIPT: ", start)
  scripts <- scripts[seq.int(position, length(scripts))]
  message("Resuming at ", start)
}
for (script in scripts) {
  run_r(script)
  if (identical(script, "R/16_compare_foundation_models.R")) {
    run_r_brca()
    run_r("R/22_build_cancer_predictability_catalog.R")
    run_r("R/23_make_cancer_feature_map.R")
  }
}

run_python("tools/build_translational_consensus.py")
run_r("R/21_make_biological_predictability_figure.R")

# Optional complete-process inference is symmetric across representations.
# The submitted matched atlas is descriptive, so this expensive extension is
# not run unless explicitly requested.
if (identical(tolower(Sys.getenv("PATHOFM_RUN_PERMUTATIONS", "false")), "true")) {
  run_r("R/16f_matched_permutation_inference.R")
} else {
  message("Descriptive matched atlas complete; optional permutation extension not run")
}

private_package <- Sys.getenv("PATHOFM_PRIVATE_PACKAGE", unset = "")
if (nzchar(private_package)) {
  script <- "R/17c_sync_private_resource_v04.R"
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c(script, normalizePath(private_package, mustWork = TRUE)))
  if (!identical(status, 0L)) stop("Private package synchronization failed")
}

run_r("R/99_release_audit_v04.R")

message("The 31-cancer atlas finished. Manuscript generation and package checks are separate audited release steps.")
