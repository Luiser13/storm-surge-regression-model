# Exploratory data analysis of the RPBU water level (Section 3.1, Q1-Q3).
# Everything here works on the 10-second RPBU series loaded by 00_load_data.R.
# The three questions build on each other: look at the raw shape (Q1), smooth away
# the harbour oscillations to see the trend (Q2), then propose a model for that
# trend (Q3). Source 00_load_data.R before this file.

library(data.table)
library(ggplot2)

# 2.30 m is the "high tide" threshold the assignment asks us to filter days by.
# Water levels are stored in centimetres relative to NAP, so this is 230, not 2.3.
HIGH_TIDE_CM <- 230

# The two days we analyse. Both clear 2.30 m and have complete data, but they were
# picked to contrast: 30 Aug has strong harbour oscillations, 1 Mar is a clean dome.
CHOSEN_DAYS <- as.Date(c("2010-08-30", "2010-03-01"))


# ---- Q1: what does the water level look like around high tide? ----

# Highest reading on each day, sorted high to low. We use this to find which days
# actually reach a high tide above 2.30 m. na.rm because the sentinel cleaning in
# 00_load_data.R leaves NAs where bad readings were.
eda_daily_max <- function(rpbu) {
  d <- rpbu[!is.na(water_cm), .(max_cm = max(water_cm)),
            by = .(day = as.Date(datetime, tz = "UTC"))]
  d[order(-max_cm)]
}

# The single highest reading on a given day, i.e. the moment of high water.
# We drop NAs first so which.max can't accidentally land on a missing value.
day_peak <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day & !is.na(water_cm)]
  sub[which.max(water_cm)]
}

# Full 24-hour view of one day, with the 2.30 m line drawn in for reference.
# Good for seeing the semidiurnal tide (two highs per day) at a glance.
plot_full_day <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day]
  ggplot(sub, aes(datetime, water_cm)) +
    geom_line(linewidth = 0.2, colour = "grey25") +
    geom_hline(yintercept = HIGH_TIDE_CM, linetype = "dashed", colour = "red") +
    labs(title = paste("RPBU water level —", format(day, "%d %b %Y")),
         x = NULL, y = "water level [cm w.r.t. NAP]") +
    theme_minimal(base_size = 10)
}

