.libPaths(c(normalizePath(".Rlib", mustWork = FALSE), .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(fastPLS)
  library(future.apply)
})
source("R/utils.R")
cfg <- load_project_config()
if (as.character(packageVersion("fastPLS")) != "0.4") {
  stop("The matched model resource requires fastPLS 0.4")
}
options(backend = tolower(Sys.getenv("TITAN_BACKEND", "cpu")))

models <- c("TITAN", "GigaSSL", "ProvGigaPath")
cohorts <- setNames(lapply(models, function(model) readRDS(file.path(
  "data/processed", paste0("patient_cohort_exact_slides_", model, ".rds")
))), models)
screen <- fread("results/tables/foundation_model_matched_screen.csv")
if (any(screen$fastPLS_version != "0.4")) stop("Primary screen is stale")
screen[, effect := fifelse(outcome_type == "continuous", q2, auc)]
screen[, effect_crossing := effect >= fifelse(outcome_type == "continuous",
                                             0.20, 0.60)]
jobs <- screen[effect_crossing == TRUE]
setorder(jobs, foundation_model, outcome_type, family, tumor_type, endpoint)
if (!nrow(jobs)) stop("No matched effect-threshold crossings to fit")
smoke_limit <- as.integer(Sys.getenv("FMPRED_RESOURCE_SMOKE_LIMIT", "0"))
if (is.finite(smoke_limit) && smoke_limit > 0L) {
  jobs <- jobs[seq_len(min(smoke_limit, nrow(jobs)))]
}

continuous <- readRDS("data/processed/continuous_targets.rds")
binary <- rbindlist(list(
  readRDS("data/processed/binary_targets_nonmutation.rds"),
  readRDS("data/processed/binary_targets_mutation.rds")
), use.names = TRUE)
out_dir <- if (is.finite(smoke_limit) && smoke_limit > 0L)
  "models/matched_v04_smoke" else "models/matched_v04"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
resource_fingerprint <- digest::digest(list(
  screen = digest::digest(file = "results/tables/foundation_model_matched_screen.csv",
                          algo = "sha256"),
  utils = digest::digest(file = "R/utils.R", algo = "sha256"),
  analysis = cfg$analysis,
  cohorts = vapply(cohorts, `[[`, character(1), "source_sha256"),
  fastPLS_version = as.character(packageVersion("fastPLS"))
), algo = "sha256")

