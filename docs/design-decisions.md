# Design Decisions

This repository publishes the engineering parts of a bachelor thesis lab. The design choices below explain why the testbed uses a single-VM K3s environment, Ansible automation, e2sim-generated E2SM-KPM traffic, Istio TCP routing, and Time-Based Switching.

## k3s For The Kubernetes Substrate

K3s was used because the lab needed a Kubernetes API with low operational overhead on one VM. It provides a standard-enough control surface for Helm, Kubernetes manifests, RIC workloads, Istio sidecars, and validation tasks without requiring a multi-node cluster.

The automation disables Traefik during K3s installation. The lab does not rely on the default K3s ingress controller, and disabling it keeps the cluster surface smaller while Istio and RIC services are being installed.

The main trade-off is fidelity. A single-node K3s cluster is practical for repeatable lab work, but it does not exercise node placement, HA control planes, production ingress, multi-node networking, or failure-domain behavior.

## Ansible For Lifecycle Automation

Ansible was used because the lab spans several layers that need strict ordering:

- OS package installation and service management on the target VM
- K3s bootstrap and kubeconfig placement
- Docker installation and support containers
- Istio installation and namespace sidecar injection
- upstream RIC deployment through `ric-plt-ric-dep`
- xApp onboarding through `dms_cli`
- optional E2Term exposure and e2sim startup
- post-deployment validation

This is not only a Kubernetes manifest problem. Some steps run on the host, some use Docker, some clone upstream repositories, and some apply Kubernetes resources. Ansible keeps those steps in one control path while still allowing variables, role-level templates, and syntax checks.

The trade-off is that long-running external installers and upstream scripts are only partly idempotent from the lab's point of view. The playbooks include checks and validation, but they still depend on network access, image availability, upstream repository state, and the target VM's package environment.

## e2sim Instead Of A Full OAI-gNB Path

The project needed sustained E2SM-KPM input to test RIC deployment, xApp onboarding, observability, and xApp traffic switching. e2sim was a better fit for that goal than making the public lab depend on a full OAI-gNB path.

A full OAI-gNB route brings more variables into the experiment: radio-stack configuration, RF or SDR assumptions, UE/core-network dependencies, E2 agent integration details, timing behavior, and container or host compatibility. Those are valid research topics, but they were outside the scope of this xApp lifecycle workflow.

e2sim narrows the input side to a controllable E2 simulator. In this lab it is started as a Docker container, uses host networking by default, and can be configured through variables such as `e2sim_image`, `e2sim_container_command`, and `e2sim_env`. The automation documents how the simulator connects to the RIC path; it does not claim that simulator traffic has the same fidelity as a real gNB.

## Istio Despite SCTP Limitations

Istio was still useful because the switching experiment targets sidecar-observed TCP traffic around the xApp service, not the SCTP leg between e2sim and E2Term. The RMR-facing `kpimon-go` service exposes TCP ports `4560` and `4561`, and the A/B workflow applies Istio `DestinationRule` and `VirtualService` resources to route that traffic between `v1` and `v2` deployments.

Istio also gives practical lab tooling: sidecar injection, TCP telemetry, Prometheus metrics, Grafana dashboards, and Kiali service views. Those are useful for checking whether traffic is moving through the mesh and for collecting the `istio_tcp_received_bytes_total` metric used by the A/B plotting script.

The limitation is explicit: SCTP/E2 traffic is not natively visible through Envoy sidecars in this setup. Istio can help inspect and route the RMR/TCP part of the xApp environment, but it does not provide packet-level visibility into E2AP or E2SM-KPM SCTP payloads.

## Time-Based Switching Instead Of Percentage Splitting

The experiment used Time-Based Switching because the traffic under test is not a set of short independent HTTP requests. RMR and E2-related paths include persistent or session-oriented connections, so static percentage-based traffic splitting can be hard to interpret: a configured percentage does not necessarily translate into an immediate or stable split of observed traffic.

The implemented workflow alternates between full routing states, typically `100/0` and `0/100`, for fixed time windows. That produces clearer Prometheus windows for comparing destination versions and records each flip in the generated metadata and plots.

This choice matches the thesis observation that throughput continuity can be preserved while switching, but convergence latency remains the main bottleneck. The experiment measures how traffic moves after a routing update; it does not promise instant migration.

## Known Constraints

- The lab is optimized for reproducibility on one VM, not for production RIC operations.
- K3s reduces setup cost but hides multi-node scheduling, node failure, and HA behavior.
- Ansible can validate the expected state, but it cannot remove all variability from upstream installers, image registries, package repositories, and network access.
- e2sim is useful for sustained E2SM-KPM stimulus, but it is not a full RAN integration test.
- Istio telemetry is limited to traffic that passes through sidecar-supported protocols and paths. SCTP/E2 remains outside native mesh observability here.
- Time-Based Switching gives clear experiment windows but trades away fine-grained simultaneous traffic distribution.
- Switch timing depends on Istio propagation, existing TCP connection behavior, pod readiness, Prometheus scrape intervals, and the selected query range window.
