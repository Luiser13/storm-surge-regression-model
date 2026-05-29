# =============================================================================
# 02_linear_model.R  --  Section 3.2 Q4: LINEAR regression model (10 pts)
# -----------------------------------------------------------------------------
# Depends on: source("R/00_load_data.R")
#
# KEY IDEA (this is the whole trick of Q4):
#   With the periods FIXED at 545, 205, 85 s, each oscillation
#        a_k * sin(w_k (t - phi_k))
#   expands to
#        alpha_k * sin(w_k t) + beta_k * cos(w_k t),
#   which is LINEAR in (alpha_k, beta_k). So the full model
#        w(t) = c0 + c1 t + c2 t^2                 <- quadratic trend (from Q3)
#               + sum_k [ alpha_k sin(w_k t) + beta_k cos(w_k t) ]
#   is linear in ALL its parameters and is fit with a single lm().
#   Recover amplitude a_k = sqrt(alpha_k^2 + beta_k^2), phase from atan2.
#
# Q4 also asks: fit on a window BEFORE high water, predict 5 min ahead
#   (= 30 steps at 10 s), experiment with the fitting-window length, and
#   QUANTIFY the 5-min-ahead error (RMSE).
#
# This is a SKELETON. Filled in during Phase 2 / handoff.
# =============================================================================

PERIODS_S <- c(545, 205, 85)          # the three known oscillation periods [s]
OMEGA     <- 2 * pi / PERIODS_S       # angular frequencies [rad/s]

# Build the design matrix of sin/cos terms for fixed periods.
#   t_sec : numeric time in SECONDS (e.g. seconds since start of the window)
osc_design <- function(t_sec) {
  cols <- lapply(OMEGA, function(w) cbind(sin(w * t_sec), cos(w * t_sec)))
  M <- do.call(cbind, cols)
  colnames(M) <- paste0(rep(c("sin", "cos"), length(OMEGA)),
                        rep(seq_along(OMEGA), each = 2))
  M
}

# TODO(Phase 2/handoff):
#   1. Extract a window ending AT high water (try 20, 30, 40 min lengths).
#   2. t_sec <- as.numeric(datetime - min(datetime))
#   3. fit <- lm(water_cm ~ poly(t_sec, 2, raw = TRUE) + osc_design(t_sec))
#   4. Predict 30 steps (5 min) beyond the window; compute RMSE vs actual.
#   5. Report how RMSE changes with window length -> pick a sensible time frame.
