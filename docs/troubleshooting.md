# Troubleshooting

This guide assumes the main lifecycle workflow in `ansible/ric-lifecycle` and the Time-Based Switching workflow in `ansible/istio-ab-testing`. Commands that use `k3s kubectl` are intended for the target VM after K3s has been installed. Commands that start with `cd ansible/...` are run from the repository root.

Do not commit real inventories, kubeconfigs, command output containing private addresses, packet captures, or large logs.

## 1. k3s Not Reachable

- **Symptom**

  `k3s kubectl` or the validation playbook cannot contact the Kubernetes API.

- **Likely cause**

  K3s is not running, installation did not finish, the API is still starting, or the kubeconfig path used by Ansible does not match the target user.

- **Checks**

  ```bash
  k3s kubectl get nodes
  systemctl status k3s --no-pager
  ls -l ~/.kube/config /etc/rancher/k3s/k3s.yaml
  ```

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

- **Fix**

  Re-run the main lifecycle playbook after confirming the inventory points at the intended VM:

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

  If the service exists but fails to start, inspect the target VM service logs locally. Do not commit log files.

- **Notes**

  The main playbook installs single-node K3s and sets `k3s_kubeconfig` to the remote user's `~/.kube/config` by default.

## 2. kubectl Context Missing Or Wrong

- **Symptom**

  `kubectl` points at another cluster, has no current context, or returns authorization or connection errors.

- **Likely cause**

  The shell is using a local kubeconfig unrelated to the target VM, or `KUBECONFIG` points to a stale file.

- **Checks**

  ```bash
  kubectl config current-context
  kubectl config get-contexts
  kubectl get namespaces
  k3s kubectl get namespaces
  ```

- **Fix**

  On the target VM, prefer `k3s kubectl` for manual checks. If you copy a kubeconfig for local use, keep it outside the repository and update the server address for your lab. For the optional rate-limit demo, use the generated `ansible/istio-rate-limit-demo/artifacts/kubeconfig` only as local runtime state and do not commit it.

- **Notes**

  A working `kubectl` context is not required for the repository's local syntax checks, but it is required for manual cluster inspection from the controller.

## 3. Ansible Inventory Misconfigured

- **Symptom**

  Ansible cannot reach the VM, uses the wrong host group, or reports that no hosts matched.

- **Likely cause**

  The inventory was copied incorrectly, the `ric_vm` group is missing, SSH user/key settings are wrong, or the inventory path does not match the command.

- **Checks**

  ```bash
  cd ansible/ric-lifecycle
  ansible-inventory -i /tmp/ric-lifecycle-hosts.ini --list
  ansible ric_vm -i /tmp/ric-lifecycle-hosts.ini -m ping
  ```

- **Fix**

  Recreate the temporary inventory from the committed template and edit only the local copy:

  ```bash
  cd ansible/ric-lifecycle
  cp inventory/hosts.ini.example /tmp/ric-lifecycle-hosts.ini
  ${EDITOR:-vi} /tmp/ric-lifecycle-hosts.ini
  ```

- **Notes**

  Real hostnames, private IPs, usernames, and key paths should stay in `/tmp` or another local-only path, not in git.

## 4. Helm Chart Or Manifest Path Missing

- **Symptom**

  The run fails while applying an Istio add-on manifest, the E2Term NodePort manifest, or the downloaded `kpimon-go` Helm chart.

- **Likely cause**

  A download failed, an upstream path changed, `dms_cli download_helm_chart` did not generate the expected archive, or a generated file was removed from the target VM.

