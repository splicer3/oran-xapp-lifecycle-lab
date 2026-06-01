# e2sim Customization

This repository uses e2sim as a controllable E2 traffic source for the Near-RT RIC lab. The public release contains the Ansible integration for running e2sim and configuring its runtime parameters; it does not include the E2Sim C++ source fork, packet captures, or raw thesis logs.

## Role In This Repository

e2sim is used to generate E2SM-KPM traffic toward the OSC Near-RT RIC so that `kpimon-go` can be deployed, subscribed, and observed without a full physical or emulated RAN stack.

The integration point is:

- `ansible/ric-lifecycle/roles/e2sim_docker/tasks/main.yml`
- `ansible/ric-lifecycle/group_vars/all.yml`
- `ansible/ric-lifecycle/site.yml`
- `ansible/ric-lifecycle/playbooks/validate.yml`

In the default public configuration, `e2sim_mode` is `fully-functional`, so `site.yml` starts the e2sim container after the RIC deployment and optional E2Term exposure, then deploys `kpimon-go`.

## Why A Simulator Was Used

The lab is meant to make xApp lifecycle tests repeatable. A simulator keeps the input side controlled: the RIC can receive E2 setup and E2SM-KPM indications without requiring RF hardware, a 5G core, UE state, or a full OAI-gNB deployment.

The thesis work attempted a fuller OAI-gNB path, but that path introduced extra variables around container privileges, virtual network interfaces, E2 agent behavior, Service Model compatibility, and startup ordering. Those details are valid research work, but they are not required for this public repository's main goal: deploy the RIC, run `kpimon-go`, generate repeatable KPM-like input, and study the xApp traffic path.

## What Was Customized

The public repo exposes the customization through runtime variables and a referenced container image. It does not contain the simulator source diff.

| Item | Status in this public release | Repo evidence |
| --- | --- | --- |
| Continuous dataset looping | Background from the thesis. The source code implementing the loop is not included here. Use only if the selected e2sim image is known to contain that behavior. | No E2Sim source files are present in this repository. |
| Configurable send frequency | Exposed through environment variables passed to the container. The current defaults are `REPORTS_RESTART_SLEEP_MS: "50"` and `REPORTS_SEND_GAP_MS: "50"`. | `ansible/ric-lifecycle/group_vars/all.yml` and `ansible/ric-lifecycle/roles/e2sim_docker/tasks/main.yml` |
| RAN Function ID alignment | Exposed through `RAN_FUNC_ID: "2"`, used to match the `kpimon-go` KPM subscription path used in the lab. | `ansible/ric-lifecycle/group_vars/all.yml` |
| Containerized execution | Present. Ansible starts e2sim with `community.docker.docker_container`. The default network mode is `host`. | `ansible/ric-lifecycle/roles/e2sim_docker/tasks/main.yml` |
| Docker image reference | Present. The default image is `splicer3/e2sim:latest`. | `ansible/ric-lifecycle/group_vars/all.yml` |
| Custom command override | Present. `e2sim_container_command` is empty by default; when set, the role passes it as the container command. | `ansible/ric-lifecycle/group_vars/all.yml` and `ansible/ric-lifecycle/roles/e2sim_docker/tasks/main.yml` |

Because the default image tag is `latest`, pin `e2sim_image` before using the lab for repeatable comparisons.

## Traffic Path To `kpimon-go`

The intended flow is:

1. e2sim behaves as an E2 node and sends E2AP/E2SM-KPM traffic over SCTP.
2. E2Term in the RIC platform receives the SCTP/E2 traffic.
3. RIC subscription handling involves the Subscription Manager path.
4. `kpimon-go` sends and receives the relevant RIC messages through RMR over TCP.
5. `kpimon-go` receives `RIC_SUB_RESP` and `RIC_INDICATION` messages through the RMR data port.

The `kpimon-go` descriptor rendered by this repo declares:

- HTTP health port: `8080`
- RMR data port: `4560`
- RMR route port: `4561`
- RMR protocol port: `tcp:4560`
- received message types: `RIC_SUB_RESP`, `RIC_INDICATION`
- transmitted message type: `RIC_SUB_REQ`

The E2/SCTP leg and the RMR/TCP leg have different observability behavior. SCTP between e2sim and E2Term is not natively visible through Istio/Envoy sidecars. RMR/TCP traffic to `kpimon-go` can be observed through Istio metrics when the relevant workloads are sidecar-injected and traffic passes through Envoy.

## Deploying e2sim With Existing Files

Use the main RIC lifecycle playbook. These commands use only files present in this repository; the inventory copied to `/tmp` must be edited for a real VM.

```bash
cd ansible/ric-lifecycle
ansible-galaxy collection install -r collections/requirements.yml
cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=fully-functional
```

`fully-functional` mode starts e2sim and then deploys `kpimon-go`. To deploy the RIC and xApp path without starting e2sim, use:

```bash
cd ansible/ric-lifecycle
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=e2sim-ready
```

If the simulator must reach E2Term through the managed SCTP NodePort service, enable the existing E2Term exposure role:

```bash
cd ansible/ric-lifecycle
ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K \
  -e e2sim_mode=fully-functional \
  -e ric_e2term_expose_enabled=true
```

