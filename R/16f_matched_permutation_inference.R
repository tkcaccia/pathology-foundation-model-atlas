.libPaths(c(normalizePath(".Rlib", mustWork = FALSE), .libPaths()))
suppressPackageStartupMessages({
  library(data.table)
  library(fastPLS)
  library(future.apply)
})
source("R/utils.R")
cfg <- load_project_config()
if (as.character(packageVersion("fastPLS")) != "0.4") {
  stop("The matched permutation analysis requires fastPLS 0.4")
}
options(backend = tolower(Sys.getenv("TITAN_BACKEND", "cpu")))

models <- c("TITAN", "GigaSSL", "ProvGigaPath")
cohorts <- setNames(lapply(models, function(model) {
  readRDS(file.path("data/processed", paste0(
    "patient_cohort_exact_slides_", model, ".rds"
  )))
}), models)
patient_sets <- lapply(cohorts, function(z) rownames(z$X))
if (!all(vapply(patient_sets[-1L], identical, logical(1), patient_sets[[1L]]))) {
  stop("Exact-common-slide cohort patient order differs across representations")
}

continuous <- readRDS("data/processed/continuous_targets.rds")
binary <- rbindlist(list(
  readRDS("data/processed/binary_targets_nonmutation.rds"),
  readRDS("data/processed/binary_targets_mutation.rds")
), use.names = TRUE)
screen_path <- "results/tables/foundation_model_matched_screen.csv"
screen <- fread(screen_path)
keys <- c("foundation_model", "outcome_type", "family", "subfamily",
          "tumor_type", "endpoint", "source")
if (anyDuplicated(screen[, ..keys])) stop("Duplicate matched task/model rows")
if (!identical(sort(unique(screen$foundation_model)), sort(models))) {
  stop("The matched screen does not contain all three representations")
}
if (any(screen$fastPLS_version != "0.4")) {
  stop("The matched screen was not regenerated with fastPLS 0.4")
}
screen[, effect := fifelse(outcome_type == "continuous", q2, auc)]
screen[, effect_threshold := fifelse(outcome_type == "continuous", 0.20, 0.60)]
screen[, checkpoint_passed := is.finite(effect) & effect >= effect_threshold]
setorder(screen, outcome_type, family, tumor_type, endpoint, foundation_model)

fingerprint <- digest::digest(list(
  version = 1L,
  screen = digest::digest(file = screen_path, algo = "sha256"),
  code = digest::digest(file = "R/utils.R", algo = "sha256"),
  cohorts = vapply(cohorts, `[[`, character(1), "common_slide_ids_sha256"),
  targets = c(
    digest::digest(file = "data/processed/continuous_targets.rds", algo = "sha256"),
    digest::digest(file = "data/processed/binary_targets_nonmutation.rds", algo = "sha256"),
    digest::digest(file = "data/processed/binary_targets_mutation.rds", algo = "sha256")
  ),
  analysis = cfg$analysis,
  fastPLS = as.character(packageVersion("fastPLS"))
), algo = "sha256")
checkpoint_dir <- "data/processed/checkpoints/matched_three_model_permutations_v04"
dir.create(checkpoint_dir, recursive = TRUE, showWarnings = FALSE)

interval <- function(exceed, attempted) {
  if (!attempted) return(c(NA_real_, NA_real_))
  alpha <- 0.05
  c(
    if (exceed == 0L) 0 else qbeta(alpha / 2, exceed, attempted - exceed + 1L),
    if (exceed == attempted) 1 else qbeta(1 - alpha / 2, exceed + 1L,
                                         attempted - exceed)
  )
}

checkpoint_path <- function(row) file.path(checkpoint_dir, paste0(
  safe_name(row$foundation_model, row$outcome_type, row$family,
            row$tumor_type, row$endpoint), ".rds"
))

atomic_save <- function(object, path) {
  temporary <- paste0(path, ".tmp-", Sys.getpid())
  saveRDS(object, temporary, compress = "xz")
  if (!file.rename(temporary, path)) {
    unlink(temporary)
    stop("Cannot replace matched permutation checkpoint: ", path)
  }
}

