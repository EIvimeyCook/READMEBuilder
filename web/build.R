# web/build.R
# Builds the browser version of READMEBuilder (Shinylive / webR) into web/_site.
# The app code is the same as the package's (inst/READMEBuilder); it switches
# to zip upload and renv.lock-only versions when it finds itself in webR.
#
# Run from the package root:   Rscript web/build.R
# Preview locally:             httpuv::runStaticServer("web/_site")
#
# Needs the shinylive package. The output is ~90 MB, almost all webR itself,
# so it is git-ignored and never part of the R package (see .Rbuildignore).

app <- file.path("inst", "READMEBuilder")
if (!dir.exists(app)) stop("Run web/build.R from the READMEBuilder package root.")

out <- file.path("web", "_site")
unlink(out, recursive = TRUE)
shinylive::export(app, out, template_params = list(title = "READMEBuilder"))
