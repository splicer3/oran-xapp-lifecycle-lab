# Time-Based Switching

The time-based traffic experiment lives in `ansible/istio-ab-testing`.

It prepares two KPI MON deployments, applies Istio `DestinationRule` and `VirtualService` templates, alternates TCP traffic weights between versions, collects Prometheus `query_range` data, and renders CSV/HTML artifacts with `scripts/plot_ab.py`.

Important files:

- `ansible/istio-ab-testing/playbooks/run_demo.yml`
- `ansible/istio-ab-testing/playbooks/prepare_kpimon_ab.yml`
- `ansible/istio-ab-testing/playbooks/istio_traffic_ab.yml`
- `ansible/istio-ab-testing/playbooks/collect_metrics.yml`
- `ansible/istio-ab-testing/roles/istio_traffic/templates/virtualservice.yaml.j2`
- `ansible/istio-ab-testing/roles/istio_traffic/templates/destinationrule.yaml.j2`
- `ansible/istio-ab-testing/scripts/plot_ab.py`

The sample outputs under `results/sample/ab-testing` are small reference artifacts. They are not published as benchmark results.

## Limitations

Istio traffic changes are not instantaneous. Sidecar configuration propagation, Prometheus scrape timing, query range windowing, and workload readiness all affect the apparent convergence time.
