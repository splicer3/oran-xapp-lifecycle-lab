# Observability

This testbed uses Istio telemetry and the Istio sample add-ons to observe mesh-enabled workloads. The boundary matters: HTTP and TCP traffic that passes through Envoy sidecars can be measured and visualized; SCTP traffic on the E2 interface is not natively visible through Istio in this repository.

## Installed Add-ons

The main install path is `ansible/ric-lifecycle/site.yml`. When `istio_enabled` and `istio_install_addons` are true, it runs `ansible/ric-lifecycle/roles/istio_addons`.

That role downloads and applies the Istio sample manifests configured in `ansible/ric-lifecycle/group_vars/all.yml`:

- Prometheus from the configured Istio `release-1.28` sample add-on URL.
- Grafana from the configured Istio `release-1.28` sample add-on URL.
- Kiali from the configured Istio `release-1.28` sample add-on URL.

The validation playbook checks that the `prometheus`, `grafana`, and `kiali` deployments are available in `istio-system` when add-ons are enabled.

## What Each Tool Is Used For

| Tool | Use in this repository |
| --- | --- |
| Prometheus | Scrapes Istio metrics and serves the Prometheus API used by the A/B and rate-limit workflows. |
| Grafana | Provides dashboard views over Prometheus data when the Istio sample add-on is installed. |
| Kiali | Shows mesh topology, workload/service relationships, and traffic rates for mesh-observed workloads. |

The automated A/B workflow in `ansible/istio-ab-testing` queries Prometheus through `prometheus_url`, which defaults to `http://localhost:9090`. The optional HTTP rate-limit demo in `ansible/istio-rate-limit-demo` also expects Prometheus on `http://127.0.0.1:9090` unless overridden.

## What Istio Observes Well

### HTTP Demo Traffic

The optional rate-limit demo uses the `demo-nginx` HTTP workload. Its telemetry export role queries `istio_requests_total` for HTTP response codes `200` and `429`, then writes CSV files and renders a Plotly HTML artifact.

Relevant files:

- `ansible/istio-rate-limit-demo/playbooks/istio/rate_limit_demo.yaml`
- `ansible/istio-rate-limit-demo/roles/export_throughput_csv/tasks/series.yaml`
- `ansible/istio-rate-limit-demo/scripts/plot_rate_limit.py`

This part checks basic HTTP telemetry, EnvoyFilter behavior, and Prometheus query/export mechanics. It is separate from the Near-RT RIC lifecycle workflow.

### TCP/RMR Traffic

The RIC/xApp workflow uses RMR over TCP for `kpimon-go`. The A/B workflow is configured for the RMR service:

- namespace: `ricxapp`
- service host: `service-ricxapp-kpimon-go-rmr.ricxapp.svc.cluster.local`
- TCP ports: `4560` and `4561`
- metric: `istio_tcp_received_bytes_total`
- reporter: `destination`

The A/B collection playbook queries Prometheus with `query_range`, groups by `destination_version`, and saves JSON snapshots that are later converted to CSV/HTML.

Relevant files:

- `ansible/istio-ab-testing/group_vars/all.yml`
- `ansible/istio-ab-testing/playbooks/collect_metrics.yml`
- `ansible/istio-ab-testing/scripts/plot_ab.py`

### Mesh Topology

Kiali is useful for seeing which mesh-enabled workloads are present and whether traffic is being observed between them. It can show topology for the HTTP demo and for RIC/xApp workloads that have sidecars and active traffic. Empty or sparse graphs usually mean no recent traffic, missing sidecars, or a Prometheus scrape issue.

## What Istio Does Not Observe Well

### SCTP On The E2 Interface

The E2 path between e2sim and E2Term uses SCTP. This lab does not route SCTP through Istio, and Envoy sidecars do not provide native E2AP/E2SM-KPM payload visibility here.

If `ric_e2term_expose_enabled=true`, the repository can create a Kubernetes `NodePort` service named `sctp-service` that maps SCTP `32222` to E2Term target port `36422`. That is Kubernetes service exposure, not Istio routing.

Relevant files:

- `ansible/ric-lifecycle/roles/e2term_expose/templates/e2term-nodeport-sctp.yml.j2`
- `ansible/ric-lifecycle/roles/e2term_expose/tasks/main.yml`
- `ansible/ric-lifecycle/playbooks/validate.yml`

### E2Sim To E2Term Visibility

Prometheus and Kiali can help infer that E2 input is affecting the xApp path when RMR/TCP traffic increases. They cannot prove SCTP handshake success, ASN.1 payload correctness, or E2SM-KPM compatibility. Those checks require E2/SCTP-aware diagnostics outside the mesh.

This public release does not include tcpdump scripts, diagnostic-container manifests, `.pcap` files, or sanitized packet captures. Keep any local packet captures out of the repository unless they are deliberately sanitized and reviewed.

## Hybrid Validation Approach

Use two layers:

