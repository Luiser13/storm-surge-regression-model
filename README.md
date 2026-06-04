# Short-term Water-Level Prediction at the RPBU Storm Surge Barrier

Regression modelling of tidal water levels for the **TU/e 2MBS50** (Regression
Models and Applications) Data Analysis Assignment.

The goal is short-term, **5-minute-ahead** prediction of the sea water level at
**Roompot Buiten (RPBU)** just before high tide. These predictions support the
decision to close the Oosterschelde storm surge barrier (closure is required by
law at +3.00 m NAP). The inner harbour at RPBU produces oscillations with periods
of roughly **545, 205 and 85 s** that, by regulation, may not be filtered out — so
the model has to capture both the slow tidal trend and those fast oscillations.

Written in **R**. The report write-up is kept in Overleaf.

## Repository layout
```
.
├── Assignment Context/        raw data + assignment brief (provided)
├── Rubric/                     grading rubric
└── src/
    ├── R/
    │   ├── 00_load_data.R      shared data loading (run this first)
    │   ├── 01_eda.R            Q1-Q3  exploratory data analysis
    │   └── 02_linear_model.R   Q4     linear model + 5-min forecasting
    ├── .Rprofile               loads the project-local package library
    ├── .Rlib/                  project-local packages (git-ignored)
    ├── cache/                  cached .rds (regenerated on first run)
    └── output/                 rendered figures
```

## Data
- `RPBU20102011.txt` — water level at RPBU every 10 s (cm w.r.t. NAP), 2010-2011.
- `data20102011-10min.txt` — OS11 / VR / RPBU water level + wind, every 10 min.

The loader (`R/00_load_data.R`) reads these, cleans the 9995 cm sentinel to NA, and
caches the result so later runs are instant.

## Setup
1. Install **R** (and RStudio). On Windows: `winget install RProject.R`.
2. Open the `src/` folder and set the working directory to it.
3. Install the packages into the project-local library (run once, wd = `src/`):
   ```r
   install.packages(c("data.table", "ggplot2", "zoo", "minpack.lm",
                      "rmarkdown", "knitr", "tinytex", "bookdown"), lib = ".Rlib")
   ```
   `src/.Rprofile` loads `.Rlib` automatically. We use a project-local library
   because the default Windows user library lives under AppData, which on some
   setups is virtualised and unreliable.
4. For PDF output, install a LaTeX engine once: `tinytex::install_tinytex()`.

## Running
```r
source("R/00_load_data.R")     # always first
source("R/01_eda.R")
rpbu <- load_rpbu()
plot_q2(rpbu, CHOSEN_DAYS[1])   # e.g. a smoothed high water

source("R/02_linear_model.R")
eval_day(rpbu, CHOSEN_DAYS[2], window_min = 25)   # 5-min-ahead RMSE
```

## Notes
- Run analysis from `.R` script files rather than long one-liners more stable.
- Render any R Markdown **in place** (the folder path contains spaces, which breaks
  LaTeX figure paths if rendered into a separate output folder).
- `loess` segfaults on this R build; use `smooth.spline` instead.