fit_one <- function(index) {
  set_model_rng_kind()
  job <- jobs[index]
  cohort <- cohorts[[job$foundation_model]]
  source <- if (job$outcome_type == "continuous") continuous else binary
  d <- source[family == job$family & tumor_type == job$tumor_type &
                endpoint == job$endpoint & source == job$source]
  d <- d[patient %chin% rownames(cohort$X)]
  d <- if (job$outcome_type == "continuous") d[is.finite(value)] else
    d[value %in% c(0L, 1L)]
  setorder(d, patient)
  if (nrow(d) != job$n || anyDuplicated(d$patient)) {
    stop("Changed outcome denominator or duplicate patient: ",
         job$foundation_model, " / ", job$tumor_type, " / ", job$endpoint)
  }
  X <- cohort$X[match(d$patient, rownames(cohort$X)), , drop = FALSE]
  y <- if (job$outcome_type == "continuous") d$value else
    factor(d$value, levels = c(0L, 1L))
  seed <- as.integer(job$seed + 700000L)
  model_id <- paste(job$foundation_model,
                    safe_name(job$family, job$tumor_type, job$endpoint),
                    sep = "__")
  path <- file.path(out_dir, paste0(model_id, ".rds"))
  cached <- if (file.exists(path)) tryCatch(readRDS(path), error = function(e) NULL)
    else NULL
  if (!is.null(cached) && identical(cached$resource_fingerprint,
                                     resource_fingerprint)) {
    artifact <- cached
    ncomp <- as.integer(artifact$ncomp)
    threshold <- artifact$operating_threshold
  } else {
  if (job$outcome_type == "binary") {
    rule <- select_binary_auroc_rule(
      X, y, rep(TRUE, nrow(X)), cfg$analysis, seed + 1000L
    )
    ncomp <- rule$component
    threshold <- rule$threshold
  } else {
    tuned <- fastPLS::pls.single.cv(
      Xdata = X, Ydata = y, ncomp = cfg$analysis$components,
      kfold = cfg$analysis$inner_folds, seed = seed + 1000L,
      fit = FALSE, rsvd_oversample = cfg$analysis$rsvd_oversample,
      rsvd_power = cfg$analysis$rsvd_power
    )
    ncomp <- as.integer(tuned$best_ncomp)
    threshold <- NULL
  }
  fitted <- fit_final_model(X, y, job$outcome_type, ncomp,
                            cfg$analysis, seed + 2000L)
  fitted$Ttrain <- NULL
  fitted$Yfit <- NULL
  transform <- if (job$outcome_type == "continuous")
    continuous_endpoint_transform(job$family, job$endpoint) else "none"
  artifact <- list(
    model = fitted, model_id = model_id,
    resource_fingerprint = resource_fingerprint,
    foundation_model = job$foundation_model,
    outcome_type = job$outcome_type, family = job$family,
    cancer_type = job$tumor_type, endpoint = job$endpoint,
    source = job$source,
    feature_names = cohort$feature_names,
    aggregation = cohort$aggregation,
    ncomp = ncomp, training_n = nrow(d),
    training_positive = if (job$outcome_type == "binary") sum(y == "1") else NA_integer_,
    training_negative = if (job$outcome_type == "binary") sum(y == "0") else NA_integer_,
    positive = if (job$outcome_type == "binary") sum(y == "1") else NA_integer_,
    negative = if (job$outcome_type == "binary") sum(y == "0") else NA_integer_,
    class_labels = if (job$outcome_type == "binary")
      c(negative = "not altered", positive = "altered") else NULL,
    class_priors = if (job$outcome_type == "binary") prop.table(table(y)) else NULL,
    operating_threshold = threshold,
    endpoint_transform = transform,
    output_units = if (job$outcome_type == "binary")
      "training-threshold class label and uncalibrated LDA score" else if
      (transform == "log1p") "log1p-transformed source units" else
        "source endpoint units",
    training_feature_min = apply(X, 2L, min),
    training_feature_max = apply(X, 2L, max),
    training_feature_mean = colMeans(X),
    training_feature_sd = apply(X, 2L, sd),
    feature_file_sha256 = cohort$source_sha256,
    feature_schema_sha256 = digest::digest(cohort$feature_names, algo = "sha256"),
    fastPLS_version = as.character(packageVersion("fastPLS")),
    fastPLS_remote_sha = if (is.null(packageDescription("fastPLS")$RemoteSha))
      NA_character_ else as.character(packageDescription("fastPLS")$RemoteSha),
    fastPLS_repository = if (is.null(packageDescription("fastPLS")$Repository))
      NA_character_ else as.character(packageDescription("fastPLS")$Repository),
    backend = getOption("backend"),
    svd_method = cfg$analysis$svd_method,
    rsvd_oversample = cfg$analysis$rsvd_oversample,
    rsvd_power = cfg$analysis$rsvd_power,
    fit_seed = seed + 2000L,
    intended_use = "Research use only; TCGA internal estimate, not externally validated",
    contains_patient_level_training_rows = FALSE
  )
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  saveRDS(artifact, temporary, compress = "xz")
  if (!file.rename(temporary, path)) {
    unlink(temporary)
    stop("Could not save matched fitted object: ", path)
  }
  }
  limited <- if (job$outcome_type == "continuous") nrow(d) < 100L else
    min(artifact$positive, artifact$negative) < 50L
  data.table(
    foundation_model = job$foundation_model, model_id = model_id,
    outcome_type = job$outcome_type, family = job$family,
    subfamily = job$subfamily, cancer_type = job$tumor_type,
    endpoint = job$endpoint, source = job$source,
    file = basename(path), sha256 = digest::digest(file = path, algo = "sha256"),
    n = nrow(d), positive = artifact$positive,
    negative = artifact$negative, ncomp = ncomp,
    feature_dimension = ncol(X),
    feature_schema_sha256 = artifact$feature_schema_sha256,
    feature_file_sha256 = cohort$source_sha256,
    aggregation = cohort$aggregation,
    fastPLS_version = artifact$fastPLS_version,
    backend = artifact$backend,
    screen_q2 = job$q2, screen_rmse = job$rmse,
    screen_spearman = job$spearman,
    screen_auc = job$auc, binary_pr_auc = job$pr_auc,
    screen_balanced_accuracy = job$balanced_accuracy,
    screen_sensitivity = job$sensitivity,
    screen_specificity = job$specificity,
    screen_ppv = job$ppv, screen_npv = job$npv,
    binary_prevalence = job$prevalence,
    binary_no_skill_pr_auc = job$no_skill_pr_auc,
    binary_operating_threshold = if (is.null(threshold)) NA_real_ else threshold,
    output_units = artifact$output_units,
    primary_estimate_label = "patient-level nested out-of-fold estimate on exact common slides",
    repeated_estimate_label = "alternative matched partitions reported separately",
    representation_effect_threshold_crossing = TRUE,
    matched_representation_effect_threshold_crossing = TRUE,
    resource_selection_basis = "representation-specific matched effect-threshold crossing",
    representation_specific_qualification =
      "descriptive effect-threshold crossing; no permutation/FDR claim",
    primary_binary_metric = if (job$outcome_type == "binary") "AUROC" else NA_character_,
    binary_crossing_rule = if (job$outcome_type == "binary")
      "AUROC >= 0.60" else NA_character_,
    tier = "descriptive crossing",
    tier_origin = "matched patient-level Q2 or AUROC effect threshold",
    model_evidence_tier = if (limited) "exploratory_limited_sample" else
      "larger_sample_internal",
    default_inference = !limited,
    limited_evidence_reason = if (!limited) "" else if
      (job$outcome_type == "continuous") "fewer than 100 labelled patients" else
        "fewer than 50 patients in one or both classes",
    external_validation = "none",
    redistribution_status = if (job$foundation_model == "TITAN")
      "private collaboration access; upstream redistribution clarification pending" else
      "private collaboration access; separate asset rights apply"
  )
}

