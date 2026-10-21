.libPaths(c(normalizePath(".Rlib", mustWork = FALSE), .libPaths()))
suppressPackageStartupMessages(library(data.table))

read_table <- function(name) fread(file.path("results", "tables", name))
models <- c("TITAN", "GigaSSL", "ProvGigaPath")
keys <- c("outcome_type", "family", "subfamily", "tumor_type", "endpoint", "source")
primary <- read_table("foundation_model_matched_screen.csv")
exact <- read_table("foundation_model_matched_screen_exact_common_slide_components_20.csv")
stopifnot(
  identical(primary, exact),
  setequal(unique(primary$foundation_model), models),
  all(primary$fastPLS_version == "0.4"),
  !anyDuplicated(primary, by = c("foundation_model", keys))
)

task_n <- primary[, .(
  representations = uniqueN(foundation_model),
  patient_denominators = uniqueN(n),
  seeds = uniqueN(seed),
  common_cohorts = uniqueN(common_cohort)
), by = keys]
if (any(task_n$representations != 3L | task_n$patient_denominators != 1L |
        task_n$seeds != 1L | task_n$common_cohorts != 1L)) {
  stop("A cancer-endpoint task differs across representations")
}

oof <- as.data.table(readRDS("results/predictions/foundation_model_matched_oof.rds"))
folds <- oof[, .(representations = uniqueN(foundation_model),
                 fold_assignments = uniqueN(outer_fold)),
             by = c(keys, "patient")]
if (any(folds$representations != 3L | folds$fold_assignments != 1L)) {
  stop("Patient-level outer-fold assignments are not matched")
}

same_he <- read_table("foundation_model_same_histology_sensitivity.csv")
if (any(same_he$matched_same_histology_tasks != 11L) ||
    any(same_he$all_continuous_tasks -
          same_he$cross_modal_continuous_tasks != 11L)) {
  stop("Same-H&E reference-phenotype scope has changed")
}

operating <- read_table("foundation_model_binary_operating_rule_metrics.csv")
primary_binary <- primary[outcome_type == "binary", .(
  foundation_model, family, tumor_type, endpoint, source,
  primary_auroc = auc
)]
operating_auc <- unique(operating[, .(
  foundation_model, family, tumor_type, endpoint, source,
  audited_auroc = auroc
)])
binary_audit <- merge(primary_binary, operating_auc,
                      by = c("foundation_model", "family", "tumor_type",
                             "endpoint", "source"), all = TRUE)
if (nrow(binary_audit) != nrow(primary_binary) ||
    anyNA(binary_audit$primary_auroc) || anyNA(binary_audit$audited_auroc) ||
    any(abs(binary_audit$primary_auroc - binary_audit$audited_auroc) > 1e-10)) {
  stop("The binary operating-rule refit does not reproduce the matched AUROC")
}

if (file.exists("results/tables/foundation_model_tss_grouped_sensitivity.csv")) {
  grouped <- read_table("foundation_model_tss_grouped_sensitivity.csv")
  expected <- unique(primary[, c(keys, "foundation_model"), with = FALSE])
  positive <- read_table("foundation_model_target_comparison.csv")[supported_by_n > 0L]
  expected <- merge(expected, positive[, ..keys], by = keys)
  if (nrow(grouped) != nrow(expected) ||
      anyDuplicated(grouped, by = c(keys, "foundation_model"))) {
    stop("Grouped sensitivity does not cover every representation of each selected task")
  }
}

registry_file <- "models/matched_v04/model_registry.csv"
if (file.exists(registry_file)) {
  registry <- fread(registry_file)
  expected <- primary[
    (outcome_type == "continuous" & q2 >= 0.20) |
      (outcome_type == "binary" & auc >= 0.60)
  ]
  if (nrow(registry) != nrow(expected) ||
      !setequal(unique(registry$foundation_model), models) ||
      any(registry$fastPLS_version != "0.4")) {
    stop("Fitted-model registry does not match the descriptive candidate set")
  }
}

public_models <- list.files("../PathoFMPred-public/inst/models", pattern = "\\.rds$",
                            full.names = TRUE)
if (any(grepl("titan|pathofmpred_(gigassl|provgigapath)\\.rds$",
              basename(public_models), ignore.case = TRUE))) {
  stop("A fitted TCGA collection is present in the public package")
}

cat("Matched release audit passed:", nrow(task_n), "paired tasks and",
    nrow(primary), "representation-task results under fastPLS 0.4.\n")
