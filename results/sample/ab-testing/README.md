# A/B Testing Samples

This directory contains small curated outputs from the KPI MON Istio A/B traffic experiment.

The CSV files are samples for validating file paths and documenting artifact shape. They are not presented as general performance benchmarks.

## Files

| File | Contents |
| --- | --- |
| `csv/ABTesting_kpimonV1.csv` | Time series for one `kpimon-go` workload column. |
| `csv/ABTesting_kpimonV2.csv` | Time series with two `kpimon-go` workload columns. |
| `conclusions/statistical_conclusion_2026-03-08T14:25:11Z.md` | Example Markdown conclusion from thesis-era Time-Based Switching analysis. |

The CSV values are human-readable rates. Use generated Prometheus JSON or numeric pivot CSV files for fresh statistical analysis.
