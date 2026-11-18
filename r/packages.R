# The NSF base image's R packages: from ML_Ad-hoc's actual use (library() and pkg:: counts, 2026-11-18), without the
# Honeylove-only ones. Installed as binaries from the CRAN snapshot set in the Dockerfile (getOption("repos")).
# A project adds its own with renv; departments of the NSF add theirs in their own image.
# Fails the build if any package doesn't install and load, and writes what it installed to /opt/nsf/r-packages.tsv.

pkgs <- c(
  # data
  "tidyverse", "arrow", "duckdb", "DBI", "data.table", "here", "glue", "scales", "janitor", "jsonlite", "httr2",
  "zoo", "openxlsx",
  # reports and plots
  "knitr", "rmarkdown", "quarto", "kableExtra", "gt", "DT", "patchwork", "cowplot", "ggrepel", "ragg", "plotly",
  "corrplot",
  # models
  "broom", "tidymodels", "xgboost", "mgcv", "lme4", "marginaleffects", "MatchIt", "CausalImpact", "coda", "pwr",
  # pipelines, tests, apps
  "targets", "tarchetypes", "mirai", "testthat", "renv", "pacman", "shiny", "bslib",
  # Positron and agents: the R console's helpers
  "languageserver"
)

options(Ncpus = max(1L, parallel::detectCores()))
install.packages(pkgs)

# every package must load, and a failure says why (a missing system library shows up here as "cannot open shared
# object file", which installing the binary doesn't catch)
why <- vapply(pkgs, function(p) tryCatch({ loadNamespace(p); "" }, error = function(e) conditionMessage(e)), "")
if (any(nzchar(why))) stop("won't load:\n", paste0("  ", names(why)[nzchar(why)], ": ", why[nzchar(why)], collapse = "\n"))

# and no compiled library anywhere in the site library is missing a system library (a dependency nobody loads above
# would otherwise fail only when a project first uses it)
so <- list.files("/usr/local/lib/R/site-library", pattern = "\\.so$", recursive = TRUE, full.names = TRUE)
gaps <- unique(unlist(lapply(so, function(f) {
  out <- system2("ldd", f, stdout = TRUE, stderr = FALSE)
  sub("^\\s*(\\S+) => not found.*$", "\\1", grep("not found", out, value = TRUE))
})))
if (length(gaps)) stop("system libraries missing for compiled R packages: ", paste(gaps, collapse = ", "))

ip <- installed.packages(fields = "Repository")
write.table(ip[, c("Package", "Version")], "/opt/nsf/r-packages.tsv", sep = "\t", quote = FALSE, row.names = FALSE)
cat(sprintf("R %s: %d packages installed (%d asked for), from %s\n", getRversion(), nrow(ip), length(pkgs),
            getOption("repos")[["CRAN"]]))
