# inst/READMEBuilder/server.R

server <- function(input, output, session) {

  volumes <- c(Home = fs::path_home(), Root = "/")
  shinyDirChoose(input, "folder_btn", roots = volumes, session = session,
                 restrictions = system.file(package = "base"))

  rv <- reactiveValues(
    folder       = NULL,
    root_name    = NULL,
    files        = character(0),
    auto         = list(),
    script_idx   = integer(0),
    script_order = integer(0),
    pkgs         = NULL,
    pkg_diag     = NULL,
    r_version    = NULL,          # imported R version (NULL -> use live R.version)
    import_msg   = NULL,
    # imported defaults for the dynamic per-file / per-script inputs (keyed by path)
    imp_desc       = list(),
    imp_coldesc    = list(),
    imp_units      = list(),
    imp_date       = list(),
    imp_loc        = list(),
    imp_scriptdesc = list()
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

  # ── Import an existing README ────────────────────────────────────────────────
  run_import <- function() {
    if (is.null(input$import_md)) {
      showNotification("Choose a README.md first.", type = "warning"); return()
    }
    txt <- tryCatch(readr::read_file(input$import_md$datapath), error = function(e) NULL)
    if (is.null(txt) || !nzchar(txt)) {
      showNotification("Could not read that file.", type = "error"); return()
    }
    p <- tryCatch(parse_readme(txt), error = function(e) NULL)
    if (is.null(p)) {
      showNotification("Could not parse that README.", type = "error"); return()
    }
    m <- p$meta

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
                           options = list(create = TRUE))
    }
    set_lic("license_code", m$license_code)
    set_lic("license_data", m$license_data)

    # Structural state (files / columns / scripts / packages / R version)
    rv$files        <- p$files
    rv$auto         <- p$auto
    rv$script_idx   <- which(is_script(p$files))
    rv$script_order <- if (length(p$script_order)) p$script_order else which(is_script(p$files))
    rv$root_name    <- if (nzchar(p$root_name)) p$root_name else NULL
    rv$folder       <- NULL
    rv$r_version    <- if (nzchar(p$r_version)) p$r_version else NULL

    rv$imp_desc       <- p$file_desc
    rv$imp_coldesc    <- p$col_desc
    rv$imp_units      <- p$units
    rv$imp_date       <- p$dates
    rv$imp_loc        <- p$locs
    rv$imp_scriptdesc <- p$script_desc

    if (!is.null(p$pkgs) && nrow(p$pkgs) > 0) {
      rv$pkgs     <- p$pkgs
      rv$pkg_diag <- list(folder = "(imported from README)",
                          n_total = length(p$files),
                          n_files = length(rv$script_idx),
                          filenames = basename(p$files[rv$script_idx]))
    } else {
      rv$pkgs <- NULL; rv$pkg_diag <- NULL
    }

    rv$import_msg <- sprintf(
      "Imported %d file%s, %d script%s, %d package%s%s.",
      length(p$files), if (length(p$files) == 1) "" else "s",
      length(rv$script_order), if (length(rv$script_order) == 1) "" else "s",
      if (is.null(rv$pkgs)) 0L else nrow(rv$pkgs),
      if (is.null(rv$pkgs) || nrow(rv$pkgs) == 0) "" else "s",
      if (!is.null(rv$r_version)) paste0(", R ", rv$r_version) else "")
    showNotification(rv$import_msg, type = "message", duration = 6)
  }

  observeEvent(input$import_md,    run_import())      # auto-import on upload
  observeEvent(input$reimport_btn, run_import())      # re-run on demand

  observeEvent(input$clear_import, {
    # title and contact are textInputs; the rest are textAreaInputs.
    updateTextInput(session, "title",   value = "")
    updateTextInput(session, "contact", value = "")
    for (id in c("description","abstract","instructions","additional_info",
                 "doi","citation_text","authors","affiliation","funders","acknowledgements"))
      updateTextAreaInput(session, id, value = "")
    updateSelectizeInput(session, "license_code", choices = license_choices, selected = "",
                         options = list(create = TRUE))
    updateSelectizeInput(session, "license_data", choices = license_choices, selected = "",
                         options = list(create = TRUE))
    rv$files <- character(0); rv$auto <- list()
    rv$script_idx <- integer(0); rv$script_order <- integer(0)
    rv$pkgs <- NULL; rv$pkg_diag <- NULL; rv$r_version <- NULL
    rv$root_name <- NULL; rv$folder <- NULL; rv$import_msg <- NULL
    rv$imp_desc <- list(); rv$imp_coldesc <- list(); rv$imp_units <- list()
    rv$imp_date <- list(); rv$imp_loc <- list(); rv$imp_scriptdesc <- list()
    showNotification("Cleared. Form reset to a blank README.", type = "message")
  })

  output$import_status <- renderUI({
    req(rv$import_msg)
    div(class = "alert alert-success py-2 px-3 small mb-0 mt-2",
        icon("circle-check"), " ", rv$import_msg,
        " Edit anything below, then export from the ", strong("Preview & Export"), " tab.")
  })

  # ── Load folder ──────────────────────────────────────────────────────────────
  observeEvent(input$folder_btn, {
    req(is.list(input$folder_btn))
    path <- parseDirPath(volumes, input$folder_btn)
    req(nzchar(path))
    rv$folder <- as.character(path)

    files <- list.files(rv$folder, recursive = TRUE, all.files = FALSE, no.. = TRUE)
    files <- files[!str_detect(files, "^\\.|/\\.")]
    if (!length(files)) {
      showNotification("No files found in that folder.", type = "warning"); return()
    }

    rv$files        <- files
    rv$auto         <- map(files, ~ auto_describe(file.path(rv$folder, .x)))
    rv$script_idx   <- which(is_script(files))
    rv$script_order <- rv$script_idx
    rv$root_name    <- basename(rv$folder)
    rv$r_version    <- NULL                  # use live R.version for a fresh folder

    # A fresh folder supersedes any imported defaults / packages.
    rv$pkgs <- NULL; rv$pkg_diag <- NULL; rv$import_msg <- NULL
    rv$imp_desc <- list(); rv$imp_coldesc <- list(); rv$imp_units <- list()
    rv$imp_date <- list(); rv$imp_loc <- list(); rv$imp_scriptdesc <- list()

    showNotification(paste0(length(files), " files loaded."), type = "message")
  })

  output$folder_label <- renderUI({
    req(rv$folder)
    tags$small(class = "text-muted", icon("folder"), " ", rv$folder)
  })

  output$file_summary_ui <- renderUI({
    req(length(rv$files) > 0)
    tagList(hr(), tags$small(class = "text-muted",
      icon("file"),  " ", length(rv$files), " files total", br(),
      icon("table"), " ", sum(map_lgl(rv$auto, Negate(is.null))), " tabular", br(),
      icon("code"),  " ", length(rv$script_idx), " scripts"))
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
        col_rows <- map(a$cols, function(col_d) {
          unit_cell <- if (col_d$type == "numeric")
            textInput(paste0("unit_", i, "_", col_d$name), label = NULL,
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
                    textInput(paste0("coldesc_", i, "_", col_d$name), label = NULL,
                              value = imp_get2(rv$imp_coldesc, f, col_d$name),
                              placeholder = "Column description")),
            tags$td(style = "width:15%;vertical-align:middle;padding:3px 4px", unit_cell)
          )
        })
        tagList(
          tags$hr(),
          tags$p(class = "text-muted small mb-1",
                 icon("table"), " ", a$nrow, " rows × ", a$ncol,
                 " cols — add a description for each column; units for numeric columns:"),
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
    if (!length(rv$script_order))
      return(p(class = "text-muted",
               "No scripts detected. Load a folder with .R/.Rmd files, or import a README."))
    n <- length(rv$script_order)
    map(seq_len(n), function(k) {
      i <- rv$script_order[k]
      f <- rv$files[i]
      up_btn <- if (k > 1)
        tags$button(class = "btn btn-sm btn-outline-secondary me-1",
                    onclick = sprintf("Shiny.setInputValue('script_move',{pos:%d,dir:'up'},{priority:'event'})", k),
                    icon("arrow-up"))
      else
        tags$button(class = "btn btn-sm btn-outline-secondary me-1", disabled = NA, icon("arrow-up"))
      down_btn <- if (k < n)
        tags$button(class = "btn btn-sm btn-outline-secondary",
                    onclick = sprintf("Shiny.setInputValue('script_move',{pos:%d,dir:'down'},{priority:'event'})", k),
                    icon("arrow-down"))
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
    pos <- input$script_move$pos; dir <- input$script_move$dir
    n   <- length(rv$script_order)
    if (dir == "up"   && pos > 1) rv$script_order[c(pos-1,pos)] <- rv$script_order[c(pos,pos-1)]
    if (dir == "down" && pos < n) rv$script_order[c(pos,pos+1)] <- rv$script_order[c(pos+1,pos)]
  })

  # ── Package scan ──────────────────────────────────────────────────────────────
  observeEvent(input$scan_pkgs, {
    req(rv$folder)
    result <- tryCatch(extract_packages(rv$folder),
      error = function(e) { showNotification(paste("Error:", e$message), type = "error"); NULL })
    if (!is.null(result)) { rv$pkgs <- result$pkgs; rv$pkg_diag <- result }
  })

  output$pkg_ui <- renderUI({
    req(rv$pkg_diag)
    d <- rv$pkg_diag
    diag_box <- div(class = "alert alert-secondary mt-3 small",
      tags$b("Diagnostic info"), br(),
      tags$b("Source: "), code(d$folder), br(),
      tags$b("Total files: "), d$n_total, br(),
      tags$b("R/Rmd/qmd files: "), d$n_files,
      if (d$n_files > 0)
        tagList(br(), tags$b("Files: "), paste(d$filenames, collapse = ", "))
    )
    if (is.null(rv$pkgs) || nrow(rv$pkgs) == 0)
      return(tagList(diag_box,
        p(class = "text-muted mt-2", "No packages found.")))
    tagList(diag_box, hr(),
      p(strong(nrow(rv$pkgs), " packages"), " | R ",
        code(rv$r_version %||% paste0(R.version$major, ".", R.version$minor))),
      tableOutput("pkg_table"))
  })

  output$pkg_table <- renderTable({
    req(rv$pkgs, nrow(rv$pkgs) > 0); rv$pkgs
  }, striped = TRUE, hover = TRUE)

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

  get_descriptions <- reactive({
    map(seq_along(rv$files), ~ input[[paste0("desc_", .x)]] %||% "")
  })

  get_units <- reactive({
    map(seq_along(rv$files), function(i) {
      a <- rv$auto[[i]]; if (is.null(a)) return(list())
      units <- list()
      for (col_d in a$cols) {
        if (col_d$type != "numeric") next
        val <- input[[paste0("unit_", i, "_", col_d$name)]]
        if (!is.null(val) && nzchar(trimws(val))) units[[col_d$name]] <- val
      }
      units
    })
  })

  get_col_descs <- reactive({
    map(seq_along(rv$files), function(i) {
      a <- rv$auto[[i]]; if (is.null(a)) return(list())
      descs <- list()
      for (col_d in a$cols) {
        val <- input[[paste0("coldesc_", i, "_", col_d$name)]]
        if (!is.null(val) && nzchar(trimws(val))) descs[[col_d$name]] <- val
      }
      descs
    })
  })

  get_file_extras <- reactive({
    map(seq_along(rv$files), function(i) {
      list(date = input[[paste0("collection_date_",     i)]] %||% "",
           loc  = input[[paste0("collection_location_", i)]] %||% "")
    })
  })

  # Read by FILE INDEX in run order, so values follow the script across reorders.
  get_script_descs <- reactive({
    map(rv$script_order, ~ input[[paste0("script_desc_", .x)]] %||% "")
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
      r_version    = rv$r_version
    )
  })

  output$preview    <- renderText({ readme_text() })
  output$export_btn <- downloadHandler(
    filename = function() "README.md",
    content  = function(f) writeLines(readme_text(), f)
  )
}
