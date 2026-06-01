# Troubleshooting

## Ansible Cannot Reach The Host

Start from the relevant `inventory/hosts.ini.example`, copy it to `inventory/hosts.ini`, and fill in lab-specific host, user, and key values. Do not commit the real inventory.

## Kubernetes API Is Unreachable

For `ansible/ric-lifecycle`, the K3s role copies the system kubeconfig to the remote user's home directory. Re-run the K3s role or check `k3s_kubeconfig` in `group_vars/all.yml`.

For the optional rate-limit demo, check whether the generated `artifacts/kubeconfig` exists and whether the SSH tunnel to the K3s API is active.

## Istio Sidecars Are Missing

Confirm that target namespaces have `istio-injection=enabled`. Existing workloads may need a rollout restart after labeling.

## Prometheus Queries Return No Data

Check that Prometheus is reachable from the controller at the configured `prometheus_url`. Then confirm that the metric name, reporter label, and scrape interval match the experiment settings.

## E2Term Or e2sim Does Not Connect

Check whether `ric_e2term_expose_enabled` is required for the lab topology. If SCTP exposure is enabled, validate the NodePort service and target port mapping. Keep packet captures local unless they are sanitized and reviewed for publication.
