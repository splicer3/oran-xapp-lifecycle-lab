# Ansible Automation

This directory contains the runnable automation for the lab.

- `ric-lifecycle` deploys the single-VM K3s, Near-RT RIC J, Istio, e2sim, and KPI MON xApp stack.
- `istio-ab-testing` runs the KPI MON time-based A/B traffic-switching experiment against the RIC stack.
- `istio-rate-limit-demo` contains the optional K3s/NGINX/Istio local-rate-limit demonstration.

Keep playbooks, roles, templates, and scripts close to the workflow that calls them. Several commands assume paths relative to their experiment directory.
