# Istio A/B Traffic Demo (TCP)

Flip Istio TCP traffic 100/0 -> 0/100 between two service versions, scrape Prometheus over the whole run (query_range), and plot the version share over time. The initial active version can be randomized per run, then traffic alternates deterministically for each cycle. Vertical markers show when a flip is applied and when the old version drains to ~0, with both JSON and CSV artifacts saved for later use.

## Prerequisites
- Istio base/ingress and Prometheus are already installed on the cluster.
- The base stack from `Experiments/ansible-k3s-ric-j-e2sim` has been deployed successfully (RIC, E2Sim mode as needed, and base `kpimon-go` assets/configmaps).
- Prometheus is reachable at `http://localhost:9090` from the Ansible control node (e.g., via SSH tunnel/port forward).
- Ansible with `kubernetes.core` available on the control node.
- Kubernetes Python dependencies available on the target `k3s_master` host (installed by the base stack playbooks).
- Python 3 plus `plotly` on the Ansible controller host (used by `scripts/plot_ab.py` to render HTML output).

## Configuration (`group_vars/all.yml`)
- `kubeconfig`: path used on the remote `k3s_master` host for `kubernetes.core.k8s` (defaults to `<remote-home>/.kube/config`).
- `namespace`, `tcp_ports`, `service_name`, `service_host`, `versions`: traffic policy inputs (two versions required); `service_host` should match the Prometheus `destination_service` label.
- `ab_randomize_start_version`: if `true` (default), each run randomizes which entry in `versions` starts as active (`primary_version`); set to `false` to keep deterministic `versions[0]` -> `versions[1]` order.
- `kpimon_v1_image`, `kpimon_v2_image`: image tags for AB variants (default both `splicer3/kpi-mon-xapp:1.0.1`).
- `kpimon_v1_deployment_name`, `kpimon_v2_deployment_name`: AB deployment names.
- `kpimon_app_label`, `kpimon_release_label`, `kpimon_namespace`: selectors/namespace used to discover base deployment(s) and deploy AB variants.
- `kpimon_base_target_replicas`: replica count applied to non-AB kpimon deployments before starting the experiment (default `0`).
- `kpimon_configmap_appenv`, `kpimon_configmap_appconfig`, `kpimon_dbaas_configmap`: required ConfigMaps mounted/referenced by AB deployments.
- `traffic_cycle_seconds`, `cycles`: how long each leg lasts and how many flip pairs to run.
- Prometheus/query:
  - `prometheus_url`: default `http://localhost:9090` (tunneled).
  - `prom_metric`: default `istio_tcp_received_bytes_total` (TCP throughput).
  - `prom_reporter`: default `destination` to avoid double counting.
  - `prom_scrape_interval`: expected Prometheus scrape interval for Istio metrics (default `15s`).
  - `prom_range_window`: default `max(2 * prom_step, 2 * prom_scrape_interval)` so `rate()` has enough samples while staying responsive for flip detection.
  - `prom_step`: default `15s` query_range step.
  - `flip_drop_threshold`: value considered "drained" for the old version when marking effective flips.
- Plotting:
  - `plot_python_bin`: Python interpreter used to run `scripts/plot_ab.py` on the controller (default `python3`).
  - `plot_html_title`: title for the generated Plotly HTML chart.

## How to run
1) Deploy infrastructure first:
   ```
   cd Experiments/ansible-k3s-ric-j-e2sim
   ansible-playbook site.yml -K
   ```
2) Ensure `Experiments/istio-ab-testing/inventory/hosts.ini` points to the same cluster host used above.
3) Run the end-to-end AB demo:
   ```
   cd Experiments/istio-ab-testing
   ansible-playbook playbooks/run_demo.yml
   ```
   - The playbook first verifies required service/configmaps, scales non-AB `kpimon-go` deployment(s) to `kpimon_base_target_replicas`, and deploys `v1`/`v2`.
   - It then applies the DestinationRule/VirtualService, logs the chosen primary/secondary order for the run, flips traffic for `cycles`, runs a Prometheus `query_range` covering the whole window, fetches the JSON to `artifacts/metrics/`, writes flip metadata to `artifacts/metrics/flip_events_<utc>.json`, and produces CSV + Plotly HTML artifacts.

Homebrew Ansible note:
- If `ansible-playbook` comes from Homebrew, install plotting dependencies in the same interpreter used by `plot_python_bin`, for example:
  - `$(which python3) -m pip install --user plotly`

Post-run state:
- AB deployments remain (`ricxapp-kpimon-go-v1`, `ricxapp-kpimon-go-v2` by default).
- Base non-AB `kpimon-go` deployment(s) remain scaled to `kpimon_base_target_replicas` (default `0`).

## Artifacts
- `artifacts/metrics/*.json`: Prometheus `query_range` responses.
- `artifacts/metrics/*.csv`: Pivoted time series (time column + one column per version).
- `artifacts/metrics/*.html`: Interactive Plotly A/B chart with flip markers.
- `artifacts/metrics/flip_events_*.json`: Flip timestamps (`to_version`/`from_version`) using the same UTC run suffix as the corresponding metrics file.

## Adjustments
- Change flip cadence with `traffic_cycle_seconds` and `cycles`.
- Switch to HTTP by editing `roles/istio_traffic/templates/virtualservice.yaml.j2` (use `http:` rules) and `prom_metric` to `istio_requests_total`.
- Tune the drain detection by changing `flip_drop_threshold` or pass `--drop-threshold` to `scripts/plot_ab.py`.
- Extend traffic policies by adding new templates under `roles/istio_traffic`.
