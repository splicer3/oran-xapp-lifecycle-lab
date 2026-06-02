# Public Release Notes

These notes summarize the public curation work used to separate the reusable O-RAN Near-RT RIC xApp lifecycle lab from the private thesis mirror. They document what was copied, what was intentionally left out, and which safety adjustments were made for a professional public repository.

## Copied Material

- Single-VM Near-RT RIC lifecycle automation from `Experiments/ansible-k3s-ric-j-e2sim`.
- Istio KPI MON A/B traffic experiment from `Experiments/istio-ab-testing`.
- Optional K3s/NGINX/Istio rate-limit demo from `Experiments/ansible-k3s-istio-demos`.
- Small sample CSV and Markdown outputs from `Tests/ansible-k3s-istio-demos` and `Tests/istio-ab-testing`.
- The A/B statistical-validation notebook, kept under `experiments/time-based-switching/`.
- Repository hygiene files: `.editorconfig`, `.gitattributes`, and `.gitignore`.

## Intentionally Excluded

- Original `.git` history from the thesis mirror.
- Real inventories and host-specific `hosts.ini` files.
- Ansible Vault files and vault password files.
- Kubeconfigs and generated cluster access files.
- Packet captures and raw SCTP traces.
- Thesis directories, presentation PDFs, report PDFs, and personal documents.
- Raw generated output batches, cache directories, build artifacts, and `.DS_Store` files.
- Timestamped A/B artifact directories beyond the small sample set.

## Public-Safety Adjustments

- Replaced real inventory files with neutral `hosts.ini.example` templates.
- Removed personal machine references from the rate-limit demo documentation.
- Replaced a hard-coded K3s tunnel script with an environment-variable based helper.
- Removed the duplicate copied notebook under the A/B experiment tree; the kept copy is in `experiments/time-based-switching/`.
- Kept packet captures, logs, PDFs, kubeconfigs, real inventories, and private local notes outside the tracked public repository.

## Scope Notes

- This repository is a research and portfolio testbed, not production RAN infrastructure.
- SCTP/E2 traffic is outside native Istio sidecar telemetry. Istio metrics in this lab are useful for sidecar-observed TCP traffic around xApp services.
- The default `splicer3/e2sim:latest` image tag is mutable. Pin the image by tag or digest before using results for repeatable comparisons.
