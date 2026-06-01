# Scripts

Top-level scripts provide safe local checks for the public repository:

- `check-prereqs.sh`: checks local tools and files used by the documented minimal path.
- `check-public-safety.sh`: scans the working tree for common files and patterns that should not be published.

Workflow-specific scripts remain in the directories that call them:

- `ansible/istio-ab-testing/scripts/plot_ab.py`
- `ansible/istio-rate-limit-demo/scripts/plot_rate_limit.py`
- `ansible/istio-rate-limit-demo/scripts/k3s-tunnel.sh`
- `ansible/istio-rate-limit-demo/lb_probe_ingress.sh`

These scripts do not install dependencies and do not require root.
