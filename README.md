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

| Area | Assumption / requirement |
| --- | --- |
| OS assumptions | Controller: Linux or macOS with Python 3, SSH, and Ansible. Target: Ubuntu/Debian-compatible Linux for the main `ansible/ric-lifecycle` workflow. |
| VM assumptions | Main path uses one reachable VM with a sudo-capable SSH user, outbound internet access, and enough CPU, memory, and disk for K3s, OSC Near-RT RIC, Istio, xApps, Docker containers, and downloaded charts/images. |
| Required CLI tools | `ansible-playbook`, `ansible-galaxy`, `python3`, `ssh`; `make` is optional for wrapper targets, and `kubectl` is useful for manual inspection. The playbooks use `k3s kubectl` on the target after K3s is installed. |
| Kubernetes/k3s assumptions | The main lifecycle playbook installs single-node K3s and disables Traefik. It does not assume an existing cluster. |
| Ansible requirements | Main workflow: `ansible/ric-lifecycle/collections/requirements.yml`. Optional rate-limit demo: `ansible/istio-rate-limit-demo/collections/requirements.yaml`. |
| Docker/container requirements | The main workflow installs Docker on the target VM. Docker is used for ChartMuseum containers and, in `fully-functional` mode, the `e2sim` container. |
| Optional local plotting | `ansible/istio-ab-testing/scripts/plot_ab.py` can emit CSV without Plotly. HTML rendering, and `ansible/istio-rate-limit-demo/scripts/plot_rate_limit.py`, require `plotly`. |
| Optional rate-limit demo | `ansible/istio-rate-limit-demo` uses Vagrant and VirtualBox and is separate from the RIC lifecycle path. It also expects local inventory and vault files that must not be committed. |

Real inventories, kubeconfigs, private IPs, and credentials must stay outside the repository. Start from committed `*.example` files and keep edited copies under `/tmp` or another local-only path.

## Quick Start

A small root Makefile exposes safe local checks. Deployment entry points remain the Ansible playbooks and Python scripts. Each command block below starts from the repository root.

### Local Sanity Checks

These commands do not modify a VM. They were run as part of this public-release pass.

```bash
make check-prereqs
make check-public-safety
```

The same checks can be run without `make`:

```bash
./scripts/check-prereqs.sh
./scripts/check-public-safety.sh
```

```bash
cd ansible/ric-lifecycle
ansible-galaxy collection install -r collections/requirements.yml
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check reset.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
```

```bash
cd ansible/istio-ab-testing
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/run_demo.yml -i inventory/hosts.ini.example
python3 scripts/plot_ab.py --in-csv ../../results/sample/ab-testing/csv/ABTesting_kpimonV2.csv --out-csv /tmp/ab-sample.csv
```

The A/B syntax check currently emits an Ansible warning about the variable name `namespace`. The playbook still parses.

### Minimal Path: RIC Platform Without E2Sim

This path changes the target VM and prompts for sudo with `-K`. It deploys K3s, Docker, Istio, OSC Near-RT RIC, and `kpimon-go`, but does not require the `e2sim` container to be running. Not tested in this pass because it requires a real lab VM.

```bash
cd ansible/ric-lifecycle
cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=e2sim-ready
ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=e2sim-ready
```

### Full Testbed Path: RIC, E2Sim, And Observability

This path changes the target VM and prompts for sudo with `-K`. It uses the repository default `fully-functional` mode, which expects the `e2sim` container to run, and installs Prometheus, Grafana, and Kiali when `istio_install_addons=true`. Not tested in this pass because it requires a real lab VM.

```bash
cd ansible/ric-lifecycle
test -f /tmp/ric-lifecycle-hosts.ini || cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=fully-functional
ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=fully-functional
```

### Time-Based Switching

Run this after the full testbed path and after Prometheus is reachable from the controller at the configured `prometheus_url` (`http://localhost:9090` by default). Not tested in this pass because it requires the deployed RIC testbed and live Prometheus access.

```bash
cd ansible/istio-ab-testing
cp inventory/hosts.ini.example /tmp/istio-ab-hosts.ini
${EDITOR:-vi} /tmp/istio-ab-hosts.ini
ansible-playbook playbooks/run_demo.yml -i /tmp/istio-ab-hosts.ini
```

### Teardown

The reset playbook exists for the main lifecycle workflow. These commands change the target VM and prompt for sudo with `-K`. Not tested in this pass.

```bash
cd ansible/ric-lifecycle
ansible-playbook reset.yml -i /tmp/ric-lifecycle-hosts.ini -K
```

K3s uninstall is intentionally gated by an explicit confirmation variable:

```bash
cd ansible/ric-lifecycle
ansible-playbook reset.yml -i /tmp/ric-lifecycle-hosts.ini -K \
  -e reset_uninstall_k3s=true \
  -e reset_confirm_uninstall_k3s=YES_UNINSTALL_K3S
```

