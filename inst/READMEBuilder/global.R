# inst/READMEBuilder/global.R
# Loaded once by Shiny before ui.R and server.R.
# Contains all libraries and internal helper functions.

library(shiny)
library(bslib)
library(dplyr, warn.conflicts = FALSE)   # bind_rows(), tibble()
library(readr)
library(readxl)
library(stringr)
library(purrr)
library(shinyFiles)
library(fs)

# Web mode: the app is running in the browser (Shinylive / webR), so it cannot
# see the user's disk and its R is not the user's R. Folders arrive as a .zip,
# and package / R versions come only from an renv.lock or an imported README.
# READMEBUILDER_WEB=true forces it, to try the web behaviour in desktop R.
is_web <- R.version$os == "emscripten" ||
  tolower(Sys.getenv("READMEBUILDER_WEB")) %in% c("true", "1")
# Shiny's default 5 MB upload limit is too small for a zipped project.
if (is_web) options(shiny.maxRequestSize = 500 * 1024^2)

# ── Logo ──────────────────────────────────────────────────────────────────────

logo_svg <- tags$img(
  src   = "logo.png",
  alt   = "READMEBuilder",
  style = "display:block; height:64px; max-width:100%; margin:0 auto;"
)

# ── Helpers ───────────────────────────────────────────────────────────────────

`%||%` <- function(a, b) if (!is.null(a) && nzchar(trimws(a))) trimws(a) else b
# Like %||% but keeps the text as typed (leading indentation matters in Markdown).
`%or%` <- function(a, b) if (is.null(a)) b else a

# The running R version, or "—" in the browser, where it would be webR's.
current_r_version <- function()
  if (is_web) "—" else paste0(R.version$major, ".", R.version$minor)

# Paths to show the user. In the browser a folder lives in a temp directory,
# so only its name means anything.
show_path <- function(p) if (is_web) basename(p) else p

# ── DOI and badge helpers ─────────────────────────────────────────────────────
# Split the DOI field on ";" or new lines and strip any resolver prefix a user
# pasted (https://doi.org/, http://dx.doi.org/, doi:), so the link is never
# doubled. A ";" only counts as a separator when the next entry looks like a
# DOI, because some older DOIs (Wiley SICI) contain ";" themselves.
normalise_doi <- function(x) {
  d <- str_trim(str_split(x %||% "",
         regex(";\\s*(?=(?:https?://|doi:|10\\.))|\\r?\\n", ignore_case = TRUE))[[1]])
  # Also split "10.1/a, 10.2/b" and "doi:10.1/a doi:10.2/b": a DOI never
  # contains whitespace, so a comma or space before a new DOI separates them.
  d <- unlist(str_split(d, regex("[,\\s]+(?=(?:https?://|doi:|(?:dx\\.|www\\.)?doi\\.org/|10\\.))",
                                 ignore_case = TRUE)))
  d <- str_remove_all(str_trim(d), "^<|>$")
  d <- str_remove(d, regex("^(?:(?:https?://)?(?:www\\.|dx\\.)?doi\\.org/|doi:?\\s*)", ignore_case = TRUE))
  # Keep just the DOI: a note after it ("; see paper", " (preprint)") or
  # brackets/quotes around it would end up inside the link. A DOI has no
  # spaces, so it runs from "10." to the first space.
  tok <- str_extract(d, "10\\.\\d{4,9}/\\S+")
  d   <- ifelse(is.na(tok), ifelse(str_detect(d, "\\s"), "", str_remove(d, "^[\"'(\\[]+")), tok)
  d   <- str_remove(d, "[.,;:'\"\\]\\s]+$")
  # A closing bracket belongs to the DOI only if it opened one too.
  for (k in seq_along(d))
    while (str_detect(d[k], "\\)$") && str_count(d[k], fixed(")")) > str_count(d[k], fixed("(")))
      d[k] <- str_remove(str_remove(d[k], "\\)$"), "[.,;:'\"]+$")
  unique(d[nzchar(d)])
}

# shields.io static badges use "-" as the label/message/colour separator and
# "_" as a space, so literal dashes and underscores must be doubled BEFORE
# percent-encoding. Without this, DOIs like 10.1111/2041-210X.13118 and
# licences like GPL-3.0 or CC BY-NC 4.0 produce broken badges.
badge_esc <- function(x) {
  URLencode(str_replace_all(str_replace_all(x, "-", "--"), "_", "__"), reserved = TRUE, repeated = TRUE)
}

# Parentheses in a DOI (e.g. old SICI DOIs) would end a Markdown link early.
href_esc <- function(x) str_replace_all(x, c("\\(" = "%28", "\\)" = "%29"))

is_script  <- function(f) str_detect(f, "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$")
is_tabular <- function(f) str_detect(f, "\\.(csv|tsv|txt|xlsx|xls)$")

# Files listed under "Data Files". A .txt only counts as data when it was
# actually read as a table; prose .txt files (notes, protocols) are "Other".
is_data_file <- function(files, auto) {
  if (!length(files)) return(logical(0))
  described <- vapply(seq_along(files),
                      function(i) i <= length(auto) && !is.null(auto[[i]]), logical(1))
  is_tabular(files) & (described | !str_detect(files, "\\.txt$"))
}

# "1 file", "2 files".
plural <- function(n, word) paste(n, if (n == 1) word else paste0(word, "s"))

# Strip a bullet the user typed themselves ("- Jane", "* Jane") so it is not
# exported as a nested "- - Jane".
# Zips made by older Windows tools store names in the DOS code page (CP437),
# not UTF-8, so "données.csv" unzips as "donn�es.csv". fix_zip_names() reads
# the original name bytes from the zip's own index and renames what was
# extracted (whether the bytes were kept or replaced by U+FFFD on the way).

# CP437 characters for bytes 0x80-0xFF (built in: the browser's R may not
# have this code page for iconv()).
cp437_high <- strsplit(paste0(
  "ÇüéâäàåçêëèïîìÄÅÉæÆôöòûùÿÖÜ¢£¥₧ƒáíóúñÑªº¿⌐¬½¼¡«»",
  "░▒▓│┤╡╢╖╕╣║╗╝╜╛┐└┴┬├─┼╞╟╚╔╩╦╠═╬╧╨╤╥╙╘╒╓╫╪┘┌█▄▌▐▀",
  "αßΓπΣσµτΦΘΩδ∞φε∩≡±≥≤⌠⌡÷≈°∙·√ⁿ²■ "), "")[[1]]

cp437_decode <- function(bytes) paste(vapply(as.integer(bytes), function(b)
  if (b < 128) rawToChar(as.raw(b)) else cp437_high[b - 127], ""), collapse = "")

# Position of the zip's end-of-central-directory record, or NA if the file is
# not a zip.
zip_eocd <- function(z) {
  n <- length(z)
  if (n < 22) return(NA)
  for (i in seq(n - 21, max(1, n - 65557), by = -1))
    if (z[i] == 0x50 && z[i + 1] == 0x4b && z[i + 2] == 0x05 && z[i + 3] == 0x06) return(i)
  NA
}

# Number of entries in a zip (0 for an empty one), or NA if it is not a zip.
zip_n_entries <- function(zipfile) {
  z <- tryCatch(readBin(zipfile, "raw", file.size(zipfile)), error = function(e) raw(0))
  e <- zip_eocd(z)
  if (is.na(e)) NA_integer_ else as.integer(z[e + 10]) + 256L * as.integer(z[e + 11])
}

# Raw name bytes of each entry whose name is NOT flagged as UTF-8.
zip_cp437_names <- function(zipfile) {
  z <- readBin(zipfile, "raw", file.size(zipfile))
  u16 <- function(i) as.integer(z[i]) + 256L * as.integer(z[i + 1])
  u32 <- function(i) u16(i) + 65536 * u16(i + 2)
  n   <- length(z)
  eocd <- zip_eocd(z)
  if (is.na(eocd)) return(list())
  pos <- u32(eocd + 16) + 1; out <- list()
  for (k in seq_len(u16(eocd + 10))) {
    if (pos + 45 > n || u32(pos) != 0x02014b50) break
    flags <- u16(pos + 8); nl <- u16(pos + 28); el <- u16(pos + 30); cl <- u16(pos + 32)
    name  <- z[pos + 46 + seq_len(nl) - 1]
    # macOS and Info-ZIP write UTF-8 names WITHOUT the UTF-8 flag, so a name
    # counts as CP437 only when its bytes are not valid UTF-8.
    if (bitwAnd(flags, 0x0800) == 0 && any(name >= as.raw(0x80)) && !validUTF8(rawToChar(name)))
      out[[length(out) + 1]] <- name
    pos <- pos + 46 + nl + el + cl
  }
  out
}

fix_zip_names <- function(zipfile, dir) {
  names <- tryCatch(zip_cp437_names(zipfile), error = function(e) list())
  if (!length(names)) return(invisible(dir))
  # Every path component (folders too), as raw bytes, deepest first.
  split_raw <- function(r) { s <- which(r == as.raw(0x2f)); starts <- c(1, s + 1); ends <- c(s - 1, length(r))
    Map(function(a, b) if (b >= a) r[a:b] else raw(0), starts, ends) }
  comps <- list()
  for (nm in names) {
    parts <- Filter(length, split_raw(nm))
    for (d in seq_along(parts)) comps[[length(comps) + 1]] <- parts[seq_len(d)]
  }
  comps <- unique(comps)
  comps <- comps[order(-lengths(comps))]
  as_found <- function(parts) {          # the path as it was extracted
    kept <- vapply(parts, rawToChar, "")
    fffd <- vapply(kept, function(s) iconv(s, "UTF-8", "UTF-8", sub = "�"), "")
    list(kept, fffd)
  }
  for (parts in comps) {
    last <- parts[[length(parts)]]
    if (!any(last >= as.raw(0x80))) next
    for (form in as_found(parts)) {
      from <- do.call(file.path, as.list(c(dir, form)))
      if (file.exists(from)) {
        file.rename(from, do.call(file.path, as.list(c(dir, form[-length(form)], cp437_decode(last)))))
        break
      }
    }
  }
  invisible(dir)
}