run_one <- function(i) {
  row <- screen[i]
  path <- checkpoint_path(row)
  if (file.exists(path)) {
    previous <- tryCatch(readRDS(path), error = function(e) NULL)
    if (!is.null(previous) && identical(previous$fingerprint, fingerprint) &&
        identical(previous$status, "complete")) return(NULL)
  } else previous <- NULL

  if (!row$checkpoint_passed) {
    atomic_save(list(
      fingerprint = fingerprint, status = "complete", p = 1,
      exceedances = NA_integer_, attempted = 0L, stopped_early = FALSE,
      p_status = "not permuted below effect threshold",
      mc_lower = NA_real_, mc_upper = NA_real_
    ), path)
    return(NULL)
  }

  target <- if (row$outcome_type == "continuous") continuous else binary
  d <- target[family == row$family & tumor_type == row$tumor_type &
                endpoint == row$endpoint & source == row$source]
  d <- d[patient %chin% patient_sets[[1L]]]
  d <- if (row$outcome_type == "continuous") d[is.finite(value)] else
    d[value %in% c(0L, 1L)]
  setorder(d, patient)
  if (nrow(d) != row$n) stop("Outcome denominator changed for ", basename(path))
  X <- cohorts[[row$foundation_model]]$X[
    match(d$patient, patient_sets[[1L]]), , drop = FALSE
  ]
  y <- if (row$outcome_type == "continuous") d$value else
    factor(d$value, levels = c(0L, 1L))
  exceed <- if (!is.null(previous) &&
                identical(previous$fingerprint, fingerprint)) {
    as.integer(previous$exceedances)
  } else 0L
  attempted <- if (!is.null(previous) &&
                   identical(previous$fingerprint, fingerprint)) {
    as.integer(previous$attempted)
  } else 0L
  if (!is.finite(exceed)) exceed <- 0L
  if (!is.finite(attempted)) attempted <- 0L

  observed <- row$effect
  seed <- as.integer(row$seed)
  max_permutations <- as.integer(cfg$analysis$extended_permutations)
  initial <- as.integer(cfg$analysis$initial_permutations)
  already_stopped <- (attempted < initial && exceed >= 5L) ||
    (attempted >= initial && attempted < max_permutations && exceed >= 49L)
  pending <- if (already_stopped || attempted >= max_permutations) integer() else
    seq.int(attempted + 1L, max_permutations)
  for (permutation in pending) {
    set_model_rng_kind()
    set.seed(seed + 500000L + permutation)
    y_permuted <- y[sample.int(length(y))]
    fit_seed <- seed + 3000L + permutation
    value <- tryCatch({
      if (row$outcome_type == "continuous") {
        fit_continuous_nested_once(X, y_permuted, cfg$analysis, fit_seed)$q2
      } else {
        fit_binary_nested_auroc_once(X, y_permuted, cfg$analysis, fit_seed)$auc
      }
    }, error = function(e) stop(
      "Matched permutation failed for ", basename(path),
      " at index ", permutation, ": ", conditionMessage(e), call. = FALSE
    ))
    if (!is.finite(value)) stop("Nonfinite permuted metric: ", basename(path))
    exceed <- exceed + as.integer(value >= observed)
    attempted <- permutation
    if (attempted %% 10L == 0L) {
      atomic_save(list(fingerprint = fingerprint, status = "running",
                       exceedances = exceed, attempted = attempted), path)
    }
    if (attempted <= initial && exceed >= 5L) break
    if (attempted > initial && exceed >= 49L) break
  }
  stopped_early <- attempted < max_permutations
  mc <- if (stopped_early) c(NA_real_, NA_real_) else interval(exceed, attempted)
  atomic_save(list(
    fingerprint = fingerprint, status = "complete",
    p = if (stopped_early) 1 else (exceed + 1) / (max_permutations + 1),
    exceedances = exceed, attempted = attempted,
    stopped_early = stopped_early,
    p_status = if (stopped_early) "conservative early stop" else
      "complete process permutation",
    mc_lower = mc[[1L]], mc_upper = mc[[2L]]
  ), path)
  NULL
}

below_threshold <- which(!screen$checkpoint_passed)
for (i in below_threshold) run_one(i)
candidate_indices <- which(screen$checkpoint_passed)
workers <- as.integer(Sys.getenv("TITAN_WORKERS", "6"))
if (workers == 1L) {
  for (i in candidate_indices) {
    run_one(i)
    if (i %% 50L == 0L) message("Completed candidate row ", i,
                               "/", nrow(screen))
  }
} else {
  future::plan(future::multicore, workers = workers)
  invisible(future_lapply(candidate_indices, run_one, future.seed = TRUE,
                          future.packages = c("fastPLS", "data.table"),
                          future.globals = TRUE, future.chunk.size = 1))
}

paths <- vapply(seq_len(nrow(screen)), function(i) checkpoint_path(screen[i]),
                character(1))
if (!all(file.exists(paths))) stop("Missing matched permutation checkpoints")
objects <- lapply(paths, readRDS)
if (!all(vapply(objects, function(z) identical(z$fingerprint, fingerprint) &&
                  identical(z$status, "complete"), logical(1)))) {
  stop("Incomplete or stale matched permutation checkpoints")
}
screen[, `:=`(
  p_permutation = vapply(objects, `[[`, numeric(1), "p"),
  permutation_exceedances = vapply(objects, `[[`, integer(1), "exceedances"),
  permutations_attempted = vapply(objects, `[[`, integer(1), "attempted"),
  permutation_stopped_early = vapply(objects, `[[`, logical(1), "stopped_early"),
  permutation_status = vapply(objects, `[[`, character(1), "p_status"),
  p_mc_lower_95 = vapply(objects, `[[`, numeric(1), "mc_lower"),
  p_mc_upper_95 = vapply(objects, `[[`, numeric(1), "mc_upper")
)]
screen[, q_within_cancer_family := p.adjust(p_permutation, method = "BH"),
       by = .(foundation_model, outcome_type, tumor_type, family)]
screen[, q_representation_atlas := p.adjust(p_permutation, method = "BH"),
       by = foundation_model]
screen[, q_all_representations := p.adjust(p_permutation, method = "BH")]
screen[, permutation_fdr_candidate := checkpoint_passed &
         q_within_cancer_family < cfg$analysis$fdr_alpha]
fwrite(screen, "results/tables/foundation_model_matched_permutation_fdr.csv")
print(screen[, .(eligible = .N, effect_crossings = sum(checkpoint_passed),
                 fdr_candidates = sum(permutation_fdr_candidate)),
             by = .(foundation_model, outcome_type)])
