# Rate-Limit Samples

This directory contains small curated CSV outputs from the Istio local-rate-limit demo.

The files are intended for checking the plotting script and documenting artifact format. This demo is separate from the Near-RT RIC lifecycle workflow.

## Files

| File | Contents |
| --- | --- |
| `csv/rate_limit_demo_200.csv` | `time,throughput_rps` values for successful HTTP responses. |
| `csv/rate_limit_demo_429.csv` | `time,rate_limited_rps` values for rate-limited HTTP responses. |
| `csv/rate_limit_demo_markers.csv` | `time,label` marker events used by the Plotly renderer. |
