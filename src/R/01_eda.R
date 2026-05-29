# =============================================================================
# 01_eda.R  --  Section 3.1 Exploratory Data Analysis (Questions 1-3, 30 pts)
# -----------------------------------------------------------------------------
# Depends on: source("R/00_load_data.R")  (provides load_rpbu(), rpbu_window())
#
# Q1  Pick two days with high tide > 2.30 m (water_cm > 230) at RPBU; plot the
#     full day and zoom in around the peaks; describe the shape.       [DONE]
# Q2  Suppress the harbour oscillations with smoothing.                [TODO next]
# Q3  Propose the simplest trend model around high tide.               [TODO next]
# =============================================================================

library(data.table)
library(ggplot2)

HIGH_TIDE_CM <- 230                                   # 2.30 m threshold
# The two days we analyse (both clearly exceed 2.30 m, both have complete data):
#   2010-08-30 (peak 265 cm) shows the harbour oscillations prominently;
#   2010-03-01 (peak 246 cm) shows a cleaner, near-parabolic dome.
CHOSEN_DAYS <- as.Date(c("2010-08-30", "2010-03-01"))

# ----- helpers ---------------------------------------------------------------

# Daily maximum water level (NA-safe), sorted high to low. Used to find the
# days whose high tide exceeds 2.30 m.
eda_daily_max <- function(rpbu) {
  d <- rpbu[!is.na(water_cm), .(max_cm = max(water_cm)),
            by = .(day = as.Date(datetime, tz = "UTC"))]
  d[order(-max_cm)]
}

# The single highest reading on a given day (the "high water" instant).
day_peak <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day & !is.na(water_cm)]
  sub[which.max(water_cm)]
}

# ----- Q1 plots --------------------------------------------------------------

# Full 24-hour view, with the 2.30 m line drawn in.
plot_full_day <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day]
  ggplot(sub, aes(datetime, water_cm)) +
    geom_line(linewidth = 0.2, colour = "grey25") +
    geom_hline(yintercept = HIGH_TIDE_CM, linetype = "dashed", colour = "red") +
    labs(title = paste("RPBU water level —", format(day, "%d %b %Y")),
         x = NULL, y = "water level [cm w.r.t. NAP]") +
    theme_minimal(base_size = 10)
}

# Zoom around the day's high water. With smooth = TRUE it also overlays the
# moving-average trend (used from Q2 onward); for Q1 we leave it raw so the
# oscillations are clearly visible.
plot_highwater <- function(rpbu, day, before = 90, after = 90,
                           smooth = FALSE, window_pts = 61) {
  pk  <- day_peak(rpbu, day)
  win <- rpbu_window(rpbu, pk$datetime, before, after)
  g <- ggplot(win, aes(datetime, water_cm)) +
    geom_line(linewidth = 0.3, colour = "steelblue") +
    labs(title = sprintf("High water on %s (peak %d cm at %s)",
                         format(day, "%d %b %Y"), pk$water_cm,
                         format(pk$datetime, "%H:%M")),
         x = NULL, y = "water level [cm w.r.t. NAP]") +
    theme_minimal(base_size = 10)
  if (smooth)
    g <- g + geom_line(aes(y = smooth_movavg(water_cm, window_pts)),
                       colour = "red", linewidth = 0.8, na.rm = TRUE)
  g
}

# ----- Q2: smoothing to suppress oscillations --------------------------------
# Centred moving average over ~one full slowest period (61 pts ~ 610 s at 10 s).
smooth_movavg <- function(x, window_pts = 61) {
  if (!requireNamespace("zoo", quietly = TRUE))
    stop("Package 'zoo' is required. Run: install.packages('zoo')")
  zoo::rollmean(x, k = window_pts, fill = NA, align = "center")
}
# TODO(Q2): also fit loess / smooth.spline and overlay smoothed vs raw.

# ----- Q3: simple trend model ------------------------------------------------
# TODO(Q3): fit w ~ poly(t, 2) near a peak; discuss cos-expansion physics.
