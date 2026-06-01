# Review Needed

These notes record what was copied from the local thesis mirror and what still needs manual review before publishing a first tagged release.

## Copied

- Single-VM Near-RT RIC lifecycle automation from `Experiments/ansible-k3s-ric-j-e2sim`.
- Istio KPI MON A/B traffic experiment from `Experiments/istio-ab-testing`.
- Optional K3s/NGINX/Istio rate-limit demo from `Experiments/ansible-k3s-istio-demos`.
- Small curated sample CSV/Markdown outputs from `Tests/ansible-k3s-istio-demos` and `Tests/istio-ab-testing`.
- The A/B statistical-validation notebook, kept once under `experiments/time-based-switching/`.
- Repository hygiene files: `.editorconfig`, `.gitattributes`, and `.gitignore`.

## Intentionally Excluded

- Original `.git` history from the thesis mirror.
- Real inventories and host-specific `hosts.ini` files.
- Ansible Vault files and vault password files.
- Kubeconfigs and generated cluster access files.
- Packet captures.
- Thesis directories, presentation PDFs, report PDFs, and personal documents.
- Raw generated output batches, cache directories, build artifacts, and `.DS_Store` files.
- Timestamped A/B artifact directories beyond the small curated sample set.

## Public-Safety Adjustments In This Copy

- Replaced real inventory files with neutral `hosts.ini.example` templates.
- Removed personal machine references from the rate-limit demo documentation.
- Replaced a hard-coded K3s tunnel script with an environment-variable based helper.
- Removed the duplicate copied notebook under the A/B experiment tree; the curated copy is in `experiments/time-based-switching/`.

## Manual Review Before Publishing

- Review the provisional repository license before public release.
- Review `THIRD_PARTY.md` for O-RAN SC, Istio, K3s, Helm, ChartMuseum, ingress-nginx, Vagrant, VirtualBox, Plotly, and Ansible collections.
- Decide whether the optional rate-limit demo should remain in the first public release or move to a later example branch.
- Re-check Docker image provenance for `splicer3/kpi-mon-xapp:1.0.1` and `splicer3/e2sim:latest`.
- Run syntax checks after installing required Ansible collections.
