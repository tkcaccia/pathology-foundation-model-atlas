suppressPackageStartupMessages(library(data.table))

args <- commandArgs(trailingOnly = TRUE)
private_root <- if (length(args)) normalizePath(args[[1L]], mustWork = TRUE) else
  normalizePath("../TITANPred", mustWork = TRUE)
remote <- suppressWarnings(system2("git", c("-C", private_root,
                                            "remote", "get-url", "origin"),
                                   stdout = TRUE, stderr = FALSE))
if (length(remote) != 1L || !grepl("PathoFMPred-private", remote, fixed = TRUE)) {
  stop("Refusing to write fitted models outside the verified private package checkout")
}

root <- "models/matched_v04"
registry <- fread(file.path(root, "model_registry.csv"))
reference <- readRDS(file.path(root, "prediction_reference.rds"))
models <- c("TITAN", "GigaSSL", "ProvGigaPath")
if (!setequal(unique(registry$foundation_model), models) ||
    anyDuplicated(registry$model_id)) {
  stop("The matched registry is incomplete or contains duplicate model IDs")
}
for (model in models) {
  rows <- registry[foundation_model == model]
  paths <- file.path(root, rows$file)
  if (!all(file.exists(paths))) stop("Missing fitted artifact for ", model)
  observed_hashes <- vapply(paths, digest::digest, character(1),
                            algo = "sha256", file = TRUE)
  if (!identical(unname(observed_hashes), unname(rows$sha256))) {
    stop("Fitted-artifact checksum mismatch for ", model)
  }
  artifacts <- lapply(paths, readRDS)
  names(artifacts) <- rows$model_id
  schemas <- unique(lapply(artifacts, `[[`, "feature_names"))
  if (length(schemas) != 1L ||
      !all(vapply(artifacts, function(x) identical(x$foundation_model, model),
                  logical(1)))) {
    stop("Model collection contains mixed schemas or representations: ", model)
  }
  key <- paste0(model, "::")
  model_reference <- reference[startsWith(names(reference), key)]
  object <- structure(list(
    format_version = "1.0.0",
    foundation_model = model,
    feature_names = schemas[[1L]],
    registry = as.data.frame(rows),
    models = artifacts,
    prediction_reference = model_reference,
    data_audit = list(
      matched_patients = 8241L,
      matched_slide_identifiers = 10165L,
      aggregation = "mean"
    ),
    provenance = list(
      analysis = "exact-common-slide matched TCGA benchmark",
      fastPLS_version = "0.4",
      selection = "representation-specific Q2 >= 0.20 or AUROC >= 0.60",
      external_validation = FALSE,
      contains_feature_rows = FALSE,
      contains_outcome_rows = FALSE,
      model_count = length(artifacts)
    )
  ), class = c("PathoFMPredObject", "list"))
  output <- file.path(private_root, "inst", "models", paste0(
    "pathofmpred_", switch(model, TITAN = "titan", GigaSSL = "gigassl",
                            ProvGigaPath = "provgigapath"), ".rds"
  ))
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(output, ".tmp")
  saveRDS(object, temporary, compress = "xz")
  if (!file.rename(temporary, output)) {
    unlink(temporary)
    stop("Failed to install private collection: ", output)
  }
  cat(model, length(artifacts), output, "\n")

  if (identical(model, "GigaSSL")) {
    example_rows <- rows[cancer_type == "COAD" & (
      (outcome_type == "binary" & family == "driver_mutation" &
         endpoint == "APC") |
      (outcome_type == "continuous" &
         family == "microsatellite_instability" &
         endpoint == "MANTIS score")
    )]
    if (nrow(example_rows) != 2L) {
      stop("The Giga-SSL package example needs the current COAD APC and MANTIS models")
    }
    example <- object
    example$registry <- as.data.frame(example_rows)
    example$models <- artifacts[example_rows$model_id]
    example$prediction_reference <- model_reference[
      names(model_reference) %in% paste0("GigaSSL::", example_rows$model_id)
    ]
    example$provenance$model_count <- length(example$models)
    example$provenance$example_fixture <- TRUE
    example_path <- file.path(private_root, "inst", "models",
                              "pathofmpred_gigassl_example.rds")
    example_temporary <- paste0(example_path, ".tmp")
    saveRDS(example, example_temporary, compress = "xz")
    if (!file.rename(example_temporary, example_path)) {
      unlink(example_temporary)
      stop("Failed to install the fastPLS 0.4 Giga-SSL example object")
    }
  }
}

extdata <- file.path(private_root, "inst", "extdata")
dir.create(extdata, recursive = TRUE, showWarnings = FALSE)
fwrite(registry, file.path(extdata, "model_registry.csv"))
saveRDS(reference, file.path(extdata, "prediction_reference.rds"),
        compress = "xz")
cat("Private PathoFMPred resource synchronized; no fitted object was written to the public package.\n")
