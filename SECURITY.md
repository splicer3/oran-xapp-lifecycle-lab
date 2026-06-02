# Security

## Reporting Security Issues

Use GitHub private vulnerability reporting or a GitHub Security Advisory if it is enabled for `splicer3/oran-xapp-lifecycle-lab`.

If private reporting is not available, open a minimal public issue without secrets, private IP addresses, kubeconfigs, packet captures, or host-specific configuration. Include:

- the affected file or workflow;
- the command that failed, if relevant;
- sanitized output;
- whether the issue is in this repository or in an upstream dependency installed by the automation.

For vulnerabilities in upstream projects such as O-RAN SC RIC components, K3s, Istio, Kubernetes, Docker, Helm, Prometheus, Grafana, Kiali, ChartMuseum, Vagrant, VirtualBox, or container images, report to the upstream project as well.

## Secrets And Local Lab Data

Do not commit:

- kubeconfigs;
- real Ansible inventories;
- Ansible Vault files or vault passwords;
- tokens, credentials, API keys, or private keys;
- private hostnames, private IP addresses, or tunnel details;
- packet captures (`.pcap`, `.pcapng`);
- raw logs or generated output batches;
- private dashboard screenshots;
- thesis PDFs, acknowledgements, or personal material.

Use the committed `*.example` inventory files as templates and keep real lab values under `/tmp` or another local-only path.

Run the lightweight public-safety check before sharing changes publicly:

```bash
make check-public-safety
```

`gitleaks detect --source .` is a useful stronger optional check when `gitleaks` is installed.

## Research Testbed Scope

This repository is a research and portfolio testbed for an O-RAN Near-RT RIC xApp lifecycle lab. It is not production RAN infrastructure and should not be used as an operational security baseline for live telecom systems.

The automation deploys third-party components and pulls container images at runtime. Review upstream security advisories, image provenance, and pinned versions before using the lab for shared infrastructure or externally visible environments.

## Supported Versions

No public release branches are maintained yet. Treat the default branch as the only supported line until tagged releases are introduced.