1. Mesh layer: use Prometheus, Grafana, and Kiali for HTTP and RMR/TCP behavior that passes through sidecars.
2. E2/SCTP layer: use out-of-band SCTP diagnostics only in a private lab environment. No reproducible SCTP capture command is committed in this public release.

For the RMR/TCP layer, the same query shape used by the A/B workflow can be run manually after Prometheus is reachable:

```bash
curl 'http://localhost:9090/api/v1/query?query=sum(rate(istio_tcp_received_bytes_total{destination_workload_namespace="ricxapp",reporter="destination",destination_service="service-ricxapp-kpimon-go-rmr.ricxapp.svc.cluster.local"}[30s]))'
```

A non-zero value is an indirect signal that TCP traffic is reaching the xApp service path. It is not proof of SCTP/E2 correctness. For common failure modes, see [troubleshooting.md](troubleshooting.md).

## Accessing Dashboards

First deploy the main stack with add-ons enabled. The inventory copied to `/tmp` is a manual prerequisite and must be edited for the target VM.

```bash
cd ansible/ric-lifecycle
ansible-galaxy collection install -r collections/requirements.yml
cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e istio_install_addons=true
ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K -e istio_install_addons=true
```

Then run these commands from a shell that has cluster access. On the target VM created by `ansible/ric-lifecycle`, `k3s kubectl` is available after K3s installation.

```bash
k3s kubectl -n istio-system get deployments prometheus grafana kiali
k3s kubectl -n istio-system get svc prometheus grafana kiali
```

Port-forward the dashboard you need. Run each port-forward in its own terminal.

```bash
k3s kubectl -n istio-system port-forward svc/prometheus 9090:9090
k3s kubectl -n istio-system port-forward svc/grafana 3000:3000
k3s kubectl -n istio-system port-forward svc/kiali 20001:20001
```

Open:

- Prometheus: `http://localhost:9090`
- Grafana: `http://localhost:3000`
- Kiali: `http://localhost:20001`

If the port-forward runs on the VM and the browser runs on another machine, use an SSH tunnel or run `kubectl` from a machine that already has access to the cluster. Do not commit kubeconfigs or tunnel credentials.

## Workflow Examples

For Time-Based Switching, Prometheus access is required by:

```bash
cd ansible/istio-ab-testing
cp inventory/hosts.ini.example /tmp/istio-ab-hosts.ini
${EDITOR:-vi} /tmp/istio-ab-hosts.ini
ansible-playbook playbooks/run_demo.yml -i /tmp/istio-ab-hosts.ini
```

The workflow expects `prometheus_url` from `ansible/istio-ab-testing/group_vars/all.yml`, defaulting to `http://localhost:9090`.

For the optional HTTP rate-limit demo:

```bash
cd ansible/istio-rate-limit-demo
ansible-playbook playbooks/istio/rate_limit_demo.yaml
```

That playbook queries Prometheus, exports `200` and `429` series, and writes artifacts under `artifacts/rate-limit/`.

## Common Failure Modes

| Symptom | Likely cause | Checks |
| --- | --- | --- |
| Prometheus/Grafana/Kiali deployments are missing | `istio_install_addons` was false, the add-on role did not run, or the manifest download/apply failed. | Run `ansible-playbook playbooks/validate.yml ... -e istio_install_addons=true` and check `k3s kubectl -n istio-system get deployments`. |
| Port-forward fails | The service is missing, the local port is already in use, or the command is running from a machine without cluster access. | Check `k3s kubectl -n istio-system get svc prometheus grafana kiali`; change the local port if needed. |
| Prometheus query returns no data | No traffic during the query window, sidecar injection missing, scrape interval delay, or query labels do not match deployed workloads. | Check pod sidecars with the validation playbook and inspect Kiali after generating traffic. |
| RMR/TCP metric stays at zero | `kpimon-go` is not receiving traffic, e2sim/E2Term/subscription flow is not active, or traffic bypasses Envoy. | Validate the RIC lifecycle stack, e2sim mode, xApp deployment, and service host from `ansible/istio-ab-testing/group_vars/all.yml`. |
| Kiali topology is empty or stale | No recent traffic, Prometheus scrape gaps, namespace not sidecar-injected, or workloads not ready. | Generate traffic, wait at least one scrape interval, and check workload readiness. |
| SCTP/E2 is invisible in Kiali or Prometheus | Expected limitation. SCTP is outside native Istio sidecar telemetry in this lab. | Use RMR/TCP metrics as an indirect signal only; keep SCTP packet diagnostics local and out of git. |
| A/B switching latency looks high | Istio propagation, long-lived TCP/RMR connections, Prometheus scrape cadence, and query windows all affect observed convergence. | Treat switching latency as a lab observation, not as fixed platform behavior. |

## Publication Rules

- Do not commit `.pcap` or `.pcapng` files.
- Do not commit private dashboard screenshots.
- Do not commit kubeconfigs, Prometheus snapshots containing private labels, tunnel credentials, or large generated logs.
- Keep public examples small and tied to the committed sample artifacts.
