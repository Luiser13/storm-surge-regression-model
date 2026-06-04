# Linear regression model for RPBU (Section 3.2, Q4).
# Source 00_load_data.R (data) and 01_eda.R (the parabola trend idea) before this.
#
# The model is a parabolic trend plus the three known harbour oscillations:
#
#   w(t) = c0 + c1 t + c2 t^2 + sum_k [ alpha_k sin(omega_k t) + beta_k cos(omega_k t) ]
#
# The periods are FIXED at 545/205/85 s, so omega_k is known. The only reason this
# is a *linear* model is the identity  a sin(omega(t - phi)) = alpha sin(omega t) +
# beta cos(omega t): with omega fixed, alpha and beta enter linearly, so a single
# lm() fits everything. (We recover amplitude a = sqrt(alpha^2+beta^2) if we want it.)
#
# Q4 is operational: stand at a "now" before high water, fit on the recent history,
# and predict 5 minutes ahead. We then vary the history length to find a good window.

library(data.table)

# The three oscillation periods Rijkswaterstaat gives, as angular frequencies.
# t is always in SECONDS so these omega are in rad/s.
PERIODS_S <- c(545, 205, 85)
OMEGA     <- 2 * pi / PERIODS_S

# Build the design columns for a vector of times (seconds, any origin).
# Trend is expressed in MINUTES (t_sec/60) just to keep the numbers well scaled so
# lm's QR stays well conditioned; the sin/cos use seconds to match OMEGA.
lin_terms <- function(t_sec, trend_degree = 2) {
  tm <- t_sec / 60
  df <- data.frame(t1 = tm)
  if (trend_degree >= 2) df$t2 <- tm^2
  for (k in seq_along(OMEGA)) {
    df[[paste0("s", k)]] <- sin(OMEGA[k] * t_sec)
    df[[paste0("c", k)]] <- cos(OMEGA[k] * t_sec)
  }
  df
}

# Fit on the window [now - window_min, now] and predict forward to now + ahead_sec.
# We put the time origin AT "now" (so history is t < 0 and the forecast is t > 0),
# which keeps the trend extrapolation centred and easy to reason about.
# Returns a list with the fit and a forecast table (predicted vs actual) so the
# caller can both plot it and score it.
linear_forecast <- function(rpbu, now_time, window_min = 30,
                            ahead_sec = 300, trend_degree = 2) {
  t0 <- as.numeric(now_time)

  # --- history we are allowed to use (everything up to and including "now") ---
  hist <- rpbu[datetime >= now_time - window_min * 60 & datetime <= now_time &
               !is.na(water_cm)]
  hist[, t_sec := as.numeric(datetime) - t0]
  train <- lin_terms(hist$t_sec, trend_degree)
  train$y <- hist$water_cm
  fit <- lm(y ~ ., data = train)

  # --- the future we want to predict, and the actual values to score against ---
  fut <- rpbu[datetime > now_time & datetime <= now_time + ahead_sec &
              !is.na(water_cm)]
  fut[, t_sec := as.numeric(datetime) - t0]
  pred <- predict(fit, newdata = lin_terms(fut$t_sec, trend_degree))

  list(
    fit  = fit,
    now  = now_time,
    hist = hist,
    fitted = data.table(datetime = hist$datetime, fit = fitted(fit)),
    fore = data.table(datetime = fut$datetime, t_sec = fut$t_sec,
                      actual = fut$water_cm, pred = pred)
  )
}

# Score one forecast: root-mean-square error over the whole 5-minute horizon, plus
# the error exactly at the +5 min point (the number the decision team cares about).
score_forecast <- function(fc) {
  f <- fc$fore
  rmse  <- sqrt(mean((f$actual - f$pred)^2))
  e5    <- f[which.max(t_sec), pred - actual]   # signed error at the far end (~+5min)
  c(rmse = rmse, err5 = e5, n = nrow(f))
}

# Sweep "now" across the approach to a day's high water and average the 5-min RMSE.
# This is the honest test: we relive every minute before high tide, each time fitting
# only on the past and predicting the next 5 minutes. lead_min sets how far before the
# peak we start; step_min how often we re-fit.
eval_day <- function(rpbu, day, window_min = 30, lead_min = 60,
                     step_min = 2, ahead_sec = 300, trend_degree = 2) {
  pk     <- day_peak(rpbu, day)
  nows   <- seq(pk$datetime - lead_min * 60, pk$datetime, by = step_min * 60)
  scores <- lapply(nows, function(nt)
    score_forecast(linear_forecast(rpbu, nt, window_min, ahead_sec, trend_degree)))
  s <- do.call(rbind, scores)
  c(window_min = window_min,
    mean_rmse  = mean(s[, "rmse"]),
    max_rmse   = max(s[, "rmse"]),
    n_fits     = nrow(s))
}
