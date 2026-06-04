# Environment setup (read this first)

This project is written in **R** and renders to PDF with **R Markdown + TinyTeX**.
Follow these steps once on each machine. It should take ~15 minutes.

## 1. Install R
- Windows: install from <https://cran.r-project.org/> (or `winget install RProject.R`).
- You already have **RStudio** (the editor). RStudio needs R installed separately —
  that is what step 1 provides.

## 2. Open the project in RStudio
- Open RStudio and open the scripts in `src/R/` (start with `00_load_data.R`).
- Set the working directory to the `src/` folder
  (`Session > Set Working Directory > Choose Directory... > src`).
- We work **code-first**: develop and check the analysis in the `R/` scripts. The
  written report (`report.Rmd`) is assembled at the very end from `REPORT_OUTLINE.md`.

## 3. Install the R packages we use
With the working directory set to `src/`, run this once in the RStudio Console:
```r
install.packages(c("data.table", "ggplot2", "zoo", "minpack.lm",
                   "rmarkdown", "knitr", "tinytex", "bookdown"))
```
Packages are kept in a **project-local library `src/.Rlib`** (loaded automatically by
`src/.Rprofile`). We use this instead of the default Windows user library because that
lives under AppData, which on some setups is virtualised/unreliable. To install into
`.Rlib` explicitly: `install.packages(..., lib = ".Rlib")`. The `.Rlib` folder is
git-ignored (compiled, machine-specific), so each machine builds its own once.

## 4. Install TinyTeX (the LaTeX engine that turns the report into a PDF)
Run once in the Console:
```r
tinytex::install_tinytex()
```
Restart RStudio afterwards. This is a one-time ~250 MB install. It auto-installs
any missing LaTeX packages later, with no popups.

## 5. Rendering to PDF (only needed when we build the report at the end)
The R Markdown + TinyTeX pipeline is already verified to work. When we assemble
`report.Rmd` at the end, render it **in place** (the folder path has spaces, which
breaks LaTeX figure paths if you render into a separate folder):
```r
rmarkdown::render("report.Rmd")   # PDF appears next to report.Rmd
```
In RStudio the **Knit** button does this and shows a live preview.

## Project layout
```
src/
  R/00_load_data.R    shared data loading (run this first in any script)
  R/01_eda.R          Q1-3  Exploratory Data Analysis
  R/02_linear_model.R Q4    linear regression model
  R/03_nonlinear.R    Q5-8  non-linear model + self-starter
  R/04_external.R     Q9-10 external information (OS11, VR)
  cache/              auto-generated .rds caches (safe to delete)
  output/             rendered PDFs (built at the end)
  REPORT_OUTLINE.md   the writing plan; report.Rmd is built from this at the end
  SETUP.md            this file
  HANDOFF.md          how to do your part
```

## Notes
- The raw data lives in `../Assignment Context/`. The loader finds it automatically.
- The first knit reads the 3.4M-row RPBU file (a few seconds) and caches it, so
  later knits are fast. If data changes, refresh with `load_rpbu(refresh = TRUE)`.
