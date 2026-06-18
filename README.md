# READMEBuilder

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE.md)
<!-- badges: end -->

READMEBuilder is an R package providing an interactive Shiny app that guides
researchers through documenting a whole project, **both the data and the code**,
in a single high-quality `README.md` to support reproducible research. It also
lets you re-open a README the app made earlier and keep editing it.

Good documentation is what makes an analysis reproducible: not just what the data
columns mean, but which scripts to run and in what order, and which package (and
R) versions produced the results. READMEBuilder captures all of this for you. It
summarises every data file, records the script run order, detects your
dependencies and their installed versions, maps the project's directory
structure, and assembles everything into a tidy Markdown file ready to archive or
share (for example on Zenodo, the OSF, Dryad, or GitHub).

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

This opens the Shiny app in your browser. The app is organised into five steps,
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
   `library()` / `require()` calls and resolves the installed version of each
   package.
5. **Preview & Export:** a live Markdown preview, with one-click download of
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
prose `.txt`) are quietly skipped and offered as free-text instead, so a single
odd file never stops the app.

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

## Editing an existing README

On the **Project Info** tab, upload a `README.md` previously produced by
READMEBuilder and click **Import / Re-import**. The app parses the file and
repopulates the whole form (project info, the file list and directory map,
per-column descriptions and units, the script run order and descriptions, and
the R / package versions) so you can edit and re-export *without* needing the
original data folder. **Clear** resets everything to a blank README.

The importer is deliberately tolerant of older or hand-edited files (for example
a `## Funders` or `## Funding` heading, and single- or split-licence wording).
File-level content is reconstructed from the README itself; to refresh the
auto-summaries from the underlying data, re-load the project folder on the
**Files** tab.

## Privacy

`build_readme()` launches a Shiny app that runs locally on your computer. Folder
browsing, file reading, and package resolution all happen on your machine, and
nothing is uploaded to any server.

## Requirements

READMEBuilder depends on the following R packages, installed automatically with
the command above:

`shiny`, `bslib`, `tidyverse`, `readxl`, `stringr`, `purrr`, `shinyFiles`, `fs`.

## Tips and limitations

- The directory map lists directories before files and sorts each level
  alphabetically, so the order in the map may differ from the order files appear
  on disk.
- A column's **description** and **units** are typed by you; only the **summary**
  column is generated automatically.
- Importing reloads metadata and structure but not the data itself. Re-load the
  folder if you want summaries recomputed from current files.

## Bug reports and contributions

Please file issues and feature requests at
<https://github.com/EIvimeyCook/READMEBuilder/issues>. Pull requests are welcome.

## Citation

If READMEBuilder helps with your work, please cite it (adjust the year as
needed):

> Ivimey-Cook, E. R. (2026). *READMEBuilder: Build high-quality READMEs for
> reproducible research datasets and code.* R package.
> <https://github.com/EIvimeyCook/READMEBuilder>

## License

Released under the [MIT License](LICENSE.md).

## AI Declaration

Claude Sonnet 4.6 nad Opus 4.8 were used in the development of this package.
