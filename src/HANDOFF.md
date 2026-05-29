# Handoff guide for the team

> Status: **placeholder** — the detailed per-question walkthroughs are written in
> Phase 3, once the scope split is final. For now this records the plan.

## How the work is split
- **[Your name]** completes: _to be decided_ (recommended: Q1-3, the EDA).
- **Partners** complete the rest, using the step-by-step walkthroughs below.

## What's already done for you
- Environment setup: see `SETUP.md`.
- Shared data loading: `R/00_load_data.R` (just `source()` it; call `load_rpbu()`
  / `load_10min()`).
- A finished worked example to copy the style from: the EDA section.
- A skeleton for every question in `R/` with the approach written as comments.

## Per-question walkthroughs
<!-- Phase 3 fills this in: for each handed-off question, a plain-language
explanation of the math, what each step does, and a runnable R skeleton with
TODOs to fill. Written assuming no R/stats fluency. -->

- **Q4 — linear model:** _walkthrough TBD_
- **Q5 — non-linear model:** _walkthrough TBD_
- **Q6 — estimation algorithm:** _walkthrough TBD_
- **Q7 — non-linear refit & compare:** _walkthrough TBD_
- **Q8 — self-starter function:** _walkthrough TBD_
- **Q9 — inter-location lags:** _walkthrough TBD_
- **Q10 — using VR (proposal only):** _walkthrough TBD_

## How to add your section to the report
1. Open `report.Rmd`, find the `## ... (Qn)` heading for your question.
2. Replace the `<!-- TODO -->` comment with your text and code chunks.
3. Put real analysis code in the matching `R/0x_*.R` file; call it from the chunk.
4. Click **Knit** and check the PDF in `output/`. Keep the whole report <= 15 pages.