# Some Windows tools (e.g. older PowerShell Compress-Archive) store paths with
# backslashes, which unzip as flat files named "proj\data\obs.csv". Moves each
# into the folders its name describes.
fix_zip_slashes <- function(dir) {
  paths <- list.files(dir, recursive = TRUE, all.files = TRUE)
  for (p in paths[str_detect(basename(paths), fixed("\\"))]) {
    to <- file.path(dir, dirname(p), str_replace_all(basename(p), fixed("\\"), "/"))
    dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
    file.rename(file.path(dir, p), to)
  }
  invisible(dir)
}

# Reads a README as text, or NULL if it cannot be. readr::read_file() stops at
# the first NUL byte, so a UTF-16 file (or one with an embedded NUL) would be
# read as a few characters that still pass validUTF8(); reject those instead.
read_text_file <- function(f) {
  raw <- tryCatch(readBin(f, "raw", file.size(f)), error = function(e) NULL)
  if (is.null(raw) || any(raw == as.raw(0))) return(NULL)
  tryCatch(readr::read_file(raw), error = function(e) NULL)
}

# All leading bullets go, so "- - Jane" exports as "- Jane" straight away
# rather than as a nested list that shrinks on each re-import.
strip_bullet <- function(x) str_remove(x, "^\\s*(?:(?:[-*+•]|\\d{1,3}[.)])\\s+)+")

# ── Raw-HTML escaping ──────────────────────────────────────────────────────────
# GitHub treats "<word ...>" as an HTML tag and drops it, so user text such as
# "<Title>" or a factor level "<test>" would vanish from the rendered README.
# Tag-like "<" is written as "\<" (a Markdown backslash escape). Code spans and
# fenced blocks are left alone, as are autolinks (<https://...>, <a@b.org>)
# and the <br> that table cells use for line breaks.
# parse_readme() applies the exact inverse, so text round-trips unchanged.

map_outside_code <- function(lines, f) {
  fm <- fence_mask(lines)
  for (k in seq_along(lines)) {
    l <- lines[k]
    if (fm[k] || !str_detect(l, "<")) next
    loc <- str_locate_all(l, "(`+).*?\\1")[[1]]
    if (!nrow(loc)) { lines[k] <- f(l); next }
    out <- character(0); pos <- 1L
    for (r in seq_len(nrow(loc))) {
      out <- c(out, f(substr(l, pos, loc[r, 1] - 1L)), substr(l, loc[r, 1], loc[r, 2]))
      pos <- loc[r, 2] + 1L
    }
    lines[k] <- paste(c(out, f(substr(l, pos, nchar(l)))), collapse = "")
  }
  lines
}

# Backslashes the user typed right before the "<" are doubled (each shows as
# one backslash) and one more escapes the "<", so the text shows exactly as
# typed and md_unescape_html() can undo it exactly.
md_escape_html <- function(lines) map_outside_code(lines, function(x)
  str_replace_all(x, paste0("(\\\\*)<(?=[A-Za-z/!?])(?!br>)(?!!-- no title -->)",
                            "(?![A-Za-z][A-Za-z0-9+.-]*:[^\\s>]*>)",
                            "(?![^\\s<>@]+@[^\\s<>]+>)"),
                  function(m) paste0(strrep("\\", 2 * (nchar(m) - 1) + 1), "<")))

md_unescape_html <- function(lines) map_outside_code(lines, function(x)
  str_replace_all(x, "(\\\\+)<(?=[A-Za-z/!?])", function(m) {
    n <- nchar(m) - 1
    ifelse(n %% 2 == 1, paste0(strrep("\\", (n - 1) %/% 2), "<"), m)
  }))

# ── Structure escaping ─────────────────────────────────────────────────────────
# parse_readme() finds sections, files and labels by the lines assemble_readme()
# writes: "## Description", "### `file`", "**Location:** ...". The same line
# typed inside a free-text field would be read as structure on re-import (and
# the real section after it lost), so such lines in user text get a leading
# backslash, a Markdown escape that GitHub shows as the plain text. Lines inside
# fenced code blocks are left alone. md_unescape_struct() is the exact inverse.

rb_struct_pat <- function() paste0(
  "^(?:##\\s+(?:", paste(str_replace_all(rb_sections, " ", "\\\\s+"), collapse = "|"), ")\\s*$",
  "|###\\s+`",
  "|\\*\\*(?:Date collected|Location|Sheets|Dimensions|Variables):\\*\\*",
  "|\\*README generated with READMEBuilder)")

# TRUE for fence lines and the lines between them, following CommonMark: an
# opening fence is 3+ backticks or tildes (up to 3 spaces in; a backtick
# fence's info string has no backticks, so "```x```" is inline code), and it
# is closed only by the same character, at least as long, with nothing after.
# An unclosed fence runs to the end (escaped on export, see md_escape_struct).
fence_info <- function(lines) {
  n <- length(lines); mask <- logical(n); open_at <- integer(0)
  ch <- ""; len <- 0L; start <- 0L
  for (k in seq_len(n)) {
    l <- lines[k]
    if (!nzchar(ch)) {
      m <- str_match(l, "^ {0,3}(`{3,}|~{3,})(.*)$")
      if (!is.na(m[1, 1]) && !(str_detect(m[1, 2], "^`") && str_detect(m[1, 3], "`"))) {
        ch <- substr(m[1, 2], 1, 1); len <- nchar(m[1, 2]); start <- k; mask[k] <- TRUE
      }
    } else {
      mask[k] <- TRUE
      m <- str_match(l, "^ {0,3}(`{3,}|~{3,})\\s*$")
      if (!is.na(m[1, 1]) && substr(m[1, 2], 1, 1) == ch && nchar(m[1, 2]) >= len) ch <- ""
    }
  }
  list(mask = mask, unclosed = if (nzchar(ch)) start else NA_integer_)
}
fence_mask <- function(lines) fence_info(lines)$mask

# Label lines ("**Location:** x") are written "\*\*Location:\*\* x", which
# GitHub shows as typed; other structure lines get a leading backslash. Any
# backslashes the user already put at the start are doubled first, so the
# escape is exactly reversible.
rb_label_pat <- "^\\*\\*((?:Date collected|Location|Sheets|Dimensions|Variables):)\\*\\*"

md_escape_struct <- function(x) {
  if (is.null(x) || !nzchar(x)) return(x)
  lines <- str_split(x, "\r?\n")[[1]]
  # An unclosed code fence would turn the rest of the README into code, so
  # its opening line is escaped too. Found on a working copy (repeatedly, in
  # case a later fence is also unclosed); the escape itself is applied below.
  work <- lines; unclosed <- integer(0)
  repeat {
    fi <- fence_info(work)
    if (is.na(fi$unclosed)) break
    unclosed <- c(unclosed, fi$unclosed)
    work[fi$unclosed] <- paste0("\\", work[fi$unclosed])
  }
  fm    <- fence_info(work)$mask
  lead  <- str_extract(lines, "^\\\\*")
  rest  <- str_sub(lines, nchar(lead) + 1)
  # Every line the unescape would touch is escaped: structure lines, unclosed
  # fence openers, and fence lines the user already put backslashes before.
  hit   <- !fm & (str_detect(rest, rb_struct_pat()) |
                  seq_along(lines) %in% unclosed |
                  (nchar(lead) > 0 & str_detect(rest, "^ {0,3}(`{3,}|~{3,})")))
  for (k in which(hit)) {
    dbl <- strrep("\\", 2 * nchar(lead[k]))
    lines[k] <- if (str_detect(rest[k], rb_label_pat))
      paste0(dbl, str_replace(rest[k], rb_label_pat, "\\\\*\\\\*\\1\\\\*\\\\*"))
    else paste0(dbl, "\\", rest[k])
  }
  paste(lines, collapse = "\n")
}

# ── Line breaks ─────────────────────────────────────────────────────────────────
# In Markdown a single line break inside a paragraph is joined up, so text typed
# on separate lines would run together on GitHub. A trailing backslash makes it
# a hard break. Added only where the next line continues the same block (not a
# blank line, list item, heading, table row, quote or fence); md_soft_breaks()
# removes exactly those again.

breaks_at <- function(lines) {
  n <- length(lines)
  if (n < 2) return(logical(n))
  fm   <- fence_mask(lines)
  nxt  <- c(lines[-1], "")
  nxt2 <- c(lines[-(1:2)], "", "")[seq_len(n)]
  # Only what CommonMark lets interrupt a paragraph starts a new block on its
  # own: a bullet, an ordered list starting at 1, a heading, a quote, a fence,
  # or a table (a "|" line followed by a delimiter row).
  starts <- str_detect(nxt, "^\\s*(?:[-*+]\\s|1[.)]\\s|#{1,6}\\s|>|```|~~~)") |
    (str_detect(nxt, "^\\s*\\|") & str_detect(nxt2, "^\\s*\\|?\\s*:?-{3,}"))
  cont <- nzchar(str_trim(lines)) & nzchar(str_trim(nxt)) & !fm & !c(fm[-1], TRUE) &
    !starts & !str_detect(lines, "^\\s*(?:#{1,6}\\s|\\|)")
  cont[n] <- FALSE
  cont
}

