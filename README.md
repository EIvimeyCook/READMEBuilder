# READMEBuilder

<!-- badges: start -->
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE.md)
<!-- badges: end -->

READMEBuilder is an R package providing an interactive Shiny app that guides researchers through building a high-quality, reproducible README file for research datasets and code.

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

This opens the Shiny app in your browser. The app walks through five steps:

1. **Project Info** — title, abstract, DOI(s), licence, authors, affiliations, funders
2. **Files** — browse to your project folder; tabular files (CSV, TSV, XLSX) are
   automatically described (column types, ranges, levels, NAs); add descriptions
   and units per column; specify collection dates and locations
3. **Script Order** — drag scripts into the order they should be run; add descriptions
4. **R Packages** — scans `.R`, `.Rmd`, and `.qmd` files for `library()` /
   `require()` calls and resolves the installed version of each package
5. **Preview & Export** — live Markdown preview with one-click download of `README.md`

## Example output

The app generates a `README.md` containing:

- Title and DOI/licence badges
- Description, Abstract, Instructions
- Author list with ORCIDs, affiliations, funding sources
- Per-file variable tables with auto-summaries, descriptions, and units
- Ordered script list with descriptions
- R version and full package dependency table

## AI Declaration

Claude Sonnet 4.6 was used in the development of this package.
