# K3s Cluster with NGINX Ingress Demo with Ansible

This demo uses Ansible to spin up a two-node K3s cluster inside VirtualBox VMs on a Linux hypervisor. The playbooks wire up networking, install K3s, deploy NGINX Ingress plus a demo workload, and manage a local SSH tunnel so you can drive `kubectl` from your controller machine.

## Component Roles
- Controller (Mac/Linux) – runs Ansible, `kubectl`, and optional `istioctl` to manage the cluster.
- Hypervisor host - runs VirtualBox and the Vagrant-managed VMs.
- `master01` – K3s server node, etcd/database, Kubernetes API endpoint.
- `worker01` – K3s agent node that schedules the demo workload and ingress controller.
- NGINX Ingress Controller – exposes the demo service via a LoadBalancer Service.
- `demo-nginx` workload – simple HTTP server used for ingress and rate-limit demonstrations.

## Networking
- A configurable host-only network carries intra-cluster traffic between the VMs.
- Optional bridged LAN addresses can expose node services to the controller network.
- Pod CIDR `10.42.0.0/16` and Service CIDR `10.43.0.0/16` use the K3s defaults.
- Ingress DNS `nginx.local.dev` resolves to the ingress controller LoadBalancer IP.
- When Istio is installed, Envoy sidecars intercept pod traffic and export metrics scraped by Prometheus.

## One-time Setup
1. Install VirtualBox and Vagrant on the hypervisor host.
2. On the controller machine:
   - Install `kubectl`.
   - Install Ansible, ideally inside a Python virtual environment (also install Plotly to run the rate limiting demo).
   - Install required collections: `ansible-galaxy collection install -r collections/requirements.yaml`.
   - Generate or reuse an SSH key: `ls ~/.ssh/id_rsa.pub || ssh-keygen -t rsa -f ~/.ssh/id_rsa`.
   - Copy the key to the hypervisor: `ssh-copy-id -i ~/.ssh/id_rsa.pub <user>@<hypervisor-host>`.
   - Create the Ansible vault with the cluster token: `ansible-vault create inventory/group_vars/all/vault.yaml` and set `k3s_token: "<secure>"`.
3. Install `istioctl` following the [official docs](https://istio.io/latest/docs/setup/additional-setup/download-istio-release/) if you want to follow the guide for the Istio Rate Limiting demo later.

## Provisioning Lifecycle
- Up: `ansible-playbook site.yaml -K -J`
  - Brings up the Vagrant VMs, installs K3s, deploys ingress and the demo workload.
  - Starts an SSH tunnel and rewrites the kubeconfig to `https://localhost:6443`.
- Down: `ansible-playbook site-reset.yaml -K`
  - Tears down the demo/ingress, K3s, and VMs, and stops the SSH tunnel.

## Accessing the Cluster
- Kubeconfig is stored at `artifacts/kubeconfig` with the server set to `https://localhost:6443`.
- Export it on the controller: `export KUBECONFIG=$(pwd)/artifacts/kubeconfig`.
- Validate connectivity: `kubectl get nodes`.
- Manage the tunnel manually when required with `scripts/k3s-tunnel.sh connect|disconnect`.

## Test the Demo via NGINX Ingress
1. Retrieve the LoadBalancer IP: `kubectl -n ingress-nginx get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`.
2. Option A – Curl with an explicit Host header: `curl --resolve nginx.local.dev:80:<LB_IP> http://nginx.local.dev/`.
3. Option B – Add `nginx.local.dev` to `/etc/hosts` with `<LB_IP>` and browse to `http://nginx.local.dev/`.

## Playbook Internals
- `vagrant-vms` – writes the `Vagrantfile` and brings up the VMs with host-only plus bridged adapters.
- `common` – tunes sysctls (br_netfilter, rp_filter loose, ip_forward) and UFW to allow flannel/VXLAN/HTTP(S).
- `k3s-master` / `k3s-worker` – installs the K3s server/agent, pins flannel interfaces, and advertises ExternalIPs.
- `ingress-nginx` – installs the ingress controller via Helm and waits for readiness.
- `demo-nginx` – provisions config/deployment/service/ingress and forces pods onto workers.
- Istio add-on playbooks layer Envoy sidecars, Prometheus, Grafana, and Kiali onto this baseline.

## Troubleshooting
- `kubectl` fails – confirm the tunnel (`ls artifacts/k3s_tunnel.sock`) and port (`nc -z 127.0.0.1 6443`).
- HTTP 502 via ingress – check endpoints (`kubectl -n demo-nginx get endpoints demo-nginx-svc -o wide`) and controller logs (`kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --tail=200`).
- Rate limiting telemetry gaps – ensure Prometheus is running/port-forwarded when the Istio stack is enabled.
- Use `scripts/k3s-tunnel.sh` if you need to manipulate the SSH tunnel outside of Ansible runs.

## Configuration Knobs
- `inventory/group_vars/all.yaml` – VM IPs, demo hostnames, namespaces, CIDRs.
- `inventory/hosts.ini` – hypervisor IP/user/key.
- `playbooks/istio/rate_limit_demo.yaml` and `roles/*/defaults/main.yaml` – rate limiting and observability parameters.
