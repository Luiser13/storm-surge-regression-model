# Shared data loading. Reads the raw .txt files and caches them as .rds.
# Water levels are in cm relative to NAP, so "high tide > 2.30 m" means water_cm > 230.

# Find the data folder whether R runs from src/, the project root, or via Knit
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

# Match the raw files by pattern, so the " (1)" download suffix doesn't matter
.raw_file <- function(pattern) {
  hits <- list.files(DATA_DIR, pattern = pattern, full.names = TRUE)
  if (length(hits) == 0) stop("No data file matching: ", pattern, " in ", DATA_DIR)
  hits[1]
}

# The 10-second RPBU series (cols: datetime, water_cm). Cached after the first read.
load_rpbu <- function(refresh = FALSE) {
  cache <- file.path(CACHE_DIR, "rpbu.rds")
  if (!refresh && file.exists(cache)) return(readRDS(cache))

  if (!requireNamespace("data.table", quietly = TRUE))
    stop("Package 'data.table' is required. Run: install.packages('data.table')")

  f  <- .raw_file("^RPBU.*\\.txt$")
  dt <- data.table::fread(f)
  data.table::setnames(dt, c("water", "datetime"), c("water_cm", "datetime"),
                       skip_absent = TRUE)
  dt[, datetime := as.POSIXct(datetime, tz = "UTC",
                              format = "%Y-%m-%d %H:%M:%S")]
  dt <- dt[!is.na(datetime)]
  # 9995 cm is the file's sentinel for a bad reading -> NA. Keep the row so the
  # 10-second grid stays regular for moving averages / spectral work.
  dt[water_cm >= 500, water_cm := NA_real_]
  dir.create(CACHE_DIR, showWarnings = FALSE, recursive = TRUE)
  saveRDS(dt, cache)
  dt
}

# The 10-minute multi-location data (OS11, VR, RPBU + wind). Used for Q9-Q10.
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

# Slice RPBU around an instant (before/after in minutes). Handy for zooming on high tide.
rpbu_window <- function(rpbu, centre, before = 60, after = 60) {
  lo <- centre - before * 60
  hi <- centre + after  * 60
  rpbu[datetime >= lo & datetime <= hi]
}