workers <- as.integer(Sys.getenv("TITAN_WORKERS", "4"))
if (workers > 1L) future::plan(future::multicore, workers = workers)
registry <- rbindlist(future_lapply(seq_len(nrow(jobs)), fit_one,
                                    future.seed = TRUE,
                                    future.packages = c("fastPLS", "data.table"),
                                    future.chunk.size = 1), use.names = TRUE)
if (anyDuplicated(registry$model_id) || nrow(registry) != nrow(jobs)) {
  stop("Incomplete or duplicate matched model resource")
}

grouped_path <- "results/tables/foundation_model_tss_grouped_sensitivity.csv"
if (!file.exists(grouped_path)) stop("Three-representation grouped sensitivity is missing")
grouped <- fread(grouped_path)[, .(
  foundation_model, outcome_type, family, cancer_type = tumor_type,
  endpoint, source, grouped_feasible = feasible,
  grouped_effect, matched_random_effect, retained_primary_crossing,
  n_codes, realized_outer_folds, grouped_fold_adequacy_flag,
  grouped_fold_adequacy_reasons, any_single_class_outer_test_fold,
  any_single_class_inner_training_fold, outer_test_n_min,
  outer_test_n_max, outer_training_positive_min,
  outer_training_negative_min, inner_folds_realized_min,
  inner_training_positive_min, inner_training_negative_min,
  metric_construction
)]
registry <- merge(registry, grouped,
                  by = c("foundation_model", "outcome_type", "family",
                         "cancer_type", "endpoint", "source"),
                  all.x = TRUE, sort = FALSE)
registry[, `:=`(
  site_grouped_metric_name = fifelse(outcome_type == "continuous", "Q2", "AUROC"),
  site_grouped_metric = grouped_effect,
  site_performance_delta = grouped_effect - matched_random_effect,
  site_retained_effect = retained_primary_crossing,
  site_robustness_status = fcase(
    grouped_feasible %in% FALSE, "grouped estimate not available",
    retained_primary_crossing %in% TRUE, "effect threshold retained under grouping",
    retained_primary_crossing %in% FALSE, "effect threshold not retained under grouping",
    default = "grouped sensitivity not evaluated"
  ),
  matched_tss_grouped_metric_name = fifelse(outcome_type == "continuous", "Q2", "AUROC"),
  matched_tss_grouped_operating_metric = grouped_effect,
  matched_tss_retained_primary_crossing = retained_primary_crossing,
  matched_tss_validation_scope = "TCGA tissue-source-site-code-grouped internal sensitivity",
  matched_tss_grouped_fold_adequacy_flag = grouped_fold_adequacy_flag,
  matched_tss_grouped_fold_adequacy_reasons = grouped_fold_adequacy_reasons,
  matched_tss_n_codes = n_codes,
  matched_tss_realized_outer_folds = realized_outer_folds,
  matched_tss_outer_test_n_min = outer_test_n_min,
  matched_tss_outer_test_n_max = outer_test_n_max,
  matched_tss_outer_training_positive_min = outer_training_positive_min,
  matched_tss_outer_training_negative_min = outer_training_negative_min,
  matched_tss_inner_folds_realized_min = inner_folds_realized_min,
  matched_tss_inner_training_positive_min = inner_training_positive_min,
  matched_tss_inner_training_negative_min = inner_training_negative_min,
  matched_tss_any_single_class_outer_test_fold = any_single_class_outer_test_fold,
  matched_tss_any_single_class_inner_training_fold = any_single_class_inner_training_fold,
  matched_tss_metric_construction = metric_construction
)]
registry[, site_robustness_warning := fcase(
  grouped_feasible %in% FALSE, "Grouped estimate not available",
  retained_primary_crossing %in% FALSE,
    "Effect threshold not retained when TCGA tissue-source-site codes were held apart",
  default = ""
)]
registry[, matched_tss_robustness_warning := fifelse(
  grouped_fold_adequacy_flag == "sparse grouped folds",
  "Sparse grouped folds limit interpretation", site_robustness_warning
)]

