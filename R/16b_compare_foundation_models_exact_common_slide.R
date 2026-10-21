# The exact common-slide analysis is primary. Retain the independently pooled
# common-patient analysis as a sensitivity to unequal slide availability.
Sys.setenv(FMPRED_COHORT_MODE = "common_patient")
source("R/16_compare_foundation_models.R", chdir = FALSE)

# Preserve the component-grid-labelled artifacts produced by the comparison,
# and refresh the common-patient sensitivity handoff consumed by R/18b.
data.table::fwrite(
  results,
  "results/tables/foundation_model_matched_screen_common_patient.csv"
)
saveRDS(
  predictions,
  "results/predictions/foundation_model_matched_oof_common_patient.rds",
  compress = "xz"
)
data.table::fwrite(
  summary,
  "results/tables/foundation_model_matched_summary_common_patient.csv"
)
