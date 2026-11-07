# ---------------------------------------------------------------------------
# Rebuild all four figures.
#
# Each script runs in its own R process so no object can leak between them.
# Order matters only for Figure 4, which reads Figure 3's exports.
#
# Run: Rscript code/build_all.R   (or source() it from the package folder)
# ---------------------------------------------------------------------------

CODE <- local({
  a <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(a)) dirname(normalizePath(sub("^--file=", "", a[1])))
  else c("code", "../code")[file.exists(file.path(c("code", "../code"), "shared.R"))][1]
})
rscript <- file.path(R.home("bin"), "Rscript")

for (script in c("make_figure1.R", "make_figure2.R", "make_figure3.R",
                 "make_figure4.R")) {
  cat("\n===", script, "===\n")
  if (system2(rscript, shQuote(file.path(CODE, script))) != 0) stop("Rebuild failed: ", script)
}
cat("\nAll four figures rebuilt.",
    "Review README.md if any analysis setting changed.\n")
