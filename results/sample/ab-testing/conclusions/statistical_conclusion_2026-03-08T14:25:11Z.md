# Statistical Conclusion for Time-Shifted A/B Testing

- Analysis timestamp (UTC): 2026-03-08T14:25:11Z
- Mode: **confirmatory** (valid runs: 30, target runs: 20)
- Alpha: 0.05
- Effective switch definition: inactive throughput <= 0.0
- Flip latency SLA (s): 30
- Continuity max dip ratio: 0.1

## Primary hypothesis decisions
1. Transition reliability (one-sided Wilcoxon on run-level SLA margin): p_holm = 1.0
   - Transition reliability claim is not statistically supported at configured SLA.
2. Service continuity (one-sided Wilcoxon on run-level dip margin): p_holm = 1.862645149230957e-09
   - Service continuity claim is statistically supported (Holm-adjusted).

## Robustness summaries (flip-level)
- Valid flips included: 238
- P(latency <= 30s): 0.06722689075630252 (Wilson CI: 0.0418007900948252, 0.10640150324011394)
- P(dip <= 0.1): 1.0 (Wilson CI: 0.9841157970207982, 0.9999999999999999)

## Secondary exploratory analysis
- Version throughput difference (two-sided Wilcoxon, raw p): 0.9551453026484324

## Interpretation guidance
- If mode is exploratory, treat results as preliminary.
- Confirmatory interpretation requires at least MIN_RUNS_FOR_CONFIRMATORY valid runs.