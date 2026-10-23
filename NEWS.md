# READMEBuilder (development version)

Version 0.2.1, on the `development` branch. The stable version on `main` is
0.2.0. Check which one you have with `packageVersion("READMEBuilder")`.

## New features

* One-click licence buttons for the common choices: MIT, Apache 2.0 or GPL-3.0
  for code, and CC0 or CC BY 4.0 for data.
* The package table has a **Source** column saying where each version came from
  (`renv.lock`, `installed` or `not installed`). If a project mixes versions from
  `renv.lock` with installed ones, a note under the table says so.
* For Excel workbooks with more than one sheet, the README lists every sheet
  name (the first sheet is still the one summarised).
* Scripts in subfolders are listed by their path within the project (e.g.
  `analysis/clean.R`), so two scripts with the same name can be told apart.
* Importing a README that READMEBuilder did not write now asks before replacing
  everything in the form.
* After importing a README, "Scan packages" explains that there is no folder to
  scan instead of doing nothing, and keeps the imported package table.

## Bug fixes

* DOI and licence badges broke for any value containing `-` or `_` (e.g.
  `10.1111/2041-210X.13118`, `GPL-3.0`, `CC BY-NC 4.0`).
* A DOI pasted as `https://doi.org/...` or `doi:...` produced a doubled link.
* Re-importing a README added every DOI found anywhere in the file (citation,
  additional information, model notes) to the DOI field, so badges multiplied
  with each import and export.
* The citation was dropped when no DOI was given, and multi-line citations were
  cut to their first line on re-import.
* Reordering scripts with the arrow buttons wiped every script description.
* Semicolon-delimited CSVs were read as a single column, and prose `.txt` files
  were summarised as if they were tables. A `.txt` is now only treated as a
  table if it is tab-delimited; anything else is listed under **Other Files**.
* The package scanner counted packages mentioned in comments at the end of a
  line, inside strings, and in the prose of R Markdown / Quarto files. Calls
  such as `library(pkg, character.only = TRUE)`, where the name is a variable,
  are no longer counted as a package called `pkg`. `p_load(char = c(...))` is
  now read.
* A column name containing `:` (e.g. `time:s`) crashed the session.
* Text that looked like an HTML tag (e.g. `<Title>` or a factor level `<test>`)
  disappeared when the README was viewed on GitHub.
* Export then import did not always give back what was entered: a `## ` heading
  or `---` typed inside a text field split it into sections, the generated
  footer leaked into the last section, script descriptions lost their line
  breaks, and a file description starting with bold text was cut short.
* A bullet typed at the start of a line (e.g. `- Jane`) was exported as a nested
  `- - Jane`.
* The app failed to start without an internet connection, because the theme
  font is loaded from Google Fonts. It now falls back to the system font.
* Parts of the sidebar tab links could not be clicked.
* The "Test / model type" box did not reset after "Add model".

## Other changes

* `tidyverse` in `Imports` replaced by the packages actually used (`dplyr`,
  `readr`, `stringr`, `purrr`), so installing pulls in far fewer packages.
* Documentation updated for the six-step workflow (including the Models tab),
  and clarifies that `jsonlite` is optional (needed only to read `renv.lock`).
