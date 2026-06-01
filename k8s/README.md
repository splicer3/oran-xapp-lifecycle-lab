# Kubernetes And Istio Manifests

Standalone manifests are not duplicated here.

The runnable Kubernetes and Istio definitions are Jinja templates owned by the Ansible roles that render and apply them:

- `ansible/ric-lifecycle/roles/e2term_expose/templates/e2term-nodeport-sctp.yml.j2`
- `ansible/istio-ab-testing/roles/istio_traffic/templates/destinationrule.yaml.j2`
- `ansible/istio-ab-testing/roles/istio_traffic/templates/virtualservice.yaml.j2`
- `ansible/istio-ab-testing/roles/istio_traffic/templates/kpimon_deployment.yaml.j2`
- `ansible/istio-rate-limit-demo/roles/enable_rate_limit/templates/envoyfilter-local-rl.yaml.j2`
- `ansible/istio-rate-limit-demo/roles/demo-nginx/templates/*.yaml.j2`

Add standalone reviewed manifests here only when they can be applied without breaking the Ansible workflows.
