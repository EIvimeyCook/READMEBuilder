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

# Shared licence choices, offered in both the code and data licence selectors.
# The selectors allow free-typed values too, so an imported licence that is not
# in this list (e.g. "CC-BY-4.0") can still be set.
license_choices <- c(
  "None / unspecified" = "",
  "CC0 1.0 (public domain)", "CC BY 4.0", "CC BY 2.0",
  "CC BY-SA 4.0", "CC BY-NC 4.0", "CC BY-NC 2.0",
  "CC BY-NC-SA 4.0", "CC BY-ND 4.0", "CC BY-NC-ND 4.0",
  "MIT", "MIT No Attribution (MIT-0)", "Apache 2.0",
  "GPL-2.0", "GPL-3.0", "LGPL-2.1", "LGPL-3.0",
  "AGPL-3.0", "MPL-2.0", "EUPL-1.2",
  "BSD 2-Clause", "BSD 3-Clause", "ISC", "Artistic-2.0",
  "ODC-By 1.0 (Open Data Commons Attribution)",
  "ODbL 1.0 (Open Database Licence)",
  "PDDL 1.0 (Public Domain Dedication & Licence)",
  "Open Government Licence v3.0 (UK)",
  "Open Government Licence v2.0 (UK)",
  "Etalab Open Licence 2.0 (France)",
  "Unlicense", "WTFPL", "All rights reserved"
)

# ── build_dir_tree() ──────────────────────────────────────────────────────────
# Builds a `tree`-style ASCII directory map from a vector of relative file paths.
# Directories are inferred from the path components, sorted before files, and
# each level is rendered with the usual box-drawing connectors.

