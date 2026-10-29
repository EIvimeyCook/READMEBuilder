# inst/READMEBuilder/server.R

server <- function(input, output, session) {

  # OS-appropriate roots for the folder picker: drive letters (C:, D:, ...) on
  # Windows, "/" on macOS/Linux. getVolumes() returns a FUNCTION, hence the ().
  # Not in the browser, which has no disk to browse (folders come as a .zip).
  if (!is_web) {
    volumes <- c(Home = fs::path_home(),
                 "R Installation" = R.home(),
                 shinyFiles::getVolumes()())
    shinyDirChoose(input, "folder_btn", roots = volumes, session = session)
  }

  # Set by build_readme(): the caller's working directory, and any folder to
  # load at start. NULL when the app is run directly with runApp().
  launch <- getOption("READMEBuilder.launch")

  rv <- reactiveValues(
    folder       = NULL,
    root_name    = NULL,
    files        = character(0),
    auto         = list(),
    script_idx   = integer(0),
    script_order = integer(0),
    pkgs         = NULL,
    pkg_diag     = NULL,
    r_version    = NULL,          # imported / lockfile R version (NULL -> live R.version)
    r_version_src = NULL,         # where r_version came from, e.g. "renv.lock"
    models       = mlast_template(),  # optional MLast-style model location table
    import_msg   = NULL,
    # imported defaults for the dynamic per-file / per-script inputs (keyed by path)
    imp_desc       = list(),
    imp_coldesc    = list(),
    imp_units      = list(),
    imp_date       = list(),
    imp_loc        = list(),
    imp_scriptdesc = list(),
    # Bumped on every folder load, import and clear, so the per-file and
    # per-script boxes are redrawn from the new defaults even when the file
    # list is unchanged (same zip twice, re-import of the same README).
    gen = 0
  )

  # Lookups that tolerate missing keys.
  imp_get  <- function(lst, key) { v <- lst[[key]]; if (is.null(v)) "" else v }
  imp_get2 <- function(lst, key, key2) {
    v <- lst[[key]]; if (is.null(v)) return("")
    w <- v[[key2]]; if (is.null(w)) "" else w
  }

  # Root label used for the directory map.
  tree_root <- reactive({
    rn <- rv$root_name
    if (!is.null(rn) && nzchar(rn)) rn
    else if (!is.null(rv$folder) && nzchar(rv$folder)) basename(rv$folder)
    else "project"
  })

  # Scans the loaded folder's scripts for packages (and renv.lock versions).
  # Defined early: a README imported at launch may call it.
  scan_folder <- function() {
    result <- tryCatch(extract_packages(rv$folder),
      error = function(e) { showNotification(paste("Error:", e$message), type = "error"); NULL })
    if (!is.null(result)) {
      # A version an imported README recorded is kept for any package the scan
      # cannot version (no lockfile entry; in the browser, nothing installed).
      old <- isolate(rv$pkgs)
      if (!is.null(old) && nrow(old) && nrow(result$pkgs)) {
        unk <- result$pkgs$Source %in% c("not recorded", "not installed")
        hit <- match(result$pkgs$Package, old$Package)
        use <- unk & !is.na(hit) & !(old$Version[hit] %in% c("—", "", NA))
        result$pkgs$Version[use] <- old$Version[hit[use]]
        result$pkgs$Source[use]  <- if ("Source" %in% names(old))
          ifelse(nzchar(old$Source[hit[use]]), old$Source[hit[use]], "README") else "README"
      }
      rv$pkgs     <- result$pkgs
      rv$pkg_diag <- result
      # If an renv.lock recorded an R version, adopt it for the export.
      if (!is.na(result$lock_r_version)) {
        rv$r_version <- result$lock_r_version; rv$r_version_src <- "renv.lock"
      }
    }
    invisible(result)
  }

  # ── Import an existing README ────────────────────────────────────────────────
  # A file that does not look like a READMEBuilder README (no generated footer
  # or section headings) is NOT imported straight away, because importing
  # replaces the whole form: the user is asked first. If even a forced import
  # finds nothing usable, the form is left untouched.
  # The README file chosen for import, kept apart from input$import_md so that
  # Clear can forget it (a file input's value cannot be reset from the server).
  import_file <- reactiveVal(NULL)
  observeEvent(input$import_md, { import_file(input$import_md); run_import() })

  # TRUE if anything has been entered or loaded, so replacing it needs a yes.
  form_has_content <- function() {
    ids <- c("title", "description", "abstract", "instructions", "additional_info",
             "doi", "citation_text", "authors", "affiliation", "contact", "funders",
             "acknowledgements", "license_code", "license_data")
    any(vapply(ids, function(id) nzchar(str_trim(paste(input[[id]] %||% "", collapse = ""))), logical(1))) ||
      length(rv$files) > 0 || nrow(rv$models) > 0
  }

  run_import <- function(force = FALSE, confirmed = FALSE) {
    f <- import_file()
    if (is.null(f)) {
      showNotification("Choose a README.md first.", type = "warning"); return()
    }
    txt <- read_text_file(f$datapath)
    if (is.null(txt) || !nzchar(txt) || !validUTF8(txt)) {
      showNotification("Could not read that file (empty, or not a UTF-8 text file).",
                       type = "error"); return()
    }
    if (!force && !is_readmebuilder(txt)) {
      showModal(modalDialog(
        title = tagList(icon("triangle-exclamation"), " Not a READMEBuilder README?"),
        p(code(f$name), " does not look like a README made by ",
          "READMEBuilder, so little or nothing may be read from it."),
        p(strong("Importing replaces everything currently in the form.")),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("import_anyway", "Import anyway", class = "btn-warning")
        )
      ))
      return()
    }
    if (!confirmed && form_has_content()) {
      showModal(modalDialog(
        title = tagList(icon("file-import"), " Replace the current form?"),
        p("Importing ", code(f$name), " replaces the project information, ",
          "descriptions and models you have entered."),
        if (!is.null(rv$folder))
          p("The loaded folder is kept; the README's descriptions are matched to its files."),
        footer = tagList(
          modalButton("Cancel"),
          actionButton("import_confirm", "Import", class = "btn-primary")
        )
      ))
      return()
    }
    p <- tryCatch(parse_readme(txt), error = function(e) NULL)
    if (is.null(p)) {
      showNotification("Could not parse that README.", type = "error"); return()
    }
    # With a folder loaded, attach the README to it rather than dropping it.
    apply_import(p, keep_folder = !is.null(rv$folder))
  }

  # Fills the form from a parsed README. With keep_folder = TRUE (a README found
  # in the loaded folder) the folder's own file list and data summaries are kept
  # and the README's descriptions attach to them by path; otherwise the README
  # also supplies the file list, as when one is uploaded with no folder.
  apply_import <- function(p, keep_folder = FALSE) {
    m <- p$meta
    if (!length(p$files) && !any(nzchar(unlist(m))) && !nrow(p$models) && !nrow(p$pkgs)) {
      showNotification("Nothing recognisable was found in that file; the form was left unchanged.",
                       type = "warning", duration = 8)
      return(invisible(FALSE))
    }

    # Project-info fields
    updateTextInput(session,     "title",           value = m$title)
    updateTextAreaInput(session, "description",     value = m$description)
    updateTextAreaInput(session, "abstract",        value = m$abstract)
    updateTextAreaInput(session, "instructions",    value = m$instructions)
    updateTextAreaInput(session, "additional_info", value = m$additional_info)
    updateTextAreaInput(session, "doi",             value = m$doi)
    updateTextAreaInput(session, "citation_text",   value = m$citation_text)
    updateTextAreaInput(session, "authors",         value = m$authors)
    updateTextAreaInput(session, "affiliation",     value = m$affiliation)
    updateTextInput(session,     "contact",         value = m$contact)
    updateTextAreaInput(session, "funders",         value = m$funders)
    updateTextAreaInput(session, "acknowledgements", value = m$acknowledgements)

    set_lic <- function(id, val) {
      ch <- license_choices
      if (nzchar(val) && !(val %in% ch)) ch <- c(ch, stats::setNames(val, val))
      updateSelectizeInput(session, id, choices = ch, selected = val,
                           options = free_select_opts)
    }
    set_lic("license_code", m$license_code)
    set_lic("license_data", m$license_data)

    # Structural state (files / columns / scripts / packages / R version)
    if (keep_folder) {
      # The README's script order indexes ITS file list: map it onto the
      # folder's files by path, then add any scripts the README did not list.
      ord <- match(p$files[p$script_order], rv$files)
      ord <- ord[!is.na(ord) & ord %in% rv$script_idx]
      rv$script_order <- c(ord, setdiff(rv$script_idx, ord))
    } else {
      rv$files        <- p$files
      rv$auto         <- p$auto
      rv$script_idx   <- which(is_script(p$files))
      rv$script_order <- if (length(p$script_order)) p$script_order else which(is_script(p$files))
      rv$root_name    <- if (nzchar(p$root_name)) p$root_name else NULL
      rv$folder       <- NULL
    }
    rv$r_version    <- if (nzchar(p$r_version)) p$r_version else NULL
    rv$r_version_src <- if (nzchar(p$r_version_src)) p$r_version_src else NULL

    rv$imp_desc       <- p$file_desc
    rv$imp_coldesc    <- p$col_desc
    rv$imp_units      <- p$units
    rv$imp_date       <- p$dates
    rv$imp_loc        <- p$locs
    rv$imp_scriptdesc <- p$script_desc
    rv$gen <- isolate(rv$gen) + 1
    rv$models         <- if (!is.null(p$models) && nrow(p$models) > 0) p$models else mlast_template()

    if (!is.null(p$pkgs) && nrow(p$pkgs) > 0) {
      rv$pkgs     <- p$pkgs
      rv$pkg_diag <- list(folder = "(imported from README)",
                          n_total = length(rv$files),
                          n_files = length(rv$script_idx),
                          filenames = rv$files[rv$script_idx])
    } else {
      rv$pkgs <- NULL; rv$pkg_diag <- NULL
    }
    # The folder's own renv.lock is more current than the versions written in
    # an older README, so rescan when there is one.
    if (keep_folder && !is.null(rv$folder)) scan_folder()   # README versions kept as fallback

    n_models <- if (nrow(rv$models)) paste0(", ", plural(nrow(rv$models), "model")) else ""
    rv$import_msg <- if (keep_folder) paste0(
      "Applied the README to the loaded folder (", sum(rv$files %in% p$files), " of ",
      plural(length(rv$files), "file"), " were in it), ",
      plural(if (is.null(rv$pkgs)) 0L else nrow(rv$pkgs), "package"), n_models,
      if (!is.null(rv$r_version)) paste0(", R ", rv$r_version) else "", ".")
    else paste0(
      "Imported ", plural(length(p$files), "file"), ", ",
      plural(length(rv$script_order), "script"), ", ",
      plural(if (is.null(rv$pkgs)) 0L else nrow(rv$pkgs), "package"), n_models,
      if (!is.null(rv$r_version)) paste0(", R ", rv$r_version) else "", ".")
    showNotification(rv$import_msg, type = "message", duration = 6)
    invisible(TRUE)
  }

  # Fills the form from the README.md at the top of the loaded folder, if
  # READMEBuilder made it. Any other README is left alone, with a note.
  import_folder_readme <- function() {
    f <- find_readme(rv$folder)
    if (is.na(f)) {
      showNotification("No README.md in that folder, so the form starts blank.",
                       type = "message", duration = 6)
      return(invisible(FALSE))
    }
    txt <- read_text_file(f)
    if (is.null(txt) || !validUTF8(txt) || !is_readmebuilder(txt)) {
      showNotification(paste0(basename(f), " was not made by READMEBuilder, so it was not loaded. ",
                              "To try anyway, upload it on the Project Info tab."),
                       type = "warning", duration = 10)
      return(invisible(FALSE))
    }
    p <- tryCatch(parse_readme(txt), error = function(e) NULL)
    if (is.null(p)) {
      showNotification(paste0("Could not parse ", basename(f), "."), type = "error")
      return(invisible(FALSE))
    }
    apply_import(p, keep_folder = TRUE)
  }

  observeEvent(input$reimport_btn, run_import())      # re-run on demand
  observeEvent(input$import_anyway,  { removeModal(); run_import(force = TRUE, confirmed = TRUE) })
  observeEvent(input$import_confirm, { removeModal(); run_import(force = TRUE, confirmed = TRUE) })
  observeEvent(input$load_folder_readme, { removeModal(); import_folder_readme() })

  # Clears the text and progress bar a file input shows (the browser keeps
  # them after the server has moved on).
  reset_file_input <- function(id) session$sendCustomMessage("rb_reset_file", id)

  observeEvent(input$clear_import, {
    showModal(modalDialog(
      title = tagList(icon("eraser"), " Clear everything?"),
      p("This removes all project information, the loaded folder, every file, ",
        "column and script description, and all models. It cannot be undone."),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("clear_confirm", "Clear everything", class = "btn-danger")
      )
    ))
  })

  observeEvent(input$clear_confirm, {
    removeModal()
    import_file(NULL)
    reset_file_input("import_md")
    reset_file_input("zip_upload")
    # title and contact are textInputs; the rest are textAreaInputs.
    updateTextInput(session, "title",   value = "")
    updateTextInput(session, "contact", value = "")
    for (id in c("description","abstract","instructions","additional_info",
                 "doi","citation_text","authors","affiliation","funders","acknowledgements"))
      updateTextAreaInput(session, id, value = "")
    updateSelectizeInput(session, "license_code", choices = license_choices, selected = "",
                         options = free_select_opts)
    updateSelectizeInput(session, "license_data", choices = license_choices, selected = "",
                         options = free_select_opts)
    rv$files <- character(0); rv$auto <- list()
    rv$script_idx <- integer(0); rv$script_order <- integer(0)
    rv$pkgs <- NULL; rv$pkg_diag <- NULL; rv$r_version <- NULL; rv$r_version_src <- NULL
    rv$root_name <- NULL; rv$folder <- NULL; rv$import_msg <- NULL
    rv$imp_desc <- list(); rv$imp_coldesc <- list(); rv$imp_units <- list()
    rv$imp_date <- list(); rv$imp_loc <- list(); rv$imp_scriptdesc <- list()
    rv$gen <- isolate(rv$gen) + 1
    rv$models <- mlast_template()
    showNotification("Cleared. Form reset to a blank README.", type = "message")
  })

  # Common-licence shortcut buttons under each licence selector.
  observeEvent(input$lic_pick, {
    id <- input$lic_pick$id
    req(id %in% c("license_code", "license_data"))
    updateSelectizeInput(session, id, selected = input$lic_pick$val)
  })

  output$import_status <- renderUI({
    req(rv$import_msg)
    div(class = "alert alert-success py-2 px-3 small mb-0 mt-2",
        icon("circle-check"), " ", rv$import_msg,
        " Edit anything below, then export from the ", strong("Preview & Export"), " tab.")
  })

  # ── Help / walkthrough ──────────────────────────────────────────────
  # Shown on demand from the sidebar, and once automatically on a user's first
  # session (tracked in a small file under the user's config dir, so it does not
  # nag on every launch).

  help_step <- function(n, title, ...) {
    div(class = "rb-step",
        tags$h6(paste0(n, ". "), title),
        tags$p(class = "text-muted", ...))
  }

  help_modal <- function() {
    modalDialog(
      title = tagList(icon("circle-question"), " How to use READMEBuilder"),
      size = "l", easyClose = TRUE,

      # Demo video / screencast. Shown only if a demo file has been shipped with
      # the package, so the app works fine without one.
      if (!is.null(demo_media_tag())) tagList(demo_media_tag(), tags$hr()),

      p(class = "text-muted small",
        "READMEBuilder walks you through documenting a project — both the data ",
        "and the code — and exports a single README.md. Work through the tabs in order; ",
        if (is_web) "your files stay in your browser and are never sent anywhere, "
        else "nothing is uploaded anywhere, ",
        "and you can stop and re-import a README later to carry on."),

      help_step(1, "Project Info",
        "Title, description, authors, licences, funding. If you already have a ",
        "README this app made, choose it here to carry on editing it."),
      help_step(2, "Files",
        if (is_web)
          paste0("Drag your project folder — the top level, not a subfolder — onto ",
                 "the box (or use Choose folder…, or a .zip). Every ")
        else
          paste0("Browse to your project folder — the top level, not a subfolder — ",
                 "click Use working directory, or upload the folder as a .zip. Every "),
        "subfolder is scanned automatically. Spreadsheets and CSVs are summarised ",
        "column by column; add a description and units for each column."),
      help_step(3, "Script Order",
        "Put your scripts in the order someone should run them, and say briefly ",
        "what each one does."),
      help_step(4, "R Packages",
        "Scans your scripts for the packages they use. If the project has an ",
        if (is_web)
          "renv.lock, versions (and the R version) come from there; without one they are shown as \"not recorded\", because the browser cannot see your installed packages."
        else "renv.lock, versions come from there."),
      help_step(5, "Models (optional)",
        "Record each analysis and where it lives: the outcome as named in your ",
        "paper, the matching data column, where the method is described, where ",
        "the results are reported, and the script and line that produced it. ",
        "Optional, but it is the link people most often need and rarely get."),
      help_step(6, "Preview & Export",
        "Check the live preview, then download your README.md."),

      div(class = "alert alert-light border small mb-0",
        tags$strong("Tip: "),
        "on the Models tab, use ", tags$em("Suggest from loaded scripts"),
        " instead of typing line numbers by hand — it finds the line for you ",
        "and stays right if you edit the script later."),

      footer = tagList(
        tags$a(href = "https://github.com/EIvimeyCook/READMEBuilder",
               target = "_blank", class = "btn btn-outline-secondary",
               icon("github"), " Docs"),
        modalButton("Got it")
      )
    )
  }

  observeEvent(input$show_help, showModal(help_modal()))

  # First-run: show the walkthrough once, then remember that we have. In the
  # browser the R side forgets everything on reload, so the browser's own
  # storage remembers instead (ui.R reports it as input$rb_seen_help).
  if (is_web) {
    observeEvent(input$rb_seen_help, once = TRUE, {
      if (!isTRUE(input$rb_seen_help)) {
        showModal(help_modal())
        session$sendCustomMessage("rb_mark_help", TRUE)
      }
    })
  } else observe({
    if (!has_seen_help()) {
      showModal(help_modal())
      mark_help_seen()
    }
  })

  # Everything currently in the per-file and per-script boxes, keyed by file
  # path (and column name), in the same shape as the imported defaults rv$imp_*.
  snapshot_typed <- function() {
    f    <- rv$files
    keep <- function(x) Filter(function(v) length(v) && any(nzchar(unlist(v))), x)
    fe   <- get_file_extras()
    list(
      desc    = keep(stats::setNames(get_descriptions(), f)),
      coldesc = keep(stats::setNames(get_col_descs(), f)),
      units   = keep(stats::setNames(get_units(), f)),
      date    = keep(stats::setNames(map(fe, "date"), f)),
      loc     = keep(stats::setNames(map(fe, "loc"), f)),
      scriptdesc = keep(stats::setNames(get_script_descs(), f[rv$script_order]))
    )
  }

  # ── Load folder ──────────────────────────────────────────────────────────────
  # Loads `path` as the project folder. With offer_readme = TRUE, a README.md
  # that READMEBuilder made is offered for loading too. Returns TRUE if loaded.
  load_folder <- function(path, offer_readme = TRUE) {
    files <- list.files(path, recursive = TRUE, all.files = FALSE, no.. = TRUE)
    files <- files[!str_detect(files, "^\\.|/\\.")]
    # Skip installed dependency libraries (renv/packrat) and IDE/VCS state:
    # these are not the researcher's own data or code, and a restored renv
    # library can hold tens of thousands of files.
    n_any <- length(files)
    files <- tree_order(files[!is_excluded(files) & !is_junk(files)])
    if (!length(files)) {
      showNotification(
        if (n_any) paste("No project files found: everything in it is in a skipped",
                         "folder (renv, packrat, .git, .Rproj.user, …) or is system clutter.")
        else "No files found in that folder.", type = "warning", duration = 8)
      return(invisible(FALSE))
    }
    # A README imported with no folder (the help's step 1 before step 2): keep
    # what it brought, and anything typed since, for the folder's matching
    # files. Otherwise a fresh folder supersedes the previous one entirely.
    carry <- is.null(rv$folder) && length(rv$files) > 0
    if (carry) {
      kept      <- snapshot_typed()
      old_order <- rv$files[rv$script_order]
    }
    rv$folder <- as.character(path)

    rv$files        <- files
    rv$auto         <- map(files, ~ auto_describe(file.path(rv$folder, .x)))
    rv$script_idx   <- which(is_script(files))
    rv$script_order <- rv$script_idx
    rv$root_name    <- basename(rv$folder)
    # The imported README's package and R versions are kept (as a fallback for
    # the scan below) only in the carry-over case.
    if (!carry) {
      rv$r_version <- NULL; rv$r_version_src <- NULL; rv$pkgs <- NULL
    }
    rv$pkg_diag <- NULL; rv$import_msg <- NULL
    if (carry) {
      rv$imp_desc <- kept$desc; rv$imp_coldesc <- kept$coldesc; rv$imp_units <- kept$units
      rv$imp_date <- kept$date; rv$imp_loc <- kept$loc; rv$imp_scriptdesc <- kept$scriptdesc
      ord <- match(old_order, files)
      ord <- ord[!is.na(ord) & ord %in% rv$script_idx]
      rv$script_order <- c(ord, setdiff(rv$script_idx, ord))
    } else {
      rv$imp_desc <- list(); rv$imp_coldesc <- list(); rv$imp_units <- list()
      rv$imp_date <- list(); rv$imp_loc <- list(); rv$imp_scriptdesc <- list()
    }
    rv$gen <- isolate(rv$gen) + 1
    scan_folder()          # packages straight away, so the README has them

    showNotification(paste0(plural(length(files), "file"), " loaded.",
                            if (carry) " Descriptions from the imported README were kept for matching files."),
                     type = "message")

    if (offer_readme) {
      f   <- find_readme(rv$folder)
      txt <- if (!is.na(f)) read_text_file(f)
      if (!is.null(txt) && validUTF8(txt) && is_readmebuilder(txt))
        showModal(modalDialog(
          title = tagList(icon("file-import"), " Load the existing README?"),
          p("This folder has a ", code(basename(f)), " made by READMEBuilder. ",
            "Load it to carry on editing: project info, file and column ",
            "descriptions, script order and models are filled in from it, and ",
            "the file list and data summaries come from the folder."),
          p(strong("Loading it replaces what is currently in the form.")),
          footer = tagList(
            modalButton("Don't load"),
            actionButton("load_folder_readme", "Load README", class = "btn-primary")
          )
        ))
    }
    invisible(TRUE)
  }

  observeEvent(input$folder_btn, {
    req(is.list(input$folder_btn))
    path <- parseDirPath(volumes, input$folder_btn)
    req(nzchar(path))
    load_folder(path)
  })

  observeEvent(input$use_wd, {
    req(launch$wd)
    load_folder(launch$wd)
  })

  # Folder (and README) passed to build_readme(folder, edit_readme).
  if (!is.null(launch$folder)) isolate({
    if (load_folder(launch$folder, offer_readme = FALSE) && isTRUE(launch$edit_readme))
      import_folder_readme()
  })

  # An uploaded folder (zip, or the browser's folder chooser) is rebuilt in a
  # temporary directory and loaded from there. In the browser those files sit
  # in memory, so only the loaded upload's copy is kept.
  upload_dir <- NULL
  load_upload <- function(root, dest) {
    if (load_folder(dest)) {
      if (!is.null(upload_dir)) unlink(upload_dir, recursive = TRUE)
      upload_dir <<- root
    } else {
      unlink(root, recursive = TRUE)
    }
  }

  # Browser version, Choose folder: the files arrive with their base names,
  # and their paths inside the chosen folder ("my-study/data/obs.csv") arrive
  # just before as input$folder_paths, in the same order. The folder is
  # rebuilt from those paths; the first part is the chosen folder itself.
  observeEvent(input$folder_upload, {
    u     <- input$folder_upload
    paths <- unlist(isolate(input$folder_paths))
    rel   <- if (length(paths) == nrow(u) && all(basename(paths) == u$name)) paths else u$name
    rel   <- str_replace_all(rel, fixed("\\"), "/")
    safe <- !vapply(str_split(rel, "/"), function(p) any(p %in% c("", ".", "..")), logical(1))
    root <- tempfile("rb_dir_")
    for (i in which(safe)) {
      to <- file.path(root, rel[i])
      dir.create(dirname(to), recursive = TRUE, showWarnings = FALSE)
      file.copy(u$datapath[i], to)
      unlink(u$datapath[i])
    }
    top  <- unique(str_extract(rel[safe], "^[^/]+"))
    dest <- if (length(top) == 1 && dir.exists(file.path(root, top))) file.path(root, top) else root
    load_upload(root, dest)
  })

  # Zip upload: unzip into a folder named after the zip, then load it. Zipping
  # a folder usually gives one top-level folder (plus macOS's __MACOSX and
  # .DS_Store), so step into it when that is all there is.
  observeEvent(input$zip_upload, {
    z    <- input$zip_upload
    root <- tempfile("rb_zip_")
    dest <- file.path(root, tools::file_path_sans_ext(z$name))
    n_entries <- zip_n_entries(z$datapath)   # read from the zip itself: unzip() errors on an empty one
    ok   <- !is.na(n_entries) && n_entries > 0 &&
      tryCatch({ utils::unzip(z$datapath, exdir = dest); TRUE },
               error = function(e) FALSE, warning = function(w) FALSE)
    if (ok) {
      fix_zip_names(z$datapath, dest)   # reads the zip's index, so before unlink
      fix_zip_slashes(dest)
    }
    unlink(z$datapath)
    if (!ok) {
      unlink(root, recursive = TRUE)
      showNotification(
        if (identical(n_entries, 0L)) "That zip is empty."
        else "That file could not be opened as a .zip archive.", type = "error")
      return()
    }
    top <- setdiff(list.files(dest, all.files = TRUE, no.. = TRUE), c("__MACOSX", ".DS_Store"))
    if (length(top) == 1 && dir.exists(file.path(dest, top))) dest <- file.path(dest, top)
    load_upload(root, dest)
  })

  output$folder_label <- renderUI({
    req(rv$folder)
    tags$small(class = "text-muted", icon("folder"), " ", show_path(rv$folder))
  })

  output$file_summary_ui <- renderUI({
    req(length(rv$files) > 0)
    tagList(hr(), tags$small(class = "text-muted",
      icon("file"),  " ", plural(length(rv$files), "file"), " total", br(),
      icon("table"), " ", sum(map_lgl(rv$auto, Negate(is.null))), " tabular", br(),
      icon("code"),  " ", plural(length(rv$script_idx), "script")))
  })

  # ── Directory map (live preview) ──────────────────────────────────────────────
  output$dir_map_ui <- renderUI({
    req(length(rv$files) > 0)
    tree <- build_dir_tree(rv$files, root = tree_root())
    card(class = "mb-3",
      card_header(icon("sitemap"), " Directory map"),
      card_body(
        p(class = "text-muted small mb-2",
          "Tree of the loaded/imported folder. Included in the exported ",
          code("README.md"), " under ", strong("Directory Structure"), "."),
        tags$pre(class = "rb-tree", paste(tree, collapse = "\n"))
      ))
  })

  # ── File cards ───────────────────────────────────────────────────────────────
  output$files_ui <- renderUI({
    rv$gen
    if (!length(rv$files))
      return(div(class = "text-muted mt-4 text-center",
                 icon("folder-open", class = "fa-2x mb-2"), br(),
                 "Load a project folder, or import a README on the Project Info tab."))

    map(seq_along(rv$files), function(i) {
      f <- rv$files[i]
      a <- rv$auto[[i]]

      badge <- if (!is.null(a))
        tags$span(class = "badge bg-success ms-2", icon("check"), " auto-described")
      else if (is_script(f))
        tags$span(class = "badge bg-info ms-2", icon("code"), " script")

      units_ui <- if (!is.null(a)) {
        # Input IDs use the column's POSITION (j), never its name: Shiny reads
        # "id:type" as an input-handler type, so a column such as "time:s"
        # would otherwise crash the session, and names may hold any character.
        col_rows <- map(seq_along(a$cols), function(j) {
          col_d <- a$cols[[j]]
          unit_cell <- if (col_d$type == "numeric")
            textInput(paste0("unit_", i, "_", j), label = NULL,
                      value = imp_get2(rv$imp_units, f, col_d$name),
                      placeholder = "e.g. mm, g, °C")
          else
            tags$span(class = "text-muted small", "—")
          tags$tr(
            tags$td(style = "width:22%;vertical-align:middle;padding:4px 6px",
                    tags$code(style = "font-size:0.82rem", col_d$name),
                    tags$span(class = paste0("badge ms-1 bg-",
                      switch(col_d$type, numeric = "success", categorical = "primary",
                             date = "warning", logical = "secondary", "light")),
                      style = "font-size:0.68rem", col_d$type)),
            tags$td(style = "width:25%;vertical-align:middle;padding:4px 6px",
                    tags$small(class = "text-muted", col_d$summary)),
            tags$td(style = "width:38%;vertical-align:middle;padding:3px 4px",
                    # A one-row text area, so a description can hold line
                    # breaks (the README table keeps them as <br>).
                    textAreaInput(paste0("coldesc_", i, "_", j), label = NULL,
                                  value = imp_get2(rv$imp_coldesc, f, col_d$name),
                                  placeholder = "Column description", rows = 1,
                                  resize = "vertical")),
            tags$td(style = "width:15%;vertical-align:middle;padding:3px 4px", unit_cell)
          )
        })
        tagList(
          tags$hr(),
          tags$p(class = "text-muted small mb-1",
                 icon("table"), " ", plural(a$nrow, "row"), " × ", plural(a$ncol, "col"),
                 " — add a description for each column; units for numeric columns:"),
          if (length(a$sheets) > 1)
            tags$p(class = "text-muted small mb-1", icon("layer-group"), " ",
                   length(a$sheets), " sheets (", paste(a$sheets, collapse = ", "),
                   "); only the first with data is summarised."),
          tags$table(class = "table table-sm table-bordered small mb-0",
            tags$thead(class = "table-light",
              tags$tr(tags$th("Column"), tags$th("Auto-summary"),
                      tags$th("Description"), tags$th("Units"))),
            tags$tbody(col_rows)),
          tags$hr(),
          layout_column_wrap(width = "200px", gap = "0.5rem",
            textInput(paste0("collection_date_", i), "Date(s) of data collection",
                      value = imp_get(rv$imp_date, f),
                      placeholder = "e.g. June–August 2022"),
            textInput(paste0("collection_location_", i), "Location of data collection",
                      value = imp_get(rv$imp_loc, f),
                      placeholder = "e.g. Cairngorms NP, Scotland, UK")
          )
        )
      }

      card(class = "mb-3",
        card_header(tags$code(f), badge),
        card_body(
          # Scripts are described (and exported) from the Script Order tab, so
          # a box here would collect text that never reaches the README.
          if (is_script(f) && is.null(a))
            p(class = "text-muted small mb-0", icon("arrow-right"),
              " Describe this script on the Script Order tab.")
          else
            textAreaInput(paste0("desc_", i), "Description",
                          value = imp_get(rv$imp_desc, f),
                          placeholder = "What does this file contain, how was it produced, any caveats?",
                          rows = 2),
          units_ui
        )
      )
    })
  })

  # ── Script order ──────────────────────────────────────────────────────────────
  # Script-description inputs are keyed by FILE INDEX (script_desc_<i>), not by
  # display position, so reordering scripts keeps each script's description.
  output$script_order_ui <- renderUI({
    rv$gen
    if (!length(rv$script_order))
      return(p(class = "text-muted",
               "No scripts detected. Load a folder with .R/.Rmd files, or import a README."))
    n <- length(rv$script_order)
    # Each arrow names its SCRIPT (file index), not its position, so a quick
    # second click before the list redraws moves the same script again rather
    # than whichever one has moved into that position. It also sends the boxes'
    # current text, since Shiny sends typed text a moment after the click.
    move_js <- function(i, dir) sprintf(paste0(
      "const d = {}; document.querySelectorAll('#script_order_ui textarea')",
      ".forEach(t => d[t.id] = t.value); Shiny.setInputValue('script_move',",
      "{file:%d,dir:'%s',descs:d},{priority:'event'})"), i, dir)
    map(seq_len(n), function(k) {
      i <- rv$script_order[k]
      f <- rv$files[i]
      up_btn <- if (k > 1)
        tags$button(class = "btn btn-sm btn-outline-secondary me-1",
                    onclick = move_js(i, "up"), icon("arrow-up"))
      else
        tags$button(class = "btn btn-sm btn-outline-secondary me-1", disabled = NA, icon("arrow-up"))
      down_btn <- if (k < n)
        tags$button(class = "btn btn-sm btn-outline-secondary",
                    onclick = move_js(i, "down"), icon("arrow-down"))
      else
        tags$button(class = "btn btn-sm btn-outline-secondary", disabled = NA, icon("arrow-down"))
      div(class = "d-flex align-items-start mb-3 gap-3",
        div(class = "d-flex align-items-center gap-1 pt-1",
          tags$span(class = "badge bg-primary rounded-pill px-2 py-1",
                    style = "min-width:2rem;text-align:center;font-size:1rem", k),
          div(up_btn, down_btn)),
        div(class = "flex-grow-1",
          card(card_body(
            tags$code(f),
            textAreaInput(paste0("script_desc_", i), label = NULL,
                          value = imp_get(rv$imp_scriptdesc, f),
                          placeholder = "What does this script do?", rows = 2)
          )))
      )
    })
  })

  # Render the dynamic file / script UIs even while their tab is hidden, so
  # imported descriptions are present in the preview without visiting the tab.
  # NOTE: outputOptions() must be called AFTER the outputs above are defined.
  outputOptions(output, "files_ui",        suspendWhenHidden = FALSE)
  outputOptions(output, "script_order_ui", suspendWhenHidden = FALSE)

  observeEvent(input$script_move, {
    mv  <- input$script_move
    pos <- match(mv$file, rv$script_order)
    if (is.na(pos)) return()

    # Reordering re-renders the list, which recreates every description box
    # from rv$imp_scriptdesc. Save what has been typed first, keyed by path,
    # or every description is wiped on the first arrow click. The click carries
    # the boxes' text; fall back to the input values.
    sd <- rv$imp_scriptdesc
    for (i in rv$script_order) {
      id  <- paste0("script_desc_", i)
      val <- if (!is.null(mv$descs[[id]])) mv$descs[[id]] else input[[id]]
      if (!is.null(val)) sd[[rv$files[i]]] <- val
    }
    rv$imp_scriptdesc <- sd

    dir <- mv$dir
    n   <- length(rv$script_order)
    if (dir == "up"   && pos > 1) rv$script_order[c(pos-1,pos)] <- rv$script_order[c(pos,pos-1)]
    if (dir == "down" && pos < n) rv$script_order[c(pos,pos+1)] <- rv$script_order[c(pos+1,pos)]
  })

  # ── Package scan ──────────────────────────────────────────────────────────────
  observeEvent(input$scan_pkgs, {
    # After an import there is no folder to scan: say so instead of silently
    # doing nothing, and keep the imported package table.
    if (is.null(rv$folder) || !nzchar(rv$folder)) {
      showNotification(
        if (!is.null(rv$pkgs) && nrow(rv$pkgs) > 0)
          paste("The package list shown was imported from the README. To rescan,",
                "load the project folder on the Files tab.")
        else "Load a project folder on the Files tab first, then scan.",
        type = "warning", duration = 8)
      return()
    }
    scan_folder()
  })

  output$pkg_ui <- renderUI({
    req(rv$pkg_diag)
    d <- rv$pkg_diag
    lock_line <- {
      lf <- d$lock_file
      if (is.null(lf)) NULL                        # imported diagnostic, no lock field
      else if (is.na(lf) && is_web)
        tagList(br(), tags$b("renv.lock: "), "not found. The browser can't see ",
                "your installed package versions; add an renv.lock to the zip ",
                "to record them.")
      else if (is.na(lf))
        tagList(br(), tags$b("renv.lock: "), "not found; using installed versions")
      else if (isFALSE(d$lock_ok))
        tagList(br(), tags$b("renv.lock: "), code(d$lock_rel %||% basename(lf)),
                tags$span(class = "text-danger",
                  paste0(" ", d$lock_reason %||% "could not be read",
                         ", so no versions were taken from it.")))
      else
        tagList(br(), tags$b("renv.lock: "), code(d$lock_rel %||% basename(lf)),
                sprintf(" (%d of %d versions from lockfile)", d$n_from_lock, nrow(rv$pkgs)),
                if (isTRUE(d$n_locks > 1))
                  tags$span(class = "text-warning",
                    sprintf(" — %d renv.lock files found; only this one is used.", d$n_locks)))
    }
    diag_box <- div(class = "alert alert-secondary mt-3 small",
      tags$b("Diagnostic info"), br(),
      tags$b("Source: "), code(show_path(d$folder)), br(),
      tags$b("Total files: "), d$n_total, br(),
      tags$b("R/Rmd/qmd files: "), d$n_files,
      if (d$n_files > 0)
        tagList(br(), tags$b("Files: "), paste(d$filenames, collapse = ", ")),
      lock_line
    )
    if (is.null(rv$pkgs) || nrow(rv$pkgs) == 0)
      return(tagList(diag_box,
        p(class = "text-muted mt-2", "No packages found.")))
    tagList(diag_box, hr(),
      p(strong(plural(nrow(rv$pkgs), "package")), " | R ",
        code(rv$r_version %||% current_r_version())),
      tableOutput("pkg_table"))
  })

  output$pkg_table <- renderTable({
    req(rv$pkgs, nrow(rv$pkgs) > 0); rv$pkgs
  }, striped = TRUE, hover = TRUE)

  # ── Models (optional MLast-style table) ──────────────────────────────────────

  observeEvent(input$add_model, {
    if (!nzchar(str_trim(input$model_outcome_data  %||% "")) &&
        !nzchar(str_trim(input$model_outcome_paper %||% ""))) {
      showNotification("Enter an outcome (paper or data) to add a model.", type = "warning")
      return()
    }
    new <- tibble(
      outcome_paper = input$model_outcome_paper %||% "",
      outcome_data  = input$model_outcome_data  %||% "",
      predictors    = input$model_predictors    %||% "",
      test_type     = input$model_test_type     %||% "",
      methods_loc   = input$model_methods_loc   %||% "",
      results_loc   = input$model_results_loc   %||% "",
      code_loc      = input$model_code_loc      %||% "",
      notes         = input$model_notes         %||% ""
    )
    # A double-click sends a second click before the cleared fields come back,
    # so it would add the same model again.
    n <- nrow(rv$models)
    if (n > 0 && isTRUE(all.equal(as.list(rv$models[n, names(new)]), as.list(new),
                                  check.attributes = FALSE))) {
      showNotification("That model is already the last one in the table.", type = "warning")
      return()
    }
    rv$models <- bind_rows(rv$models, new)
    updateTextInput(session,     "model_outcome_paper", value = "")
    updateTextInput(session,     "model_outcome_data",  value = "")
    updateTextInput(session,     "model_predictors",    value = "")
    updateSelectizeInput(session, "model_test_type",    selected = "")
    updateTextInput(session,     "model_methods_loc",   value = "")
    updateTextInput(session,     "model_results_loc",   value = "")
    updateTextInput(session,     "model_code_loc",      value = "")
    updateTextAreaInput(session, "model_notes",         value = "")
  })

  observeEvent(input$clear_models, {
    req(nrow(rv$models) > 0)
    showModal(modalDialog(
      title = tagList(icon("trash"), " Delete all models?"),
      p(paste0("This removes all ", plural(nrow(rv$models), "recorded model"), ". It cannot be undone.")),
      footer = tagList(modalButton("Cancel"),
                       actionButton("clear_models_confirm", "Delete all", class = "btn-danger"))
    ))
  })
  observeEvent(input$clear_models_confirm, { removeModal(); rv$models <- mlast_template() })

  # Each delete button sends its row number and the table version it was drawn
  # for, so a second click on a stale button (a double-click) is ignored rather
  # than deleting the row that moved up into its place.
  models_rev <- reactiveVal(0)
  observeEvent(rv$models, models_rev(isolate(models_rev()) + 1))

  observeEvent(input$model_delete, {
    i <- input$model_delete$i
    if (!identical(as.numeric(input$model_delete$rev), as.numeric(models_rev()))) return()
    if (i >= 1 && i <= nrow(rv$models)) rv$models <- rv$models[-i, ]
  })

  # "Suggest from loaded scripts": searches the loaded project folder for the
  # outcome data-column name (falling back to the first predictor) and lets
  # the user pick a matching script:line rather than typing it from memory.
  observeEvent(input$model_suggest_code, {
    if (is.null(rv$folder) || !nzchar(rv$folder)) {
      showNotification("Load a project folder on the Files tab first.", type = "warning")
      return()
    }
    pat <- str_trim(input$model_outcome_data %||% "")
    if (!nzchar(pat))
      pat <- (c(Filter(nzchar, str_trim(str_split(input$model_predictors %||% "", ",")[[1]])), ""))[1]
    if (!nzchar(pat)) {
      showNotification("Enter an outcome or predictor to search for first.", type = "warning")
      return()
    }
    hits <- find_code_locations(rv$folder, pat)
    if (nrow(hits) == 0) {
      showNotification(
        paste0("No matches for \"", pat, "\" in the loaded scripts. Enter the code location manually."),
        type = "warning")
      return()
    }
    showModal(modalDialog(
      title = paste0("Matches for \"", pat, "\""), size = "l", easyClose = TRUE,
      radioButtons("model_code_pick", NULL,
        choiceNames = map(seq_len(nrow(hits)), function(i)
          tagList(tags$code(paste0(hits$script[i], ":", hits$line[i])), " — ",
                  tags$small(class = "text-muted", hits$snippet[i]))),
        choiceValues = paste0(hits$script, ":", hits$line)),
      footer = tagList(
        modalButton("Cancel"),
        actionButton("model_code_pick_use", "Use selected", class = "btn-primary")
      )
    ))
  })

  observeEvent(input$model_code_pick_use, {
    req(input$model_code_pick)
    updateTextInput(session, "model_code_loc", value = input$model_code_pick)
    removeModal()
  })

  output$models_table_ui <- renderUI({
    if (is.null(rv$models) || nrow(rv$models) == 0)
      return(p(class = "text-muted",
               "No models recorded yet — this tab is optional. Add one above, ",
               "or leave it empty and the README will have no Models section."))

    header <- tags$tr(
      tags$th("#"), tags$th("Outcome (paper)"), tags$th("Outcome (data)"),
      tags$th("Predictors"), tags$th("Test"), tags$th("Methods loc."),
      tags$th("Results loc."), tags$th("Code loc."), tags$th("Notes"), tags$th()
    )
    rows <- map(seq_len(nrow(rv$models)), function(i) {
      r <- rv$models[i, ]
      tags$tr(
        tags$td(i), tags$td(r$outcome_paper),
        tags$td(if (nzchar(r$outcome_data)) tags$code(r$outcome_data)),
        tags$td(r$predictors), tags$td(r$test_type), tags$td(r$methods_loc),
        tags$td(r$results_loc), tags$td(if (nzchar(r$code_loc)) tags$code(r$code_loc)),
        tags$td(class = "rb-notes", r$notes),
        tags$td(tags$button(
          class = "btn btn-sm btn-outline-danger",
          onclick = sprintf("Shiny.setInputValue('model_delete',{i:%d,rev:%d},{priority:'event'})",
                            i, models_rev()),
          icon("trash")))
      )
    })
    tags$table(class = "table table-sm table-bordered small mb-0",
      tags$thead(class = "table-light", header), tags$tbody(rows))
  })
  outputOptions(output, "models_table_ui", suspendWhenHidden = FALSE)

  # ── Collect inputs ────────────────────────────────────────────────────────────
  get_meta <- reactive({
    list(title = input$title, description = input$description,
         abstract = input$abstract, instructions = input$instructions,
         additional_info = input$additional_info,
         doi = input$doi, citation_text = input$citation_text,
         license_code = input$license_code, license_data = input$license_data,
         authors = input$authors,
         affiliation = input$affiliation, contact = input$contact,
         funders = input$funders, acknowledgements = input$acknowledgements)
  })

  # Shiny keeps the last value of an input whose box is no longer drawn, so
  # read only the boxes files_ui draws for each file (none for scripts; date
  # and location only for files read as a table).
  get_descriptions <- reactive({
    map(seq_along(rv$files), function(i)
      if (is_script(rv$files[i]) && is.null(rv$auto[[i]])) ""
      else input[[paste0("desc_", i)]] %or% "")
  })

  get_units <- reactive({
    map(seq_along(rv$files), function(i) {
      a <- rv$auto[[i]]; if (is.null(a)) return(list())
      units <- list()
      for (j in seq_along(a$cols)) {
        col_d <- a$cols[[j]]
        if (col_d$type != "numeric") next
        val <- input[[paste0("unit_", i, "_", j)]]
        if (!is.null(val) && nzchar(trimws(val))) units[[col_d$name]] <- val
      }
      units
    })
  })

  get_col_descs <- reactive({
    map(seq_along(rv$files), function(i) {
      a <- rv$auto[[i]]; if (is.null(a)) return(list())
      descs <- list()
      for (j in seq_along(a$cols)) {
        col_d <- a$cols[[j]]
        val <- input[[paste0("coldesc_", i, "_", j)]]
        if (!is.null(val) && nzchar(trimws(val))) descs[[col_d$name]] <- val
      }
      descs
    })
  })

  get_file_extras <- reactive({
    map(seq_along(rv$files), function(i) {
      if (is.null(rv$auto[[i]])) return(list(date = "", loc = ""))
      list(date = input[[paste0("collection_date_",     i)]] %||% "",
           loc  = input[[paste0("collection_location_", i)]] %||% "")
    })
  })

  # Read by FILE INDEX in run order, so values follow the script across reorders.
  get_script_descs <- reactive({
    map(rv$script_order, ~ input[[paste0("script_desc_", .x)]] %or% "")
  })

  # ── Build & export ────────────────────────────────────────────────────────────
  readme_text <- reactive({
    assemble_readme(
      meta         = get_meta(),
      files        = rv$files,
      descriptions = get_descriptions(),
      auto         = rv$auto,
      pkgs         = rv$pkgs,
      script_order = rv$script_order,
      script_descs = get_script_descs(),
      units_list   = get_units(),
      col_descs    = get_col_descs(),
      file_extras  = get_file_extras(),
      root         = tree_root(),
      r_version    = rv$r_version,
      models       = rv$models,
      r_version_src = rv$r_version_src
    )
  })

  output$preview    <- renderText({ readme_text() })

  # Browser version: keep the current README in the page, so a Download click
  # while R is idle saves it at once (see the click handler in ui.R).
  if (is_web) observe(session$sendCustomMessage("rb_readme", readme_text()))
  output$export_btn <- downloadHandler(
    filename = function() "README.md",
    # Force UTF-8 bytes so the directory-map box characters, "×", and accented
    # text export correctly regardless of the user's locale (matters on Windows).
    content  = function(f) writeLines(enc2utf8(readme_text()), f, useBytes = TRUE)
  )
}