The separate HTTP rate-limit demo also has a lifecycle and teardown:

```bash
cd ansible/istio-rate-limit-demo
ansible-galaxy collection install -r collections/requirements.yaml
ansible-playbook site.yaml -K -J
ansible-playbook site-reset.yaml -K
```

Those commands are not part of the RIC path. They use the optional Vagrant/VirtualBox demo, require a local `inventory/hosts.ini` and Ansible vault as described in `ansible/istio-rate-limit-demo/README.md`, and were not tested in this pass.

## Validation Workflow

The main validation command is the committed lifecycle validator:

```bash
cd ansible/ric-lifecycle
ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
```

For local artifact checks without a VM, use the sample A/B CSV:

```bash
cd ansible/istio-ab-testing
python3 scripts/plot_ab.py --in-csv ../../results/sample/ab-testing/csv/ABTesting_kpimonV2.csv --out-csv /tmp/ab-sample.csv
```

Optional HTML chart rendering requires Plotly:

```bash
cd ansible/istio-ab-testing
python3 scripts/plot_ab.py --in-csv ../../results/sample/ab-testing/csv/ABTesting_kpimonV2.csv --out-html /tmp/ab-sample.html
```

The rate-limit sample renderer also requires Plotly and is separate from the RIC lifecycle:

```bash
cd ansible/istio-rate-limit-demo
python3 scripts/plot_rate_limit.py \
  --success-csv ../../results/sample/rate-limit/csv/rate_limit_demo_200.csv \
  --limited-csv ../../results/sample/rate-limit/csv/rate_limit_demo_429.csv \
  --markers-csv ../../results/sample/rate-limit/csv/rate_limit_demo_markers.csv \
  --output /tmp/rate-limit-sample.html
```

HTML rendering commands were not tested in this pass because Plotly was not installed locally. The GitHub Actions workflow in `.github/workflows/ci.yml` installs Plotly, compiles both plotting scripts, syntax-checks the main lifecycle playbooks, and blocks common unsafe artifacts.

`scripts/check-public-safety.sh` is a lightweight repository scanner for obvious unsafe files and secret-like values. It does not replace a dedicated scanner; `gitleaks detect --source .` is a useful stronger check when `gitleaks` is installed.

## Expected Outputs

The lifecycle validator is the first success signal. It checks required RIC namespaces, K3s without Traefik, Istio control-plane availability, sidecar injection, optional Istio addons, optional E2Term SCTP NodePort mapping, the `kpimon-go` xApp image, and e2sim container state in `fully-functional` mode.

Manual inspection commands below are for the target VM after deployment:

| Signal | Command | Expected result |
| --- | --- | --- |
| Pods ready | `k3s kubectl get pods -A` | RIC, Istio, and xApp pods are `Running` or `Succeeded`; validation fails if required namespace pods are unhealthy. |
| Namespaces present | `k3s kubectl get ns ricplt ricinfra ricxapp istio-system` | Main RIC and Istio namespaces exist. |
| RIC services present | `k3s kubectl -n ricplt get svc` and `k3s kubectl -n ricxapp get svc` | RIC platform services and xApp services are listed. |
| xApp deployed | `k3s kubectl -n ricxapp get deploy | grep kpimon` | A `kpimon-go` deployment is present. |
| E2Sim traffic running | `docker ps --filter name=e2sim` and `docker logs e2sim --tail 50` | In `fully-functional` mode, the `e2sim` container is running. Logs should be reviewed for active connection/report output; validation checks container state, not full KPM semantics. |
| Prometheus, Kiali, Grafana reachable | `k3s kubectl -n istio-system get deploy prometheus kiali grafana` | Addon deployments are available when `istio_install_addons=true`. See `docs/observability.md` for manual port-forward access. |

The Time-Based Switching workflow creates an ignored artifacts directory inside `ansible/istio-ab-testing` during a run. Typical artifacts include Prometheus JSON snapshots, pivoted CSV files, Plotly HTML charts, and `flip_events_*.json`.

The optional rate-limit demo creates an ignored artifacts directory inside `ansible/istio-rate-limit-demo`. Curated static examples are kept under `results/sample`.

For failures, start with `docs/troubleshooting.md`, then use `docs/e2sim-customization.md`, `docs/observability.md`, or `docs/time-based-switching.md` for workflow-specific checks.

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
├── LICENSE_DECISION.md
├── Makefile
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

Original repository code and documentation are released under the MIT license in `LICENSE`. The license does not apply to third-party projects, images, manifests, charts, or packages installed or downloaded by the automation.

The automation installs or interacts with third-party projects including O-RAN SC RIC components, K3s, Istio, Prometheus, Grafana, Kiali, Helm, ChartMuseum, Docker, Vagrant, VirtualBox, Ansible collections, and Plotly. See `THIRD_PARTY.md` and `LICENSE_DECISION.md` for the maintained notes and review upstream licenses before redistributing modified third-party source or images.
