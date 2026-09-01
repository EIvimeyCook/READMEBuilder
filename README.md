<p align="center">
  <img src="https://github.com/EIvimeyCook/READMEBuilder/blob/main/man/figures/logo.png" width = "200"/>
</p>

<div align="center">
 <h1>READMEBuilder</h1>
</div>

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE.md)
<!-- badges: end -->

READMEBuilder is an R package with an interactive Shiny app that turns a project folder into a single `README.md` documenting both **the data and the code**. 

Good documentation is what makes an analysis reproducible: not just what the data
columns mean, but which scripts to run and in what order, and which package (and
R) versions produced the results. READMEBuilder captures all of this for you. It
summarises every data file, records the script run order, detects your
dependencies and their installed versions, maps the project's directory
structure, and assembles everything into a tidy Markdown file ready to archive or
share (for example on Zenodo, Dryad, or GitHub).

## Features

- **Documents data *and* code together.** Column-level data summaries sit
  alongside the script run order, dependencies, and environment that make an
  analysis reproducible.
- **Guided, five-step workflow** from project metadata to a downloadable `README.md`.
- **Automatic data description.** Point at a folder and every tabular file is
  summarised column-by-column (types, ranges, levels, missing values).
- **Script run order.** Record the exact order scripts should be executed, each
  with a short description.
- **Dependency and environment capture.** Scans your scripts and resolves the
  installed version of every package, plus the R version.
- **Directory map.** An ASCII tree of your project, embedded in the README.
- **Separate code and data licences.** Pick from a list or type your own.
- **Model location and specification (MLast).** Optionally record each analysis
  and link it to the data, with *separate* fields for where the method is
  described, where the results are reported, and where the code lives.
- **Dependency libraries are skipped.** Restored `renv`/`packrat` libraries are
  excluded from scanning, so loading a project folder stays fast.
- **Built-in walkthrough.** A **How to use this app** button explains each tab;
  it also opens automatically the first time you run the app.
- **Re-open and edit.** Import a README the app made earlier and continue where
  you left off, without the original data folder.
- **Runs entirely on your machine.** Files are read locally and never uploaded.

## Installation

READMEBuilder is not on CRAN. Install the development version from GitHub:

```r
install.packages("devtools")
devtools::install_github("EIvimeyCook/READMEBuilder")
```

## Usage

```r
library(READMEBuilder)
build_readme()
```

This opens the Shiny app in your browser. The app is organised into six steps,
shown in the left-hand navigation:

