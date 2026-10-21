options(repos = c(CRAN = "https://cloud.r-project.org"))

cran <- c(
  "data.table", "readxl", "digest", "jsonlite", "future.apply", "float",
  "progressr", "pROC", "ggplot2", "glmnet", "testthat", "remotes",
  "gpuinfo",
  "BiocManager"
)
missing <- cran[!vapply(cran, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)

dir.create(".Rlib", showWarnings = FALSE)
.libPaths(c(normalizePath(".Rlib"), .libPaths()))

need_fastpls <- !requireNamespace("fastPLS", quietly = TRUE) ||
  packageVersion("fastPLS") != "0.4"
if (need_fastpls) {
  remotes::install_github(
    "tkcaccia/fastPLS@265108b6aa250c2534f98ec89037bb5cd001dca0",
    lib = ".Rlib", upgrade = "never", dependencies = TRUE, force = TRUE
  )
}
stopifnot(as.character(packageVersion("fastPLS")) == "0.4")

if (!requireNamespace("PathoFMPred", quietly = TRUE)) {
  remotes::install_github(
    "tkcaccia/PathoFMPred",
    lib = ".Rlib", upgrade = "never", dependencies = TRUE
  )
}

bioc <- c("maftools")
missing_bioc <- bioc[!vapply(bioc, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_bioc)) {
  BiocManager::install(missing_bioc, lib = ".Rlib", ask = FALSE,
                       update = FALSE)
}
if (!requireNamespace("TCGAmutations", quietly = TRUE)) {
  remotes::install_github(
    "PoisonAlien/TCGAmutations@3474e3412cfa1490db4a84db57e4a732480990a9",
    lib = ".Rlib",
                          upgrade = "never", dependencies = FALSE,
                          force = TRUE)
}

message("fastPLS ", as.character(packageVersion("fastPLS")),
        " installed at ", find.package("fastPLS"))