md_hard_breaks <- function(x) {
  if (!nzchar(x %||% "")) return(x)
  lines <- str_split(x, "\r?\n")[[1]]
  # Always exactly one added (even after a backslash the user typed), so the
  # inverse can always remove exactly one.
  add   <- breaks_at(lines)
  lines[add] <- paste0(lines[add], "\\")
  paste(lines, collapse = "\n")
}

md_soft_breaks <- function(lines) {
  if (!length(lines)) return(lines)
  drop <- breaks_at(lines) & str_detect(lines, "\\\\$")
  lines[drop] <- str_remove(lines[drop], "\\\\$")
  lines
}

md_unescape_struct <- function(lines) {
  if (!length(lines)) return(lines)
  fm   <- fence_mask(lines)
  lead <- str_extract(lines, "^\\\\*")
  rest <- str_sub(lines, nchar(lead) + 1)
  n    <- nchar(lead)                      # odd for every escaped line
  # An escaped label reads <2u backslashes>\*\*Label:\*\*, so after the run
  # comes "*\*Label:\*\*".
  lab  <- "^\\*\\\\\\*((?:Date collected|Location|Sheets|Dimensions|Variables):)\\\\\\*\\\\\\*"
  for (k in which(!fm & n %% 2 == 1)) {
    if (str_detect(rest[k], lab))
      lines[k] <- paste0(strrep("\\", (n[k] - 1) / 2), str_replace(rest[k], lab, "**\\1**"))
    else if (str_detect(rest[k], rb_struct_pat()) || str_detect(rest[k], "^ {0,3}(`{3,}|~{3,})"))
      lines[k] <- paste0(strrep("\\", (n[k] - 1) / 2), rest[k])
  }
  lines
}

# ── Help walkthrough support ──────────────────────────────────────────
# Remembers whether the user has seen the walkthrough, so it shows once on a
# first run and thereafter only via the Help button. Stored as an empty marker
# file in the user's config directory; if that is not writable the walkthrough
# simply shows each launch rather than erroring.

help_flag_path <- function() {
  dir <- tryCatch(tools::R_user_dir("READMEBuilder", "config"),
                  error = function(e) file.path(tempdir(), "READMEBuilder"))
  file.path(dir, "seen_help")
}

has_seen_help <- function() file.exists(help_flag_path())

mark_help_seen <- function() {
  p <- help_flag_path()
  tryCatch({
    dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
    file.create(p)
  }, error = function(e) invisible(FALSE))
  invisible(TRUE)
}

# ── Demo media ──────────────────────────────────────────────────────
# Optional screencast shown at the top of the help dialog. Drop a file named
# demo.mp4 (or demo.gif / demo.webm) into inst/READMEBuilder/www/ and it is
# picked up automatically; with no such file the dialog just shows the written
# walkthrough. Shiny serves inst/READMEBuilder/www/ at the app root, so the
# file is referenced by name only.

demo_media_tag <- function() {
  www <- file.path("www")
  for (f in c("demo.mp4", "demo.webm")) {
    if (file.exists(file.path(www, f)))
      return(tags$video(src = f, controls = NA, autoplay = NA, muted = NA,
                        loop = NA, playsinline = NA,
                        style = "width:100%; border-radius:8px; margin-bottom:0.5rem;"))
  }
  if (file.exists(file.path(www, "demo.gif")))
    return(tags$img(src = "demo.gif", alt = "READMEBuilder walkthrough",
                    style = "width:100%; border-radius:8px; margin-bottom:0.5rem;"))
  NULL
}

# ── Excluded machinery folders ────────────────────────────────────────────────
# Project folders that hold *installed dependencies* or IDE/VCS state rather
# than the researcher's own data and code. A restored renv/packrat library is a
# full copy of every dependency's source tree — often tens of thousands of files
# — so walking it makes the app appear to hang, misclassifies every package's
# internal .R files as the user's own scripts, and pollutes the detected package
# list with dependencies-of-dependencies.
#
# The WHOLE renv/ and packrat/ directories are excluded, not just their library
# subfolders: renv/activate.R is a generated bootstrap script (not the user's
# code, and its own requireNamespace("renv") call would otherwise add renv to
# the detected dependencies), and renv/settings.json is configuration.
#
# NOTE: renv.lock sits at the PROJECT ROOT, not inside renv/, so it is untouched
# by this filter and is still found and used for package and R versions.

exclude_dirs <- c("renv", "packrat",
                  ".Rproj.user", ".git", ".Rcheck", "node_modules",
                  "__pycache__", ".venv", "venv", ".quarto", "__MACOSX")

# Selectize options for pickers that also accept typed values. createOnBlur
# keeps text the user typed but left without pressing Enter.
# The clear button empties the box (an empty "None" choice cannot be listed).
free_select_opts <- list(create = TRUE, createOnBlur = TRUE, placeholder = "Select or type…",
                         plugins = list("clear_button"))

# Operating-system and Office clutter that is never part of a project:
# Office lock files (~$book.xlsx), Windows thumbnail caches and folder settings.
is_junk <- function(paths)
  str_detect(basename(paths), regex("^~\\$|^(thumbs\\.db|desktop\\.ini|ehthumbs\\.db)$", ignore_case = TRUE))

# TRUE for any relative path sitting inside one of the folders above (at any
# depth), so those files can be dropped from every recursive scan.
is_excluded <- function(paths) {
  if (!length(paths)) return(logical(0))
  pat <- paste0("(^|/)(", paste(str_replace_all(exclude_dirs, fixed("."), "\\."),
                                 collapse = "|"), ")(/|$)")
  str_detect(paths, pat)
}

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

# One-click shortcuts for the most common licences, shown under each licence
# selector. Values must match entries in license_choices exactly.
license_picks_code <- c("MIT" = "MIT", "Apache 2.0" = "Apache 2.0",
                        "GPL-3.0" = "GPL-3.0")
license_picks_data <- c("CC0" = "CC0 1.0 (public domain)", "CC BY 4.0" = "CC BY 4.0")

license_quick_picks <- function(target, picks, hint = NULL) {
  div(class = "rb-lic-picks",
    tags$span(class = "text-muted small me-1", "Common:"),
    lapply(names(picks), function(lbl)
      tags$button(type = "button", class = "btn btn-sm btn-outline-secondary rb-chip",
        onclick = sprintf(
          "Shiny.setInputValue('lic_pick',{id:'%s',val:'%s'},{priority:'event'})",
          target, picks[[lbl]]),
        lbl)),
    if (!is.null(hint)) tags$div(class = "form-text mt-1", hint))
}

# ── MLast (Model Location and Specification table) ───────────────────────────
# Optional, per-project table recording, for each analysis: its outcome and
# predictors (mapped to the actual data column names), and — kept as three
# DISTINCT fields rather than one ambiguous "location" column — where the
# analysis is described (methods), where its output is reported (results),
# and where the code that produced it lives. This resolves an ambiguity in
# the original MLast proposal (Jones et al. 2026, medRxiv
# doi:10.64898/2026.04.07.26350286, Table 5), whose single "Location" column
# does not distinguish a methods citation from a results citation.

mlast_cols <- c("Outcome (paper)", "Outcome (data)", "Predictors (data)",
                "Test", "Methods location", "Results location",
                "Code location", "Notes")

mlast_template <- function() {
  tibble(
    outcome_paper = character(), outcome_data = character(),
    predictors    = character(), test_type    = character(),
    methods_loc   = character(), results_loc  = character(),
    code_loc      = character(), notes        = character()
  )
}

# ── find_code_locations() ─────────────────────────────────────────────────────
# Searches script files (.R/.Rmd/.qmd/.Rnw) under `folder` for a literal,
# case-insensitive substring and returns every matching line as a
# script:line pair with a snippet, so a model's code location can be found
# rather than typed from memory (which drifts as soon as a script is edited).
# Returns a 0-row tibble if `folder`/`pattern` are blank or nothing matches.

find_code_locations <- function(folder, pattern) {
  pattern <- str_trim(pattern %||% "")
  empty   <- tibble(script = character(), line = integer(), snippet = character())
  if (!nzchar(pattern) || is.null(folder) || !nzchar(folder) || !dir.exists(folder))
    return(empty)

  files <- list.files(folder, pattern = "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$",
                       recursive = TRUE, full.names = TRUE, all.files = TRUE)
  # Only search the researcher's own scripts, not installed dependencies.
  rel   <- str_remove(files, fixed(paste0(folder, .Platform$file.sep)))
  keep_ <- !is_excluded(rel)
  files <- files[keep_]; rel <- rel[keep_]
  if (!length(files)) return(empty)

  # Report the path relative to the project root, so two scripts with the same
  # name in different folders (e.g. a/clean.R, b/clean.R) can be told apart.
  hits <- map_dfr(seq_along(files), function(k) {
    ls <- tryCatch(readLines(files[k], warn = FALSE), error = function(e) character(0))
    if (!length(ls)) return(NULL)
    idx <- which(str_detect(ls, fixed(pattern, ignore_case = TRUE)))
    if (!length(idx)) return(NULL)
    tibble(script = rel[k], line = idx, snippet = str_trim(ls[idx]))
  })

  if (is.null(hits) || nrow(hits) == 0) empty else hits
}

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

