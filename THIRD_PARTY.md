# Third-Party Components

This repository contains automation that installs or interacts with third-party projects. Their source code is not vendored here unless explicitly present in a role template or sample file.

Referenced components include:

- O-RAN SC `ric-plt-ric-dep`
- O-RAN SC `ric-plt-appmgr`
- K3s
- Istio and Istio sample addons
- Prometheus, Grafana, and Kiali through Istio sample addons
- Helm
- ChartMuseum
- ingress-nginx
- Docker
- Vagrant and VirtualBox for the optional local demo
- Ansible collections: `kubernetes.core`, `community.docker`, `community.general`, `ansible.posix`
- Python Plotly for local HTML chart rendering

Docker images referenced by defaults:

- `splicer3/kpi-mon-xapp:1.0.1`
- `splicer3/e2sim:latest`
- `ghcr.io/helm/chartmuseum:v0.14.0`
- `nginx:alpine`
- `alpine:3.19`

Review upstream licenses before redistributing modified third-party source or publishing derived images.
