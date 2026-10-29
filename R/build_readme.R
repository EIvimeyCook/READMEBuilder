#' Launch the READMEBuilder Shiny app
#'
#' Opens an interactive Shiny application that guides you through building a
#' high-quality README file for a research dataset or code repository, covering
#' both the data and the code so the work can be reproduced.
#'
#' The app walks through six steps:
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
#'         version. The scan runs as soon as a folder is loaded. If an
#'         \code{renv.lock} is present, its recorded versions (and R version)
#'         are used.
#'   \item \strong{Models} (optional): record where each analysis is
#'         described, reported, and coded (an MLast-style table).
#'   \item \strong{Preview & Export}: live Markdown preview and one-click
#'         download of \code{README.md}.
#' }
#'
#' The Files tab also has a \strong{Use working directory} button, which loads
#' the folder \code{build_readme()} was called from (\code{getwd()}), so a
#' project already open in your IDE does not have to be browsed to. A project
#' can also be uploaded as a \code{.zip}.
#'
#' The same app also runs in a web browser without installing anything, at
#' \url{https://eivimeycook.github.io/READMEBuilder/}. There the project folder
#' is chosen with the browser's folder chooser or uploaded as a \code{.zip}
#' (read inside the page, never sent anywhere), and package versions come only
#' from the project's \code{renv.lock}.
#'
#' @param folder Optional path to the project folder to load when the app
#'   opens: absolute (\code{"~/projects/my-study"}), relative to the working
#'   directory (\code{"."}, \code{"analysis"}), or built with
#'   \code{here::here()}. \code{NULL} (the default) opens the app with no folder
#'   loaded.
#' @param edit_readme If \code{TRUE}, and the folder contains a
#'   \code{README.md} made by READMEBuilder, the form is filled in from it
#'   (project info, file and column descriptions, units, script order and
#'   descriptions, models, and the recorded R / package versions), while the
#'   file list and data summaries come from the folder itself. A README not
#'   made by READMEBuilder is left alone. If \code{folder} is not given, the
#'   working directory is used.
#'
#' @return Launches the Shiny app; does not return a value. Produces a
#'   \code{README.md} file.
#'
#' @examples
#' \dontrun{
#' build_readme()
#'
#' # Open with a project folder already loaded
#' build_readme(".")
#' build_readme("~/projects/my-study")
#' build_readme(here::here())
#'
#' # Load the working directory and carry on editing its README.md
#' build_readme(edit_readme = TRUE)
#' }
#'
#' @export
build_readme <- function(folder = NULL, edit_readme = FALSE) {
  if (!is.logical(edit_readme) || length(edit_readme) != 1 || is.na(edit_readme))
    stop("`edit_readme` must be TRUE or FALSE.", call. = FALSE)

  # runApp() switches the working directory to the app's own folder, so the
  # caller's working directory (and any relative `folder`) is resolved here.
  wd <- normalizePath(getwd(), winslash = "/")
  if (is.null(folder) && edit_readme) folder <- wd
  if (!is.null(folder)) {
    if (!is.character(folder) || length(folder) != 1 || is.na(folder) || !nzchar(folder))
      stop("`folder` must be a single path to a folder.", call. = FALSE)
    path <- normalizePath(path.expand(folder), winslash = "/", mustWork = FALSE)
    if (!dir.exists(path))
      stop("Folder not found: ", folder, call. = FALSE)
    folder <- path
  }

  app_dir <- system.file("READMEBuilder", package = "READMEBuilder")
  if (!nzchar(app_dir)) {
    stop(
      "Could not find the READMEBuilder app directory. ",
      "Try re-installing the package with: ",
      "devtools::install_github(\"EIvimeyCook/READMEBuilder\")",
      call. = FALSE
    )
  }

  # Read by the app's server; restored when the app closes.
  op <- options(READMEBuilder.launch = list(wd = wd, folder = folder,
                                            edit_readme = edit_readme))
  on.exit(options(op), add = TRUE)
  shiny::runApp(app_dir, display.mode = "normal")
}