- **Checks**

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook --syntax-check site.yml -i inventory/hosts.ini.example
  ansible-playbook --syntax-check playbooks/validate.yml -i inventory/hosts.ini.example
  ```

  On the target VM:

  ```bash
  helm version
  ls -l ~/xapps/kpimon
  ls -l ~/tmp/istio-addons
  ls -l ~/tmp/e2term-nodeport-sctp.yml
  ```

- **Fix**

  Re-run the lifecycle playbook so the roles can re-download or re-render generated files:

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

  If the missing file is the xApp chart archive, check the `xapp_kpimon_deploy` role output around onboarding and chart download.

- **Notes**

  The `kpimon-go` chart archive is generated on the target VM and is not committed. The E2Term NodePort manifest is rendered only when `ric_e2term_expose_enabled=true`.

## 5. Near-RT RIC Pods Not Ready

- **Symptom**

  RIC namespaces exist, but pods in `ricplt`, `ricinfra`, or `ricxapp` remain `Pending`, `CrashLoopBackOff`, `ImagePullBackOff`, or otherwise not ready.

- **Likely cause**

  Resource pressure, image pull failures, upstream chart changes, slow startup, failed ChartMuseum state, or a RIC component dependency that did not become ready.

- **Checks**

  ```bash
  k3s kubectl get ns ricplt ricinfra ricxapp
  k3s kubectl -n ricplt get pods -o wide
  k3s kubectl -n ricinfra get pods -o wide
  k3s kubectl -n ricxapp get pods -o wide
  k3s kubectl -n ricplt describe pod <pod-name>
  k3s kubectl -n ricplt logs <pod-name> --tail=100
  ```

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

- **Fix**

  Fix the specific pod condition first: image pull, scheduling, crash logs, or dependency readiness. Then re-run the lifecycle playbook if the failure came from the automated deployment path.

- **Notes**

  The validation playbook checks that required RIC namespaces have pods and that those pods are `Running` or `Succeeded`. It does not prove that every RIC control-plane interaction is semantically healthy.

## 6. xApp Not Deployed Or Wrong Image

- **Symptom**

  `kpimon-go` is missing, not ready, or running an image different from the configured `xapp_image`.

- **Likely cause**

  xApp onboarding failed, the generated chart was not installed, the existing deployment was not replaced, or `xapp_image` does not match the intended image.

- **Checks**

  ```bash
  k3s kubectl -n ricxapp get deploy -o wide
  k3s kubectl -n ricxapp get deploy -o yaml | grep -n 'image:'
  k3s kubectl -n ricxapp get pods -o wide
  ```

  ```bash
  cd ansible/ric-lifecycle
  grep -n 'xapp_image\|xapp_name_match_regex\|force_xapp_reinstall' group_vars/all.yml
  ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

- **Fix**

  Use the configured image intentionally. The public default is `splicer3/kpi-mon-xapp:1.0.1`. If an existing deployment should be replaced, re-run the lifecycle playbook with `force_xapp_reinstall=true`:

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K -e force_xapp_reinstall=true
  ```

- **Notes**

  The validation playbook accepts both `splicer3/...` and `docker.io/splicer3/...` image forms.

## 7. Subscription Manager Endpoint Mismatch

- **Symptom**

  `kpimon-go` is running, but subscription requests fail or no subscription response appears in xApp logs.

- **Likely cause**

  The live RIC service names, xApp ConfigMaps, or routing state do not match the endpoint assumptions used by the installed xApp. This can happen when the upstream RIC release changes service names or when stale ConfigMaps remain from an older install.

- **Checks**

  ```bash
  k3s kubectl -n ricplt get svc | grep -i sub
  k3s kubectl -n ricplt get pods | grep -i sub
  k3s kubectl -n ricxapp get configmap
  k3s kubectl -n ricxapp get configmap configmap-ricxapp-kpimon-go-appconfig -o yaml
  k3s kubectl -n ricxapp logs <kpimon-pod-name> --tail=100
  ```

- **Fix**

  Compare the live Subscription Manager service and the xApp ConfigMaps. If they are stale, re-run the RIC lifecycle workflow so xApp onboarding and deployment are regenerated against the current RIC install.

- **Notes**

  This repository does not hardcode a public Subscription Manager endpoint in the docs because the concrete service name comes from the deployed OSC RIC release. Treat endpoint mismatches as a live-cluster diagnosis.

## 8. E2Sim Cannot Connect To E2Term

- **Symptom**

  The e2sim container is running, but E2 setup does not complete or no downstream xApp activity appears.

- **Likely cause**

  E2Term is not ready, E2Term is not reachable from the simulator network path, the optional SCTP NodePort service is required but disabled, or the simulator image is incompatible with the RIC/E2SM-KPM version.

- **Checks**

  ```bash
  docker ps --filter name=e2sim
  docker logs e2sim --tail=100
  k3s kubectl -n ricplt get deploy deployment-ricplt-e2term-alpha
  k3s kubectl -n ricplt get pods | grep -i e2term
  k3s kubectl -n ricplt get svc | grep -i e2term
  k3s kubectl -n ricplt get svc sctp-service -o yaml
  ```

- **Fix**

  If the lab topology requires external SCTP exposure, enable the existing E2Term exposure role:

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook site.yml -i /tmp/ric-lifecycle-hosts.ini -K \
    -e e2sim_mode=fully-functional \
    -e ric_e2term_expose_enabled=true
  ```

  If the simulator image or command is the issue, pin or override `e2sim_image` and `e2sim_container_command` deliberately.