build_dir_tree <- function(files, root = "project") {
  files <- sort(unique(files[nzchar(files)]))
  if (!length(files)) return(paste0(root, "/"))

  split_paths <- str_split(files, "/")

  render_level <- function(paths, prefix) {
    heads  <- map_chr(paths, 1L)
    groups <- split(paths, heads)
    names_here <- names(groups)

    is_dir <- map_lgl(names_here, function(nm)
      any(map_int(groups[[nm]], length) > 1L))

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

# parse_dir_tree(): reverse of build_dir_tree(). Given the body lines of a
# directory map (excluding the fences and the root line), returns the relative
# file paths (files only, not directories).
parse_dir_tree <- function(body) {
  body  <- body[nzchar(str_trim(body))]
  files <- character(0)
  dir_at <- character(0)              # dir_at[d+1] = directory name at depth d
  for (l in body) {
    mm <- str_match(l, "^((?:│   |    )*)(?:├── |└── )(.*)$")
    if (is.na(mm[1, 1])) next
    depth <- nchar(mm[1, 2]) %/% 4L     # 0-based
    name  <- mm[1, 3]
    if (str_detect(name, "/$")) {
      dir_at[depth + 1L] <- str_remove(name, "/$")
      if (length(dir_at) > depth + 1L) dir_at <- dir_at[seq_len(depth + 1L)]
    } else {
      anc   <- if (depth >= 1L) dir_at[seq_len(depth)] else character(0)
      anc   <- anc[!is.na(anc)]
      files <- c(files, paste(c(anc, name), collapse = "/"))
    }
  }
  files
}

# ── auto_describe() ───────────────────────────────────────────────────────────
# Reads a tabular file and returns per-column summary metadata.
# Returns NULL for non-tabular, unreadable, or degenerate files — so a single
# bad file degrades gracefully instead of crashing the app. The whole read AND
# summarise is wrapped in tryCatch; read warnings/messages are suppressed; files
# whose headers are all auto-generated (prose .txt) are skipped.

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
    auto_named <- is.na(nm) | !nzchar(nm) | str_detect(nm, "^\\.\\.\\.[0-9]+$")
    if (all(auto_named)) return(NULL)

    col_data <- map(nm, function(col) {
      x    <- df[[col]]
      na_n <- sum(is.na(x))
      if (is.numeric(x)) {
        if (all(is.na(x))) {
          list(name = col, type = "numeric", summary = sprintf("all NA | NAs: %d", na_n))
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
          list(name = col, type = "date", summary = sprintf("all NA | NAs: %d", na_n))
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
    lines <- lines[!str_detect(lines, "^\\s*#")]
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

# ── parse_readme() ────────────────────────────────────────────────────────────
# Reverse of assemble_readme(). Given the text of a README produced by
# READMEBuilder, returns a list with both the project-info `meta` AND the
# structural content (files, column metadata, script order, packages, R version)
# so a previous README can be fully re-loaded WITHOUT the original data folder.
#
# Tolerances baked in (so older / hand-tweaked READMEs still import):
#   * Funders section may be "## Funding" or "## Funders".
#   * Licence lines may be "- **Code:** licensed under X." or
#     "This code is licensed under X" (period optional), or a single
#     "This work is licensed under X" (-> code slot).
#   * Variable-table cells may contain unescaped "|" (older output): extra
#     cells are folded back into the trailing Summary column.
#   * Avoids `%||%` on multi-element vectors (it uses `&&`, which errors on
#     length-> 1 logicals in R >= 4.3).

parse_readme <- function(text) {
  lines <- str_split(text, "\r?\n")[[1]]

  h1    <- which(str_detect(lines, "^#\\s+"))
  title <- if (length(h1)) str_trim(str_remove(lines[h1[1]], "^#\\s+")) else ""

  m   <- str_match_all(text, "https?://doi\\.org/([^)\\s]+)")[[1]]
  doi <- if (nrow(m) > 0) paste(unique(str_trim(m[, 2])), collapse = "; ") else ""

  # Map each level-2 heading to its body lines (excluding ### headings),
  # stopping each body at a horizontal rule so the footer never leaks in.
  h2  <- which(str_detect(lines, "^##\\s+") & !str_detect(lines, "^###"))
  sec <- list()
  if (length(h2)) {
    for (j in seq_along(h2)) {
      start <- h2[j]
      end   <- if (j < length(h2)) h2[j + 1] - 1 else length(lines)
      nm    <- str_trim(str_remove(lines[start], "^##\\s+"))
      body  <- if (end > start) lines[(start + 1):end] else character(0)
      hr <- which(str_detect(body, "^---\\s*$"))
      if (length(hr)) body <- if (hr[1] > 1) body[seq_len(hr[1] - 1)] else character(0)
      sec[[nm]] <- body
    }
  }

  sec_body <- function(...) {
    for (nm in c(...)) if (!is.null(sec[[nm]])) return(sec[[nm]])
    character(0)
  }
  trim_blanks <- function(x) {
    x <- x[!is.na(x)]
    while (length(x) && !nzchar(str_trim(x[1])))         x <- x[-1]
    while (length(x) && !nzchar(str_trim(x[length(x)]))) x <- x[-length(x)]
    x
  }
  as_para <- function(...) paste(trim_blanks(sec_body(...)), collapse = "\n")
  as_bullets <- function(...) {
    b <- sec_body(...)
    b <- b[str_detect(b, "^\\s*-\\s+")]
    paste(str_trim(str_remove(b, "^\\s*-\\s+")), collapse = "\n")
  }

  contact <- {
    b <- trim_blanks(sec_body("Contact"))
    if (length(b)) str_trim(str_replace(b[1], "^[^\\w@]+", "")) else ""
  }
  citation_text <- {
    q <- sec_body("Citation")
    q <- q[str_detect(q, "^\\s*>\\s+")]
    if (length(q)) str_trim(str_remove(q[1], "^\\s*>\\s+")) else ""
  }

  lic <- function(word) {
    b   <- sec_body("License", "Licence")
    hit <- b[str_detect(b, regex(word, ignore_case = TRUE)) &
             str_detect(b, regex("licensed under", ignore_case = TRUE))]
    if (!length(hit)) return("")
    mm <- str_match(hit[1], regex("licensed under\\s*(.+?)\\.?\\s*$", ignore_case = TRUE))
    if (is.na(mm[1, 2])) "" else str_trim(mm[1, 2])
  }
  license_code <- lic("code")
  license_data <- lic("data")
  if (!nzchar(license_code) && !nzchar(license_data)) {
    b  <- sec_body("License", "Licence")
    mm <- str_match(b, regex("licensed under\\s*(.+?)\\.?\\s*$", ignore_case = TRUE))
    hit <- mm[!is.na(mm[, 2]), 2]
    if (length(hit)) license_code <- str_trim(hit[1])
  }

  meta <- list(
    title = title, description = as_para("Description"),
    abstract = as_para("Abstract"), instructions = as_para("Instructions"),
    additional_info = as_para("Additional information"),
    doi = doi, citation_text = citation_text,
    license_code = license_code, license_data = license_data,
    authors = as_bullets("Authors"), affiliation = as_bullets("Affiliations"),
    contact = contact, funders = as_bullets("Funding", "Funders"),
    acknowledgements = as_para("Acknowledgements")
  )

  # ── Directory tree -> files + root name ─────────────────────────────────────
  tb <- sec_body("Directory Structure", "Directory map", "Directory Map")
  tb <- tb[!str_detect(tb, "^\\s*```")]
  tb <- tb[nzchar(str_trim(tb))]
  root_name <- ""
  if (length(tb)) {
    rn <- str_trim(tb[1])
    if (str_detect(rn, "/$") && !str_detect(rn, "[│├└]"))
      root_name <- str_remove(rn, "/$")
    tb <- tb[-1]
  }
  files <- if (length(tb)) parse_dir_tree(tb) else character(0)

  # ── markdown table helpers ──────────────────────────────────────────────────
  split_row <- function(row) {
    parts <- str_split(str_trim(row), "(?<!\\\\)\\|")[[1]]
    if (length(parts) && !nzchar(str_trim(parts[1])))             parts <- parts[-1]
    if (length(parts) && !nzchar(str_trim(parts[length(parts)]))) parts <- parts[-length(parts)]
    str_replace_all(str_trim(parts), fixed("\\|"), "|")
  }
  split_h3 <- function(body) {
    idx <- which(str_detect(body, "^###\\s+`.+`"))
    if (!length(idx)) return(list())
    out <- list()
    for (k in seq_along(idx)) {
      s <- idx[k]; e <- if (k < length(idx)) idx[k + 1] - 1 else length(body)
      path <- str_match(body[s], "^###\\s+`(.+?)`")[1, 2]
      out[[length(out) + 1]] <- list(path = path,
        lines = if (e > s) body[(s + 1):e] else character(0))
    }
    out
  }

  file_desc <- list(); col_desc <- list(); units <- list()
  dates <- list(); locs <- list(); auto_by_path <- list()

  for (it in split_h3(sec_body("Data Files"))) {
    p <- it$path; bl <- it$lines
    desc <- character(0)
    for (l in bl) {
      s <- str_trim(l)
      if (str_detect(s, "^\\*\\*") || str_detect(s, "^\\|")) break
      if (nzchar(s)) desc <- c(desc, s)
    }
    if (length(desc)) file_desc[[p]] <- paste(desc, collapse = "\n")

    dline <- bl[str_detect(bl, "\\*\\*Date collected:\\*\\*")]
    if (length(dline)) {
      d1 <- str_match(dline[1],
        "\\*\\*Date collected:\\*\\*\\s*(.+?)(?:\\s*\\|\\s*\\*\\*Location:\\*\\*\\s*(.+))?$")
      if (!is.na(d1[1, 2])) dates[[p]] <- str_trim(d1[1, 2])
      if (!is.na(d1[1, 3])) locs[[p]]  <- str_trim(d1[1, 3])
    }
    lline <- bl[str_detect(bl, "\\*\\*Location:\\*\\*") &
                !str_detect(bl, "\\*\\*Date collected:\\*\\*")]
    if (length(lline) && is.null(locs[[p]])) {
      l1 <- str_match(lline[1], "\\*\\*Location:\\*\\*\\s*(.+)$")
      if (!is.na(l1[1, 2])) locs[[p]] <- str_trim(l1[1, 2])
    }

    dim <- str_match(paste(bl, collapse = "\n"),
      "\\*\\*Dimensions:\\*\\*\\s*([0-9]+)\\s*rows\\s*[×x]\\s*([0-9]+)\\s*columns")
    nrw <- if (!is.na(dim[1, 2])) as.integer(dim[1, 2]) else NA_integer_
    ncl <- if (!is.na(dim[1, 3])) as.integer(dim[1, 3]) else NA_integer_

    rows <- bl[str_detect(bl, "^\\s*\\|")]
    rows <- rows[!str_detect(rows, "^\\s*\\|\\s*:?-{2,}")]
    rows <- rows[!str_detect(rows, "Column\\s*\\|\\s*Type")]
    cols <- list(); cd <- list(); un <- list()
    for (r in rows) {
      cells <- split_row(r)
      if (length(cells) < 5) next
      nmc  <- str_replace_all(cells[1], "`", "")
      typ  <- cells[2]; dsc <- cells[3]; unt <- cells[4]
      summ <- paste(cells[5:length(cells)], collapse = " | ")
      cols[[length(cols) + 1]] <- list(name = nmc, type = typ, summary = summ)
      if (nzchar(dsc)) cd[[nmc]] <- dsc
      if (nzchar(unt)) un[[nmc]] <- unt
    }
    if (length(cols)) auto_by_path[[p]] <- list(nrow = nrw, ncol = ncl, cols = cols)
    if (length(cd)) col_desc[[p]] <- cd
    if (length(un)) units[[p]] <- un
  }

  for (it in split_h3(sec_body("Other Files"))) {
    bl <- str_trim(it$lines); bl <- bl[nzchar(bl)]
    if (length(bl)) file_desc[[it$path]] <- paste(bl, collapse = "\n")
  }

  # ── Code / scripts (run order + descriptions) ───────────────────────────────
  script_paths <- character(0); script_desc <- list(); cur <- NULL
  for (l in sec_body("Code")) {
    mm <- str_match(l, "^\\s*\\d+\\.\\s+\\*\\*`(.+?)`\\*\\*")
    if (!is.na(mm[1, 2])) {
      cur <- mm[1, 2]; script_paths <- c(script_paths, cur)
    } else if (!is.null(cur) && nzchar(str_trim(l))) {
      add  <- str_trim(l)
      prev <- script_desc[[cur]]
      script_desc[[cur]] <- if (is.null(prev) || !nzchar(prev)) add else paste(prev, add)
    }
  }

  # ── R environment (version + package table) ─────────────────────────────────
  renv <- sec_body("R Environment", "R environment")
  rvm  <- str_match(paste(renv, collapse = "\n"), "\\*\\*R version:\\*\\*\\s*([0-9.]+)")
  r_version <- if (!is.na(rvm[1, 2])) rvm[1, 2] else ""
  pk_pkg <- character(0); pk_ver <- character(0)
  for (l in renv) {
    mm <- str_match(l, "^\\|\\s*`(.+?)`\\s*\\|\\s*(.+?)\\s*\\|")
    if (!is.na(mm[1, 2])) { pk_pkg <- c(pk_pkg, mm[1, 2]); pk_ver <- c(pk_ver, str_trim(mm[1, 3])) }
  }
  pkgs <- tibble(Package = pk_pkg, Version = pk_ver)

  auto <- map(files, function(p) if (!is.null(auto_by_path[[p]])) auto_by_path[[p]] else NULL)
  script_order <- match(script_paths, files)
  script_order <- script_order[!is.na(script_order)]

  list(
    meta = meta, root_name = root_name, files = files, auto = auto,
    script_order = script_order, script_desc = script_desc,
    pkgs = pkgs, r_version = r_version,
    file_desc = file_desc, col_desc = col_desc, units = units,
    dates = dates, locs = locs
  )
}

# ── assemble_readme() ─────────────────────────────────────────────────────────
# Builds the final README.md string from all collected inputs.

assemble_readme <- function(meta, files, descriptions, auto, pkgs,
                            script_order, script_descs, units_list,
                            col_descs, file_extras, root = "project",
                            r_version = NULL) {
  md   <- character(0)
  push <- function(...) md <<- c(md, c(...), "")

  # Escape a markdown table cell: collapse newlines and escape "|" so a value
  # containing pipes (every auto-summary does) cannot break the table layout.
  esc_cell <- function(x) {
    x <- x %||% ""
    x <- str_replace_all(x, "[\r\n]+", " ")
    str_replace_all(x, fixed("|"), "\\|")
  }

  push(paste0("# ", meta$title %||% "Untitled Project"))

  badges <- character(0)
  dois   <- keep(str_trim(str_split(meta$doi %||% "", ";")[[1]]), nzchar)
  for (d in dois)
    badges <- c(badges, sprintf(
      "[![DOI](https://img.shields.io/badge/DOI-%s-blue)](https://doi.org/%s)",
      URLencode(d, TRUE), d))
  if (nzchar(meta$license_code %||% ""))
    badges <- c(badges, sprintf(
      "![Code License](https://img.shields.io/badge/code%%20license-%s-green)",
      URLencode(meta$license_code, TRUE)))
  if (nzchar(meta$license_data %||% ""))
    badges <- c(badges, sprintf(
      "![Data License](https://img.shields.io/badge/data%%20license-%s-blue)",
      URLencode(meta$license_data, TRUE)))
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

  # Licence — separate entries for code and data.
  lic_lines <- character(0)
  if (nzchar(meta$license_code %||% ""))
    lic_lines <- c(lic_lines, paste0("- **Code:** licensed under ", meta$license_code, "."))
  if (nzchar(meta$license_data %||% ""))
    lic_lines <- c(lic_lines, paste0("- **Data:** licensed under ", meta$license_data, "."))
  if (length(lic_lines)) push("## License", lic_lines)

  if (nzchar(meta$additional_info %||% ""))
    push("## Additional information", meta$additional_info)

  # Directory map
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
            esc_cell(col_d$name), esc_cell(col_d$type),
            esc_cell(cd[[col_d$name]] %||% ""),
            esc_cell(if (col_d$type == "numeric") u[[col_d$name]] %||% "" else ""),
            esc_cell(col_d$summary)))
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
  r_ver <- r_version %||% paste0(R.version$major, ".", R.version$minor)
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
