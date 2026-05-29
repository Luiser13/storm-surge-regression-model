# =============================================================================
# 03_nonlinear.R  --  Section 3.2 Q5-Q8: NON-LINEAR model (40 pts)
# -----------------------------------------------------------------------------
# Depends on: source("R/00_load_data.R")
#
# Q5  Same trend + oscillations, but the PERIODS are now free parameters.
#     Classification: the model is CONDITIONALLY LINEAR (linear in the
#     amplitudes / trend coefficients once the frequencies are fixed) and
#     otherwise INTRINSICALLY NON-LINEAR (no transform makes the frequencies
#     linear). Parameter count: quadratic trend (3) + 3 x (amplitude, frequency,
#     phase) = 12 parameters.
# Q6  Estimation: Gauss-Newton / Levenberg-Marquardt (nls / minpack.lm::nlsLM).
#     With nls(algorithm = "plinear") you only need STARTING VALUES for the
#     NON-LINEAR parameters (frequencies + phases), not the amplitudes.
# Q7  Refit the Q4 cases non-linearly. Starting values from: known periods
#     545/205/85, the Q4 linear amplitudes/phases, and/or an FFT periodogram.
#     Compare fit quality and whether the estimated periods drift.
# Q8  Wrap the FFT-based frequency detection + linear amplitude estimate into an
#     R selfStart function so nls initialises itself automatically.
#
# This is a SKELETON. Filled in during Phase 2 / handoff.
# =============================================================================

# Non-linear model function: trend + 3 sines with FREE angular frequencies.
#   par = c(c0, c1, c2, a1, w1, p1, a2, w2, p2, a3, w3, p3)
nl_model <- function(par, t_sec) {
  c0 <- par[1]; c1 <- par[2]; c2 <- par[3]
  trend <- c0 + c1 * t_sec + c2 * t_sec^2
  osc <- 0
  for (k in 0:2) {
    a <- par[4 + 3*k]; w <- par[5 + 3*k]; p <- par[6 + 3*k]
    osc <- osc + a * sin(w * (t_sec - p))
  }
  trend + osc
}

# TODO(Phase 2/handoff):
#   - Q6: fit with minpack.lm::nlsLM (robust) or nls(algorithm = "plinear").
#   - Q7: start frequencies from 2*pi/c(545,205,85); compare to lm() results.
#   - Q8: self_start <- function(mCall, data, LHS, ...) { ...FFT to find the
#         dominant frequencies, then lm() for amplitudes... }  wrapped via
#         selfStart(model, initial, parameters).
