#' Launch the READMEBuilder Shiny app
#'
#' Opens an interactive Shiny application that guides you through building a
#' high-quality README file for a research dataset or code repository.
#'
#' The app walks through five steps:
#' \enumerate{
#'   \item **Project Info** — title, abstract, DOI(s), licence, authors, funders
#'   \item **Files** — load a project folder; tabular files are auto-described
#'         (column types, ranges, levels); add descriptions and units per column;
#'         specify collection dates and locations
#'   \item **Script Order** — define the run order of R/Rmd/Quarto scripts
#'   \item **R Packages** — scan scripts for \code{library()} / \code{require()}
#'         calls and resolve installed versions
#'   \item **Preview & Export** — live Markdown preview and one-click download
#'         of \code{README.md}
#' }
#'
#' @return Launches the Shiny app; does not return a value. Produces a .MD file. 
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