1. **Project Info:** title, description, abstract, instructions, DOI(s),
   citation text, authors (with ORCIDs), affiliations, contact, funders, and
   acknowledgements. Code and data are licensed **separately**: choose each from
   a list or type your own value (for example `CC-BY-4.0`). You can also upload
   an existing README here to reload and edit it (see
   [Editing an existing README](#editing-an-existing-readme)).
2. **Files:** browse to your project folder. A directory map of the folder is
   shown and included in the export. Tabular files are described automatically
   (see [What gets auto-detected](#what-gets-auto-detected)); add a description
   and a unit for each column, plus the date(s) and location of data collection.
3. **Script Order:** reorder your code with the up/down arrows to record the
   sequence it should be run in, and add a short description of what each script
   does.  
4. **R Packages:** scans every R script (`.R`, `.Rmd`, `.qmd`, `.Rnw`) for
   `library()`, `require()`, `requireNamespace()`, `pacman::p_load()`, and
   `pkg::fun` calls, then resolves each package's version. If the folder contains
   an `renv.lock`, the versions (and R version) recorded there are used in
   preference to what is installed.  
5. **Models (optional):** record each analysis and where it lives — see
   [Recording models (MLast)](#recording-models-mlast). Leave this tab empty and
   no Models section is added.
6. **Preview & Export:** a live Markdown preview, with one-click download of
   `README.md`.

## What gets auto-detected

When you load a folder, files are sorted into three groups by extension:

| Group | Extensions | What happens |
| :---- | :--------- | :----------- |
| Tabular data | `.csv` `.tsv` `.txt` `.xlsx` `.xls` | Read and summarised column-by-column |
| Code / scripts | `.R` `.Rmd` `.qmd` `.Rnw` | Listed on **Script Order**; scanned for packages |
| Everything else | any | Listed under **Other Files** for a free-text description |

Each column in a tabular file gets an automatic summary:

| Column type | Auto-summary |
| :---------- | :----------- |
| Numeric | range, mean, and number of `NA`s |
| Categorical (character / factor) | the levels (if ≤ 10) or a unique-value count, and `NA`s |
| Date / datetime | min–max range and `NA`s |
| Logical | counts of `TRUE`, `FALSE`, and `NA` |

Files that look tabular by extension but do not parse cleanly (for example a
prose `.txt`) are quietly skipped and offered as free-text instead.

## What the output looks like

The generated `README.md` includes a title, DOI badges, separate **code** and
**data** licence badges, the project metadata, a directory map, per-file variable
tables, the ordered script list, and an R environment table.

A directory map looks like this:

````text
MyProject/
├── data/
│   └── data.csv
├── analysis.R
├── report.Rmd
└── README.md
````

Each tabular file gets a variable table:

```text
**Dimensions:** 150 rows × 2 columns

| Column | Type | Description | Units | Summary |
| :----- | :--- | :---------- | :---- | :------ |
| `habitat` | categorical | Habitat type | | levels: A, B, C, D, E \| NAs: 0 |
| `caterpillar_count` | numeric | Caterpillars per survey | count | range 2–36 \| mean 15.11 \| NAs: 0 |
```

And the code and environment are recorded so the analysis can be rerun:

```text
## Code
Scripts should be run in the following order:

1. **`analysis.R`**
   Load and clean data, fit the model, produce Figure 1.
2. **`report.Rmd`**
   Render the results into a report.

## R Environment
**R version:** 4.5.2

| Package | Version |
| :------ | :------ |
| `dplyr`   | 1.1.4 |
| `ggplot2` | 3.5.1 |
```

If you fill in the optional **Models** tab, a models table is included too:

```text
## Models

| Outcome (paper) | Outcome (data) | Predictors (data) | Test | Methods location | Results location | Code location | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Proportion scrounging | PropPS | Opponent_propPS_average | Linear Regression | Methods, p.4 | Table 2, p.7 | sem.R:3 | Type III SS |
```

## Getting help inside the app

The **How to use this app** button at the bottom of the left-hand navigation
opens a short walkthrough of what each tab is for. It also opens by itself the
first time you launch the app, and then not again — the fact that you have seen
it is recorded in a small marker file under `tools::R_user_dir("READMEBuilder",
"config")`. Delete that file to see the walkthrough again on next launch.

## Recording models (MLast)

The **Models** tab is entirely optional — leave it empty and nothing is added to
your README. It is, however, one of the most useful things you can fill in. It
records a *Model Location and Specification Table* (MLast): for each analysis,
what was modelled, which data columns it used, and where to find it. 

The idea is adapted from the Model Location and Specification Table proposed by
Jones et al. ([2026](https://doi.org/10.64898/2026.04.07.26350286)), *Challenges
in the Computational Reproducibility of Linear Regression Analyses*, with one
deliberate change.

**"location" is split into three separate fields.** The original proposal
has a single `Location` column, which leaves it ambiguous whether you should cite
where a method is *described* or where its results are *reported*. Here they are
distinct, and a third field records the code:

| Field | What it records | Example |
| :---- | :-------------- | :------ |
| Outcome (paper) | Outcome as named in the manuscript | `Proportion scrounging` |
| Outcome (data) | Matching column name in the data | `PropPS` |
| Predictors (data) | Predictor column names | `Opponent_propPS_average` |
| Test | Model or test type | `Linear Regression` |
| Methods location | Where the analysis is **described** | `Methods, p.4, para 2` |
| Results location | Where the output is **reported** | `Table 2, p.7` |
| Code location | Script and line | `sem.R:3` |
| Notes | Anything else | `Type III SS` |

Rather than typing line numbers by hand (they go stale as soon as a script is
edited), **Suggest from loaded scripts** searches the scripts in your loaded
project folder for the outcome or first predictor and offers each match as a
`script:line` option with a preview of the line. Load a project folder on the
**Files** tab first.

The result is written to the README as a `## Models` table, and is restored when
you re-import that README later.

## Dependency folders are skipped

If you have run `renv::restore()`, your project folder contains a full local copy
of every dependency's source under `renv/library` — often tens of thousands of
files. Scanning those is slow, treats every package's internal `.R` files as if
they were your own scripts, and pollutes the detected dependency list.

READMEBuilder therefore skips the following when loading a folder, scanning for
packages, and searching for code locations:

```text
renv    packrat    .Rproj.user    .git      .Rcheck
venv    .venv      node_modules   .quarto   __pycache__
```

The whole `renv/` directory is skipped, not just `renv/library`: `renv/activate.R`
is a bootstrap script renv generates rather than anything you wrote, and its own
`requireNamespace("renv")` call would otherwise add renv to your dependency list
and put `activate.R` in your script run order.

`renv.lock` is **not** affected — it sits at the project root rather than inside
`renv/`, so package and R versions are still read from it exactly as before.

## Editing an existing README

On the **Project Info** tab, upload a `README.md` previously produced by
READMEBuilder and click **Import / Re-import**. The app parses the file and
repopulates the whole form (project info, the file list and directory map,
per-column descriptions and units, the script run order and descriptions, any
recorded models, and the R / package versions) so you can edit and re-export
*without* needing the original data folder. **Clear** resets everything to a blank README.

The importer is deliberately tolerant of older or hand-edited files (for example
a `## Funders` or `## Funding` heading, and single- or split-licence wording).
File-level content is reconstructed from the README itself; to refresh the
auto-summaries from the underlying data, re-load the project folder on the
**Files** tab.

## Privacy

`build_readme()` launches a Shiny app that runs locally on your computer. Your
files and their contents stay on your machine: folder browsing, file reading, and
package resolution all happen locally, and nothing you load is uploaded to any
server.

The one exception is cosmetic. The app's theme uses the Inter font from Google
Fonts, so on first launch it fetches that font from Google's servers (and caches
it afterwards). No file data is included in that request. If you want zero
external calls, swap the theme to a system font.

## Requirements

READMEBuilder depends on the following R packages, installed automatically with
the command above:

`shiny`, `bslib`, `tidyverse`, `readxl`, `stringr`, `purrr`, `shinyFiles`, `fs`,
and `jsonlite` (used to read `renv.lock`; the lockfile step is skipped if it is
not installed).

## Tips and limitations

- The directory map lists directories before files and sorts each level
  alphabetically, so the order in the map may differ from the order files appear
  on disk.
- A column's **description** and **units** are typed by you; only the **summary**
  column is generated automatically.
- Importing reloads metadata and structure but not the data itself. Re-load the
  folder if you want summaries recomputed from current files.
- The **Models** tab is filled in by you. Only the code location can be
  suggested automatically, and only for scripts in the loaded folder.

## Bug reports and contributions

Please file issues and feature requests at
<https://github.com/EIvimeyCook/READMEBuilder/issues>. Pull requests are welcome.

## Citation

If READMEBuilder helps with your work, please cite it:

> Ivimey-Cook, E. R. (2026). *READMEBuilder: Build high-quality READMEs for
> reproducible research* R package.
> <https://github.com/EIvimeyCook/READMEBuilder>

A machine-readable [`CITATION.cff`](CITATION.cff) is included, so GitHub's
"Cite this repository" button gives formatted APA and BibTeX.

## License

Released under the [MIT License](LICENSE.md).

## AI Declaration

Claude Sonnet 4.6 and Opus 4.8 were used in the development of this package.