# Older reports expose a broad set of optional audit fields. Keep the schema
# explicit while leaving fields without a symmetric fastPLS 0.4 estimate empty.
optional_report_fields <- c(
  "binary_all_repeat_class_agreement", "binary_minimum_inner_training_negative",
  "binary_minimum_inner_training_positive", "binary_minimum_outer_test_negative",
  "binary_minimum_outer_test_positive", "binary_npv_tcga_prevalence",
  "binary_ppv_tcga_prevalence", "binary_repeat_class_agreement",
  "binary_repeat_score_spearman", "binary_selected_components_maximum",
  "binary_selected_components_median", "binary_selected_components_minimum",
  "binary_selected_components_q1", "binary_selected_components_q3",
  "continuous_evidence_category", "continuous_outer_fit_ceiling_fraction",
  "continuous_outer_fits", "continuous_outer_fits_at_ceiling",
  "continuous_prediction_repeat_spearman", "continuous_repeat_q2_sd",
  "continuous_selected_components_max", "continuous_selected_components_median",
  "continuous_selected_components_min", "decision_rule_sensitivity_status",
  "equal_prior_balanced_accuracy", "equal_prior_crossing", "median_equal_component",
  "median_optimized_component", "median_optimized_threshold",
  "optimized_balanced_accuracy", "optimized_crossing", "repeated_auc",
  "repeated_balanced_accuracy", "repeated_minus_primary_primary_metric",
  "repeated_q2", "repeated_rmse", "repeated_sensitivity",
  "repeated_spearman", "repeated_specificity",
  "site_grouped_inner_site_separation", "site_grouped_maximum_test_patients",
  "site_grouped_maximum_test_positive", "site_grouped_maximum_test_sites",
  "site_grouped_minimum_test_patients", "site_grouped_minimum_test_positive",
  "site_grouped_minimum_test_sites", "site_grouped_n_sites",
  "site_grouped_outer_folds", "site_grouped_validation_scope",
  "site_near_chance_or_worse"
)
for (field in setdiff(optional_report_fields, names(registry))) {
  registry[, (field) := NA]
}
setorder(registry, foundation_model, cancer_type, outcome_type, family,
         endpoint)
fwrite(registry, file.path(out_dir, "model_registry.csv"))

oof <- as.data.table(readRDS("results/predictions/foundation_model_matched_oof.rds"))
oof <- merge(oof, registry[, .(foundation_model, outcome_type, family,
                               tumor_type = cancer_type, endpoint, model_id)],
             by = c("foundation_model", "outcome_type", "family",
                    "tumor_type", "endpoint"), all = FALSE)
oof[, reference_value := fifelse(outcome_type == "continuous", predicted, score)]
reference <- oof[is.finite(reference_value),
                 .(reference_values = list(sort(reference_value))),
                 by = .(foundation_model, model_id)]
reference_list <- setNames(reference$reference_values,
                           paste(reference$foundation_model,
                                 reference$model_id, sep = "::"))
saveRDS(reference_list, file.path(out_dir, "prediction_reference.rds"),
        compress = "xz")
print(registry[, .(models = .N, default_inference = sum(default_inference)),
               by = .(foundation_model, outcome_type)])
