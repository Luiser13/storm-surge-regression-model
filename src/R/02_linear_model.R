# Linear regression model for RPBU (Q4): parabola trend + 3 fixed-period oscillations.
# Linear because a sin(w(t-phi)) = alpha sin(wt) + beta cos(wt) when w is fixed.
# Source 00_load_data.R and 01_eda.R first.

library(data.table)

# The three oscillation periods (s) as angular frequencies; t is always in seconds.
PERIODS_S <- c(545, 205, 85)
OMEGA     <- 2 * pi / PERIODS_S

# Design columns for a time vector. Trend in minutes (t_sec/60) to keep lm well conditioned.
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

# Fit on [now - window_min, now], predict to now + ahead_sec. Time origin at "now"
# (history t < 0, forecast t > 0). Returns the fit + a predicted-vs-actual table.
linear_forecast <- function(rpbu, now_time, window_min = 30,
                            ahead_sec = 300, trend_degree = 2) {
  t0 <- as.numeric(now_time)

  hist <- rpbu[datetime >= now_time - window_min * 60 & datetime <= now_time &
               !is.na(water_cm)]
  hist[, t_sec := as.numeric(datetime) - t0]
  train <- lin_terms(hist$t_sec, trend_degree)
  train$y <- hist$water_cm
  fit <- lm(y ~ ., data = train)

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

# Score a forecast: RMSE over the horizon + signed error at the far (+5 min) end.
score_forecast <- function(fc) {
  f <- fc$fore
  rmse <- sqrt(mean((f$actual - f$pred)^2))
  e5   <- f[which.max(t_sec), pred - actual]
  c(rmse = rmse, err5 = e5, n = nrow(f))
}

# Slide "now" across the hour before high water and average the 5-min RMSE.
# This is the honest test: each step fits only on the past and predicts the next 5 min.
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
