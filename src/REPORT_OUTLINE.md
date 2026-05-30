# Report writing outline (assemble at the END)

We are working **code-first**: all analysis lives in `R/00_load_data.R` ... `R/04_external.R`.
The report (`report.Rmd`) is rebuilt at the very end from this outline + the scripts.
Each section below lists what to write and the key findings to expand into prose.

## Render config (recreate report.Rmd YAML with this)
- Output: `bookdown::pdf_document2` (gives numbered figures/tables + `\@ref` cross-refs).
- `number_sections: true`, `toc: true`, `toc_depth: 2`, `geometry: margin=2.5cm`.
- `knitr::opts_chunk$set(echo=FALSE, message=FALSE, warning=FALSE, cache=TRUE, fig.align="center")`.
- Put full R scripts in the Appendix; keep total **<= 15 pages**.
- Render in-place (NOT into a separate output/ dir) — folder path has spaces, which breaks
  LaTeX figure paths when absolute. Knit button in RStudio does the right thing.

## 1. Introduction
- 1953 North Sea flood (1836 deaths) -> Delta Works -> Oosterschelde storm surge barrier.
- Barrier closes by law at +3.00 m NAP at RPBU; decision team re-decides every minute and
  needs a 5-minute-ahead prediction of the level.
- RPBU harbour geometry causes oscillations (periods ~545/205/85 s) that may NOT be filtered.
- Data: RPBU @ 10 s; OS11/VR/wind @ 10 min. Goal: short-term prediction at RPBU.
- End with a one-paragraph roadmap of the report.

## 2. Exploratory Data Analysis

### Q1 — Shape around high tide  [CODE DONE: R/01_eda.R]
- Functions: `eda_daily_max()`, `day_peak()`, `plot_full_day()`, `plot_highwater()`.
- Record: 2010-03-01 to 2011-03-31, 10 s sampling. Sentinel 9995 cm -> NA (in loader).
- Chosen days: **2010-08-30 (265 cm)** and **2010-03-01 (246 cm)** (both complete data).
- Findings to write up:
  1. Semidiurnal tide (two highs/day); each high water is a smooth, rounded **dome**,
     roughly symmetric, with a broad flat **"stand"** at the top (small rate of change).
  2. Harbour **oscillations** ~5-20 cm ride on the trend, clearest on the rising flank /
     near the peak; periods of a few minutes; cannot be filtered out by regulation.
  3. Day-to-day variability: oscillations larger on 30 Aug, smaller on 1 Mar; storm days
     far more irregular (4 Oct 2010 driven past +3.00 m closure threshold).

### Q2 — Suppressing the oscillations  [CODE DONE: R/01_eda.R]
- Functions: `smooth_movavg()`, `smooth_spline_trend()`, `q2_smoothed()`, `plot_q2()`.
- Method: centred moving average of width = slowest period (~545 s = 55 samples at 10 s).
  Averaging a full cycle nulls the 545 s oscillation exactly and attenuates the 205/85 s.
- Cross-checked with `smooth.spline` (spar=0.8). NOTE: `loess` segfaults in this
  R 4.6.0 / Windows build, so we use smooth.spline as the R-smoother comparison.
- Findings: both smoothers recover a smooth tidal **dome**. On 30 Aug (oscillation-rich)
  the 55-pt moving average leaves small residual wiggles (single rectangular window does
  not fully cancel the faster oscillations); the spline is visually cleaner. On 1 Mar the
  oscillations are tiny and the two agree closely. The clean dome motivates the Q3 parabola.

### Q3 — Simple trend model  [CODE DONE: R/01_eda.R]
- Functions: `q3_parabola()` (fit + interpreted numbers), `plot_q3()` (overlay).
- Model: downward **parabola** w(t) = a - b (t - t0)^2, fit as a quadratic regression
  (lm: water ~ tc + tc^2, tc = minutes from high water) on +/- 45 min around the peak.
  Least squares treats the oscillations as zero-mean noise and recovers the trend.
- Fit quality: 1 Mar (clean dome) R2 = 0.96 at every window (parabola excellent);
  30 Aug (broad flat "stand") R2 = 0.75 at +/-45 min, rising to 0.90 at +/-60 min
  (a single parabola smooths over its slight double-bump top). Curvature c2 < 0 (dome).
- Physics (the "does it coincide" answer): the parabola is the 2nd-order Taylor
  expansion of the tidal cosine A cos(omega t) at high water (cos x ~ 1 - x^2/2), so
  b = A omega^2 / 2 > 0. So YES it matches elementary tide physics. Keep this
  QUALITATIVE: the measured curvature is sharper than a pure M2 cosine predicts
  (real tide = many constituents + shallow-water effects), so don't claim a precise
  amplitude match.

## 3. Predictions of RPBU

### Q4 — Linear regression model  [TODO]
- Fixed periods 545/205/85 s. a sin(w(t-phi)) = alpha sin(wt) + beta cos(wt) -> LINEAR.
- Model: quadratic trend + 3 sin/cos pairs, fit with `lm()`.
- Fit on a window before high water; experiment with window length; report 5-min-ahead RMSE.

### Q5 — Non-linear model  [TODO]
- Periods free. Classify: conditionally linear (linear in amplitudes/trend given freqs),
  otherwise intrinsically non-linear. Parameter count: 3 (trend) + 3x3 = 12.

### Q6 — Estimation algorithm  [TODO]
- Gauss-Newton / Levenberg-Marquardt (`nls` / `minpack.lm::nlsLM`).
- With `nls(algorithm="plinear")` only the non-linear params (freqs, phases) need starts.

### Q7 — Non-linear vs linear fits  [TODO]
- Refit Q4 cases; starts from known periods / Q4 amplitudes / FFT; compare fit + drift.

### Q8 — Self-starter function  [TODO]
- FFT/periodogram to detect dominant freqs + lm for amplitudes, wrapped via `selfStart`.

## 4. Using External Information

### Q9 — Inter-location time lags  [TODO]
- Check claimed lags (OS11-RPBU 6 min, VR-RPBU 23 min, VR-OS11 17 min) via
  cross-correlation / lagged regression on the 10-min data.
- Caveat: 10-min sampling cannot resolve a 6-min lag exactly -> interpolate / state limit.

### Q10 — Using VR to improve RPBU  [TODO, proposal only]
- VR leads RPBU ~23 min and has no harbour oscillations -> clean leading indicator
  (lagged VR as exogenous regressor / ARX). Note: VR may be unavailable in storms.

## 5. Conclusion
- Summarise chosen model + time frame and the achieved 5-min prediction accuracy;
  note external-data improvement and practical caveats.

## 6. Appendix: R code
- Include 00_load_data.R ... 04_external.R.
