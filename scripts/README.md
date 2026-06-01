# Scripts

No top-level wrapper scripts are currently required.

Runnable scripts remain in the workflow directories that call them:

- `ansible/istio-ab-testing/scripts/plot_ab.py`
- `ansible/istio-rate-limit-demo/scripts/plot_rate_limit.py`
- `ansible/istio-rate-limit-demo/scripts/k3s-tunnel.sh`
- `ansible/istio-rate-limit-demo/lb_probe_ingress.sh`

Keep new shared scripts here only if they are used by more than one workflow.