- **Notes**

  The managed SCTP service is named `sctp-service` only when `ric_e2term_expose_enabled=true`. The default mapping is SCTP NodePort `32222` to target port `36422`.

## 9. No KPM/RMR Traffic Visible

- **Symptom**

  The xApp is running, but KPM indications or RMR/TCP activity are not visible in logs, Prometheus, or Kiali.

- **Likely cause**

  No active E2/KPM stream, subscription setup failed, e2sim/E2Term is not connected, RMR traffic bypasses Envoy, sidecars are missing, or Prometheus is querying the wrong labels.

- **Checks**

  ```bash
  k3s kubectl -n ricxapp get pods -o wide
  k3s kubectl -n ricxapp get svc | grep kpimon
  k3s kubectl -n ricxapp logs <kpimon-pod-name> --tail=100
  docker logs e2sim --tail=100
  ```

  If Prometheus is reachable at the documented default:

  ```bash
  curl 'http://localhost:9090/api/v1/query?query=sum(rate(istio_tcp_received_bytes_total{destination_workload_namespace="ricxapp",reporter="destination",destination_service="service-ricxapp-kpimon-go-rmr.ricxapp.svc.cluster.local"}[30s]))'
  ```

- **Fix**

  Work upstream to downstream: E2Term ready, e2sim connected, subscription accepted, xApp ready, sidecars present, Prometheus reachable. Re-run the lifecycle validator after fixing the failing layer.

- **Notes**

  A non-zero RMR/TCP metric is an indirect signal that sidecar-observed traffic reached the xApp service path. It is not proof that SCTP/E2 payloads are correct.

## 10. Istio Sidecar Injection Problems

- **Symptom**

  Pods in `ricplt`, `ricinfra`, or `ricxapp` do not have an `istio-proxy` container, or the validation playbook fails sidecar checks.

- **Likely cause**

  Namespace labels were missing when workloads started, workloads were not restarted after labeling, or Istio was disabled or not ready.

- **Checks**

  ```bash
  k3s kubectl get ns ricplt ricinfra ricxapp --show-labels
  k3s kubectl -n istio-system get deploy istiod
  k3s kubectl -n ricxapp get pod <pod-name> -o jsonpath='{.spec.containers[*].name}{"\n"}'
  ```

  ```bash
  cd ansible/ric-lifecycle
  ansible-playbook playbooks/validate.yml -i /tmp/ric-lifecycle-hosts.ini -K
  ```

- **Fix**

  Re-run the lifecycle playbook so the Istio role labels target namespaces and restarts workloads when needed. For manual repair:

  ```bash
  k3s kubectl label namespace ricplt ricinfra ricxapp istio-injection=enabled --overwrite
  k3s kubectl -n ricplt rollout restart deploy
  k3s kubectl -n ricinfra rollout restart deploy
  k3s kubectl -n ricxapp rollout restart deploy
  ```

- **Notes**

  Sidecar injection only affects newly created pods. Existing pods need a restart before the sidecar appears.

## 11. Kiali Graph Empty Or Misleading

- **Symptom**

  Kiali opens, but the graph is empty, stale, or does not show the expected RIC/xApp flow.

- **Likely cause**

  No recent sidecar-observed traffic, the namespace filter is wrong, Prometheus has no matching samples, workloads lack sidecars, or the traffic is SCTP/E2 and therefore outside the mesh view.

- **Checks**

  ```bash
  k3s kubectl -n istio-system get deploy prometheus kiali
  k3s kubectl -n istio-system get svc prometheus kiali
  k3s kubectl -n ricxapp get pods -o wide
  curl 'http://localhost:9090/api/v1/query?query=up'
  ```

