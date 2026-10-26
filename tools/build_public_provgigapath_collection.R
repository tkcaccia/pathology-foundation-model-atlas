#!/usr/bin/env Rscript

# Build a coefficient-only Prov-GigaPath collection for an optional,
# user-initiated download. This file is not added to the package tarball.
suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L) {
  stop("Usage: Rscript tools/build_public_provgigapath_collection.R PRIVATE_OBJECT OUTPUT_RDS")
}
source_path <- normalizePath(args[[1L]], mustWork = TRUE)
target_path <- args[[2L]]
object <- readRDS(source_path)
if (!identical(object$foundation_model, "ProvGigaPath") ||
    !identical(object$provenance$fastPLS_version, "0.4") ||
    !identical(object$provenance$model_count, length(object$models))) {
  stop("Source is not the verified fastPLS 0.4 Prov-GigaPath collection")
}
screen <- fread("results/tables/foundation_model_matched_screen.csv")[
  foundation_model == "ProvGigaPath"
]
screen[, effect_crossing := fifelse(outcome_type == "binary",
                                   auc >= 0.60, q2 >= 0.20)]
expected <- screen[effect_crossing == TRUE]
if (nrow(expected) != 618L || nrow(object$registry) != nrow(expected) ||
    !setequal(paste(expected$family, expected$tumor_type, expected$endpoint),
              paste(object$registry$family, object$registry$cancer_type,
                    object$registry$endpoint))) {
  stop("Collection is not synchronized with the complete Prov-GigaPath screen")
}
if (anyDuplicated(object$registry$model_id) ||
    !setequal(object$registry$model_id, names(object$models)) ||
    any(grepl("TCGA-", unlist(object$registry), fixed = TRUE), na.rm = TRUE)) {
  stop("Model registry is inconsistent or contains patient identifiers")
}
for (artifact in object$models) {
  if (!identical(artifact$foundation_model, "ProvGigaPath") ||
      !identical(artifact$fastPLS_version, "0.4") ||
      !identical(artifact$contains_patient_level_training_rows, FALSE) ||
      !is.null(artifact$model$Ttrain) || !is.null(artifact$model$Yfit) ||
      any(c("X", "Y", "patient", "patient_id") %in% names(artifact$model))) {
    stop("A fitted object failed the coefficient-only release audit")
  }
}

# Sorted patient-level held-out scores are unnecessary for model inference and
# are deliberately excluded from this public asset. The interface will return
# NA for a reference rank while still returning the original predicted value
# or binary class call and uncalibrated score.
object$prediction_reference <- NULL
object$provenance$release_scope <- "Prov-GigaPath coefficients and aggregate metadata only"
object$provenance$prediction_reference_included <- FALSE
object$provenance$license <- "CC BY 4.0 for this fitted-object collection"
object$provenance$upstream_code_license <- "Apache 2.0"
object$provenance$upstream_embedding_dataset_license <- "CC BY 4.0"
object$provenance$upstream_embedding_dataset <-
  "https://huggingface.co/datasets/seandavis/tcga_provgigapath_embeddings"
object$provenance$contains_feature_rows <- FALSE
object$provenance$contains_outcome_rows <- FALSE
object$provenance$contains_patient_level_predictions <- FALSE

dir.create(dirname(target_path), recursive = TRUE, showWarnings = FALSE)
saveRDS(object, target_path, compress = "xz")
reloaded <- readRDS(target_path)
if (length(reloaded$models) != 618L ||
    !is.null(reloaded$prediction_reference) ||
    !setequal(names(reloaded$models), reloaded$registry$model_id)) {
  stop("The exported collection failed the round-trip audit")
}
cat("models", length(reloaded$models), "\n")
cat("bytes", file.info(target_path)$size, "\n")
cat("sha256", digest::digest(file = target_path, algo = "sha256"), "\n")
