# Ansible Single-VM K3s + Near-RT RIC J + Istio + Optional e2sim

This experiment deploys a full internship Near-RT RIC stack on one VM with Ansible.

It includes:
- K3s server with Traefik disabled.
- Near-RT RIC J deployment from `ric-dep`.
- Deterministic `ric-common` Helm repo preparation via a dedicated chartmuseum container on `127.0.0.1:8879` (default).
- Optional E2Term mirror service (`SCTP 32222 -> 36422`) sourced from `deployment-ricplt-e2term-alpha` (fallback: `e2term-alpha` service selector).
- KPI MON xApp deployment with pinned image `splicer3/kpi-mon-xapp:1.0.1`.
- `dms_cli` installation aligned with xDevSM flow (`ric-plt-appmgr` checkout at `j-release`, Python venv, `pip install -r requirements.txt`, `pip install .`).
- Istio minimal profile (no ingress gateway), sidecar injection on `ricplt`, `ricinfra`, `ricxapp`.
- Istio quick-start addons (Prometheus, Grafana, Kiali) with pinned manifest branch.
- Optional e2sim container (`splicer3/e2sim:latest`) with ordering enforced in full mode.
- User-space workspace paths by default (`{{ ansible_facts.user_dir }}`) for `ric-dep`, xApp files, and chart repositories.

## Modes
- `e2sim-ready`
  - Deploys K3s, Istio, RIC, `nearrtric`, xApp.
  - Does not start e2sim.
- `fully-functional`
  - Deploys RIC first, then exposes E2Term, then starts e2sim.
  - Deploys xApps only after e2sim is running.

## Pipeline Order (`site.yml`)
1. `k3s_single`
2. `docker_host`
3. `istio_minimal` (if `istio_enabled`)
4. `istio_addons` (if `istio_enabled` and `istio_install_addons`)
5. `ric_j_deploy`
6. `e2term_expose` (if `ric_e2term_expose_enabled`)
7. `e2sim_docker` (if `e2sim_mode == fully-functional`)
8. `xapp_kpimon_deploy`
9. `playbooks/validate.yml`

## Prerequisites
- Controller host:
  - Ansible 2.9+ (recommended `ansible-core` modern version).
  - SSH access to target VM with sudo privileges.
- Target VM:
  - Ubuntu/Debian compatible.
  - Internet access for package installs and Istio/RIC downloads.

Privilege model:
- The playbook runs unprivileged by default.
- `become` is used only for tasks that require system-level changes (package install, K3s/bootstrap service work, explicit K3s uninstall).

Install collections:
```bash
cd Experiments/ansible-k3s-ric-j-e2sim
ansible-galaxy collection install -r collections/requirements.yml
```

## Inventory Setup
```bash
cp inventory/hosts.ini.example inventory/hosts.ini
```
Edit `inventory/hosts.ini` for your VM host/user/key.

## Deploy
```bash
cd Experiments/ansible-k3s-ric-j-e2sim
ansible-playbook site.yml -K
```

## Syntax Check (temp override is optional but might be needed)
```bash
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check reset.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
```

## Key Variables (`group_vars/all.yml`)
### Core
- `e2sim_mode`: `e2sim-ready` or `fully-functional`.
- `ric_release_branch`: default `j-release`.
- `ric_namespaces`: default `ricplt`, `ricinfra`, `ricxapp`.
- `ric_common_chartmuseum_port`: default `18879` (internal `ric-common` Helm repo endpoint for `ric-dep`).
- `ric_dep_git_force_update`: default `true` (keeps managed `ric-dep` checkout clean on reruns).
- `k3s_system_kubeconfig`: default `/etc/rancher/k3s/k3s.yaml`.
- `k3s_kubeconfig`: default `{{ ansible_facts.user_dir }}/.kube/config` (auto-copied from system kubeconfig with mode `0600`).

### E2Term mirror
- `ric_e2term_expose_enabled`: default `false` (set `true` only on environments that require mirror exposure).
- `ric_e2term_namespace`: default `ricplt`.
- `ric_e2term_source_deployment_name`: default `deployment-ricplt-e2term-alpha`.
- `ric_e2term_source_service_match`: default `e2term-alpha`.
- `ric_e2term_nodeport_service_name`: default `sctp-service`.
- `ric_e2term_nodeport`: default `32222`.
- `ric_e2term_target_port`: default `36422`.
- `ric_e2term_external_ip`: optional external IP to include in service `externalIPs`.

### Istio
- `istio_enabled`: default `true`.
- `istio_version`: default `1.28.3`.
- `istio_addons_release`: default `release-1.28`.
- `istio_profile`: default `minimal`.
- `istio_install_addons`: default `true`.
- `istio_target_namespaces`: default `[ricplt, ricinfra, ricxapp]`.
- `force_istio_reinstall`: default `false`.

