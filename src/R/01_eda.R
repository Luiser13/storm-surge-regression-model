# =============================================================================
# 01_eda.R  --  Section 3.1 Exploratory Data Analysis (Questions 1-3, 30 pts)
# -----------------------------------------------------------------------------
# Depends on: source("R/00_load_data.R")  (provides load_rpbu(), rpbu_window())
#
# Q1  Pick two days with high tide > 2.30 m (water_cm > 230) at RPBU; plot the
#     full day and zoom in around the peaks; describe the shape.       [DONE]
# Q2  Suppress the harbour oscillations with smoothing.                [DONE]
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
# Idea: a centred moving average of width = one full oscillation period averages
# that oscillation to (nearly) zero while leaving the slow tidal trend intact.
# The slowest harbour oscillation is ~545 s (the assignment also calls it "almost
# 10 min"). At 10-s sampling that is ~55 samples, so a 55-point centred mean nulls
# the slowest oscillation exactly and strongly attenuates the 205 s and 85 s ones.
MOVAVG_PTS <- 55                                   # ~550 s window (= slowest period)

# Simple method (the one the hint points to): centred moving average.
smooth_movavg <- function(x, window_pts = MOVAVG_PTS) {
  if (!requireNamespace("zoo", quietly = TRUE))
    stop("Package 'zoo' is required. Run: install.packages('zoo')")
  zoo::rollmean(x, k = window_pts, fill = NA, align = "center")
}

# Alternative R smoother: a smoothing spline. 'spar' (in [0,1], higher = smoother)
# is set so the spline follows the slow tidal trend and ignores the oscillations.
# (We use smooth.spline rather than loess: loess segfaults in this R/Windows build.)
smooth_spline_trend <- function(t_sec, x, spar = 0.8) {
  ok <- !is.na(x)
  fit <- smooth.spline(t_sec[ok], x[ok], spar = spar)
  predict(fit, t_sec)$y
}

# Build a tidy data.frame for one high-water window with both smoothers attached.
q2_smoothed <- function(rpbu, day, before = 90, after = 90,
                        window_pts = MOVAVG_PTS, spar = 0.8) {
  pk  <- day_peak(rpbu, day)
  win <- rpbu_window(rpbu, pk$datetime, before, after)
  win[, t_sec := as.numeric(datetime - min(datetime))]
  win[, mov  := smooth_movavg(water_cm, window_pts)]
  win[, spl  := smooth_spline_trend(t_sec, water_cm, spar)]
  win[]
}

# Plot raw vs smoothers for one high water (used to compare visually in Q2).
plot_q2 <- function(rpbu, day, before = 90, after = 90,
                    window_pts = MOVAVG_PTS, spar = 0.8) {
  d  <- q2_smoothed(rpbu, day, before, after, window_pts, spar)
  pk <- day_peak(rpbu, day)
  ggplot(d, aes(datetime)) +
    geom_line(aes(y = water_cm, colour = "raw (10 s)"), linewidth = 0.3) +
    geom_line(aes(y = mov, colour = "moving avg (55 pt)"), linewidth = 0.9, na.rm = TRUE) +
    geom_line(aes(y = spl, colour = "smooth.spline"),     linewidth = 0.9, na.rm = TRUE) +
    scale_colour_manual(values = c("raw (10 s)" = "grey70",
                                   "moving avg (55 pt)" = "red",
                                   "smooth.spline" = "blue")) +
    labs(title = sprintf("Smoothed high water on %s (peak %d cm)",
                         format(day, "%d %b %Y"), pk$water_cm),
         x = NULL, y = "water level [cm w.r.t. NAP]", colour = NULL) +
    theme_minimal(base_size = 10) + theme(legend.position = "top")
}

# ----- Q3: simple trend model ------------------------------------------------
# TODO(Q3): fit w ~ poly(t, 2) near a peak; discuss cos-expansion physics.
