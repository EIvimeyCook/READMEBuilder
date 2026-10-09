#' @keywords internal
"_PACKAGE"

# The Shiny app in inst/READMEBuilder/ attaches these packages itself (via
# library() in global.R), so nothing in R/ calls them directly. One import from
# each records the dependency in NAMESPACE, which keeps R CMD check from
# reporting them as unused Imports.
#' @importFrom bslib bs_theme
#' @importFrom dplyr bind_rows
#' @importFrom fs path_home
#' @importFrom purrr map
#' @importFrom readr read_file
#' @importFrom readxl read_excel
#' @importFrom shinyFiles shinyDirChoose
#' @importFrom stringr str_detect
NULL
