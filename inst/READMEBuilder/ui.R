# inst/READMEBuilder/ui.R
# All objects from global.R (logo_svg, helpers) are available here.

ui <- page_fluid(
  title = "READMEBuilder",
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#1a3a52",
    base_font  = font_google("Inter")
  ),

  tags$head(tags$style(HTML("
    .rb-sidenav {
      background: #1a3a52;
      min-height: 100vh;
      padding: 0;
      position: sticky;
      top: 0;
      overflow-y: auto;
    }
    .rb-logo {
      padding: 1rem 1rem 0.8rem 1rem;
      border-bottom: 1px solid rgba(255,255,255,0.12);
      margin-bottom: 0.4rem;
    }
    .rb-sidenav .nav-pills .nav-link {
      color: rgba(255,255,255,0.72);
      border-radius: 6px;
      margin: 2px 8px;
      padding: 0.55rem 0.9rem;
      font-size: 0.88rem;
      font-weight: 500;
      white-space: nowrap;
      transition: background 0.15s, color 0.15s;
    }
    .rb-sidenav .nav-pills .nav-link:hover {
      background: rgba(255,255,255,0.1);
      color: #fff;
    }
    .rb-sidenav .nav-pills .nav-link.active {
      background: #2196a6;
      color: #fff;
      font-weight: 600;
    }
    .rb-sidenav .nav-pills .nav-link .fa,
    .rb-sidenav .nav-pills .nav-link svg {
      width: 1em;
      margin-right: 0.5em;
      opacity: 0.9;
    }
    .rb-main {
      padding: 1.5rem 1.8rem;
      background: #f8f9fa;
      min-height: 100vh;
    }
    .rb-two-col {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(420px, 1fr));
      gap: 1rem;
      align-items: start;
    }
    .card { box-shadow: 0 1px 4px rgba(0,0,0,0.07); }
    .card-header { font-weight: 600; font-size: 0.93rem; }
    textarea { resize: vertical; }
    .rb-tree {
      font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
      font-size: 0.8rem;
      line-height: 1.45;
      background: #f4f6f8;
      padding: 0.75rem 1rem;
      border-radius: 6px;
      white-space: pre;
      overflow-x: auto;
      margin: 0;
    }
  "))),

  div(class = "d-flex",

    # ── Side-nav ──────────────────────────────────────────────────────────────
    div(class = "rb-sidenav", style = "width:200px; flex-shrink:0;",
      div(class = "rb-logo", logo_svg),
      navset_pill_list(
        id = "main_nav", well = FALSE,
        nav_panel(tagList(icon("circle-info"), " Project Info"),  value = "tab_project",  NULL),
        nav_panel(tagList(icon("folder-open"), " Files"),          value = "tab_files",    NULL),
        nav_panel(tagList(icon("list-ol"),     " Script Order"),   value = "tab_scripts",  NULL),
        nav_panel(tagList(icon("box"),         " R Packages"),     value = "tab_packages", NULL),
        nav_panel(tagList(icon("eye"),         " Preview & Export"), value = "tab_preview", NULL)
      )
    ),

    # ── Main content ───────────────────────────────────────────────────────────
    div(class = "rb-main flex-grow-1",

      # 1 · Project Info ────────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_project'",
        div(class = "rb-two-col",
          card(
            card_header(icon("file-lines"), " Basic Details"),
            textInput("title", "Project title *",
                      placeholder = "Reproductive isolation in Drosophila melanogaster"),
            textAreaInput("description", "Description", rows = 3,
                          placeholder = "A concise description of what this project/dataset is."),
            textAreaInput("abstract", "Abstract", rows = 4,
                          placeholder = "The full abstract — aims, methods, main findings."),
            textAreaInput("instructions", "Instructions for use", rows = 3,
                          placeholder = "How to reproduce the analysis. E.g. 'Run scripts in order. Requires R ≥ 4.3.'"),
            textAreaInput("additional_info", "Additional information", rows = 3,
                          placeholder = "Known issues, limitations, related datasets, links to protocols, etc."),
            textAreaInput("doi", "DOI(s) — separate multiple with \";\"", rows = 2,
                          placeholder = "10.1234/journal.xyz; 10.5678/zenodo.abc"),
            textAreaInput("citation_text", "Full citation text", rows = 3,
                          placeholder = "Smith J, Doe J (2024). Title. Journal. 10.1234/xyz"),
            selectInput("license", "License",
                        choices = c(
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
                        ))
          ),
          card(
            card_header(icon("users"), " People & Funding"),
            textAreaInput("authors", "Authors — one per line (include ORCID if available)", rows = 4,
                          placeholder = "Jane Smith (0000-0001-2345-6789)\nJohn Doe (0000-0002-3456-7890)"),
            textAreaInput("affiliation", "Affiliations — one per line", rows = 3,
                          placeholder = "Department of Biology, University of Example\nAnother Institute, Another University"),
            textInput("contact", "Corresponding author / contact email",
                      placeholder = "j.smith@example.ac.uk"),
            textAreaInput("funders", "Funders & grant numbers — one per line", rows = 3,
                          placeholder = "NERC — NE/X000000/1\nERC Starting Grant — 123456"),
            textAreaInput("acknowledgements", "Additional acknowledgements", rows = 2)
          )
        )
      ),

      # 2 · Files ───────────────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_files'",
        layout_sidebar(fillable = FALSE,
          sidebar = sidebar(title = "Load a folder", width = 240,
            shinyDirButton("folder_btn", "Browse for folder…",
                           title = "Select your project folder",
                           class = "btn-primary w-100", icon = icon("folder-open")),
            br(),
            uiOutput("folder_label"),
            hr(),
            helpText(
              icon("table"), " CSV / TSV / XLSX → auto-described", br(), br(),
              icon("code"),  " R / Rmd → ordered in Script Order",  br(), br(),
              icon("file"),  " Everything else → describe freely"
            ),
            uiOutput("file_summary_ui")
          ),
          # Directory map (live preview) sits above the per-file cards.
          uiOutput("dir_map_ui"),
          uiOutput("files_ui")
        )
      ),

      # 3 · Script Order ─────────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_scripts'",
        card(
          card_header(icon("list-ol"), " Run order for code scripts"),
          card_body(
            p("Use the arrows to define the order scripts should be run.",
              "Add a short description for each."),
            uiOutput("script_order_ui")
          )
        )
      ),

      # 4 · R Packages ───────────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_packages'",
        card(
          card_header(icon("box"), " Detected R packages"),
          card_body(
            p("Scans all ", code(".R"), " / ", code(".Rmd"), " / ", code(".qmd"),
              " files for ", code("library()"), " and ", code("require()"),
              " calls, then resolves installed versions."),
            actionButton("scan_pkgs", "Scan for packages",
                         class = "btn-primary", icon = icon("magnifying-glass")),
            uiOutput("pkg_ui")
          )
        )
      ),

      # 5 · Preview & Export ─────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_preview'",
        card(
          card_header(
            icon("eye"), " README.md preview",
            downloadButton("export_btn", " Download README.md",
                           class = "btn-sm btn-success ms-auto",
                           icon  = icon("download"))
          ),
          card_body(
            p(class = "text-muted small",
              "Raw Markdown — copy or download as ", code("README.md"), "."),
            verbatimTextOutput("preview")
          )
        )
      )

    ) # end rb-main
  )   # end d-flex
)