### xApp
- `xapp_image`: default `splicer3/kpi-mon-xapp:1.0.1`.
- `xapp_dms_cli_repo_url`: default `https://github.com/o-ran-sc/ric-plt-appmgr.git`.
- `xapp_dms_cli_repo_dest`: local checkout path for `ric-plt-appmgr`.
- `xapp_dms_cli_workdir`: default `xapp_orchestrater/dev/xapp_onboarder`.
- `xapp_dms_cli_venv_dir`: virtualenv used for `dms_cli`.
- `xapp_dms_cli_python_version`: default `3.9` (Ubuntu flow with deadsnakes PPA, fallback to system Python if unavailable).
- `xapp_dms_cli_setuptools_version`: default `70.0.0` (Python 3.9 compatibility pin before `pip install .`).
- `xapp_dms_cli_override`: optional explicit `dms_cli` path.
- `xapp_download_helm_command_override`: optional override for `dms_cli download_helm_chart`.
- `xapp_chart_package_path`: expected chart archive generated by `dms_cli download_helm_chart`.
- `force_xapp_reinstall`: default `false`.

### e2sim
- `e2sim_image`: default `splicer3/e2sim:latest`.
- `e2sim_container_name`: default `e2sim`.

### Reset toggles
- `reset_remove_ric`: remove RIC namespaces and `ric-dep` checkout.
- `reset_remove_istio_addons`: remove Prometheus/Grafana/Kiali.
- `reset_remove_istio`: uninstall Istio with `istioctl uninstall --purge -y`.
- `reset_remove_istio_namespace`: if true, also remove `istio-system` namespace.
- `reset_uninstall_k3s`: uninstall K3s (requires explicit confirmation string).

## Validation
`playbooks/validate.yml` asserts:
- RIC namespaces exist and pods are healthy.
- Traefik is absent.
- Istio namespace and `istiod` are available when `istio_enabled=true`.
- `istio-ingressgateway` is absent (minimal profile).
- Injection labels exist on target namespaces.
- Workload pods in target namespaces contain sidecar `istio-proxy` and are running.
- Addon deployments are available when `istio_install_addons=true`.
- when `ric_e2term_expose_enabled=true`, mirror service exists with `SCTP 32222 -> 36422`.
- when `ric_e2term_expose_enabled=true` and `ric_e2term_external_ip` is set, service includes that external IP.
- xApp deployment exists with image `splicer3/kpi-mon-xapp:1.0.1`.
- In `fully-functional` mode, e2sim container is running.

Run directly:
```bash
ansible-playbook playbooks/validate.yml -i inventory/hosts.ini -K
```
`playbooks/validate.yml` now auto-loads defaults from `../group_vars/all.yml` when run standalone, so it does not depend on being imported by `site.yml`.

## Reset / Teardown
Safe default reset:
```bash
ansible-playbook reset.yml -i inventory/hosts.ini -K
```

Examples:
```bash
ansible-playbook reset.yml -i inventory/hosts.ini -K -e reset_remove_ric=true
ansible-playbook reset.yml -i inventory/hosts.ini -K -e reset_remove_istio_addons=true -e reset_remove_istio=true
ansible-playbook reset.yml -i inventory/hosts.ini -K -e reset_uninstall_k3s=true -e reset_confirm_uninstall_k3s=YES_UNINSTALL_K3S
```

## Idempotency Notes
- K3s install guarded by binary/service checks.
- Istio install guarded by version + `istiod` state unless forced.
- RIC install guarded by namespace/pod state unless forced.
- xApp onboarding/install guarded by deployed image unless forced.
- Declarative Kubernetes and Docker state used for repeatability.

## Troubleshooting
- `dms_cli` missing:
  - verify `xapp_dms_cli_repo_dest` and `xapp_dms_cli_venv_dir` setup.
  - optionally set `xapp_dms_cli_override` to a valid executable path.
- Istio download fails:
  - verify outbound network and pinned version URLs.
- Kubernetes cluster unreachable from shell/script tasks:
  - rerun `site.yml`; `k3s_single` now enforces `/etc/rancher/k3s/k3s.yaml` permissions and creates `{{ k3s_kubeconfig }}` for the SSH user automatically.
- Sidecar validation fails after labeling:
  - rerun `site.yml`; rollout restart logic is automatic for deployment/statefulset workloads.
- E2Term mirror creation fails:
  - confirm source service naming in RIC (`ric_e2term_source_service_match`).

## Security
- Do not commit credentials/secrets.
- Use Ansible Vault for sensitive values.
