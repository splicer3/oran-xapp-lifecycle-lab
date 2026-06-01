# Design Decisions

## Curated Public Scope

The repository keeps runnable automation and small reproducibility artifacts. It excludes thesis PDFs, packet captures, private inventories, kubeconfigs, generated report output, and personal material.

## Ansible-First Layout

The lab is organized around Ansible workflows because the deployment order matters: K3s, Docker, Istio, RIC, optional E2Term exposure, optional e2sim, xApp onboarding, and validation. Role-local templates stay under `ansible/**/roles` so existing playbooks can render them without path rewrites.

## Single-VM RIC Baseline

`ansible/ric-lifecycle` is the main workflow. It targets one Linux VM and installs K3s with Traefik disabled, Near-RT RIC J components, Istio minimal profile, optional Istio addons, optional e2sim, and KPI MON xApp onboarding.

## Optional Demo Isolation

The NGINX rate-limit demo remains under `ansible/istio-rate-limit-demo` because it is useful for Istio/Prometheus mechanics but is not required for the RIC xApp lifecycle workflow.

## Results Policy

Only small sample CSV and Markdown files are kept under `results/sample`. They document artifact format and support plotting/analysis commands. They are not general benchmarks.
