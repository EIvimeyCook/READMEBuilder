# inst/READMEBuilder/global.R
# Loaded once by Shiny before ui.R and server.R.
# Contains all libraries and internal helper functions.

library(shiny)
library(bslib)
library(tidyverse)
library(readxl)
library(stringr)
library(purrr)
library(shinyFiles)
library(fs)

# ── Logo ──────────────────────────────────────────────────────────────────────

logo_svg <- HTML('
<svg height="44" viewBox="0 0 190 44" xmlns="http://www.w3.org/2000/svg">
  <rect x="0" y="2" width="40" height="40" rx="8" fill="rgba(255,255,255,0.12)"/>
  <rect x="7"  y="18" width="26" height="4" rx="2" fill="#4dd0e1"/>
  <rect x="7"  y="26" width="26" height="4" rx="2" fill="#4dd0e1"/>
  <rect x="13" y="12" width="4"  height="20" rx="2" fill="white"/>
  <rect x="23" y="12" width="4"  height="20" rx="2" fill="white"/>
  <ellipse cx="30" cy="10" rx="8" ry="5" fill="#f5a623"/>
  <ellipse cx="30" cy="12" rx="10" ry="3" fill="#f5a623"/>
  <rect x="22" y="13" width="16" height="3" rx="1.5" fill="#e08800"/>
  <rect x="29" y="9"  width="3"  height="5" rx="1"   fill="#fff8e1"/>
  <text x="50" y="21" font-family="system-ui,sans-serif" font-size="13"
        font-weight="700" fill="white" letter-spacing="0.5">README</text>
  <text x="50" y="37" font-family="system-ui,sans-serif" font-size="13"
        font-weight="700" fill="#4dd0e1" letter-spacing="0.5">Builder</text>
</svg>
')

# ── Helpers ───────────────────────────────────────────────────────────────────

`%||%` <- function(a, b) if (!is.null(a) && nzchar(trimws(a))) trimws(a) else b

is_script  <- function(f) str_detect(f, "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$")
is_tabular <- function(f) str_detect(f, "\\.(csv|tsv|txt|xlsx|xls)$")

# ── build_dir_tree() ──────────────────────────────────────────────────────────
# Builds a `tree`-style ASCII directory map from a vector of relative file
# paths (as returned by list.files(..., recursive = TRUE)).
# Directories are inferred from the path components, sorted before files, and
# each level is rendered with the usual box-drawing connectors. Returns a
# character vector of lines (one per node), with `root`/ as the first line.

build_dir_tree <- function(files, root = "project") {
  files <- sort(unique(files[nzchar(files)]))
  if (!length(files)) return(paste0(root, "/"))

  split_paths <- str_split(files, "/")

  # Render one level of the tree.
  #   paths  : list of character vectors (remaining path components)
  #   prefix : string of leading spaces / pipes for this depth
  render_level <- function(paths, prefix) {
    heads  <- map_chr(paths, 1L)
    groups <- split(paths, heads)
    names_here <- names(groups)

    # A node is a directory if any path beneath it still has depth > 1.
    is_dir <- map_lgl(names_here, function(nm)
      any(map_int(groups[[nm]], length) > 1L))

    # Directories first, then files; each block alphabetical (case-insensitive).
    ord        <- order(!is_dir, tolower(names_here))
    names_here <- names_here[ord]
    is_dir     <- is_dir[ord]

    out <- character(0)
    n   <- length(names_here)
    for (i in seq_len(n)) {
      nm   <- names_here[i]
      last <- i == n
      connector <- if (last) "└── " else "├── "
      label     <- if (is_dir[i]) paste0(nm, "/") else nm
      out <- c(out, paste0(prefix, connector, label))

      if (is_dir[i]) {
        child_paths  <- keep(groups[[nm]], ~ length(.x) > 1L)
        children     <- map(child_paths, ~ .x[-1L])
        child_prefix <- paste0(prefix, if (last) "    " else "│   ")
        out <- c(out, render_level(children, child_prefix))
      }
    }
    out
  }

  c(paste0(root, "/"), render_level(split_paths, ""))
}

# ── auto_describe() ───────────────────────────────────────────────────────────
# Reads a tabular file and returns per-column summary metadata.
# Returns NULL for non-tabular, unreadable, or degenerate files — so a single
# bad file degrades gracefully to "describe freely" instead of crashing the app.
#
# Robustness notes:
#   * Reads are wrapped in suppressWarnings()/suppressMessages() so vroom parse
#     problems and tibble "New names: `` -> `...1`" repair notices stay quiet.
#   * The WHOLE read-and-summarise is wrapped in tryCatch (the previous version
#     only guarded the read, so an error while summarising a malformed column
#     took the Shiny app down).
#   * Files whose headers are ALL auto-generated (`...1`, `...2`, blank, NA) are
#     treated as non-tabular — this is what prose .txt files look like.
#   * All-NA numeric/date columns are handled without tripping min()/max().

auto_describe <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% c("csv", "tsv", "txt", "xlsx", "xls")) return(NULL)

  out <- tryCatch({
    df <- suppressWarnings(suppressMessages(
      switch(ext,
        csv  = readr::read_csv(path,  show_col_types = FALSE, name_repair = "unique"),
        tsv  = readr::read_tsv(path,  show_col_types = FALSE, name_repair = "unique"),
        txt  = readr::read_tsv(path,  show_col_types = FALSE, name_repair = "unique"),
        xlsx = readxl::read_excel(path, .name_repair = "unique"),
        xls  = readxl::read_excel(path, .name_repair = "unique"),
        NULL
      )
    ))

    if (is.null(df) || ncol(df) == 0 || nrow(df) == 0) return(NULL)

    nm <- names(df)
    # If every header had to be auto-generated, this isn't a real table.
    auto_named <- is.na(nm) | !nzchar(nm) | str_detect(nm, "^\\.\\.\\.[0-9]+$")
    if (all(auto_named)) return(NULL)

    col_data <- map(nm, function(col) {
      x    <- df[[col]]
      na_n <- sum(is.na(x))
      if (is.numeric(x)) {
        if (all(is.na(x))) {
          list(name = col, type = "numeric",
               summary = sprintf("all NA | NAs: %d", na_n))
        } else {
          list(name = col, type = "numeric",
               summary = sprintf("range %s–%s | mean %s | NAs: %d",
                 signif(min(x, na.rm = TRUE), 4), signif(max(x, na.rm = TRUE), 4),
                 signif(mean(x, na.rm = TRUE), 4), na_n))
        }
      } else if (is.character(x) || is.factor(x)) {
        vals <- sort(unique(na.omit(as.character(x))))
        list(name = col, type = "categorical",
             summary = if (length(vals) <= 10)
               sprintf("levels: %s | NAs: %d", paste(vals, collapse = ", "), na_n)
             else
               sprintf("%d unique values | NAs: %d", length(vals), na_n))
      } else if (inherits(x, c("Date", "POSIXct", "POSIXlt"))) {
        if (all(is.na(x))) {
          list(name = col, type = "date",
               summary = sprintf("all NA | NAs: %d", na_n))
        } else {
          list(name = col, type = "date",
               summary = sprintf("range %s–%s | NAs: %d",
                 format(min(x, na.rm = TRUE)), format(max(x, na.rm = TRUE)), na_n))
        }
      } else if (is.logical(x)) {
        list(name = col, type = "logical",
             summary = sprintf("TRUE: %d | FALSE: %d | NAs: %d",
               sum(x, na.rm = TRUE), sum(!x, na.rm = TRUE), na_n))
      } else {
        list(name = col, type = class(x)[1], summary = "")
      }
    })

    list(nrow = nrow(df), ncol = ncol(df), cols = col_data)
  },
  error = function(e) NULL)

  out
}