# Files in the order the directory map lists them (folders first, then files,
# case-insensitively at each level) -- the same order an imported README gives,
# so a loaded folder and its re-imported README number their files alike.
tree_order <- function(files) {
  if (!length(files)) return(files)
  ord <- parse_dir_tree(build_dir_tree(files)[-1])
  c(ord[ord %in% files], setdiff(files, ord))
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

# Windows-1252 (Excel's default "CSV" on Windows) to UTF-8, done here rather
# than with iconv(), which the browser's R may not support. Bytes 0x80-0x9F
# are the cp1252 punctuation; 0xA0-0xFF match Latin-1, i.e. their code points.
cp1252_80 <- c(0x20AC, 0xFFFD, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021,
               0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0xFFFD, 0x017D, 0xFFFD,
               0xFFFD, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014,
               0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0xFFFD, 0x017E, 0x0178)
win1252_to_utf8 <- function(bytes) {
  cp <- as.integer(bytes)
  hi <- cp >= 0x80 & cp <= 0x9F
  cp[hi] <- cp1252_80[cp[hi] - 0x7F]
  intToUtf8(cp)
}

auto_describe <- function(path) {
  ext <- tolower(tools::file_ext(path))
  if (!ext %in% c("csv", "tsv", "txt", "xlsx", "xls")) return(NULL)

  # A text table that is not valid UTF-8 is read from a decoded copy.
  src <- path
  if (ext %in% c("csv", "tsv", "txt")) {
    raw <- tryCatch(readBin(path, "raw", file.size(path)), error = function(e) raw(0))
    if (length(raw) && !any(raw == as.raw(0)) && !validUTF8(rawToChar(raw)))
      src <- I(win1252_to_utf8(raw))
  }
  read_lines5 <- function() if (inherits(src, "AsIs"))
    head(str_split(src, "\r?\n")[[1]], 5L) else readLines(path, n = 5L, warn = FALSE)

  out <- tryCatch({
    # Sniff the delimiter from the header line: semicolon-delimited CSVs
    # (decimal comma, common in Europe) otherwise read as one "x;y" column.
    # A .txt is only treated as a table if it is TAB-delimited, with the same
    # number of tabs on each of its first few lines. Commas and semicolons are
    # not trusted in .txt files: ordinary prose ("dried, weighed, frozen") can
    # have a consistent comma count, and would be summarised as a fake table.
    delim <- if (ext %in% c("csv", "txt")) {
      head5 <- tryCatch(read_lines5(), error = function(e) character(0))
      head5 <- head5[nzchar(str_trim(head5))]
      first <- if (length(head5)) head5[1] else ""
      seps  <- c(tab = "\t", semi = ";", comma = ",")
      n_sep <- vapply(seps, function(p) str_count(first, p), integer(1))
      best  <- if (all(n_sep == 0)) "comma" else names(n_sep)[which.max(n_sep)]
      if (ext == "txt") {
        counts <- str_count(head5, "\t")
        if (length(head5) < 2 || any(counts == 0) || length(unique(counts)) > 1) "none" else "tab"
      } else best
    } else if (ext == "tsv") "tab" else NA_character_
    if (identical(delim, "none")) return(NULL)

    # Workbooks: only the first sheet is summarised, but every sheet name is
    # recorded so the README says what else the file holds.
    sheets <- if (ext %in% c("xlsx", "xls"))
      tryCatch(readxl::excel_sheets(path), error = function(e) character(0))
    else character(0)

    # The first sheet with any data is summarised (an empty cover sheet is
    # skipped).
    read_sheet <- function(s) suppressWarnings(suppressMessages(
      readxl::read_excel(path, sheet = s, .name_repair = "unique")))
    df <- suppressWarnings(suppressMessages(
      if (ext %in% c("xlsx", "xls")) {
        d <- NULL
        for (s in if (length(sheets)) sheets else 1L) {
          d <- tryCatch(read_sheet(s), error = function(e) NULL)
          if (!is.null(d) && ncol(d) > 0) break
        }
        d
      }
      else switch(delim,
        tab   = readr::read_tsv(src,  show_col_types = FALSE, name_repair = "unique"),
        semi  = readr::read_csv2(src, show_col_types = FALSE, name_repair = "unique"),
        comma = readr::read_csv(src,  show_col_types = FALSE, name_repair = "unique"))
    ))

    # A header-only table still has columns to describe.
    if (is.null(df) || ncol(df) == 0) return(NULL)

    nm <- names(df)
    auto_named <- is.na(nm) | !nzchar(nm) | str_detect(nm, "^\\.\\.\\.[0-9]+$")
    if (all(auto_named)) return(NULL)

    col_data <- map(nm, function(col) {
      x    <- df[[col]]
      na_n <- sum(is.na(x))
      if (!nrow(df)) return(list(name = col, type = "categorical", summary = "no data rows"))
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

    list(nrow = nrow(df), ncol = ncol(df), cols = col_data, sheets = sheets)
  },
  error = function(e) NULL)

  out
}

# ── extract_packages() ────────────────────────────────────────────────────────
# Detects R package dependencies from source and resolves their versions.
#
# Detection covers:
#   * library(pkg) / require(pkg) / requireNamespace("pkg")
#   * namespace calls  pkg::fun  and  pkg:::fun
#   * pacman::p_load(a, b, c), p_load(a, b, c) and p_load(char = c("a", "b"))
#
# Only R code is scanned: comments are stripped, and for .Rmd/.qmd/.Rnw only
# the R code chunks are read, so prose mentioning library(x) is ignored.
#
# Version resolution: if an renv.lock is present in the folder, the versions
# (and the R version) recorded there are used in preference to whatever is
# installed in the current session; anything detected but not in the lockfile
# falls back to packageVersion() (in the browser, to "not recorded"). Each
# version's origin is kept in a Source column ("renv.lock", "installed",
# "not installed", "not recorded") so a README never passes
# off a mix of the two as one consistent environment. Reading renv.lock needs
# the 'jsonlite' package; if it is missing, the lockfile step is skipped and
# installed versions are used.
#
# Returns a list: $pkgs (tibble Package/Version/Source), $n_files, $n_total,
# $folder, $filenames, $lock_file, $lock_r_version, $n_from_lock.

# The R code in a script: the whole file for .R, only the code chunks for
# .Rmd/.qmd (```{r ...} ... ```) and .Rnw (<<...>>= ... @).
r_code_lines <- function(lines, path) {
  ext <- tolower(tools::file_ext(path))
  if (!length(lines) || ext == "r") return(lines)
  if (ext == "rnw") {
    start <- "^\\s*<<.*>>=\\s*$"; end <- "^\\s*@"
  } else {
    start <- "^\\s*(`{3,}|~{3,})\\s*\\{\\s*[rR](\\s|,|\\})"; end <- "^\\s*(`{3,}|~{3,})\\s*$"
  }
  keep_ <- logical(length(lines)); inside <- FALSE
  for (k in seq_along(lines)) {
    if (!inside && str_detect(lines[k], start)) { inside <- TRUE; next }
    if (inside && str_detect(lines[k], end))    { inside <- FALSE; next }
    keep_[k] <- inside
  }
  lines[keep_]
}

# Remove # comments, leaving any "#" inside a string or backtick name alone.
strip_r_comments <- function(lines) {
  if (!length(lines)) return(lines)
  str_replace_all(lines,
    "\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'|`[^`]*`|#.*$",
    function(m) ifelse(str_detect(m, "^#"), "", m))
}

extract_packages <- function(folder) {
  folder    <- normalizePath(folder, mustWork = FALSE)
  r_files   <- list.files(folder, pattern = "\\.(R|r|Rmd|rmd|Rnw|rnw|qmd)$",
                           recursive = TRUE, full.names = TRUE, all.files = TRUE)
  all_files <- list.files(folder, recursive = TRUE, full.names = FALSE)

  # Drop anything inside an installed package library / IDE state folder: those
  # are dependencies, not this project's code. Compared on the path RELATIVE to
  # the project root so a user whose project happens to live under e.g.
  # ~/.git-backups/ is not wrongly filtered.
  rel_r    <- str_remove(r_files, fixed(paste0(folder, .Platform$file.sep)))
  r_files  <- r_files[!is_excluded(rel_r)]
  all_files <- all_files[!is_excluded(all_files)]

  # ---- collect package names from source ----
  pkgs <- character(0)
  for (f in r_files) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character(0))
    lines <- strip_r_comments(r_code_lines(lines, f))   # code chunks only, no comments
    if (!length(lines)) next
    text  <- paste(lines, collapse = "\n")

    # Matches that START inside a string literal are prose, not calls, e.g.
    # message("may require (approx.) 2 GB"). Rows of str_locate_all() and
    # str_match_all() for the same pattern line up, so filter by start position.
    str_spans <- str_locate_all(text, "\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'")[[1]]
    in_code <- function(pattern) {
      starts <- str_locate_all(text, pattern)[[1]][, 1]
      !vapply(starts, function(p) any(str_spans[, 1] < p & p <= str_spans[, 2]), logical(1))
    }

    # library(pkg) / require(pkg) / requireNamespace("pkg")
    # Lookbehind so substrings like groundhog.library( or bookshelf( don't match.
    # An UNQUOTED name is a variable, not a package, when the call has
    # character.only = TRUE (library(p, character.only = TRUE)) or is
    # requireNamespace(), which always takes a string.
    p1 <- paste0(
      "(?<![A-Za-z0-9._])(library|require|requireNamespace)\\s*\\(\\s*",
      "([\"']?)([A-Za-z][A-Za-z0-9._]*)\\2([^)]*)\\)")
    m1 <- str_match_all(text, p1)[[1]]
    m1 <- m1[in_code(p1), , drop = FALSE]
    if (nrow(m1) > 0) {
      is_var <- !nzchar(m1[, 3]) &
        (m1[, 2] == "requireNamespace" | str_detect(m1[, 5], "character\\.only"))
      pkgs <- c(pkgs, m1[!is_var, 4])
    }

    # namespace calls: pkg::fun and pkg:::fun. Also catches the loader packages
    # themselves when namespaced (pacman, librarian, import, groundhog).
    # Searched with string literals blanked, so "see dplyr::filter" inside a
    # message() is not counted.
    no_str <- str_replace_all(text, "\"(?:[^\"\\\\]|\\\\.)*\"|'(?:[^'\\\\]|\\\\.)*'", "\"\"")
    m2 <- str_match_all(no_str, "(?<![A-Za-z0-9._])([A-Za-z][A-Za-z0-9.]*):::?")[[1]]
    if (nrow(m2) > 0) pkgs <- c(pkgs, m2[, 2])

    # Flat comma-lists: pacman::p_load(...) and librarian::shelf(...)
    pf <- paste0(
      "(?<![A-Za-z0-9._])(?:pacman::)?p_load\\s*\\(([^)]*)\\)",
      "|(?<![A-Za-z0-9._])(?:librarian::)?shelf\\s*\\(([^)]*)\\)")
    fl <- str_match_all(text, pf)[[1]]
    fl <- fl[in_code(pf), , drop = FALSE]
    if (nrow(fl) > 0) {
      arg_lists <- c(fl[, 2], fl[, 3])
      arg_lists <- arg_lists[!is.na(arg_lists) & nzchar(arg_lists)]
      for (args in arg_lists) {
        # p_load(char = c("a", "b")) / p_load(char = "a"): take the quoted names.
        if (str_detect(args, "(^|,)\\s*char\\s*=")) {
          q <- str_match_all(args, "[\"']([A-Za-z][A-Za-z0-9._]*)[\"']")[[1]]
          if (nrow(q) > 0) pkgs <- c(pkgs, q[, 2])
          next
        }
        toks <- str_trim(str_replace_all(str_split(args, ",")[[1]], "[\"']", ""))
        toks <- toks[!str_detect(toks, "=")]                       # drop named args
        toks <- str_remove(str_remove(toks, "^[^/]+/"), "@.*$")     # GitHub "owner/repo@ref" -> repo
        toks <- toks[str_detect(toks, "^[A-Za-z][A-Za-z0-9._]*$")] # keep identifiers
        if (length(toks)) pkgs <- c(pkgs, toks)
      }
    }

    # import::from(pkg, ...) / import::here(pkg, ...) -> first argument is the pkg
    im <- str_match_all(text,
      "import::(?:from|here)\\s*\\(\\s*[\"']?([A-Za-z][A-Za-z0-9._]*)[\"']?")[[1]]
    if (nrow(im) > 0) pkgs <- c(pkgs, im[, 2])

    # groundhog.library("pkg", date) / groundhog.library(c("a","b"), date)
    gh <- str_match_all(text,
      "(?:groundhog::)?groundhog\\.library\\s*\\(\\s*(c\\s*\\([^)]*\\)|\"[^\"]*\"|'[^']*')")[[1]]
    if (nrow(gh) > 0) {
      for (arg in gh[, 2]) {
        arg  <- str_remove(arg, "^\\s*c\\s*\\(")
        toks <- str_match_all(arg, "[\"']([A-Za-z][A-Za-z0-9._]*)[\"']")[[1]]
        if (nrow(toks) > 0) pkgs <- c(pkgs, toks[, 2])
      }
    }
  }
  # Case-insensitive order, so the browser (C locale: capitals first) and
  # desktop R list packages the same way.
  pkgs <- unique(pkgs[!is.na(pkgs) & nzchar(pkgs)])
  pkgs <- pkgs[order(tolower(pkgs), pkgs, method = "radix")]

  # Drop base-priority packages (base, stats, utils, methods, ...) which ship
  # with R and are picked up by the new pkg:: scan; keep recommended packages.
  if (length(pkgs)) {
    is_base <- vapply(pkgs, function(p)
      identical(unname(tryCatch(
        suppressWarnings(utils::packageDescription(p, fields = "Priority")),
        error = function(e) NA_character_)), "base"),
      logical(1))
    pkgs <- pkgs[!is_base]
  }

  # ---- renv.lock (authoritative versions if present) ----
  lock_file <- {
    top <- file.path(folder, "renv.lock")
    if (file.exists(top)) top
    else {
      hits <- list.files(folder, pattern = "^renv\\.lock$",
                         recursive = TRUE, full.names = TRUE)
      hits <- hits[!is_excluded(str_remove(hits, fixed(paste0(folder, .Platform$file.sep))))]
      if (length(hits)) hits[1] else NA_character_
    }
  }
  # Other lockfiles in subfolders are not used; the diagnostics say so.
  n_locks <- length(list.files(folder, pattern = "^renv\\.lock$", recursive = TRUE))
  lock_versions  <- character(0)
  lock_r_version <- NA_character_
  lock_ok        <- NA          # NA: no lockfile; FALSE: present but unreadable
  lock_reason    <- ""
  if (!is.na(lock_file) && requireNamespace("jsonlite", quietly = TRUE)) {
    lock <- tryCatch(jsonlite::fromJSON(lock_file, simplifyVector = FALSE),
                     error = function(e) NULL)
    lock_ok <- is.list(lock) && !is.null(names(lock))
    lock_reason <- if (lock_ok) "" else if (isTRUE(file.size(lock_file) == 0)) "is empty"
      else if (is.null(lock)) "is not valid JSON" else "is not an renv lockfile (no top-level object)"
    # A field that is a single value, else NA (tolerates odd JSON shapes).
    fld <- function(x, k) {
      v <- if (is.list(x)) x[[k]] else NULL
      if (length(v) == 1 && !is.list(v)) as.character(v) else NA_character_
    }
    if (lock_ok) {
      lock_r_version <- fld(lock$R, "Version")
      pk <- if (is.list(lock$Packages)) lock$Packages else list()
      if (length(pk)) {
        vers <- vapply(pk, fld, character(1), k = "Version")
        nms  <- vapply(pk, fld, character(1), k = "Package")
        keep <- !is.na(nms) & nzchar(nms)
        lock_versions <- stats::setNames(vers[keep], nms[keep])
      }
    }
  }

  # ---- resolve a version for each detected package ----
  # Returns c(version, source) so the README can say where each version came from.
  resolve <- function(p) {
    if (p %in% names(lock_versions) && !is.na(lock_versions[[p]]))
      return(c(lock_versions[[p]], "renv.lock"))
    # In the browser the installed packages are webR's, not the user's.
    if (is_web) return(c("—", "not recorded"))
    tryCatch(c(as.character(packageVersion(p)), "installed"),
             error = function(e) c("—", "not installed"))
  }
  res         <- if (length(pkgs)) vapply(pkgs, resolve, character(2)) else matrix(character(0), 2, 0)
  n_from_lock <- sum(res[2, ] == "renv.lock")

  # Paths relative to the project, so same-named scripts in different folders
  # (and a lockfile in a subfolder) can be told apart.
  rel <- function(p) str_remove(p, fixed(paste0(folder, .Platform$file.sep)))
  list(
    pkgs = if (!length(pkgs)) tibble(Package = character(), Version = character(), Source = character())
           else tibble(Package = pkgs, Version = unname(res[1, ]), Source = unname(res[2, ])),
    n_files = length(r_files), n_total = length(all_files),
    folder = folder, filenames = rel(r_files),
    lock_file = lock_file, lock_rel = if (is.na(lock_file)) NA_character_ else rel(lock_file),
    lock_ok = lock_ok, lock_reason = lock_reason, n_locks = n_locks, lock_r_version = lock_r_version, n_from_lock = n_from_lock
  )
}

# ── parse_readme() ────────────────────────────────────────────────────────────
# Reverse of assemble_readme(). Given the text of a README produced by
# READMEBuilder, returns a list with both the project-info `meta` AND the
# structural content (files, column metadata, script order, packages, R version)
# so a previous README can be fully re-loaded WITHOUT the original data folder.
#
# Round-trip rules (so export -> import -> export loses nothing):
#   * Only the level-2 headings assemble_readme() writes (rb_sections) split the
#     file into sections; a "## ..." or "---" line typed inside a free-text
#     field stays part of that field. Only the generated footer is dropped.
#   * A data file's description runs until one of the generated labels
#     (**Date collected:**, **Location:**, **Sheets:**, **Dimensions:**,
#     **Variables:**), so a description may itself start with bold text.
#   * Script descriptions keep their line breaks.
#   * The "\<" escapes added by assemble_readme() are undone first.
#
# Tolerances baked in (so older / hand-tweaked READMEs still import):
#   * Funders section may be "## Funding" or "## Funders".
#   * Licence lines may be "- **Code:** licensed under X." or
#     "This code is licensed under X" (period optional), or a single
#     "This work is licensed under X" (-> code slot).
#   * Variable-table cells may contain unescaped "|" (older output): extra
#     cells are folded back into the trailing Summary column.
#   * Package tables with or without the Source column.
#   * Avoids `%||%` on multi-element vectors (it uses `&&`, which errors on
#     length-> 1 logicals in R >= 4.3).

# Level-2 headings written by assemble_readme() (plus older aliases).
rb_sections <- c("Description", "Abstract", "Instructions", "Authors",
                 "Affiliations", "Contact", "Funding", "Funders",
                 "Acknowledgements", "Citation", "License", "Licence",
                 "Additional information", "Directory Structure",
                 "Directory map", "Directory Map", "Data Files", "Other Files",
                 "Models", "Code", "R Environment", "R environment")

rb_footer      <- "^\\*README generated with READMEBuilder"
rb_file_labels <- "^\\*\\*(Date collected|Location|Sheets|Dimensions|Variables):\\*\\*"

# TRUE if `text` looks like a README this app wrote: it has the footer, or a
# "# " title plus at least two headings only this app writes (common ones such
# as Description or Authors appear in any README, so they do not count).
rb_own_sections <- c("Directory Structure", "Directory map", "Directory Map",
                     "Data Files", "Other Files", "Models", "R Environment", "R environment")

is_readmebuilder <- function(text) {
  lines <- str_split(text %||% "", "\r?\n")[[1]]
  if (any(str_detect(lines, rb_footer))) return(TRUE)
  heads <- str_trim(str_remove(lines[str_detect(lines, "^##\\s")], "^##\\s+"))
  any(str_detect(lines, "^#\\s+\\S")) && sum(unique(heads) %in% rb_own_sections) >= 2
}

# The README.md (any capitalisation, or .markdown) at the TOP of `folder`, or
# NA if there is none. Subfolders are not searched: a README there describes
# something else (a vendored package, a data subfolder).
find_readme <- function(folder) {
  if (is.null(folder) || !dir.exists(folder)) return(NA_character_)
  hits <- list.files(folder, pattern = "^readme\\.(md|markdown)$",
                     ignore.case = TRUE, full.names = TRUE)
  hits <- hits[utils::file_test("-f", hits)]           # files only, not folders
  if (length(hits)) sort(hits)[1] else NA_character_
}

parse_readme <- function(text) {
  lines <- md_unescape_html(str_split(text, "\r?\n")[[1]])

  # Drop the generated footer ("---" then "*README generated ...*") so it never
  # leaks into the last section. A "---" typed by the user is kept.
  ft <- which(str_detect(lines, rb_footer))
  if (length(ft)) {
    ft  <- ft[length(ft)]
    cut <- ft
    hr  <- which(str_detect(lines[seq_len(ft - 1)], "^---\\s*$"))
    if (length(hr)) {
      h <- hr[length(hr)]
      gap <- if (ft - h > 1) lines[(h + 1):(ft - 1)] else character(0)
      if (!any(nzchar(str_trim(gap)))) cut <- h
    }
    lines <- head(lines, cut - 1)
  }

  h1    <- which(str_detect(lines, "^#\\s+"))
  title <- if (length(h1)) str_trim(str_remove(lines[h1[1]], "^#\\s+")) else ""
  if (identical(title, "Untitled Project <!-- no title -->")) title <- ""   # assemble_readme()'s placeholder

  sec_pat <- paste0("^##\\s+(",
                    paste(str_replace_all(rb_sections, " ", "\\\\s+"), collapse = "|"),
                    ")\\s*$")
  # A "## Models" line inside a user's code block is code, not a section.
  h2 <- which(str_detect(lines, sec_pat) & !fence_mask(lines))

  # DOIs come from the badge line(s) only -- everything above the first
  # section heading. Scanning the whole file would also pick up DOIs quoted in
  # the citation, additional information or model notes, and each
  # import/export cycle would then add them as extra badges.
  header <- if (!length(h2)) lines else head(lines, h2[1] - 1)
  m   <- str_match_all(paste(header, collapse = "\n"),
                       "\\]\\(https?://(?:dx\\.)?doi\\.org/([^)\\s]+)\\)")[[1]]
  doi <- if (nrow(m) > 0) {
    d <- normalise_doi(paste(str_replace_all(m[, 2], c("%28" = "(", "%29" = ")")), collapse = ";"))   # undo href_esc() only
    paste(d, collapse = "; ")
  } else ""

  # Map each known level-2 heading to its body lines.
  sec <- list()
  if (length(h2)) {
    for (j in seq_along(h2)) {
      start <- h2[j]
      end   <- if (j < length(h2)) h2[j + 1] - 1 else length(lines)
      nm    <- str_squish(str_remove(lines[start], "^##\\s+"))
      body  <- if (end > start) lines[(start + 1):end] else character(0)
      if (is.null(sec[[nm]])) sec[[nm]] <- body
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
  as_para <- function(...) paste(md_unescape_struct(md_soft_breaks(trim_blanks(sec_body(...)))), collapse = "\n")
  as_bullets <- function(...) {
    b <- sec_body(...)
    b <- b[str_detect(b, "^\\s*-\\s+")]
    paste(str_trim(str_remove(b, "^\\s*-\\s+")), collapse = "\n")
  }

  contact <- {
    b <- trim_blanks(sec_body("Contact"))
    # Remove only the envelope assemble_readme() adds, so a contact starting
    # with "<", "+44" or a quote keeps it.
    if (length(b)) str_trim(str_remove(b[1], "^\\s*\U0001F4E7\\s*")) else ""
  }
  citation_text <- {
    q <- sec_body("Citation")
    q <- q[str_detect(q, "^\\s*>")]
    if (length(q)) str_trim(paste(md_soft_breaks(str_remove(q, "^\\s*>\\s?")), collapse = "\n")) else ""
  }

  lic <- function(word) {
    # The badge holds the exact name (the sentence may drop a final full stop).
    bm <- str_match(paste(header, collapse = " "), paste0(
      "!\\[", str_to_title(word), " License\\]\\(https://img\\.shields\\.io/badge/",
      word, "%20license-(.+?)-(?:green|blue)\\)"))
    if (!is.na(bm[1, 2])) {
      v <- tryCatch(URLdecode(bm[1, 2]), error = function(e) NA_character_)
      if (!is.na(v)) Encoding(v) <- "UTF-8"
      if (!is.na(v) && validUTF8(v)) return(str_replace_all(str_replace_all(v, "--", "-"), "__", "_"))
    }
    b   <- sec_body("License", "Licence")
    # Generated label first: "- **Code:** licensed under X." or
    # "- **Code:** All rights reserved."
    gl <- str_match(b, regex(paste0("^\\s*-\\s*\\*\\*", word,
                                    ":\\*\\*\\s*(?:licensed under\\s*)?(.+?)\\.?\\s*$"),
                             ignore_case = TRUE))
    gl <- gl[!is.na(gl[, 2]), 2]
    if (length(gl)) return(str_trim(gl[1]))
    # Free-text fallback for older READMEs only: if this README has the
    # generated badges or labels at all, the other slot's text is not ours.
    if (str_detect(paste(header, collapse = " "), "img\\.shields\\.io/badge/(?:code|data)%20license-") ||
        any(str_detect(b, regex("^\\s*-\\s*\\*\\*(?:Code|Data):\\*\\*", ignore_case = TRUE))))
      return("")
    # The word must come BEFORE "licensed under" ("**Code:** licensed under",
    # "This code is licensed under"), so a licence NAME containing it, such as
    # "Open Data Commons", is not taken as the other slot.
    hit <- b[str_detect(b, regex(paste0("\\b", word, "\\b.*licensed under"), ignore_case = TRUE))]
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
    authors = str_replace_all(as_bullets("Authors"),
                              "\\[([0-9X-]+)\\]\\(https://orcid\\.org/\\1\\)", "\\1"),
    affiliation = as_bullets("Affiliations"),
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
    parts <- str_replace_all(str_trim(parts), fixed("\\|"), "|")
    parts <- str_replace_all(parts, fixed("<br>"), "\n")
    # Reverse esc_cell(): "&amp;" last, so "&amp;lt;br&amp;gt;" -> "&lt;br&gt;".
    parts <- str_replace_all(parts, fixed("&lt;br&gt;"), "<br>")
    parts <- str_replace_all(parts, fixed("&#92;"), "\\")
    str_replace_all(parts, fixed("&amp;"), "&")
  }
  split_h3 <- function(body) {
    idx <- which(str_detect(body, "^###\\s+`") & !fence_mask(body))
    if (!length(idx)) return(list())
    out <- list()
    for (k in seq_along(idx)) {
      s <- idx[k]; e <- if (k < length(idx)) idx[k + 1] - 1 else length(body)
      path <- str_match(body[s], "^###\\s+(`+) ?(.+?) ?\\1\\s*$")[1, 3]   # "`a`" or "`` a`b ``"
      out[[length(out) + 1]] <- list(path = path,
        lines = if (e > s) body[(s + 1):e] else character(0))
    }
    out
  }

  file_desc <- list(); col_desc <- list(); units <- list()
  dates <- list(); locs <- list(); auto_by_path <- list()

  for (it in split_h3(sec_body("Data Files"))) {
    p <- it$path; bl <- it$lines

    # Description = everything before the first generated label.
    lab  <- which(str_detect(bl, rb_file_labels) & !fence_mask(bl))   # not a label quoted in code
    desc <- trim_blanks(if (length(lab)) bl[seq_len(lab[1] - 1)] else bl)
    if (length(desc)) file_desc[[p]] <- paste(md_unescape_struct(md_soft_breaks(desc)), collapse = "\n")
    info <- if (length(lab)) bl[lab[1]:length(bl)] else character(0)

    dline <- info[str_detect(info, "^\\*\\*Date collected:\\*\\*")]
    if (length(dline)) {
      d1 <- str_match(dline[1],
        "^\\*\\*Date collected:\\*\\*\\s*(.+?)(?:\\s*\\|\\s*\\*\\*Location:\\*\\*\\s*(.+))?$")
      if (!is.na(d1[1, 2])) dates[[p]] <- str_trim(d1[1, 2])
      if (!is.na(d1[1, 3])) locs[[p]]  <- str_trim(d1[1, 3])
    }
    lline <- info[str_detect(info, "^\\*\\*Location:\\*\\*")]
    if (length(lline) && is.null(locs[[p]])) {
      l1 <- str_match(lline[1], "^\\*\\*Location:\\*\\*\\s*(.+)$")
      if (!is.na(l1[1, 2])) locs[[p]] <- str_trim(l1[1, 2])
    }

    sline  <- info[str_detect(info, "^\\*\\*Sheets:\\*\\*")]
    sheets <- if (length(sline)) str_match_all(sline[1], "`([^`]+)`")[[1]][, 2] else character(0)

    dim <- str_match(paste(info, collapse = "\n"),
      "\\*\\*Dimensions:\\*\\*\\s*([0-9]+)\\s*rows?\\s*[×x]\\s*([0-9]+)\\s*columns?")
    nrw <- if (!is.na(dim[1, 2])) as.integer(dim[1, 2]) else NA_integer_
    ncl <- if (!is.na(dim[1, 3])) as.integer(dim[1, 3]) else NA_integer_

    # Variable rows: table lines after **Variables:** only, so a table the
    # user put in the description is never read as column metadata.
    vl   <- which(str_detect(info, "^\\*\\*Variables:\\*\\*"))
    rows <- if (length(vl) && vl[1] < length(info)) info[(vl[1] + 1):length(info)] else character(0)
    rows <- rows[str_detect(rows, "^\\s*\\|")]
    rows <- rows[!str_detect(rows, "^\\s*\\|\\s*:?-{2,}")]
    rows <- rows[!str_detect(rows, "Column\\s*\\|\\s*Type")]
    cols <- list(); cd <- list(); un <- list()
    for (r in rows) {
      cells <- split_row(r)
      if (length(cells) < 5) next
      # Strip only the code-span delimiters ("`x`", or "`` a`b ``" for a name
      # holding a backtick), so the name matches the folder's column again.
      cs   <- str_match(cells[1], "^(`+) ?(.*?) ?\\1$")
      nmc  <- if (!is.na(cs[1, 3])) cs[1, 3] else cells[1]
      typ  <- cells[2]; dsc <- cells[3]; unt <- cells[4]
      summ <- paste(cells[5:length(cells)], collapse = " | ")
      cols[[length(cols) + 1]] <- list(name = nmc, type = typ, summary = summ)
      if (nzchar(dsc)) cd[[nmc]] <- dsc
      if (nzchar(unt)) un[[nmc]] <- unt
    }
    if (length(cols))
      auto_by_path[[p]] <- list(nrow = nrw, ncol = ncl, cols = cols, sheets = sheets)
    if (length(cd)) col_desc[[p]] <- cd
    if (length(un)) units[[p]] <- un
  }

  for (it in split_h3(sec_body("Other Files"))) {
    bl <- trim_blanks(it$lines)
    if (length(bl)) file_desc[[it$path]] <- paste(md_unescape_struct(md_soft_breaks(bl)), collapse = "\n")
  }

  # ── Models (MLast) ───────────────────────────────────────────────────────────
  models_body <- sec_body("Models")
  model_rows  <- models_body[str_detect(models_body, "^\\s*\\|")]
  model_rows  <- model_rows[!str_detect(model_rows, "^\\s*\\|(\\s*:?-{2,}:?\\s*\\|)+\\s*$")]   # the separator row only
  # Drop the generated header row only, so a model whose own text mentions
  # "Outcome (paper)" is kept.
  model_rows  <- model_rows[str_squish(model_rows) !=
                              str_squish(paste0("| ", paste(mlast_cols, collapse = " | "), " |"))]
  models <- mlast_template()
  for (r in model_rows) {
    cells <- split_row(r)
    if (length(cells) < 8) next
    models <- bind_rows(models, tibble(
      outcome_paper = cells[1], outcome_data = cells[2], predictors = cells[3],
      test_type = cells[4], methods_loc = cells[5], results_loc = cells[6],
      code_loc = cells[7], notes = cells[8]
    ))
  }

  # ── Code / scripts (run order + descriptions) ───────────────────────────────
  # Items are "1. **`path`**" at the start of a line; the description lines
  # under each are indented by three spaces, which are removed again here.
  script_paths <- character(0); script_lines <- list(); cur <- NULL
  for (l in sec_body("Code")) {
    mm <- str_match(l, "^\\d+\\.\\s+\\*\\*(`+) ?(.+?) ?\\1\\*\\*\\s*$")[, -2, drop = FALSE]
    if (!is.na(mm[1, 2])) {
      cur <- mm[1, 2]; script_paths <- c(script_paths, cur)
      script_lines[[cur]] <- ""
    } else if (!is.null(cur)) {
      script_lines[[cur]] <- c(script_lines[[cur]], l)
    }
  }
  script_desc <- list()
  for (sp in names(script_lines)) {
    d <- trim_blanks(str_remove(script_lines[[sp]], "^   "))
    if (length(d)) script_desc[[sp]] <- paste(md_unescape_struct(md_soft_breaks(d)), collapse = "\n")
  }

  # ── R environment (version + package table) ─────────────────────────────────
  renv <- sec_body("R Environment", "R environment")
  rvm  <- str_match(paste(renv, collapse = "\n"),
                    "\\*\\*R version:\\*\\*\\s*([0-9.]+)(?:\\s*\\(from ([^)\n]+)\\))?")
  r_version     <- if (!is.na(rvm[1, 2])) rvm[1, 2] else ""
  r_version_src <- if (!is.na(rvm[1, 3])) str_trim(rvm[1, 3]) else ""
  pk_pkg <- character(0); pk_ver <- character(0); pk_src <- character(0)
  for (l in renv) {
    mm <- str_match(l, "^\\|\\s*`(.+?)`\\s*\\|\\s*(.+?)\\s*\\|(?:\\s*(.*?)\\s*\\|)?\\s*$")
    if (!is.na(mm[1, 2])) {
      pk_pkg <- c(pk_pkg, mm[1, 2]); pk_ver <- c(pk_ver, str_trim(mm[1, 3]))
      pk_src <- c(pk_src, if (is.na(mm[1, 4])) "" else mm[1, 4])
    }
  }
  pkgs <- tibble(Package = pk_pkg, Version = pk_ver, Source = pk_src)

  auto <- map(files, function(p) if (!is.null(auto_by_path[[p]])) auto_by_path[[p]] else NULL)
  script_order <- match(script_paths, files)
  script_order <- script_order[!is.na(script_order)]

  list(
    meta = meta, root_name = root_name, files = files, auto = auto,
    script_order = script_order, script_desc = script_desc,
    pkgs = pkgs, r_version = r_version, r_version_src = r_version_src,
    file_desc = file_desc, col_desc = col_desc, units = units,
    dates = dates, locs = locs, models = models
  )
}

# ── assemble_readme() ─────────────────────────────────────────────────────────
# Builds the final README.md string from all collected inputs.

assemble_readme <- function(meta, files, descriptions, auto, pkgs,
                            script_order, script_descs, units_list,
                            col_descs, file_extras, root = "project",
                            r_version = NULL, models = NULL,
                            r_version_src = NULL) {
  md   <- character(0)
  push <- function(...) md <<- c(md, c(...), "")

  # Escape a markdown table cell: write line breaks as <br> (GitHub renders
  # them inside tables; parse_readme() turns them back into newlines) and
  # escape "|" so a value containing pipes (every auto-summary does) cannot
  # break the table layout.
  # Outside code, "&" is written "&amp;" so that a literal "<br>" ("&lt;br&gt;"),
  # entity text the user typed, and a backslash at a line end ("&#92;", else it
  # would escape the "<br>") all come back exactly; split_row() reverses it.
  # Inside a code span (column names) GitHub shows entities literally, so
  # only "|" and line breaks are touched there.
  esc_cell <- function(x, code = FALSE) {
    x <- x %||% ""
    if (!code) {
      x <- str_replace_all(x, fixed("&"), "&amp;")
      x <- str_replace_all(x, fixed("<br>"), "&lt;br&gt;")
      x <- str_replace_all(x, "\\\\(?=\r?\n|$)", "&#92;")
    }
    x <- str_replace_all(x, "\r?\n", "<br>")
    str_replace_all(x, fixed("|"), "\\|")
  }
  # A column name as inline code; a name holding a backtick needs a longer
  # delimiter ("`` a`b ``") or the code span breaks.
  code_name <- function(x) if (str_detect(x, "`")) paste0("`` ", x, " ``") else paste0("`", x, "`")

  # One bullet per non-empty line; a bullet the user typed is not doubled.
  bullets <- function(x)
    paste0("- ", keep(strip_bullet(str_trim(str_split(x, "\r?\n")[[1]])), nzchar))
  # Bare ORCID iDs become links (parse_readme() turns them back into the iD).
  orcid_links <- function(x) str_replace_all(x,
    "(?<![\\w/\\[-])(\\d{4}-\\d{4}-\\d{4}-\\d{3}[\\dX])(?![\\w\\]-])", "[\\1](https://orcid.org/\\1)")

  # Free-text fields, with structure-like lines escaped (see md_escape_struct).
  # Then single line breaks become hard breaks (see md_hard_breaks).
  for (f in c("description", "abstract", "instructions", "additional_info", "acknowledgements"))
    meta[[f]] <- md_hard_breaks(md_escape_struct(meta[[f]] %or% ""))
  meta$citation_text <- md_hard_breaks(meta$citation_text %||% "")
  descriptions  <- map(descriptions,  ~ md_hard_breaks(md_escape_struct(.x %or% "")))
  script_descs  <- map(script_descs,  ~ md_hard_breaks(md_escape_struct(.x %or% "")))

  # With no title, a placeholder marked by a hidden comment, so the importer
  # can tell it from a project really called "Untitled Project".
  push(paste0("# ", meta$title %||% "Untitled Project <!-- no title -->"))

  badges <- character(0)
  dois   <- normalise_doi(meta$doi)
  for (d in dois)
    badges <- c(badges, sprintf(
      "[![DOI](https://img.shields.io/badge/DOI-%s-blue)](https://doi.org/%s)",
      badge_esc(d), href_esc(d)))
  if (nzchar(meta$license_code %||% ""))
    badges <- c(badges, sprintf(
      "![Code License](https://img.shields.io/badge/code%%20license-%s-green)",
      badge_esc(meta$license_code)))
  if (nzchar(meta$license_data %||% ""))
    badges <- c(badges, sprintf(
      "![Data License](https://img.shields.io/badge/data%%20license-%s-blue)",
      badge_esc(meta$license_data)))
  if (length(badges)) push(paste(badges, collapse = " "))

  if (nzchar(meta$description  %||% "")) push("## Description",  meta$description)
  if (nzchar(meta$abstract     %||% "")) push("## Abstract",     meta$abstract)
  if (nzchar(meta$instructions %||% "")) push("## Instructions", meta$instructions)

  if (nzchar(meta$authors %||% ""))     push("## Authors",      orcid_links(bullets(meta$authors)))
  if (nzchar(meta$affiliation %||% "")) push("## Affiliations", bullets(meta$affiliation))
  if (nzchar(meta$contact %||% ""))
    push("## Contact", paste0("\U0001F4E7 ", str_trim(meta$contact)))

  if (nzchar(meta$funders %||% ""))     push("## Funding",      bullets(meta$funders))
  if (nzchar(meta$acknowledgements %||% ""))
    push("## Acknowledgements", meta$acknowledgements)

  # Shown if there is a DOI OR citation text (previously citation text was
  # silently dropped when no DOI was given). Every line of a multi-line
  # citation is quoted so the importer can read all of it back.
  cit <- meta$citation_text %||% ""
  if (length(dois) > 0 || nzchar(cit)) {
    push("## Citation",
         if (length(dois) > 0) c("If you use this work please cite it using the DOI(s) above.", ""),
         if (nzchar(cit)) paste0("> ", str_split(cit, "\r?\n")[[1]]))
  }

  # Licence — separate entries for code and data.
  # "All rights reserved" is not a licence one is "licensed under".
  # No full stop is added after a licence that already ends in one; the exact
  # name is read back from the badge, so nothing is lost.
  lic_line <- function(label, lic) {
    if (str_detect(lic, regex("^all rights reserved\\.?$", ignore_case = TRUE)))
      paste0("- **", label, ":** All rights reserved.")
    else paste0("- **", label, ":** licensed under ", lic, if (!str_detect(lic, "\\.$")) ".")
  }
  lic_lines <- character(0)
  if (nzchar(meta$license_code %||% "")) lic_lines <- c(lic_lines, lic_line("Code", meta$license_code))
  if (nzchar(meta$license_data %||% "")) lic_lines <- c(lic_lines, lic_line("Data", meta$license_data))
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

  # Data files (tabular files; a .txt only if it was read as a table)
  is_data  <- is_data_file(files, auto)
  data_idx <- which(is_data)
  if (length(data_idx) > 0) {
    push("## Data Files")
    for (i in data_idx) {
      desc <- descriptions[[i]]; a <- auto[[i]]
      u <- units_list[[i]]; cd <- col_descs[[i]]; fe <- file_extras[[i]]
      md <- c(md, paste0("### ", code_name(files[i])))
      if (nzchar(desc %||% "")) md <- c(md, "", desc)
      meta_parts <- character(0)
      if (nzchar(fe$date %||% "")) meta_parts <- c(meta_parts, paste0("**Date collected:** ", fe$date))
      if (nzchar(fe$loc  %||% "")) meta_parts <- c(meta_parts, paste0("**Location:** ", fe$loc))
      if (length(meta_parts)) md <- c(md, "", paste(meta_parts, collapse = " | "))
      if (!is.null(a)) {
        if (length(a$sheets) > 1)
          md <- c(md, "", paste0("**Sheets:** ", length(a$sheets), " (",
                                 paste0("`", a$sheets, "`", collapse = ", "),
                                 "); only the first sheet with data is summarised below."))
        md <- c(md, "",
                paste0("**Dimensions:** ", plural(a$nrow, "row"), " × ", plural(a$ncol, "column")),
                "", "**Variables:**", "",
                "| Column | Type | Description | Units | Summary |",
                "| :----- | :--- | :---------- | :---- | :------ |")
        for (col_d in a$cols) {
          md <- c(md, sprintf("| %s | %s | %s | %s | %s |",
            esc_cell(code_name(col_d$name), code = TRUE), esc_cell(col_d$type),
            esc_cell(cd[[col_d$name]] %||% ""),
            esc_cell(if (col_d$type == "numeric") u[[col_d$name]] %||% "" else ""),
            esc_cell(col_d$summary)))
        }
      }
      md <- c(md, "")
    }
  }

  # Other files
  other_idx <- which(!is_data & !is_script(files))
  if (length(other_idx) > 0) {
    push("## Other Files")
    for (i in other_idx) {
      desc <- descriptions[[i]]
      md   <- c(md, paste0("### ", code_name(files[i])))
      if (nzchar(desc %||% "")) md <- c(md, "", desc)
      md <- c(md, "")
    }
  }

  # Models (optional MLast-style table — location and specification of each
  # analysis). Omitted entirely when no rows have been recorded.
  if (!is.null(models) && nrow(models) > 0) {
    push("## Models",
         paste0(
           "Location and specification of each analysis, linking the outcome ",
           "and predictors to the underlying data, and (kept separately) where ",
           "the analysis is described, where its results are reported, and ",
           "where the code that produced it lives. **Methods location** = ",
           "where the analysis is described; **Results location** = where the ",
           "output is reported; **Code location** = script and line."))
    md <- c(md,
            paste0("| ", paste(mlast_cols, collapse = " | "), " |"),
            paste0("| ", paste(rep(":---", length(mlast_cols)), collapse = " | "), " |"))
    for (i in seq_len(nrow(models))) {
      r <- models[i, ]
      md <- c(md, sprintf("| %s | %s | %s | %s | %s | %s | %s | %s |",
        esc_cell(r$outcome_paper), esc_cell(r$outcome_data), esc_cell(r$predictors),
        esc_cell(r$test_type), esc_cell(r$methods_loc), esc_cell(r$results_loc),
        esc_cell(r$code_loc), esc_cell(r$notes)))
    }
    md <- c(md, "")
  }

  # Scripts. Every line of a description is indented three spaces so it stays
  # inside its numbered item (and multi-line descriptions import intact).
  if (length(script_order) > 0) {
    push("## Code", "Scripts should be run in the following order:")
    for (k in seq_along(script_order)) {
      desc <- script_descs[[k]] %||% ""
      md   <- c(md, paste0(k, ". **", code_name(files[script_order[k]]), "**"))
      if (nzchar(desc)) {
        dl <- str_split(desc, "\r?\n")[[1]]
        md <- c(md, "", ifelse(nzchar(str_trim(dl)), paste0("   ", dl), ""))
      }
      md <- c(md, "")
    }
  }

  # R environment. The Source column says where each version came from
  # (renv.lock, or whatever was installed when the README was generated).
  r_ver  <- r_version %||% current_r_version()
  r_line <- paste0("**R version:** ", r_ver,
                   if (!is.null(r_version) && nzchar(r_version_src %||% ""))
                     paste0(" (from ", r_version_src, ")"))
  if (!is.null(pkgs) && nrow(pkgs) > 0) {
    src <- if ("Source" %in% names(pkgs)) pkgs$Source else rep("", nrow(pkgs))
    src[is.na(src)] <- ""
    if (any(nzchar(src))) {
      note <- if (any(src == "not recorded"))
        c("", paste0("Packages with source *not recorded* have no version in an renv.lock; ",
                     "run `sessionInfo()` in the project to find them."))
      else if (any(src == "renv.lock") && any(src != "renv.lock"))
        c("", paste0("Packages with source *installed* are not recorded in renv.lock; ",
                     "their versions are those installed where this README was generated."))
      push("## R Environment", r_line, note, "",
           "| Package | Version | Source |", "| :------ | :------ | :----- |",
           paste0("| `", pkgs$Package, "` | ", pkgs$Version, " | ", src, " |"))
    } else {
      push("## R Environment", r_line, "",
           "| Package | Version |", "| :------ | :------ |",
           paste0("| `", pkgs$Package, "` | ", pkgs$Version, " |"))
    }
  } else {
    push("## R Environment", r_line)
  }

  push("---", paste0("*README generated with READMEBuilder on ",
                      format(Sys.Date(), "%d %B %Y"), ".*"))
  # Escape line by line (multi-line fields are single elements of `md`), so
  # fenced code blocks inside a user's text are recognised and left alone.
  md <- str_split(paste(md, collapse = "\n"), "\n")[[1]]
  paste(md_escape_html(md), collapse = "\n")
}