# Zoom in on the high water itself. We leave the data raw here (smooth = FALSE) so
# the harbour oscillations are visible; that is the whole point of Q1. The smooth
# overlay is wired up for re-use later but stays off by default.
plot_highwater <- function(rpbu, day, before = 90, after = 90,
                           smooth = FALSE, window_pts = 55) {
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


# ---- Q2: suppress the oscillations to reveal the trend ----

# A centred moving average of width = one full oscillation period averages that
# oscillation to (almost) zero while leaving the slow tidal trend intact. The
# slowest harbour oscillation is ~545 s (the assignment also calls it "almost
# 10 min"). At 10-second sampling that is ~55 samples, so a 55-point window nulls
# the 545 s oscillation exactly and strongly attenuates the 205 s and 85 s ones.
MOVAVG_PTS <- 55

# The simple method the assignment hint points to: a centred moving average.
# fill = NA keeps the output the same length as the input (the ends are just NA).
smooth_movavg <- function(x, window_pts = MOVAVG_PTS) {
  if (!requireNamespace("zoo", quietly = TRUE))
    stop("Package 'zoo' is required. Run: install.packages('zoo')")
  zoo::rollmean(x, k = window_pts, fill = NA, align = "center")
}

# An alternative "smoothing method available in R": a smoothing spline.
# spar in [0,1] controls smoothness (higher = smoother); 0.8 follows the slow
# trend and ignores the oscillations. We feed it only the non-NA points.
# NOTE: we deliberately use smooth.spline and NOT loess here — loess segfaults on
# this R 4.6.0 / Windows build, while smooth.spline is rock solid.
smooth_spline_trend <- function(t_sec, x, spar = 0.8) {
  ok  <- !is.na(x)
  fit <- smooth.spline(t_sec[ok], x[ok], spar = spar)
  predict(fit, t_sec)$y
}

# Build one high-water window with both smoothers attached as extra columns.
# t_sec is seconds from the start of the window (the spline needs a numeric x).
q2_smoothed <- function(rpbu, day, before = 90, after = 90,
                        window_pts = MOVAVG_PTS, spar = 0.8) {
  pk  <- day_peak(rpbu, day)
  win <- rpbu_window(rpbu, pk$datetime, before, after)
  win[, t_sec := as.numeric(datetime - min(datetime))]
  win[, mov  := smooth_movavg(water_cm, window_pts)]
  win[, spl  := smooth_spline_trend(t_sec, water_cm, spar)]
  win[]
}

# Raw vs both smoothers for one high water, so we can eyeball that the smoothing
# really does strip the oscillations and leave a clean dome.
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


# ---- Q3: a simple model for the trend around high tide ----

# The smoothed curve from Q2 is a dome, so the simplest sensible model is a
# downward parabola  w(t) = a - b (t - t0)^2 . We fit it as an ordinary quadratic
# regression on a window around the peak: least squares treats the oscillations as
# zero-mean noise and so recovers the trend on its own.
#
# This matches elementary tide physics. The tide is roughly sinusoidal,
# h(t) ~ A cos(omega t), and near the peak cos(x) ~ 1 - x^2 / 2. Substituting gives
# h ~ A - (A omega^2 / 2)(t - t_peak)^2, which is exactly a downward parabola.
# So the parabola is just the second-order Taylor expansion of the tidal cosine
# at high water (curvature b = A omega^2 / 2 > 0).

# Fit the quadratic trend on +/- window_min minutes around the day's high water.
# Returns the fit plus a few interpreted numbers we report in the text.
q3_parabola <- function(rpbu, day, window_min = 45) {
  pk <- day_peak(rpbu, day)
  w  <- rpbu_window(rpbu, pk$datetime, window_min, window_min)
  # Measure time in minutes FROM the high-water instant, so t = 0 sits at the peak.
  # That makes the intercept ~ the peak level and the vertex easy to interpret.
  w[, tc := as.numeric(difftime(datetime, pk$datetime, units = "mins"))]
  fit <- lm(water_cm ~ tc + I(tc^2), data = w)
  co  <- coef(fit)
  list(
    fit       = fit,
    day       = day,
    # c2 < 0 confirms a dome (concave down). Its size is the curvature in cm/min^2.
    curvature = unname(co[3]),
    # Vertex of the parabola: where the modelled trend peaks, and at what level.
    vertex_t  = unname(-co[2] / (2 * co[3])),
    vertex_w  = unname(co[1] - co[2]^2 / (4 * co[3])),
    r2        = summary(fit)$r.squared
  )
}

# Overlay the fitted parabola on the raw + smoothed data for one high water.
# Shows visually that a single quadratic captures the trend the smoother found.
plot_q3 <- function(rpbu, day, window_min = 45) {
  pk <- day_peak(rpbu, day)
  w  <- rpbu_window(rpbu, pk$datetime, window_min, window_min)
  w[, tc  := as.numeric(difftime(datetime, pk$datetime, units = "mins"))]
  w[, spl := smooth_spline_trend(as.numeric(datetime - min(datetime)), water_cm)]
  fit <- lm(water_cm ~ tc + I(tc^2), data = w)
  w[, para := predict(fit)]
  ggplot(w, aes(datetime)) +
    geom_line(aes(y = water_cm, colour = "raw (10 s)"),    linewidth = 0.3) +
    geom_line(aes(y = spl,  colour = "smoothed trend"),    linewidth = 0.8, na.rm = TRUE) +
    geom_line(aes(y = para, colour = "parabola fit"),      linewidth = 1.0, linetype = "dashed") +
    scale_colour_manual(values = c("raw (10 s)" = "grey70",
                                   "smoothed trend" = "blue",
                                   "parabola fit" = "red")) +
    labs(title = sprintf("Parabolic trend on %s (R2 = %.2f over +/-%d min)",
                         format(day, "%d %b %Y"), summary(fit)$r.squared, window_min),
         x = NULL, y = "water level [cm w.r.t. NAP]", colour = NULL) +
    theme_minimal(base_size = 10) + theme(legend.position = "top")
}
