# Exploratory data analysis of the RPBU water level (Q1-Q3).
# Source 00_load_data.R first.

library(data.table)
library(ggplot2)

HIGH_TIDE_CM <- 230                                  # the 2.30 m threshold, in cm
# Two contrasting days above 2.30 m: 30 Aug = strong oscillations, 1 Mar = clean dome
CHOSEN_DAYS <- as.Date(c("2010-08-30", "2010-03-01"))


# ---- Q1: shape of the water level around high tide ----

# Daily maxima sorted high to low, to find days whose high tide tops 2.30 m
eda_daily_max <- function(rpbu) {
  d <- rpbu[!is.na(water_cm), .(max_cm = max(water_cm)),
            by = .(day = as.Date(datetime, tz = "UTC"))]
  d[order(-max_cm)]
}

# The highest reading on a day (the high-water instant)
day_peak <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day & !is.na(water_cm)]
  sub[which.max(water_cm)]
}

# Full 24-hour view with the 2.30 m line; shows the semidiurnal tide
plot_full_day <- function(rpbu, day) {
  sub <- rpbu[as.Date(datetime, tz = "UTC") == day]
  ggplot(sub, aes(datetime, water_cm)) +
    geom_line(linewidth = 0.2, colour = "grey25") +
    geom_hline(yintercept = HIGH_TIDE_CM, linetype = "dashed", colour = "red") +
    labs(title = paste("RPBU water level —", format(day, "%d %b %Y")),
         x = NULL, y = "water level [cm w.r.t. NAP]") +
    theme_minimal(base_size = 10)
}

# Zoom on the high water. Raw by default (smooth = FALSE) so the oscillations show.
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

# Window for the moving average: ~55 samples = the slowest oscillation period
# (~545 s at 10-s sampling), so a full cycle averages out.
MOVAVG_PTS <- 55

# Centred moving average (the simple method the hint points to)
smooth_movavg <- function(x, window_pts = MOVAVG_PTS) {
  if (!requireNamespace("zoo", quietly = TRUE))
    stop("Package 'zoo' is required. Run: install.packages('zoo')")
  zoo::rollmean(x, k = window_pts, fill = NA, align = "center")
}

# Alternative R smoother. NOTE: loess segfaults on this R build, so we use a spline.
smooth_spline_trend <- function(t_sec, x, spar = 0.8) {
  ok  <- !is.na(x)
  fit <- smooth.spline(t_sec[ok], x[ok], spar = spar)
  predict(fit, t_sec)$y
}

# One high-water window with both smoothers attached as columns
q2_smoothed <- function(rpbu, day, before = 90, after = 90,
                        window_pts = MOVAVG_PTS, spar = 0.8) {
  pk  <- day_peak(rpbu, day)
  win <- rpbu_window(rpbu, pk$datetime, before, after)
  win[, t_sec := as.numeric(datetime - min(datetime))]
  win[, mov  := smooth_movavg(water_cm, window_pts)]
  win[, spl  := smooth_spline_trend(t_sec, water_cm, spar)]
  win[]
}

# Raw vs both smoothers, to check the oscillations are gone and a dome remains
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


# ---- Q3: a simple model for the trend ----

# Fit a downward parabola to +/- window_min around high water. Least squares treats
# the oscillations as zero-mean noise, so the quadratic recovers the trend.
# This is the 2nd-order Taylor expansion of the tidal cosine at its peak.
q3_parabola <- function(rpbu, day, window_min = 45) {
  pk <- day_peak(rpbu, day)
  w  <- rpbu_window(rpbu, pk$datetime, window_min, window_min)
  w[, tc := as.numeric(difftime(datetime, pk$datetime, units = "mins"))]  # t=0 at the peak
  fit <- lm(water_cm ~ tc + I(tc^2), data = w)
  co  <- coef(fit)
  list(
    fit       = fit,
    day       = day,
    curvature = unname(co[3]),                          # c2 < 0 => dome
    vertex_t  = unname(-co[2] / (2 * co[3])),           # minutes from high water
    vertex_w  = unname(co[1] - co[2]^2 / (4 * co[3])),  # fitted peak level
    r2        = summary(fit)$r.squared
  )
}

# Overlay the fitted parabola on the raw + smoothed data
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