- **Fix**

  Select the correct namespace and time range in Kiali, generate fresh RMR/TCP traffic, wait for at least one Prometheus scrape interval, and confirm sidecar injection.

- **Notes**

  Kiali is useful for mesh topology, not for packet-level E2/SCTP validation. Empty E2Sim-to-E2Term edges are expected in this repository.

## 12. SCTP Not Visible In Mesh

- **Symptom**

  E2Sim and E2Term traffic does not appear in Istio metrics or Kiali, even when the E2 path is active.

- **Likely cause**

  Expected limitation. This lab does not route SCTP/E2 through Istio, and Envoy sidecars do not provide native E2AP/E2SM-KPM payload visibility here.

- **Checks**

  ```bash
  k3s kubectl -n ricplt get pods | grep -i e2term
  k3s kubectl -n ricplt get svc | grep -i e2term
  k3s kubectl -n ricplt get svc sctp-service -o yaml
  ```

- **Fix**

  There is no Istio configuration in this repository that makes SCTP/E2 natively visible in the mesh. Use mesh metrics for RMR/TCP and keep SCTP diagnostics as private lab work.

- **Notes**

  Do not commit `.pcap` or `.pcapng` files. If packet-level SCTP analysis is needed, keep it outside the public repository unless it is deliberately sanitized and reviewed.

## 13. Time-Based Switching Does Not Converge Within Expected Window

- **Symptom**

  After a 100/0 or 0/100 route change, the old `kpimon-go` version continues receiving traffic longer than expected, or the generated plot shows a slow transition.

- **Likely cause**

  Long-lived TCP/RMR connections, Istio configuration propagation, Envoy update timing, Prometheus scrape cadence, or a query `rate()` window that is too coarse for the chosen switching interval.

- **Checks**

  ```bash
  cd ansible/istio-ab-testing
  grep -n 'traffic_cycle_seconds\|cycles\|prom_step\|prom_scrape_interval\|prom_range_window' group_vars/all.yml
  ```

  On the target VM:

  ```bash
  k3s kubectl -n ricxapp get virtualservice,destinationrule
  k3s kubectl -n ricxapp get deploy -L version
  k3s kubectl -n ricxapp get pods -o wide
  ```

- **Fix**

  Increase `traffic_cycle_seconds`, use a Prometheus step/range window that matches the scrape interval, and interpret only the stable portion of each leg. Re-run the A/B workflow after changing the analysis or switching cadence:

  ```bash
  cd ansible/istio-ab-testing
  ansible-playbook playbooks/run_demo.yml -i /tmp/istio-ab-hosts.ini
  ```

- **Notes**

  The repository does not define a universal expected convergence window. The thesis validation found throughput continuity, but convergence latency was the main bottleneck.

## 14. Prometheus Query Returns No Data

- **Symptom**

  Prometheus is reachable, but the query API returns an empty result for Istio or A/B metrics.

- **Likely cause**

  No traffic during the query window, wrong `prometheus_url`, missing sidecars, scrape delay, disabled add-ons, or a label mismatch in the query.

- **Checks**

  ```bash
  k3s kubectl -n istio-system get deploy prometheus
  k3s kubectl -n istio-system get svc prometheus
  curl 'http://localhost:9090/api/v1/query?query=up'
  curl 'http://localhost:9090/api/v1/query?query=istio_tcp_received_bytes_total'
  ```

  Check the query inputs used by the A/B workflow:

  ```bash
  cd ansible/istio-ab-testing
  grep -n 'prometheus_url\|prom_metric\|prom_reporter\|service_host\|namespace' group_vars/all.yml
  sed -n '1,120p' playbooks/collect_metrics.yml
  ```

- **Fix**

  Port-forward Prometheus if needed, generate fresh traffic, wait for scrape data, and make sure `service_host`, namespace, reporter, and metric name match the live workload:

  ```bash
  k3s kubectl -n istio-system port-forward svc/prometheus 9090:9090
  ```

- **Notes**

  Prometheus can show sidecar-observed RMR/TCP behavior. It does not prove SCTP/E2 correctness and will not show SCTP payload visibility.
