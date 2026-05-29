# =============================================================================
# 04_external.R  --  Section 3.3 Q9-Q10: external information (20 pts)
# -----------------------------------------------------------------------------
# Depends on: source("R/00_load_data.R")  -> load_10min()
#
# Q9  Rijkswaterstaat claims fixed lags between locations:
#       OS11 -> RPBU  ~  6 min,   VR -> RPBU ~ 23 min,   so VR -> OS11 ~ 17 min.
#     Check via cross-correlation / lagged regression on the 10-minute data.
#     IMPORTANT CAVEAT to discuss: the 10-min sampling cannot resolve a 6-min
#     lag exactly -> either interpolate to a finer grid or state the resolution
#     limit honestly (the rubric rewards quantifying the error).
# Q10 PROPOSE ONLY (do not execute): because VR leads RPBU by ~23 min and has no
#     harbour oscillations, use lagged VR as a clean leading indicator (an
#     exogenous regressor / ARX-style term) to extend the forecast horizon.
#     Note: VR data may be unavailable during heavy storms.
#
# This is a SKELETON. Filled in during Phase 2 / handoff.
# =============================================================================

# TODO(Phase 2/handoff):
#   wide <- load_10min()
#   - Q9: use ccf(wide$RPBUwaterlevel, wide$VRwaterlevel) etc. to find the lag
#         that maximises cross-correlation; convert lag (in 10-min steps) to
#         minutes; compare to the claimed 6 / 23 / 17 min.
#         Alternatively fit lm(RPBU ~ lagged VR) over a grid of lags and pick
#         the best-fitting lag. Discuss resolution limit + interpolation.
#   - Q10: written suggestion only, with a small diagram/argument in the report.