The default E2Term exposure settings are:

- namespace: `ricplt`
- source deployment: `deployment-ricplt-e2term-alpha`
- fallback service match: `e2term-alpha`
- generated service name: `sctp-service`
- protocol: `SCTP`
- service port: `36422`
- target port: `36422`
- NodePort: `32222`

Only enable `ric_e2term_expose_enabled` when the lab topology needs that external SCTP mapping. It is disabled by default.

## Verification

Run the repository validation playbook first:

```bash
cd ansible/ric-lifecycle
ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K -e e2sim_mode=fully-functional
```

This validates that the RIC namespaces exist, RIC pods are healthy, Istio state matches the configured mode, `kpimon-go` is deployed with the expected image, and the e2sim container is running in `fully-functional` mode. If `ric_e2term_expose_enabled=true`, it also validates that the SCTP NodePort service exists with the expected mapping.

For traffic flow, use layered checks. The exact log messages depend on the selected images and RIC release, so treat these as manual diagnostics rather than scripted pass/fail tests.

On the target VM, check the simulator container:

```bash
docker ps --filter name=e2sim
docker logs e2sim
```

On the target VM, check the RIC and xApp pods:

```bash
k3s kubectl -n ricplt get pods
k3s kubectl -n ricxapp get pods
```

If Istio addons are enabled and Prometheus is reachable from the controller, the RMR/TCP side can be checked indirectly with the same metric family used by the A/B workflow:

```bash
curl 'http://localhost:9090/api/v1/query?query=sum(rate(istio_tcp_received_bytes_total{destination_workload_namespace="ricxapp",reporter="destination",destination_service="service-ricxapp-kpimon-go-rmr.ricxapp.svc.cluster.local"}[30s]))'
```

A non-zero RMR/TCP rate is an indirect signal that traffic is reaching the xApp service path. It is not proof of SCTP payload correctness. A zero result can mean no active subscription, no E2 input, missing sidecars, Prometheus scrape delay, an unavailable port-forward, or a traffic path that does not pass through Envoy.

## Troubleshooting

| Symptom | Likely cause | Checks |
| --- | --- | --- |
| `fully-functional mode requires a running e2sim container` | e2sim did not start, Docker is unavailable, image pull failed, or `e2sim_container_command` is invalid. | Run `ansible-playbook playbooks/validate.yml ... -e e2sim_mode=fully-functional`; on the target VM check `docker ps --filter name=e2sim` and `docker logs e2sim`. |
| e2sim starts but E2 setup does not complete | E2Term is not ready, E2Term is not reachable from the simulator, or the NodePort mapping is required but disabled. | Check `ricplt` pods, decide whether `ric_e2term_expose_enabled=true` is needed, and validate the `sctp-service` mapping when enabled. |
| E2Term exposure role fails | The RIC release produced different E2Term deployment or service names/selectors. | Review `ric_e2term_source_deployment_name`, `ric_e2term_source_service_match`, and the actual resources in `ricplt`. |
| `kpimon-go` does not receive indications | Subscription setup may have failed, RAN Function ID may not match, or E2SM-KPM versions may be incompatible. | Confirm `RAN_FUNC_ID` is appropriate for the selected simulator image and `kpimon-go` version. Check `ricxapp` pod state and xApp logs. |
| RMR/TCP Prometheus metrics stay at zero | No active KPM stream, no sidecar-observed traffic, Prometheus is not scraping, or the query target does not match the deployed service. | Verify sidecar injection through `playbooks/validate.yml`, check `service-ricxapp-kpimon-go-rmr.ricxapp.svc.cluster.local`, and inspect Kiali/Prometheus only after scrape intervals have elapsed. |
| SCTP traffic is not visible in Istio | Expected limitation. Envoy sidecars do not provide native SCTP visibility in this lab. | Use SCTP-aware tooling outside the public repo if packet-level validation is required. Do not commit `.pcap` files. |

## Background

The thesis work describes an E2Sim fork that added continuous dataset looping and runtime-controlled send timing. It also describes OAI-gNB integration attempts and SCTP packet-capture validation. Those items are useful context, but only the curated automation and small public artifacts are kept here.

## Not Included In This Public Release

- E2Sim C++ source code or patch files.
- Dockerfile or image build pipeline for `splicer3/e2sim:latest`.
- OAI-gNB manifests or full RAN deployment files.
- Packet captures, raw SCTP traces, kubeconfigs, private inventories, or large logs.
- Claims that a specific image digest, send rate, or throughput result is reproducible from this repository alone.

## Known Limitations

- e2sim is not a full physical RAN, and it does not model RF behavior, UE mobility, scheduler behavior, or complete gNB/core-network interactions.
- SCTP/E2 visibility is limited. Istio can help observe RMR/TCP traffic around xApps, but it does not expose E2AP/E2SM-KPM SCTP payloads.
- Version compatibility matters. RIC release, E2AP version, E2SM-KPM encoding, `kpimon-go`, and the selected e2sim image must line up.
- The default `splicer3/e2sim:latest` tag is mutable. Pin it for repeatable work and review image provenance before publishing derived results.
