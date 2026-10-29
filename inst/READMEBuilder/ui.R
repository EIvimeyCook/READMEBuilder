# inst/READMEBuilder/ui.R
# All objects from global.R (logo_svg, helpers, license_choices) are available here.

ui <- page_fluid(
  title = "READMEBuilder",
  theme = bs_theme(
    bootswatch = "flatly",
    primary    = "#1a3a52",
    base_font  = font_collection(font_google("Inter", local = FALSE),
                                 "system-ui", "-apple-system", "Segoe UI",
                                 "Roboto", "Helvetica Neue", "Arial", "sans-serif")
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
      padding: 1.5rem 1.8rem 5.5rem 1.8rem;   /* bottom room for .rb-download */
      background: #f8f9fa;
      min-height: 100vh;
      min-width: 0;
    }
    .rb-download {
      position: fixed;
      right: 1.5rem;
      bottom: 1.5rem;
      z-index: 1030;                           /* above content, below modals */
      background: #fff;
      padding: 0.5rem;
      border-radius: 10px;
      box-shadow: 0 4px 16px rgba(0,0,0,0.18);
    }
    /* Notifications share the bottom-right corner; lift them above the box. */
    #shiny-notification-panel { bottom: 4.5rem; }
    .rb-help-wrap {
      padding: 0.5rem 8px 1.2rem 8px;
      margin-top: 0.6rem;
      border-top: 1px solid rgba(255,255,255,0.12);
    }
    .rb-help-btn {
      width: 100%;
      color: rgba(255,255,255,0.8);
      background: rgba(255,255,255,0.08);
      border: 1px solid rgba(255,255,255,0.18);
      font-size: 0.82rem;
      text-align: left;
    }
    .rb-help-btn:hover {
      background: rgba(255,255,255,0.16);
      color: #fff;
    }
    .rb-step {
      border-left: 3px solid #2196a6;
      padding: 0.1rem 0 0.1rem 0.9rem;
      margin-bottom: 1rem;
    }
    .rb-step h6 { margin-bottom: 0.25rem; font-weight: 600; }
    .rb-step p  { margin-bottom: 0.25rem; font-size: 0.9rem; }
    .rb-two-col {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(min(420px, 100%), 1fr));
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
    .rb-import .card-header { background: #e8f4f6; }
    .rb-lic-picks { margin-top: -0.5rem; margin-bottom: 0.75rem; }
    .rb-chip { padding: 0.1rem 0.55rem; font-size: 0.78rem; margin: 0 0.25rem 0.25rem 0; }
    /* Wrap long paragraphs instead of one very wide sideways-scrolling line. */
    #preview { white-space: pre-wrap; overflow-wrap: anywhere; }
    /* Browser version: the drop zone for a project folder. */
    .rb-drop { border: 2px dashed #9fb3c2; border-radius: 8px; padding: 0.9rem 0.5rem;
               text-align: center; color: #1a3a52; background: #fff; line-height: 1.5; }
    .rb-drop.rb-drop-over { border-color: #2196a6; background: #e8f4f6; }
    /* Script descriptions fill their card rather than a fixed 300px. */
    #script_order_ui .flex-grow-1 { min-width: 0; }
    #script_order_ui .shiny-input-container, #script_order_ui textarea { width: 100% !important; }
    /* The side menu runs to the window edge. */
    body > .container-fluid { padding-left: 0; padding-right: 0; }
    /* Recorded models: wrap long values; notes keep their line breaks. */
    #models_table_ui td { white-space: normal; overflow-wrap: anywhere; min-width: 5rem; }
    #models_table_ui td.rb-notes { white-space: pre-line; }
    /* Phones and narrow windows: the menu sits above the content. */
    @media (max-width: 767.98px) {
      .rb-shell { flex-direction: column; }
      .rb-sidenav { width: 100% !important; min-height: 0; position: static; }
      .rb-sidenav .nav-pills { flex-direction: row !important; flex-wrap: wrap; }
      .rb-logo { display: none; }
      .rb-main { padding: 1rem 1rem 5.5rem 1rem; min-height: 0; }
      .rb-download { right: 0.75rem; bottom: 0.75rem; }
    }
  "))),

  # Clears a file input's text and progress bar after the server has dropped
  # the file (Clear), so it does not keep showing the old file's name.
  tags$script(HTML("
    Shiny.addCustomMessageHandler('rb_reset_file', function (id) {
      const el = document.getElementById(id);
      if (!el) return;
      el.value = '';
      const box = el.closest('.input-group');
      const txt = box && box.querySelector('input[type=text]');
      if (txt) txt.value = '';
      const bar = document.getElementById(id + '_progress');
      if (bar) bar.style.visibility = 'hidden';
    });
  ")),

  # Browser version, Choose folder. Where the browser has the File System
  # Access API (Chrome, Edge), showDirectoryPicker() is used: its prompt asks
  # to let the site VIEW the folder's files, which is what happens, whereas a
  # folder <input> makes Chrome ask whether to "upload" them. Skipped folders
  # (renv, .git, ...) are then never even opened. Elsewhere (Firefox, Safari)
  # the folder <input> is used and gives each file's path as
  # webkitRelativePath. Either way skipped and hidden files are dropped, the
  # rest go to the hidden folder_upload input with their paths in
  # input$folder_paths, and server.R rebuilds the folder. The drag-and-drop
  # part (and the loader) is used by the desktop app too.
  tags$script(HTML("
    const rbSkipDir = /^(renv|packrat|\\.Rproj\\.user|\\.git|\\.Rcheck|node_modules|__pycache__|\\.venv|venv|\\.quarto|__MACOSX)$/;
    const rbSkipPath = /(^|\\/)(renv|packrat|\\.Rproj\\.user|\\.git|\\.Rcheck|node_modules|__pycache__|\\.venv|venv|\\.quarto|__MACOSX)(\\/|$)|(^|\\/)\\./;

    // items: [{ file, path }], path including the chosen folder's name.
    function rbLoadFiles(items, nAll) {
      if (!items.length) {
        Shiny.notifications.show({ type: 'warning', html: nAll ?
          'No project files found: everything in that folder is in a skipped folder (renv, .git, …) or hidden.' :
          'That folder is empty.' });
        return;
      }
      // Shiny keeps only each upload's base name, so the paths go separately,
      // in the same order as the files.
      Shiny.setInputValue('folder_paths', items.map(it => it.path), { priority: 'event' });
      const dt = new DataTransfer();
      items.forEach(it => dt.items.add(it.file));
      const inp = document.getElementById('folder_upload');
      inp.files = dt.files;
      inp.dispatchEvent(new Event('change', { bubbles: true }));
    }

    // Walks a directory handle, skipping excluded and hidden entries.
    async function rbWalk(dir, prefix, out, count) {
      for await (const [name, h] of dir.entries()) {
        count.n++;
        if (name.startsWith('.') || (h.kind === 'directory' && rbSkipDir.test(name))) continue;
        if (h.kind === 'directory') await rbWalk(h, prefix + name + '/', out, count);
        else out.push({ file: await h.getFile(), path: prefix + name });
      }
    }

    $(document).on('click', 'label[for=folder_pick]', async function (e) {
      if (!window.showDirectoryPicker) return;          // default: the folder <input>
      e.preventDefault();
      let dir;
      try {
        dir = await window.showDirectoryPicker({ mode: 'read', id: 'readmebuilder' });
      } catch (err) {
        if (err && err.name === 'AbortError') return;    // the user cancelled
        document.getElementById('folder_pick').click();  // not allowed here: fall back
        return;
      }
      const items = [], count = { n: 0 };
      await rbWalk(dir, dir.name + '/', items, count);
      rbLoadFiles(items, count.n);
    });

    $(document).on('change', '#folder_pick', function () {
      const all = Array.from(this.files);
      this.value = '';
      const items = all.map(f => ({ file: f, path: f.webkitRelativePath || f.name }))
                       .filter(it => !rbSkipPath.test(it.path));
      rbLoadFiles(items, all.length);
    });

    // Drag and drop: a dropped folder is walked with webkitGetAsEntry()
    // (supported by every current browser), skipping excluded and hidden
    // entries without opening them. A dropped .zip goes to the zip upload.
    function rbReadAll(reader) {           // readEntries() returns batches
      return new Promise((resolve, reject) => {
        const all = [];
        const next = () => reader.readEntries(batch => {
          if (!batch.length) return resolve(all);
          all.push(...batch); next();
        }, reject);
        next();
      });
    }
    async function rbWalkEntry(entry, out, count) {
      count.n++;
      if (entry.name.startsWith('.') || (entry.isDirectory && rbSkipDir.test(entry.name))) return;
      if (entry.isDirectory) {
        for (const child of await rbReadAll(entry.createReader())) await rbWalkEntry(child, out, count);
      } else {
        const file = await new Promise((res, rej) => entry.file(res, rej));
        out.push({ file: file, path: entry.fullPath.replace(/^\\//, '') });
      }
    }
    $(document).on('dragenter dragover', '#folder_drop', function (e) {
      e.preventDefault(); $(this).addClass('rb-drop-over');
    });
    $(document).on('dragleave', '#folder_drop', function () { $(this).removeClass('rb-drop-over'); });
    $(document).on('drop', '#folder_drop', async function (e) {
      e.preventDefault(); $(this).removeClass('rb-drop-over');
      const dt = e.originalEvent.dataTransfer;
      const entries = Array.from(dt.items || []).map(it => it.webkitGetAsEntry && it.webkitGetAsEntry()).filter(Boolean);
      // A single .zip: hand it to the zip upload.
      if (entries.length === 1 && entries[0].isFile && /\\.zip$/i.test(entries[0].name)) {
        const zt = new DataTransfer(); zt.items.add(dt.files[0]);
        const zin = document.getElementById('zip_upload');
        zin.files = zt.files; zin.dispatchEvent(new Event('change', { bubbles: true }));
        return;
      }
      if (!entries.length || (entries.length > 1 || !entries[0].isDirectory)) {
        Shiny.notifications.show({ type: 'warning',
          html: 'Drop one project folder (the top level), or a single .zip.' });
        return;
      }
      const items = [], count = { n: 0 };
      await rbWalkEntry(entries[0], items, count);
      rbLoadFiles(items, count.n - 1);        // not counting the folder itself
    });
    // Dropping anywhere else must not make the browser open the file.
    $(document).on('dragover drop', function (e) {
      if (!$(e.target).closest('#folder_drop').length) e.preventDefault();
    });
  ")),

  # Browser version: remember across visits that the walkthrough was seen.
  if (is_web) tags$script(HTML("
    $(document).on('shiny:connected', function () {
      let seen = false;
      try { seen = window.localStorage.getItem('rb_seen_help') === '1'; } catch (e) {}
      Shiny.setInputValue('rb_seen_help', seen);
    });
    Shiny.addCustomMessageHandler('rb_mark_help', function (msg) {
      try { window.localStorage.setItem('rb_seen_help', '1'); } catch (e) {}
    });
  ")),

  # In the browser the app is served by a service worker, which the browser's
  # download manager bypasses, so a plain download link gets a 404. Fetch the
  # file through the page instead (which the service worker does answer) and
  # save it from memory under the name the server gives it. For the README
  # itself, while R is idle the copy server.R keeps in the page is saved at
  # once, so no wait can make the browser treat the save as unprompted.
  if (is_web) tags$script(HTML("
    let rbReadme = null;
    Shiny.addCustomMessageHandler('rb_readme', function (txt) { rbReadme = txt; });
    function rbSave(blob, name) {
      const url = URL.createObjectURL(blob);
      const tmp = document.createElement('a');
      tmp.href = url;
      tmp.download = name;
      document.body.appendChild(tmp);
      tmp.click();
      tmp.remove();
      setTimeout(function () { URL.revokeObjectURL(url); }, 10000);
    }
    document.addEventListener('click', async function (e) {
      const a = e.target.closest('a.shiny-download-link');
      if (!a) return;
      e.preventDefault();
      e.stopPropagation();
      const href = a.getAttribute('href');
      if (!href || a.classList.contains('disabled')) return;
      if (a.id === 'export_btn' && rbReadme !== null &&
          !document.documentElement.classList.contains('shiny-busy')) {
        // Same bytes as the download handler (writeLines adds a final newline).
        rbSave(new Blob([rbReadme + '\\n'], { type: 'text/markdown;charset=utf-8' }), 'README.md');
        return;
      }
      // R may be busy for a few seconds; show that the click was taken.
      const label = a.innerHTML;
      a.classList.add('disabled');
      a.innerHTML = 'Preparing…';
      try {
        const resp = await fetch(href);
        if (!resp.ok) throw new Error('HTTP ' + resp.status);
        const cd = resp.headers.get('Content-Disposition') || '';
        const m  = /filename\\*=UTF-8''([^;]+)/i.exec(cd) || /filename=\"?([^\";]+)\"?/i.exec(cd);
        rbSave(await resp.blob(), m ? decodeURIComponent(m[1]) : 'download');
      } catch (err) {
        if (window.Shiny && Shiny.notifications)
          Shiny.notifications.show({ html: 'The download failed (' + err.message + ').', type: 'error' });
      } finally {
        a.innerHTML = label;
        a.classList.remove('disabled');
      }
    }, true);
  ")),

  div(class = "d-flex rb-shell",

    # ── Side-nav ──────────────────────────────────────────────────────────────
    div(class = "rb-sidenav", style = "width:200px; flex-shrink:0;",
      div(class = "rb-logo", logo_svg),
      navset_pill_list(
        id = "main_nav", well = FALSE, widths = c(12, 12),
        nav_panel(tagList(icon("circle-info"), " Project Info"),  value = "tab_project",  NULL),
        nav_panel(tagList(icon("folder-open"), " Files"),          value = "tab_files",    NULL),
        nav_panel(tagList(icon("list-ol"),     " Script Order"),   value = "tab_scripts",  NULL),
        nav_panel(tagList(icon("box"),         " R Packages"),     value = "tab_packages", NULL),
        nav_panel(tagList(icon("diagram-project"), " Models"),     value = "tab_models",   NULL),
        nav_panel(tagList(icon("eye"),         " Preview & Export"), value = "tab_preview", NULL)
      ),
      div(class = "rb-help-wrap",
        actionButton("show_help", tagList(icon("circle-question"), " How to use this app"),
                     class = "btn btn-sm rb-help-btn")
      )
    ),

    # ── Main content ───────────────────────────────────────────────────────────
    div(class = "rb-main flex-grow-1",

      # 1 · Project Info ────────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_project'",

        # Import / edit an existing READMEBuilder README ──────────────────────────
        card(class = "mb-3 rb-import",
          card_header(icon("file-import"), " Edit an existing README"),
          card_body(
            p(class = "text-muted small mb-2",
              "Upload a ", code("README.md"), " previously made with READMEBuilder to ",
              "reload everything: project info, the file list, column descriptions & units, ",
              "script order, and the R / package versions. Then edit and re-export."),
            layout_column_wrap(width = "260px", gap = "0.75rem",
              fileInput("import_md", NULL,
                        accept = c(".md", ".markdown", "text/markdown"),
                        buttonLabel = "Choose README.md…",
                        placeholder = "No file selected"),
              div(class = "pt-1",
                actionButton("reimport_btn", "Import / Re-import",
                             class = "btn-primary", icon = icon("rotate")),
                actionButton("clear_import", "Clear",
                             class = "btn-outline-secondary ms-1", icon = icon("eraser"))
              )
            ),
            uiOutput("import_status")
          )
        ),

        div(class = "rb-two-col",
          card(
            card_header(icon("file-lines"), " Basic Details"),
            textInput("title", "Project title *",
                      placeholder = "Reproductive isolation in Drosophila melanogaster"),
            p(class = "small text-muted mb-2", icon("circle-info"),
              " Text fields accept Markdown. Line breaks are kept; leave a blank ",
              "line to start a new paragraph."),
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
            # Two separate licences (free-typed values allowed, e.g. "CC-BY-4.0").
            layout_column_wrap(width = "220px", gap = "0.75rem",
              div(
                selectizeInput("license_code", "Code license", choices = license_choices,
                               options = free_select_opts),
                license_quick_picks("license_code", license_picks_code,
                  "MIT and Apache 2.0 are permissive; GPL-3.0 requires derived code to stay open.")
              ),
              div(
                selectizeInput("license_data", "Data license", choices = license_choices,
                               options = free_select_opts),
                license_quick_picks("license_data", license_picks_data,
                  "Dryad requires CC0; Zenodo defaults to CC BY 4.0.")
              )
            )
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
            # Both versions: drop a folder (or zip) on the box, pick a folder, or
            # upload a zip. A dropped folder is read by the page (see the script
            # above) and needs no "upload" confirmation in any browser. To pick
            # a folder, the browser version uses the browser's folder chooser;
            # the desktop app browses the disk directly.
            div(id = "folder_drop", class = "rb-drop mb-2",
              icon("folder-open", class = "fa-lg"), br(),
              strong("Drag your project folder here"), br(),
              tags$span(class = "small", "(or a .zip)")),
            # Receives a dropped or picked folder's files; their paths arrive
            # as input$folder_paths.
            div(style = "display:none", fileInput("folder_upload", NULL, multiple = TRUE)),
            if (is_web)
              tags$label(class = "btn btn-outline-primary w-100 mb-0", `for` = "folder_pick",
                icon("folder-open"), " Choose folder…",
                tags$input(id = "folder_pick", type = "file", multiple = NA,
                           webkitdirectory = NA, style = "display:none"))
            else
              shinyDirButton("folder_btn", "Browse for folder…",
                             title = "Select your project folder",
                             class = "btn-primary w-100", icon = icon("folder-open")),
            # Only when launched with build_readme(), which records the
            # caller's working directory (runApp() itself moves into the app).
            if (!is.null(getOption("READMEBuilder.launch")$wd))
              div(title = getOption("READMEBuilder.launch")$wd,
                actionButton("use_wd", "Use working directory",
                             class = "btn-outline-primary w-100 mt-2",
                             icon = icon("location-crosshairs"))),
            p(class = "small text-muted text-center my-2", "or"),
            fileInput("zip_upload", NULL, accept = c(".zip", "application/zip"),
                      buttonLabel = "Upload .zip…", placeholder = "Zipped folder"),
            p(class = "small text-muted mb-0",
              "Choose the top level of your project (not a subfolder). To upload a zip: right-click the folder › Compress (macOS) or ",
              "Send to › Compressed folder (Windows).",
              if (!is_web) " A dropped folder or zip is copied into a temporary folder; Browse reads it where it is.",
              if (is_web) tagList(" ", strong("Your files stay on your computer:"),
                " they are read by this page and never sent anywhere. Choose folder… ",
                "may make your browser ask to \"upload\" the files (its standard ",
                "wording); dragging the folder in avoids that prompt.")),
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
            p("Scans ", code(".R"), " / ", code(".Rmd"), " / ", code(".qmd"), " / ",
              code(".Rnw"), " files for ", code("library()"), ", ", code("require()"), ", ",
              code("pacman::p_load()"), ", ", code("librarian::shelf()"), ", ",
              code("import::from()"), ", ", code("groundhog.library()"), ", and ",
              code("pkg::"), " calls, then resolves each version. If an ",
              code("renv.lock"), " is present, its recorded versions are used."),
            actionButton("scan_pkgs", "Scan for packages",
                         class = "btn-primary", icon = icon("magnifying-glass")),
            uiOutput("pkg_ui")
          )
        )
      ),

      # 5 · Models (optional MLast-style table) ──────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_models'",
        card(class = "mb-3",
          card_header(icon("diagram-project"), " Model location & specification (optional)"),
          card_body(
            div(class = "alert alert-info py-2 small mb-3",
              tags$strong("Optional — but worth filling in."),
              " Leave this tab empty and no Models section is added to the README.",
              " Completing it, though, is one of the most useful things you can do",
              " for reproducibility: it maps each analysis in your write-up to the",
              " data columns it used and to the code that produced it, which is",
              " exactly the link that is usually missing when someone tries to",
              " reproduce a result.",
              tags$br(), tags$br(),
              "Inspired by the Model Location and Specification Table (MLast)",
              " proposed in ",
              tags$a(href = "https://doi.org/10.64898/2026.04.07.26350286",
                     target = "_blank",
                     "Jones et al. (2026), \"Challenges in the Computational ",
                     "Reproducibility of Linear Regression Analyses\""),
              ". Their table uses a single \"Location\" column; here that is split",
              " into separate methods, results, and code locations, since those are",
              " three different places and conflating them is ambiguous."),
            p(class = "text-muted small",
              "For each analysis, record the outcome and predictors (mapped to the ",
              "actual data columns), and where it is described, where the results ",
              "are reported, and where the code lives."),
            div(class = "rb-two-col",
              textInput("model_outcome_paper", "Outcome (as named in the paper)",
                        placeholder = "e.g. Systolic Blood Pressure"),
              textInput("model_outcome_data", "Outcome (data column name)",
                        placeholder = "e.g. sbp")
            ),
            textInput("model_predictors", "Predictors (data column names, comma-separated)",
                      placeholder = "e.g. age, sex, bmi_category"),
            div(class = "rb-two-col",
              selectizeInput("model_test_type", "Test / model type",
                # "" first so the box starts (and is reset after "Add model") empty.
                choices = c("", "Linear Regression", "Logistic Regression", "Correlation",
                            "ANOVA", "Mixed Model", "Other"),
                options = free_select_opts),
              textInput("model_methods_loc", "Methods location",
                        placeholder = "e.g. Methods, p.4, para 2")
            ),
            div(class = "rb-two-col",
              textInput("model_results_loc", "Results location",
                        placeholder = "e.g. Table 2, p.7"),
              div(
                textInput("model_code_loc", "Code location (script:line)",
                          placeholder = "e.g. analysis.R:42"),
                actionButton("model_suggest_code", "Suggest from loaded scripts",
                             class = "btn-outline-secondary btn-sm mb-2",
                             icon = icon("magnifying-glass"))
              )
            ),
            textAreaInput("model_notes", "Notes", rows = 2,
                          placeholder = "e.g. Type III SS, reference category = Normal"),
            actionButton("add_model", "Add model", class = "btn-primary",
                         icon = icon("plus")),
            actionButton("clear_models", "Clear all",
                         class = "btn-outline-danger ms-1", icon = icon("trash"))
          )
        ),
        card(
          card_header(icon("table-list"), " Recorded models"),
          card_body(uiOutput("models_table_ui"))
        )
      ),

      # 6 · Preview & Export ─────────────────────────────────────────────────────
      conditionalPanel("input.main_nav === 'tab_preview'",
        card(
          card_header(icon("eye"), " README.md preview"),
          card_body(
            p(class = "text-muted small",
              "Raw Markdown — copy it, or use the Download button in the ",
              "bottom-right corner to save it as ", code("README.md"), "."),
            verbatimTextOutput("preview")
          )
        )
      )

    ) # end rb-main
  ),  # end d-flex

  # Always-visible download box, so the README can be saved from any tab.
  div(class = "rb-download",
    downloadButton("export_btn", "Download README.md",
                   class = "btn-success", icon = icon("download"))
  )
)
