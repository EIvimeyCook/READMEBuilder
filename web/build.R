# web/build.R
# Builds the browser version of READMEBuilder (Shinylive / webR) into web/_site.
# The app code is the same as the package's (inst/READMEBuilder); it switches
# to zip upload and renv.lock-only versions when it finds itself in webR.
#
# Run from the package root:   Rscript web/build.R   (or source() it in RStudio)
# Preview locally:             python3 -m http.server 8765 --directory web/_site
#                              then open http://localhost:8765
#
# Needs the shinylive package. The output is ~90 MB, almost all webR itself,
# so it is git-ignored and never part of the R package (see .Rbuildignore).
# On GitHub, .github/workflows/deploy-web.yml runs this and publishes the
# result to GitHub Pages.

app <- file.path("inst", "READMEBuilder")
if (!dir.exists(app)) stop("Run web/build.R from the READMEBuilder package root.")

out <- file.path("web", "_site")
unlink(out, recursive = TRUE)
shinylive::export(app, out, template_params = list(title = "READMEBuilder"))
