options(repos = c(CRAN = "https://cloud.r-project.org"))

cran <- c(
  "data.table", "readxl", "digest", "jsonlite", "future.apply", "float",
  "progressr", "pROC", "ggplot2", "glmnet", "testthat", "remotes",
  "BiocManager"
)
missing <- cran[!vapply(cran, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)

dir.create(".Rlib", showWarnings = FALSE)
.libPaths(c(normalizePath(".Rlib"), .libPaths()))

need_fastpls <- !requireNamespace("fastPLS", quietly = TRUE) ||
  packageVersion("fastPLS") != "0.3" ||
  !identical(packageDescription("fastPLS")$Repository, "CRAN")
if (need_fastpls) {
  fastpls_archive <- tempfile(fileext = ".tar.gz")
  fastpls_urls <- c(
    "https://cloud.r-project.org/src/contrib/fastPLS_0.3.tar.gz",
    "https://cloud.r-project.org/src/contrib/Archive/fastPLS/fastPLS_0.3.tar.gz"
  )
  downloaded <- FALSE
  for (url in fastpls_urls) {
    downloaded <- tryCatch({
      status <- suppressWarnings(download.file(
        url, fastpls_archive, mode = "wb", quiet = TRUE
      ))
      identical(status, 0L) && file.exists(fastpls_archive) &&
        file.info(fastpls_archive)$size > 0
    }, error = function(e) FALSE)
    if (downloaded) break
  }
  if (!downloaded) stop("Could not download the pinned CRAN fastPLS 0.3 source")
  fastpls_sha256 <- digest::digest(file = fastpls_archive, algo = "sha256")
  expected_sha256 <-
    "e752ed28dcbaf162d8e622d3c7dc436b315ef4b767c06db2ae8b29cbbfa7b51f"
  if (!identical(fastpls_sha256, expected_sha256)) {
    stop("CRAN fastPLS 0.3 source SHA-256 mismatch: ", fastpls_sha256)
  }
  install.packages(fastpls_archive, lib = ".Rlib", repos = NULL, type = "source")
  unlink(fastpls_archive)
}
stopifnot(as.character(packageVersion("fastPLS")) == "0.3",
          identical(packageDescription("fastPLS")$Repository, "CRAN"))

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
        " from ", packageDescription("fastPLS")$Repository,
        " installed at ", find.package("fastPLS"))
