# Observability

Istio observability is installed by `ansible/ric-lifecycle/roles/istio_addons` when `istio_install_addons` is enabled.

The role downloads Istio sample manifests for:

- Prometheus
- Grafana
- Kiali

The A/B experiment in `ansible/istio-ab-testing` queries Prometheus through `prometheus_url`, which defaults to `http://localhost:9090`. The expected setup is a local port-forward or tunnel from the controller to Prometheus.

## Limitations

SCTP observability is limited in this lab. Istio metrics are useful for TCP-level traffic seen by sidecars, but SCTP signaling visibility depends on where traffic is exposed and captured. Packet captures are treated as unsafe by default and are not part of the public repository.

Prometheus scrape interval and Istio telemetry convergence affect observed switch timing. Treat switch-latency measurements as lab observations, not as platform guarantees.
