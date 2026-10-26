suppressPackageStartupMessages({
  library(data.table)
  library(ggplot2)
})

atlas <- fread("results/tables/cancer_predictability_catalogue_all_eligible.csv")
atlas <- atlas[same_histology_modality == FALSE]
atlas[, feature_class := fcase(
  measurement_class == "directly observed genomic alteration",
    "Mutation or fusion",
  outcome_type == "binary" &
    measurement_class == "composite genomic-context score",
    "Genomic status",
  measurement_class == "sequencing-derived continuous burden",
    "Sequence burden",
  measurement_class == "transcriptomic pathway score",
    "RNA pathway",
  measurement_class == "transcriptomic signature",
    "RNA signature",
  measurement_class == "computationally inferred immune-cell fraction",
    "Inferred immune fraction",
  outcome_type == "continuous" &
    measurement_class == "composite genomic-context score",
    "Genomic score",
  default = NA_character_
)]
if (anyNA(atlas$feature_class)) stop("Unmapped cross-modal feature class")
order_class <- c("Mutation or fusion", "Genomic status", "Sequence burden",
                 "RNA pathway", "RNA signature", "Inferred immune fraction",
                 "Genomic score")
counts <- atlas[, .(
  eligible = .N, crossing = sum(any_effect_crossing)
), by = .(tumor_type, feature_class)]
counts[, rate := 100 * crossing / eligible]
counts[, label := fifelse(crossing == 0L, "", as.character(crossing))]
counts[, feature_class := factor(feature_class, levels = order_class)]
counts[, tumor_type := factor(tumor_type,
                             levels = rev(sort(unique(tumor_type))))]
if (uniqueN(counts$tumor_type) != 32L ||
    sum(counts$crossing) != 1072L ||
    counts[tumor_type == "BRCA", sum(crossing)] != 71L ||
    counts[tumor_type == "CHOL", sum(crossing)] != 8L) {
  stop("The cancer-feature map does not reconcile with the catalogue")
}

figure <- ggplot(counts, aes(feature_class, tumor_type, fill = rate)) +
  geom_tile(colour = "white", linewidth = 0.65) +
  geom_text(aes(label = label, colour = rate >= 45), size = 3.0,
            fontface = "bold", show.legend = FALSE) +
  scale_colour_manual(values = c(`FALSE` = "#203246", `TRUE` = "white")) +
  scale_fill_gradientn(
    colours = c("#F1F5F9", "#BED5E4", "#6BA6C7", "#266B98", "#153B66"),
    limits = c(0, 100), breaks = c(0, 25, 50, 75, 100),
    name = "Eligible pairs\nreaching cutoff (%)"
  ) +
  labs(
    title = "Cancer-specific outcomes reaching descriptive cutoffs",
    subtitle = "Number of outcomes reaching a descriptive cutoff with any available representation",
    x = NULL, y = NULL
  ) +
  theme_minimal(base_size = 12, base_family = "Arial") +
  theme(
    panel.grid = element_blank(),
    plot.title = element_text(face = "bold", size = 16, colour = "#17324D"),
    plot.subtitle = element_text(size = 11.2, colour = "#4B5D6B"),
    axis.text.x = element_text(size = 10.2, angle = 28, hjust = 1,
                               colour = "#203246"),
    axis.text.y = element_text(size = 10.0, face = "bold", colour = "#203246"),
    legend.title = element_text(size = 10.5),
    legend.text = element_text(size = 9.5),
    plot.margin = margin(9, 12, 10, 9)
  )

for (path in c("figures/Figure2_cancer_feature_map.png",
               "results/figures/Figure2_cancer_feature_map.png")) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  ggsave(path, figure, width = 10.4, height = 10.1, dpi = 300, bg = "white")
}
fwrite(counts, "results/tables/cancer_feature_map_counts.csv")
