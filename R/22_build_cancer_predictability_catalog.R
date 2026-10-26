suppressPackageStartupMessages(library(data.table))

matched <- fread("results/tables/foundation_model_matched_screen.csv")
brca <- fread(paste0(
  "results/tables/foundation_model_matched_screen_common_patient_",
  "BRCA_TITAN_GigaSSL_components_20.csv"
))
if (!all(as.character(matched$fastPLS_version) == "0.4") ||
    !all(as.character(brca$fastPLS_version) == "0.4")) {
  stop("The cancer catalogue requires the fastPLS 0.4 screens")
}
if (any(matched$tumor_type == "BRCA") ||
    !identical(sort(unique(brca$foundation_model)), c("GigaSSL", "TITAN"))) {
  stop("Unexpected BRCA representation coverage")
}

keys <- c("outcome_type", "family", "tumor_type", "endpoint", "source")
results <- rbindlist(list(matched, brca), use.names = TRUE, fill = TRUE)
if (anyDuplicated(results, by = c(keys, "foundation_model"))) {
  stop("Duplicate cancer-endpoint-representation result")
}
results[, effect := fifelse(outcome_type == "binary", auc, q2)]
results[, effect_threshold := fifelse(outcome_type == "binary", 0.60, 0.20)]
results[, effect_crossing := is.finite(effect) & effect >= effect_threshold]

provenance <- unique(fread("results/tables/endpoint_dictionary.csv")[,
  c(keys, "measurement_class", "same_histology_modality"), with = FALSE])
if (anyDuplicated(provenance, by = keys)) stop("Duplicate endpoint provenance")

wide <- dcast(
  results[, c(keys, "n", "positive", "negative", "foundation_model",
              "effect", "effect_crossing"), with = FALSE],
  outcome_type + family + tumor_type + endpoint + source + n +
    positive + negative ~ foundation_model,
  value.var = c("effect", "effect_crossing")
)
# dcast's row key cannot safely contain NA class counts. Check against the
# independent list of eligible cancer-endpoint tasks before continuing.
expected <- unique(results[, ..keys])
if (nrow(wide) != nrow(expected)) {
  stop("Casting lost a cancer-endpoint task; check NA class-count keys")
}
catalogue <- merge(wide, provenance, by = keys, all.x = TRUE, sort = FALSE)
if (nrow(catalogue) != nrow(expected) || anyNA(catalogue$measurement_class)) {
  stop("Endpoint provenance join is incomplete")
}
for (model in c("TITAN", "GigaSSL", "ProvGigaPath")) {
  field <- paste0("effect_crossing_", model)
  catalogue[is.na(get(field)), (field) := FALSE]
}
catalogue[, any_effect_crossing := effect_crossing_TITAN |
            effect_crossing_GigaSSL | effect_crossing_ProvGigaPath]
catalogue[, n_representations_crossing := as.integer(effect_crossing_TITAN) +
            as.integer(effect_crossing_GigaSSL) +
            as.integer(effect_crossing_ProvGigaPath)]
catalogue[, crossing_representations := vapply(seq_len(.N), function(i) {
  paste(c("TITAN", "Giga-SSL", "Prov-GigaPath")[c(
    effect_crossing_TITAN[i], effect_crossing_GigaSSL[i],
    effect_crossing_ProvGigaPath[i]
  )], collapse = ", ")
}, character(1))]
catalogue[, representation_coverage := fifelse(
  tumor_type == "BRCA", "TITAN and Giga-SSL only", "all three")]
setorder(catalogue, tumor_type, outcome_type, family, endpoint)

positive <- catalogue[any_effect_crossing == TRUE]
cross_modal <- positive[same_histology_modality == FALSE]
if (nrow(matched) != 3L * 3389L || nrow(brca) != 2L * 139L ||
    nrow(catalogue) != 3528L || nrow(positive) != 1076L ||
    nrow(cross_modal) != 1064L ||
    nrow(positive[tumor_type == "BRCA"]) != 72L ||
    nrow(cross_modal[tumor_type == "BRCA"]) != 71L) {
  stop("Catalogue totals do not reconcile: ", paste(c(
    matched = nrow(matched), brca = nrow(brca),
    eligible = nrow(catalogue), crossing = nrow(positive),
    cross_modal = nrow(cross_modal),
    brca_crossing = nrow(positive[tumor_type == "BRCA"]),
    brca_cross_modal = nrow(cross_modal[tumor_type == "BRCA"])
  ), collapse = ", "))
}

dir.create("results/tables", recursive = TRUE, showWarnings = FALSE)
fwrite(catalogue, "results/tables/cancer_predictability_catalogue_all_eligible.csv")
fwrite(positive, "results/tables/cancer_predictability_catalogue_crossings.csv")
summary <- catalogue[, .(
  eligible_pairs = .N,
  crossing_pairs = sum(any_effect_crossing),
  cross_modal_crossings = sum(any_effect_crossing & !same_histology_modality),
  directly_observed_crossings = sum(any_effect_crossing &
      measurement_class == "directly observed genomic alteration"),
  binary_crossings = sum(any_effect_crossing & outcome_type == "binary"),
  continuous_crossings = sum(any_effect_crossing & outcome_type == "continuous")
), by = .(tumor_type, representation_coverage)]
fwrite(summary, "results/tables/cancer_predictability_by_cancer.csv")
print(summary)
