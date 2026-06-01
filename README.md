# oran-xapp-lifecycle-lab

`oran-xapp-lifecycle-lab` is a curated O-RAN Near-RT RIC xApp lifecycle automation testbed. It uses Ansible to build a single-VM K3s environment, deploy the O-RAN Software Community Near-RT RIC, install a `kpimon-go` xApp, run a customized e2sim workload for sustained E2SM-KPM traffic, and evaluate xApp traffic switching with Istio, Prometheus, Grafana, and Kiali.

## What This Repository Contains

- `ansible/ric-lifecycle`: the main Infrastructure as Code workflow for K3s, Docker, Istio, OSC Near-RT RIC, optional E2Term exposure, e2sim, KPI MON xApp onboarding, and validation.
- `ansible/istio-ab-testing`: the Time-Based Switching experiment for `kpimon-go` A/B traffic testing with Istio TCP routing and Prometheus metrics collection.
- `ansible/istio-rate-limit-demo`: an optional K3s/NGINX/Istio demo used to exercise local rate limiting and observability mechanics.
- `docs`: architecture notes, design decisions, observability notes, e2sim customization notes, switching details, and troubleshooting guidance.
- `experiments/time-based-switching`: the notebook used with the curated A/B switching samples.
- `results/sample`: small CSV and Markdown samples kept for script validation and artifact format reference.
- `k8s`: pointers to Kubernetes and Istio manifests that are rendered by Ansible roles.

This is not a thesis dump. Private inventories, kubeconfigs, packet captures, large generated logs, report PDFs, and personal material are intentionally excluded.

## Architecture Summary

The main lab path is a single Linux VM running K3s with Traefik disabled. Ansible installs Docker, deploys the OSC Near-RT RIC J-release components, configures Istio with the minimal profile, optionally installs Istio sample addons for Prometheus/Grafana/Kiali, and onboards `kpimon-go` through the RIC xApp flow.

e2sim runs as a Docker container and can be configured for sustained E2SM-KPM report traffic. The A/B experiment creates two `kpimon-go` variants, applies Istio `DestinationRule` and `VirtualService` templates, alternates TCP weights over time, and queries Prometheus to produce JSON, CSV, and HTML artifacts.

SCTP/E2 signaling is not natively visible to Istio/Envoy sidecars. Istio telemetry is useful for sidecar-observed TCP traffic around xApp services, while SCTP inspection requires separate tooling and is not published here.

## Main Features

- Ansible-driven single-VM K3s testbed.
- OSC Near-RT RIC deployment from upstream `ric-plt-ric-dep`.
- KPI MON xApp onboarding and validation.
- e2sim container integration with configurable environment and command overrides.
- Istio minimal profile with namespace sidecar injection.
- Prometheus, Grafana, and Kiali addon installation through pinned Istio sample branches.
- Time-Based Switching for xApp A/B traffic experiments.
- Plotly-based conversion of Prometheus query results into CSV and HTML charts.
- Small public sample outputs for local script checks.

## Prerequisites

Controller host:

- Ansible / `ansible-core`
- Python 3
- `plotly` for local chart rendering
- SSH access to the target VM
- `kubectl` for manual cluster inspection

Target VM for `ansible/ric-lifecycle`:

- Ubuntu/Debian-compatible Linux
- Sudo privileges for the SSH user
- Internet access for package, image, Helm, Istio, and O-RAN SC downloads
- Enough CPU, memory, and disk for K3s, OSC Near-RT RIC, Istio, and xApp workloads

Optional rate-limit demo:

- VirtualBox and Vagrant on the hypervisor host
- A lab network that can support the host-only and optional bridged VM interfaces

Real inventories and kubeconfigs must stay local. Use the committed `*.example` files as templates.

## Quick Start

The commands below are tied to files present in this repository. Deployment commands require a real lab VM and a temporary inventory edited for that VM.

1. Install Ansible collections for the main RIC lifecycle workflow:

   ```bash
   cd ansible/ric-lifecycle
   ansible-galaxy collection install -r collections/requirements.yml
   ```

2. Create a temporary inventory outside the repository and edit it for your VM:

   ```bash
   cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
   ${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
   ```

3. Check playbook syntax before touching the VM:

   ```bash
   ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
   ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check reset.yml -i inventory/hosts.ini.example
   ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
   ```

4. Deploy the main lab stack:

   ```bash
   ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K
   ```

5. Run validation explicitly if needed:

   ```bash
   ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
   ```

