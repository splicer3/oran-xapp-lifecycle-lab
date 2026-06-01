# oran-xapp-lifecycle-lab

Ansible-based O-RAN Near-RT RIC xApp lifecycle lab with K3s, Istio traffic steering, e2sim, KPI MON deployment, and reproducible validation steps.

This repository is a curated public mirror of engineering artifacts from a local lab. It is not a thesis archive and does not include private inventories, kubeconfigs, packet captures, generated report output, or personal documents.

## Contents

- `ansible/ric-lifecycle` deploys a single-VM K3s, Near-RT RIC J, optional e2sim, Istio minimal profile, Istio addons, and KPI MON xApp stack.
- `ansible/istio-ab-testing` prepares KPI MON v1/v2 workloads, applies Istio TCP traffic splitting, collects Prometheus metrics, and renders CSV/Plotly outputs.
- `ansible/istio-rate-limit-demo` is an optional K3s/NGINX/Istio local-rate-limit demonstration.
- `results/sample` contains small curated CSV and Markdown artifacts only.
- `experiments/time-based-switching` contains the statistical-validation notebook used with the curated A/B samples.
- `k8s` documents where the Kubernetes and Istio manifests live in the Ansible roles.

## Validation

Run syntax checks before using the playbooks against a real lab host:

```bash
cd ansible/ric-lifecycle
ansible-galaxy collection install -r collections/requirements.yml
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check reset.yml -i inventory/hosts.ini.example
ANSIBLE_LOCAL_TEMP=/tmp ANSIBLE_REMOTE_TEMP=/tmp ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
```

Render the curated A/B sample:

```bash
cd ansible/istio-ab-testing
python3 scripts/plot_ab.py --in-csv ../../results/sample/ab-testing/csv/ABTesting_kpimonV2.csv --out-html /tmp/ab-sample.html
```

Render the curated rate-limit sample:

```bash
cd ansible/istio-rate-limit-demo
python3 scripts/plot_rate_limit.py \
  --success-csv ../../results/sample/rate-limit/csv/rate_limit_demo_200.csv \
  --limited-csv ../../results/sample/rate-limit/csv/rate_limit_demo_429.csv \
  --markers-csv ../../results/sample/rate-limit/csv/rate_limit_demo_markers.csv \
  --output /tmp/rate-limit-sample.html
```

Deployment requires editing the example inventory for your own lab VM or hypervisor. Do not commit real inventories or generated kubeconfigs.
