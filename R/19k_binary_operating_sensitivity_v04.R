.libPaths(c(normalizePath(".Rlib", mustWork = FALSE), .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(fastPLS)
  library(future.apply)
})
source("R/utils.R")
cfg <- load_project_config()
if (as.character(packageVersion("fastPLS")) != "0.4") {
  stop("The operating-rule audit requires fastPLS 0.4")
}
options(backend = tolower(Sys.getenv("TITAN_BACKEND", "cpu")))

models <- c("TITAN", "GigaSSL", "ProvGigaPath")
cohorts <- setNames(lapply(models, function(model) readRDS(file.path(
  "data/processed", paste0("patient_cohort_exact_slides_", model, ".rds")
))), models)
screen <- fread("results/tables/foundation_model_matched_screen.csv")
if (any(screen$fastPLS_version != "0.4")) stop("Primary screen is not fastPLS 0.4")
jobs <- unique(screen[outcome_type == "binary", .(
  family, subfamily, tumor_type, endpoint, source, n, positive, negative, seed
)])
setorder(jobs, family, tumor_type, endpoint)
targets <- rbindlist(list(
  readRDS("data/processed/binary_targets_nonmutation.rds"),
  readRDS("data/processed/binary_targets_mutation.rds")
), use.names = TRUE)

average_precision <- function(truth, score) {
  truth <- as.integer(as.character(truth))
  z <- data.table(score, positive = truth == 1L)[, .(
    positives = sum(positive), total = .N
  ), by = score]
  setorder(z, -score)
  z[, `:=`(cum_pos = cumsum(positives), cum_n = cumsum(total))]
  sum((z$positives / sum(truth == 1L)) * (z$cum_pos / z$cum_n))
}

run_job <- function(index) {
  job <- jobs[index]
  d <- targets[family == job$family & tumor_type == job$tumor_type &
                 endpoint == job$endpoint & source == job$source &
                 value %in% c(0L, 1L)]
  d <- d[patient %chin% rownames(cohorts[[1L]]$X)]
  setorder(d, patient)
  if (nrow(d) != job$n) stop("Binary target denominator changed")
  y <- factor(d$value, levels = c(0L, 1L))
  rows <- vector("list", length(models))
  for (position in seq_along(models)) {
    model <- models[[position]]
    cohort <- cohorts[[model]]
    X <- cohort$X[match(d$patient, rownames(cohort$X)), , drop = FALSE]
    fit <- fit_binary_nested_auroc_once(X, y, cfg$analysis, job$seed)
    primary <- screen[foundation_model == model & outcome_type == "binary" &
                        family == job$family & tumor_type == job$tumor_type &
                        endpoint == job$endpoint & source == job$source]
    if (nrow(primary) != 1L || abs(fit$auc - primary$auc) > 1e-10) {
      stop("Operating-rule refit differs from primary AUROC: ", model,
           " / ", job$tumor_type, " / ", job$endpoint,
           "; refit=", format(fit$auc, digits = 16L),
           "; primary=", paste(format(primary$auc, digits = 16L), collapse = ","),
           "; seed=", job$seed, "; n=", nrow(d), call. = FALSE)
    }
    predictions <- list(
      "empirical training priors" = fit$empirical_prediction,
      "equal class priors" = fit$equal_prediction,
      "training-only optimized threshold" = fit$prediction
    )
    rows[[position]] <- rbindlist(lapply(names(predictions), function(rule) {
      metric <- binary_classification_metrics(y, predictions[[rule]], fit$score)
      data.table(
        foundation_model = model, outcome_type = "binary",
        family = job$family, subfamily = job$subfamily,
        tumor_type = job$tumor_type, endpoint = job$endpoint,
        source = job$source, n = nrow(d), positive = sum(y == "1"),
        negative = sum(y == "0"), rule = rule,
        balanced_accuracy = metric$balanced_accuracy,
        sensitivity = metric$sensitivity,
        specificity = metric$specificity, ppv = metric$ppv, npv = metric$npv,
        auroc = metric$auc, pr_auc = average_precision(y, fit$score),
        prevalence = metric$prevalence,
        no_skill_pr_auc = metric$no_skill_pr_auc,
        selected_components_median = median(fit$ncomp),
        selected_components_at_ceiling = sum(fit$ncomp == 20L),
        primary_screen_auroc = primary$auc,
        fastPLS_version = as.character(packageVersion("fastPLS"))
      )
    }))
  }
  rbindlist(rows)
}

workers <- as.integer(Sys.getenv("TITAN_WORKERS", "6"))
if (workers > 1L) future::plan(future::multicore, workers = workers)
result <- rbindlist(future_lapply(seq_len(nrow(jobs)), run_job,
                                  future.seed = TRUE,
                                  future.packages = c("fastPLS", "data.table")),
                    use.names = TRUE)
result[, ba_crossing_sensitivity := balanced_accuracy >= 0.60]
baseline <- result[rule == "empirical training priors", .(
  foundation_model, family, tumor_type, endpoint,
  baseline_ba = balanced_accuracy, baseline_sensitivity = sensitivity,
  baseline_specificity = specificity, baseline_ppv = ppv,
  baseline_npv = npv
)]
result <- merge(result, baseline,
  by = c("foundation_model", "family", "tumor_type", "endpoint"),
  all.x = TRUE, sort = FALSE)
for (metric in c("balanced_accuracy", "sensitivity", "specificity", "ppv", "npv")) {
  source_col <- if (metric == "balanced_accuracy") "baseline_ba" else
    paste0("baseline_", metric)
  result[, (paste0(metric, "_delta_vs_empirical")) := get(metric) - get(source_col)]
}
setorder(result, foundation_model, family, tumor_type, endpoint, rule)
fwrite(result, "results/tables/foundation_model_binary_operating_rule_metrics.csv")

summary <- result[, .(
  tasks = .N,
  ba_crossings_for_sensitivity = sum(ba_crossing_sensitivity),
  median_balanced_accuracy = median(balanced_accuracy),
  median_ba_delta_vs_empirical = median(balanced_accuracy_delta_vs_empirical),
  q25_ba_delta_vs_empirical = quantile(balanced_accuracy_delta_vs_empirical, 0.25),
  q75_ba_delta_vs_empirical = quantile(balanced_accuracy_delta_vs_empirical, 0.75),
  median_sensitivity_delta_vs_empirical = median(sensitivity_delta_vs_empirical),
  median_specificity_delta_vs_empirical = median(specificity_delta_vs_empirical),
  finite_ppv_delta_tasks = sum(is.finite(ppv_delta_vs_empirical)),
  finite_npv_delta_tasks = sum(is.finite(npv_delta_vs_empirical)),
  median_ppv_delta_vs_empirical = median(ppv_delta_vs_empirical, na.rm = TRUE),
  median_npv_delta_vs_empirical = median(npv_delta_vs_empirical, na.rm = TRUE),
  median_auroc = median(auroc), median_pr_auc = median(pr_auc),
  median_prevalence = median(prevalence)
), by = .(foundation_model, rule)]
fwrite(summary,
       "results/tables/foundation_model_binary_operating_rule_paired_summary.csv")
print(summary)
