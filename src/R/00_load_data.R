# =============================================================================
# 00_load_data.R  --  Shared data loading for the whole assignment
# -----------------------------------------------------------------------------
# Everyone uses this. It reads the two raw .txt files, parses the timestamps,
# and caches the result as .rds so we don't re-read the 3.4-million-row RPBU
# file every single time we knit the report (that read takes a few seconds).
#
# HOW TO USE (from any other script or the .Rmd):
#     source("R/00_load_data.R")
#     rpbu  <- load_rpbu()      # 10-second data at RPBU  (cols: datetime, water_cm)
#     wide  <- load_10min()     # 10-minute multi-location data (incl. wind)
#
# Water levels are in CENTIMETRES relative to NAP (Dutch sea-level reference).
# So "high tide above 2.30 metres" in the assignment means water_cm > 230.
# =============================================================================

# --- locate the project folders, no matter where R is launched from ----------
# We walk up from the working directory until we find the "Assignment Context"
# folder that holds the raw data. This makes the scripts work whether you run
# them from src/, from the project root, or via Knit.
.find_data_dir <- function() {
  candidates <- c(
    "Assignment Context",
    file.path("..", "Assignment Context"),
    file.path("..", "..", "Assignment Context")
  )
  for (p in candidates) if (dir.exists(p)) return(normalizePath(p))
  stop("Could not find the 'Assignment Context' folder. ",
       "Run R with the working directory set to the project or src/ folder.")
}

DATA_DIR  <- .find_data_dir()
CACHE_DIR <- file.path(dirname(DATA_DIR), "src", "cache")
if (!dir.exists(CACHE_DIR)) CACHE_DIR <- "cache"   # fallback when wd == src/

# The raw files currently ship with a " (1)" suffix from the download.
# We match them by pattern so a rename later won't break anything.
.raw_file <- function(pattern) {
  hits <- list.files(DATA_DIR, pattern = pattern, full.names = TRUE)
  if (length(hits) == 0) stop("No data file matching: ", pattern, " in ", DATA_DIR)
  hits[1]
}

# -----------------------------------------------------------------------------
# load_rpbu(): the 10-second water-level series at RPBU (the barrier itself).
# -----------------------------------------------------------------------------
load_rpbu <- function(refresh = FALSE) {
  cache <- file.path(CACHE_DIR, "rpbu.rds")
  if (!refresh && file.exists(cache)) return(readRDS(cache))

  if (!requireNamespace("data.table", quietly = TRUE))
    stop("Package 'data.table' is required. Run: install.packages('data.table')")

  f  <- .raw_file("^RPBU.*\\.txt$")
  dt <- data.table::fread(f)                       # fast read of ~3.4M rows
  data.table::setnames(dt, c("water", "datetime"), c("water_cm", "datetime"),
                       skip_absent = TRUE)
  dt[, datetime := as.POSIXct(datetime, tz = "UTC",
                              format = "%Y-%m-%d %H:%M:%S")]
  dt <- dt[!is.na(datetime)]
  # Data cleaning: the file uses an out-of-range sentinel (9995 cm = 99.95 m,
  # physically impossible) to flag bad readings. Turn these into NA so they are
  # not plotted as spikes or averaged into smoothers. We keep the rows (NA), so
  # the 10-second time grid stays regular for moving averages and spectral work.
  dt[water_cm >= 500, water_cm := NA_real_]
  dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(dt, cache)
  dt
}

# -----------------------------------------------------------------------------
# load_10min(): the 10-minute multi-location data (OS11, VR, RPBU + wind).
# Used mainly for Section 3.3 (external information).
# -----------------------------------------------------------------------------
load_10min <- function(refresh = FALSE) {
  cache <- file.path(CACHE_DIR, "tenmin.rds")
  if (!refresh && file.exists(cache)) return(readRDS(cache))

  if (!requireNamespace("data.table", quietly = TRUE))
    stop("Package 'data.table' is required. Run: install.packages('data.table')")

  f  <- .raw_file("^data.*10min.*\\.txt$")
  dt <- data.table::fread(f)
  dt[, datetime := as.POSIXct(datetime, tz = "UTC",
                              format = "%Y-%m-%d %H:%M:%S")]
  dt <- dt[!is.na(datetime)]
  dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(dt, cache)
  dt
}

# -----------------------------------------------------------------------------
# Helper: pull out a time window of RPBU data around a chosen instant.
# Handy for "zoom in around high tide". Returns a data.table.
#   centre  : a POSIXct timestamp (e.g. the moment of a high tide)
#   before  : minutes to include before centre
#   after   : minutes to include after centre
# -----------------------------------------------------------------------------
rpbu_window <- function(rpbu, centre, before = 60, after = 60) {
  lo <- centre - before * 60
  hi <- centre + after  * 60
  rpbu[datetime >= lo & datetime <= hi]
}
