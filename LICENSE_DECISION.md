# License Decision

The repository keeps the existing MIT `LICENSE` for original code, scripts, templates, documentation, and small sample metadata created for this curated public release.

The MIT license does not cover third-party software that this repository installs, downloads, clones, references, or runs, including upstream O-RAN SC repositories, Docker images, Helm charts, Kubernetes distributions, service mesh components, observability tools, VM boxes, CI actions, Python packages, or Ansible collections. See `THIRD_PARTY.md`.

## Local Review Performed

- Scanned committed files for common license headers and copyright notices.
- Found no SPDX or upstream copyright headers in committed source files.
- Found only the root `LICENSE` and `CITATION.cff` license metadata.
- Confirmed third-party components are generally referenced, downloaded, cloned, or pulled at runtime rather than vendored as source trees.

## Manual Review Still Required

Before publishing derived images, redistributing upstream source, copying upstream manifests into this repository, or creating a formal tagged release:

- review O-RAN SC licenses and notices for `ric-plt-ric-dep`, `ric-plt-appmgr`, RIC runtime components, and any xApp source used to build images;
- review the provenance and licenses for `splicer3/kpi-mon-xapp:1.0.1` and `splicer3/e2sim:latest`;
- review licenses for downloaded Istio sample add-ons and any generated manifests retained as samples;
- preserve any upstream license headers if third-party source or manifests are copied into the repository;
- update `THIRD_PARTY.md` when new external components are added.
