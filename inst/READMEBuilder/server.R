# inst/READMEBuilder/server.R

server <- function(input, output, session) {

  volumes <- c(Home = fs::path_home(), Root = "/")
  shinyDirChoose(input, "folder_btn", roots = volumes, session = session,
                 restrictions = system.file(package = "base"))

  rv <- reactiveValues(
    folder       = NULL,
    files        = character(0),
    auto         = list(),
    script_idx   = integer(0),
    script_order = integer(0),
    pkgs         = NULL,
    pkg_diag     = NULL
  )

  # Root label used for the directory map (folder basename, or a fallback).
  tree_root <- reactive({
    if (!is.null(rv$folder) && nzchar(rv$folder)) basename(rv$folder) else "project"
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
          "Tree of the loaded folder. This block is included in the exported ",
          code("README.md"), " under ", strong("Directory Structure"), "."),
        tags$pre(class = "rb-tree", paste(tree, collapse = "\n"))
      ))
  })

  # ── File cards ───────────────────────────────────────────────────────────────
  output$files_ui <- renderUI({
    if (!length(rv$files))
      return(div(class = "text-muted mt-4 text-center",
                 icon("folder-open", class = "fa-2x mb-2"), br(),
                 "Use the sidebar to load a project folder."))

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
                    textInput(paste0("coldesc_", i, "_", col_d$name),
                              label = NULL, placeholder = "Column description")),
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
                      placeholder = "e.g. June–August 2022"),
            textInput(paste0("collection_location_", i), "Location of data collection",
                      placeholder = "e.g. Cairngorms NP, Scotland, UK")
          )
        )
      }

      card(class = "mb-3",
        card_header(tags$code(f), badge),
        card_body(
          textAreaInput(paste0("desc_", i), "Description",
                        placeholder = "What does this file contain, how was it produced, any caveats?",
                        rows = 2),
          units_ui
        )
      )
    })
  })

  # ── Script order ──────────────────────────────────────────────────────────────
  output$script_order_ui <- renderUI({
    if (!length(rv$script_order))
      return(p(class = "text-muted",
               "No scripts detected. Load a folder with .R or .Rmd files."))
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
            textAreaInput(paste0("script_desc_", k), label = NULL,
                          placeholder = "What does this script do?", rows = 2)
          )))
      )
    })
  })

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
      tags$b("Folder searched: "), code(d$folder), br(),
      tags$b("Total files in folder: "), d$n_total, br(),
      tags$b("R/Rmd/qmd files found: "), d$n_files,
      if (d$n_files > 0)
        tagList(br(), tags$b("Files scanned: "), paste(d$filenames, collapse = ", "))
    )
    if (nrow(rv$pkgs) == 0)
      return(tagList(diag_box,
        p(class = "text-muted mt-2",
          "No packages found. Check the folder above — if 0 R files were found, ",
          "scripts may not contain ", code("library()"), " or ", code("require()"), " calls.")))
    tagList(diag_box, hr(),
      p(strong(nrow(rv$pkgs), " packages detected"), " | R ",
        code(paste0(R.version$major, ".", R.version$minor))),
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
         license = input$license, authors = input$authors,
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

  get_script_descs <- reactive({
    map(seq_along(rv$script_order), ~ input[[paste0("script_desc_", .x)]] %||% "")
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
      root         = tree_root()
    )
  })

  output$preview    <- renderText({ readme_text() })
  output$export_btn <- downloadHandler(
    filename = function() "README.md",
    content  = function(f) writeLines(readme_text(), f)
  )
}