# ── extract_packages() ────────────────────────────────────────────────────────
# Scans R/Rmd/Quarto scripts for library()/require() calls.
# Returns a list: $pkgs (tibble), $n_files, $n_total, $folder, $filenames.

extract_packages <- function(folder) {
  folder    <- normalizePath(folder, mustWork = FALSE)
  r_files   <- list.files(folder, pattern = "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$",
                           recursive = TRUE, full.names = TRUE, all.files = TRUE)
  all_files <- list.files(folder, recursive = TRUE, full.names = FALSE)

  empty <- list(pkgs = tibble(Package = character(), Version = character()),
                n_files = 0L, n_total = length(all_files),
                folder = folder, filenames = character(0))

  if (!length(r_files)) return(empty)

  pkgs <- character(0)
  for (f in r_files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
    if (!length(lines)) next
    lines <- lines[!str_detect(lines, "^\\s*#")]   # strip comment lines
    text  <- paste(lines, collapse = "\n")
    m     <- str_match_all(text,
      "(?:library|require)\\s*\\(\\s*[\"']?([A-Za-z][A-Za-z0-9._]*)[\"']?")[[1]]
    if (nrow(m) > 0) pkgs <- c(pkgs, m[, 2])
  }

  pkgs <- sort(unique(pkgs[!is.na(pkgs) & nzchar(pkgs)]))

  list(
    pkgs = if (!length(pkgs)) {
      tibble(Package = character(), Version = character())
    } else {
      tibble(Package = pkgs,
             Version = map_chr(pkgs, ~ tryCatch(
               as.character(packageVersion(.x)), error = function(e) "not installed")))
    },
    n_files = length(r_files), n_total = length(all_files),
    folder = folder, filenames = basename(r_files)
  )
}

