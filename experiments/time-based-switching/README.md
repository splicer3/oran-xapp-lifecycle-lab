# Time-Based Switching Analysis

This directory contains the notebook used to analyze the curated KPI MON A/B switching samples.

The runnable traffic-switching workflow is `ansible/istio-ab-testing`.

`ab_statistical_validation.ipynb` is not invoked by Ansible. It expects archived Time-Based Switching metrics and flip-event files, then writes statistical CSV, HTML, and Markdown outputs. Raw run archives are not committed in this public release.

Before running the notebook, review the `DATA_ROOTS` and `OUTPUT_DIR` values in its first parameter cell. They reflect the historical analysis layout and may need local adjustment for regenerated artifacts.

Standard execution command:

```bash
jupyter nbconvert --execute --to notebook --inplace experiments/time-based-switching/ab_statistical_validation.ipynb
```
