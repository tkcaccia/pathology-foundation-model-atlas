suppressPackageStartupMessages(library(data.table))

primary <- fread("results/tables/foundation_model_matched_screen.csv")
common_patient <- fread("results/tables/foundation_model_matched_screen_common_patient.csv")
keys <- c("foundation_model", "outcome_type", "family", "subfamily",
          "tumor_type", "endpoint", "source")
metric <- function(d) fifelse(d$outcome_type == "continuous", d$q2,
                              d$auc)
positive <- function(d) fifelse(d$outcome_type == "continuous", d$q2 >= 0.20,
                                d$auc >= 0.60)
primary[, `:=`(metric_primary = metric(.SD), threshold_crossing_primary = positive(.SD))]
common_patient[, `:=`(
  metric_common_patient = metric(.SD),
  threshold_crossing_common_patient = positive(.SD)
)]
z <- merge(
  primary[, c(keys, "n", "positive", "negative", "metric_primary", "threshold_crossing_primary"), with = FALSE],
  common_patient[, c(keys, "n", "positive", "negative", "metric_common_patient", "threshold_crossing_common_patient"), with = FALSE],
  by = keys, suffixes = c("_primary", "_common_patient"), all = TRUE
)
z[, delta_common_patient_minus_primary := metric_common_patient - metric_primary]
z[, threshold_change := fcase(
  threshold_crossing_primary & !threshold_crossing_common_patient, "lost threshold",
  !threshold_crossing_primary & threshold_crossing_common_patient, "gained threshold",
  threshold_crossing_primary & threshold_crossing_common_patient, "retained crossing",
  default = "retained negative"
)]
summary <- z[, .(
  tasks = .N,
  median_delta = median(delta_common_patient_minus_primary, na.rm = TRUE),
  q1_delta = quantile(delta_common_patient_minus_primary, 0.25, na.rm = TRUE),
  q3_delta = quantile(delta_common_patient_minus_primary, 0.75, na.rm = TRUE),
  spearman_primary_common_patient = cor(metric_primary, metric_common_patient, method = "spearman",
                               use = "complete.obs"),
  primary_threshold_crossings = sum(threshold_crossing_primary, na.rm = TRUE),
  common_patient_threshold_crossings = sum(threshold_crossing_common_patient, na.rm = TRUE),
  lost_threshold = sum(threshold_change == "lost threshold"),
  gained_threshold = sum(threshold_change == "gained threshold"),
  maximum_absolute_delta = max(abs(delta_common_patient_minus_primary), na.rm = TRUE)
), by = .(foundation_model, outcome_type)]

fwrite(z, "results/tables/foundation_model_common_patient_target_sensitivity.csv")
fwrite(summary, "results/tables/foundation_model_common_patient_sensitivity_summary.csv")
print(summary)