# ── assemble_readme() ─────────────────────────────────────────────────────────
# Builds the final README.md string from all collected inputs.
# (Named assemble_readme internally to avoid clashing with the exported
#  build_readme() launcher in R/build_readme.R.)

assemble_readme <- function(meta, files, descriptions, auto, pkgs,
                            script_order, script_descs, units_list,
                            col_descs, file_extras, root = "project") {
  md   <- character(0)
  push <- function(...) md <<- c(md, c(...), "")

  push(paste0("# ", meta$title %||% "Untitled Project"))

  badges <- character(0)
  dois   <- keep(str_trim(str_split(meta$doi %||% "", ";")[[1]]), nzchar)
  for (d in dois)
    badges <- c(badges, sprintf(
      "[![DOI](https://img.shields.io/badge/DOI-%s-blue)](https://doi.org/%s)",
      URLencode(d, TRUE), d))
  if (nzchar(meta$license %||% ""))
    badges <- c(badges, sprintf(
      "![License](https://img.shields.io/badge/license-%s-green)",
      URLencode(meta$license, TRUE)))
  if (length(badges)) push(paste(badges, collapse = " "))

  if (nzchar(meta$description  %||% "")) push("## Description",  meta$description)
  if (nzchar(meta$abstract     %||% "")) push("## Abstract",     meta$abstract)
  if (nzchar(meta$instructions %||% "")) push("## Instructions", meta$instructions)

  if (nzchar(meta$authors %||% "")) {
    lines <- keep(str_trim(str_split(meta$authors, "\n")[[1]]), nzchar)
    push("## Authors", paste0("- ", lines))
  }
  if (nzchar(meta$affiliation %||% "")) {
    lines <- keep(str_trim(str_split(meta$affiliation, "\n")[[1]]), nzchar)
    push("## Affiliations", paste0("- ", lines))
  }
  if (nzchar(meta$contact %||% ""))
    push("## Contact", paste0("\U0001F4E7 ", meta$contact))

  if (nzchar(meta$funders %||% "")) {
    lines <- keep(str_trim(str_split(meta$funders, "\n")[[1]]), nzchar)
    push("## Funding", paste0("- ", lines))
  }
  if (nzchar(meta$acknowledgements %||% ""))
    push("## Acknowledgements", meta$acknowledgements)

  if (length(dois) > 0) {
    push("## Citation", "If you use this work please cite it using the DOI(s) above.")
    if (nzchar(meta$citation_text %||% "")) push(paste0("> ", meta$citation_text))
  }
  if (nzchar(meta$license %||% ""))
    push("## License", paste0("This work is licensed under ", meta$license, "."))
  if (nzchar(meta$additional_info %||% ""))
    push("## Additional information", meta$additional_info)

  # Directory map ───────────────────────────────────────────────────────────────
  if (length(files) > 0) {
    push("## Directory Structure",
         "```text",
         build_dir_tree(files, root = root),
         "```")
  }

  # Data files
  data_idx <- which(is_tabular(files))
  if (length(data_idx) > 0) {
    push("## Data Files")
    for (i in data_idx) {
      desc <- descriptions[[i]]; a <- auto[[i]]
      u <- units_list[[i]]; cd <- col_descs[[i]]; fe <- file_extras[[i]]
      md <- c(md, paste0("### `", files[i], "`"))
      if (nzchar(desc %||% "")) md <- c(md, "", desc)
      meta_parts <- character(0)
      if (nzchar(fe$date %||% "")) meta_parts <- c(meta_parts, paste0("**Date collected:** ", fe$date))
      if (nzchar(fe$loc  %||% "")) meta_parts <- c(meta_parts, paste0("**Location:** ", fe$loc))
      if (length(meta_parts)) md <- c(md, "", paste(meta_parts, collapse = " | "))
      if (!is.null(a)) {
        md <- c(md, "",
                paste0("**Dimensions:** ", a$nrow, " rows × ", a$ncol, " columns"),
                "", "**Variables:**", "",
                "| Column | Type | Description | Units | Summary |",
                "| :----- | :--- | :---------- | :---- | :------ |")
        for (col_d in a$cols) {
          md <- c(md, sprintf("| `%s` | %s | %s | %s | %s |",
            col_d$name, col_d$type,
            cd[[col_d$name]] %||% "",
            if (col_d$type == "numeric") u[[col_d$name]] %||% "" else "",
            col_d$summary))
        }
      }
      md <- c(md, "")
    }
  }

  # Other files
  other_idx <- which(!is_tabular(files) & !is_script(files))
  if (length(other_idx) > 0) {
    push("## Other Files")
    for (i in other_idx) {
      desc <- descriptions[[i]]
      md   <- c(md, paste0("### `", files[i], "`"))
      if (nzchar(desc %||% "")) md <- c(md, "", desc)
      md <- c(md, "")
    }
  }

  # Scripts
  if (length(script_order) > 0) {
    push("## Code", "Scripts should be run in the following order:", "")
    for (k in seq_along(script_order)) {
      desc <- script_descs[[k]] %||% ""
      md   <- c(md, paste0(k, ". **`", files[script_order[k]], "`**"))
      if (nzchar(desc)) md <- c(md, "   ", paste0("   ", desc))
      md <- c(md, "")
    }
  }

  # R environment
  r_ver <- paste0(R.version$major, ".", R.version$minor)
  if (!is.null(pkgs) && nrow(pkgs) > 0) {
    push("## R Environment",
         paste0("**R version:** ", r_ver), "",
         "| Package | Version |", "| :------ | :------ |",
         paste0("| `", pkgs$Package, "` | ", pkgs$Version, " |"))
  } else {
    push("## R Environment", paste0("**R version:** ", r_ver))
  }

  push("---", paste0("*README generated with READMEBuilder on ",
                      format(Sys.Date(), "%d %B %Y"), ".*"))
  paste(md, collapse = "\n")
}