6. After the RIC stack and Prometheus access are available, run the Time-Based Switching experiment:

   ```bash
   cd ../istio-ab-testing
   cp inventory/hosts.ini.example /tmp/istio-ab-hosts.ini
   ${EDITOR:-vi} /tmp/istio-ab-hosts.ini
   ansible-playbook playbooks/run_demo.yml -i /tmp/istio-ab-hosts.ini
   ```

The A/B workflow expects Prometheus to be reachable from the controller at the configured `prometheus_url`, which defaults to `http://localhost:9090`.

## Validation Workflow

Use syntax checks for the Ansible lifecycle playbooks:

```bash
cd ansible/ric-lifecycle
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check reset.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
```

Check the A/B plotting script against the curated sample:

```bash
cd ansible/istio-ab-testing
python3 scripts/plot_ab.py --in-csv ../../results/sample/ab-testing/csv/ABTesting_kpimonV2.csv --out-html /tmp/ab-sample.html
```

Check the rate-limit plotting script against the curated sample:

```bash
cd ansible/istio-rate-limit-demo
python3 scripts/plot_rate_limit.py \
  --success-csv ../../results/sample/rate-limit/csv/rate_limit_demo_200.csv \
  --limited-csv ../../results/sample/rate-limit/csv/rate_limit_demo_429.csv \
  --markers-csv ../../results/sample/rate-limit/csv/rate_limit_demo_markers.csv \
  --output /tmp/rate-limit-sample.html
```

The GitHub Actions workflow in `.github/workflows/ci.yml` mirrors these lightweight checks and blocks common unsafe artifacts.

## Expected Outputs

Main RIC lifecycle validation checks for:

- required RIC namespaces
- K3s without Traefik
- Istio control plane availability
- sidecar injection on target namespaces
- Prometheus, Grafana, and Kiali deployments when enabled
- optional E2Term SCTP NodePort mapping
- `kpimon-go` xApp deployment image
- e2sim container state in `fully-functional` mode

The Time-Based Switching workflow creates an ignored artifacts directory inside `ansible/istio-ab-testing` during a run. Typical artifacts include Prometheus JSON snapshots, pivoted CSV files, Plotly HTML charts, and `flip_events_*.json`.

The optional rate-limit demo creates an ignored artifacts directory inside `ansible/istio-rate-limit-demo`. Curated static examples are kept under `results/sample`.

## Repository Structure

```text
.
├── ansible/
│   ├── ric-lifecycle/
│   ├── istio-ab-testing/
│   └── istio-rate-limit-demo/
├── docs/
├── experiments/
├── k8s/
├── results/
│   └── sample/
├── scripts/
├── .github/workflows/
├── AGENTS.md
├── CITATION.cff
├── LICENSE
├── SECURITY.md
└── THIRD_PARTY.md
```

See `docs/architecture.md`, `docs/design-decisions.md`, `docs/observability.md`, `docs/e2sim-customization.md`, and `docs/time-based-switching.md` for focused notes.

## Known Limitations

- SCTP/E2 traffic is not natively visible to Istio/Envoy sidecars. Sidecar telemetry does not replace SCTP-specific inspection.
- Time-Based Switching preserved throughput continuity in the thesis experiments, but switch convergence latency was the main bottleneck.
- Prometheus scrape interval, query windows, sidecar propagation, and workload readiness all affect observed switching time.
- The default `e2sim_image` uses `splicer3/e2sim:latest`; pin it before using the lab for repeatable comparisons.
- The public repository does not include packet captures, kubeconfigs, real inventories, or raw generated result batches.
- The optional rate-limit demo is separate from the RIC lifecycle workflow.

## Citation / Thesis Context

This repository is a public engineering release derived from bachelor thesis work on O-RAN Near-RT RIC xApp lifecycle automation. It keeps the reproducible lab automation and selected small artifacts, not private thesis material.

Use `CITATION.cff` if you need citation metadata for the repository. The sample results under `results/sample` document artifact format and selected thesis-era observations; they should not be treated as general performance benchmarks.

## License And Third-Party Notes

Repository code and documentation are released under the MIT license in `LICENSE`.

The automation installs or interacts with third-party projects including O-RAN SC RIC components, K3s, Istio, Prometheus, Grafana, Kiali, Helm, ChartMuseum, Docker, Vagrant, VirtualBox, Ansible collections, and Plotly. See `THIRD_PARTY.md` for the maintained list and review upstream licenses before redistributing modified third-party source or images.
