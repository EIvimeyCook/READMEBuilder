# READMEBuilder 0.2.1 (development version)

Version 0.2.1, on the `development` branch. The stable version on `main` is
0.2.0. Check which one you have with `packageVersion("READMEBuilder")`.

## New features

* **Browser version.** The app now also runs in a web browser with nothing to
  install, at <https://eivimeycook.github.io/READMEBuilder/>. It is the same app
  running in webR (via Shinylive): drag the project folder (or a `.zip`) onto
  the Files tab, or use **Choose folder…** or **Upload .zip…**, and it is read
  inside the page, so files are never sent anywhere. Package versions
  come from the project's `renv.lock`; packages it does not list are marked
  `not recorded`. Built by `web/build.R` and published by a GitHub Actions
  workflow; neither is part of the R package.
* The desktop app can also load a project uploaded as a `.zip` (**Upload
  .zip…** on the Files tab), so both versions offer a folder and a zip.
* The **Download README.md** button now floats in the bottom-right corner on
  every tab, instead of sitting off to the right in the Preview card.
* Packages are scanned as soon as a folder is loaded, so the README has its
  package table and lockfile R version without clicking **Scan**.
* Single line breaks typed in text fields now show as line breaks on GitHub,
  and column descriptions can span several lines.
* ORCID iDs typed after an author's name are written as links to orcid.org.
* Importing a README while a folder is loaded keeps the folder and matches the
  README's descriptions to its files. Importing a README first and loading the
  folder afterwards keeps the descriptions too. Package versions recorded in
  the README are kept for any package the folder's `renv.lock` does not cover.
* The app asks before **Clear**, before importing over a form that already has
  content, and before deleting all models.
* The licence boxes keep a typed value when you click away without pressing
  Enter, and have a **×** button to clear them.
* CSVs saved by Excel on Windows (Windows-1252), files with a header but no
  rows, and workbooks whose first sheet is empty are now summarised. Office
  lock files, `Thumbs.db` and `desktop.ini` are left out.
* The package diagnostics show paths within the project, say why an unusable
  `renv.lock` was ignored, and say when there is more than one lockfile.
* The layout works on phones and narrow windows (the navigation moves to the
  top).
* `build_readme()` takes a `folder` argument to open the app with a project
  folder already loaded (absolute, relative to the working directory, or from
  `here::here()`), and `edit_readme = TRUE` to also fill the form from that
  folder's `README.md` if READMEBuilder made it.
* A **Use working directory** button on the Files tab loads the folder
  `build_readme()` was called from.
* Loading a folder that already has a READMEBuilder `README.md` offers to load
  it, keeping the folder's own file list and data summaries.

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
* Re-importing a README, or loading the same folder (or one with the same file
  names) again, left the previous file, column and script descriptions in place.
  Dates and locations of a file that was no longer a table were still exported.
* Re-import did not survive some text: a `## Description` (or other section
  heading) typed in a field, a `## Models` line inside a code block, an unclosed
  code fence, a `**Location:**` or `` ### `file` `` line in a description, file
  or column names containing a backtick, a literal `<br>` or trailing backslash
  in a table cell, a model whose text mentions "Outcome (paper)" or starts with
  `--`, a contact starting with `<` or `+44`, a backslash the user typed, and
  indentation at the start of a field.
* On import, a licence whose name contains "Code" or "Data" was put in the
  wrong slot, a licence ending in a full stop was exported with two, "All rights
  reserved" read "licensed under All rights reserved", and a placeholder title
  "Untitled Project" came back as a real title.
* A generic README with a title and a couple of common headings was treated as
  one READMEBuilder made, and replaced the form without asking. UTF-16 files and
  files containing a NUL byte were read in truncated instead of being refused.
* DOIs written as `doi.org/…`, `www.doi.org/…`, `<…>`, `DOI 10…`, in quotes or
  brackets, with a trailing full stop or note ("; see paper"), or separated by
  commas or spaces gave broken or doubled links. DOIs containing `%` changed on
  re-import.
* Authors, affiliations or funders typed as `1. Name` or `• Name` got an extra
  bullet.
* Double-clicking a model's delete button deleted two models, double-clicking
  **Add model** added it twice, and **Add model** with no outcome did nothing
  without saying why.
* Double-clicking a script's arrow undid the move, and text typed just before
  clicking an arrow was lost.
* Scripts had a Description box on the Files tab whose text never reached the
  README; they are now described only on the Script Order tab.
* The package scanner counted `library()` / `require()` text inside strings
  (e.g. `"may require (approx.) 2 GB"`), missed `librarian::shelf("owner/repo")`,
  counted hidden `__MACOSX` files as scripts, and counted lockfile entries
  without a usable version as "from lockfile". A malformed `renv.lock` was
  silently treated as present.
* The preview did not wrap long lines.
* "1 packages" / "1 rows" now read "1 package" / "1 row".

## Other changes

* `tidyverse` in `Imports` replaced by the packages actually used (`dplyr`,
  `readr`, `stringr`, `purrr`), so installing pulls in far fewer packages.
* Documentation updated for the six-step workflow (including the Models tab),
  and clarifies that `jsonlite` is optional (needed only to read `renv.lock`).
* README updated for the browser version, including how it differs from the
  package.
* Setting the environment variable `READMEBUILDER_WEB=true` makes the desktop
  app behave like the browser version, for testing.
