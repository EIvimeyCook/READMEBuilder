#' Launch the READMEBuilder Shiny app
#'
#' Opens an interactive Shiny application that guides you through building a
#' high-quality README file for a research dataset or code repository, covering
#' both the data and the code so the work can be reproduced.
#'
#' The app walks through five steps:
#' \enumerate{
#'   \item \strong{Project Info}: title, description, abstract, instructions,
#'         DOI(s), citation, authors, affiliations, contact, funders,
#'         acknowledgements, and separate code and data licences. An existing
#'         README made by the app can be uploaded here to reload and edit it.
#'   \item \strong{Files}: load a project folder. A directory map is shown and
#'         included in the export; tabular files are auto-described (column
#'         types, ranges, levels, NAs); add descriptions and units per column,
#'         and the date(s) and location of data collection.
#'   \item \strong{Script Order}: define the run order of R/Rmd/Quarto scripts
#'         and describe each one.
#'   \item \strong{R Packages}: scan scripts for \code{library()},
#'         \code{require()}, \code{requireNamespace()}, \code{pkg::fun}, and the
#'         pacman, librarian, import, and groundhog loaders, then resolve each
#'         version. If an \code{renv.lock} is present, its recorded versions
#'         (and R version) are used.
#'   \item \strong{Preview & Export}: live Markdown preview and one-click
#'         download of \code{README.md}.
#' }
#'
#' @return Launches the Shiny app; does not return a value. Produces a
#'   \code{README.md} file.
#'
#' @examples
#' \dontrun{
#' build_readme()
#' }
#'
#' @export
build_readme <- function() {
  app_dir <- system.file("READMEBuilder", package = "READMEBuilder")
  if (!nzchar(app_dir)) {
    stop(
      "Could not find the READMEBuilder app directory. ",
      "Try re-installing the package with: ",
      "devtools::install_github(\"EIvimeyCook/READMEBuilder\")",
      call. = FALSE
    )
  }
  shiny::runApp(app_dir, display.mode = "normal")
}
