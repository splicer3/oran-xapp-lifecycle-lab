# Istio Rate Limit Demo Playbook

This repository includes an automated playbook that enables Istio local rate limiting on the `demo-nginx` workload, records a metrics window, exports throughput data, and removes the EnvoyFilter so you can study the behaviour before, during, and after rate limiting.
> :warning: **The RPS limit is applied to each pod**, so the global equivalent RPS is `local_rps * number of pods`.

## Prerequisites

- A working Kubernetes cluster with Istio sidecars injected into the target namespace (defaults to `demo-nginx`).
- The `demo-nginx` workload deployed via this repository (`ansible-playbook site.yaml` or the relevant playbook).
- Ansible and required collections installed (activate the provided virtualenv: `source .venv/bin/activate`).
- Plotly Python package available in the environment (`pip install plotly`).
- Authenticated `kubectl` context pointing at the cluster.
- A Prometheus instance reachable at `http://127.0.0.1:9090` (default). Run a port-forward if necessary:
  ```bash
  kubectl -n istio-system port-forward svc/prometheus 9090:9090
  ```

## Optimal Prerequisite Setup

1. Ensure `virtualbox` and `vagrant` are installed on the target computer using your system's package manager.
2. Ensure the target system has enough CPU, memory, and disk for two Ubuntu VMs, or adjust the Vagrantfile template and inventory for a smaller topology.
3. Run `ansible-playbook site.yaml -J -K` to bring up the VMs, K3s, and the `demo-nginx` namespace.
4. If you ran the `site.yaml` playbook, the SSH tunnel for `kubectl` should already be running. If not, manage it with `scripts/k3s-tunnel.sh connect|disconnect`.
5. Run `export KUBECONFIG=[ProjectRootDirectory]/artifacts/kubeconfig`
6. Install `istioctl` following the [official docs](https://istio.io/latest/docs/setup/additional-setup/download-istio-release/)
7. Run `istioctl install --set profile=minimal` to avoid installing Istio Ingress Gateway
8. Label the `demo-nginx` namespace for Istio sidecar injection by running: `kubectl label namespace demo-nginx istio-injection=enabled --overwrite`
9. Wait for the 2-container Nginx pods to go up. If any issues arise, check that flannel and CoreDNS work as expected.
10. Install Prometheus, Grafana and Kiali using the official docs' quick start manifests:
```bash
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/prometheus.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/grafana.yaml
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.27/samples/addons/kiali.yaml
```
11. Port forward Prometheus with: `kubectl -n istio-system port-forward svc/prometheus 9090:9090`
12. Start hitting the demo hostname in the background after resolving the ingress LoadBalancer IP: `while true; do curl -s --resolve nginx.local.dev:80:<INGRESS_LB_IP> http://nginx.local.dev/ > /dev/null; done`.
13. (Optional) Edit the Prometheus ConfigMap with `kubectl -n istio-system edit cm prometheus` for additional tweaking, especially regarding the scrape interval (which is 15s by default, but can be pushed down to 5s), and force changes by deleting the Prometheus pods and waiting for them to be recreated: `kubectl -n istio-system delete pod -l app=prometheus`.

## Running the Demo

1. (Optional) Adjust rate limiting parameters by overriding variables. For example:
   ```bash
   ansible-playbook playbooks/istio/rate_limit_demo.yaml \
     -e rps=5 \
     -e demo_wait_seconds=120
   ```
2. Execute the playbook:
   ```bash
   ansible-playbook playbooks/istio/rate_limit_demo.yaml
   ```
3. The playbook will:
   - Apply an EnvoyFilter that limits traffic to the configured RPS multiplied by the number of pods.
   - Wait for the specified stabilization window.
   - Continue gathering data for a configurable padding window before and after rate limiting so graphs show lead-in and tail behaviour.
   - Query Prometheus for HTTP 200 and 429 rates over the padded window.
   - Persist metrics and marker CSV files under `artifacts/rate-limit/`.
   - Remove the EnvoyFilter to restore normal traffic.
   - Run `scripts/plot_rate_limit.py` with appropriate arguments to save an interactive plot in `artifacts/rate-limit`.

## Outputs

After the run you will find three CSV files and an HTML file in `artifacts/rate-limit/`:

- `rate_limit_demo_200.csv` – successful request throughput over time (`time,throughput_rps`).
- `rate_limit_demo_429.csv` – rate-limited (HTTP 429) throughput over time (`time,rate_limited_rps`).
- `rate_limit_demo_markers.csv` – key playbook timestamps to overlay on charts (`time,label`). The file includes rate-limit enable/disable events and an automatically detected `rate_limit_effective` timestamp (first moment either the 200 RPS drops below the configured per-pod threshold or 429 responses appear).
- `rate_limit_demo_plot.html` – interactive Plotly dashboard combining the throughput curves and marker annotations. Open in a browser to inspect the rate limit behaviour.

## Customisation

All behaviour is driven by Ansible variables, so you can override namespace, workload labels, rate limit value, pod replica count (`rate_limit_pod_count`, autodetected when omitted), padding duration (`metrics_padding_seconds`), Prometheus address, sampling window, artifact naming, and Plotly output path without editing the playbook. See `playbooks/istio/rate_limit_demo.yaml`, `roles/export_throughput_csv/defaults/main.yaml`, and `scripts/plot_rate_limit.py` for the available knobs.
