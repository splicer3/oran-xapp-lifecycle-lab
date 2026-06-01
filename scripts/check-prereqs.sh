#!/bin/sh

set -u

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)

fail_count=0
warn_count=0

pass() {
  printf 'PASS: %s\n' "$1"
}

warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  fail_count=$((fail_count + 1))
  printf 'FAIL: %s\n' "$1"
}

first_line() {
  "$@" 2>/dev/null | sed -n '1p'
}

check_cmd_required() {
  name=$1
  detail=$2

  if command -v "$name" >/dev/null 2>&1; then
    version=$(first_line "$name" --version)
    if [ -n "$version" ]; then
      pass "$name found: $version"
    else
      pass "$name found ($detail)"
    fi
  else
    fail "$name not found ($detail)"
  fi
}

check_cmd_optional() {
  name=$1
  detail=$2

  if command -v "$name" >/dev/null 2>&1; then
    version=$(first_line "$name" --version)
    if [ -n "$version" ]; then
      pass "$name found: $version"
    else
      pass "$name found ($detail)"
    fi
  else
    warn "$name not found ($detail)"
  fi
}

check_file_required() {
  path=$1
  detail=$2

  if [ -e "$REPO_ROOT/$path" ]; then
    pass "$path exists ($detail)"
  else
    fail "$path missing ($detail)"
  fi
}

check_file_optional() {
  path=$1
  detail=$2

  if [ -e "$REPO_ROOT/$path" ]; then
    pass "$path exists ($detail)"
  else
    warn "$path missing ($detail)"
  fi
}

check_python_module_optional() {
  module=$1
  detail=$2

  if command -v python3 >/dev/null 2>&1 && python3 -c "import $module" >/dev/null 2>&1; then
    pass "python3 module '$module' import works"
  else
    warn "python3 module '$module' not available ($detail)"
  fi
}

check_container_runtime() {
  if command -v docker >/dev/null 2>&1; then
    pass "docker command found"
    if docker info >/dev/null 2>&1; then
      pass "docker daemon reachable without sudo"
    else
      warn "docker command found, but daemon is not reachable without sudo"
    fi
    return
  fi

  if command -v podman >/dev/null 2>&1; then
    pass "podman command found as a Docker-compatible local runtime"
    return
  fi

  if command -v nerdctl >/dev/null 2>&1; then
    pass "nerdctl command found as a containerd-compatible local runtime"
    return
  fi

  warn "no local docker, podman, or nerdctl command found; the main playbook installs Docker on the target VM"
}

check_kubeconfig_optional() {
  if [ -n "${KUBECONFIG:-}" ]; then
    case $KUBECONFIG in
      *:*)
        warn "KUBECONFIG contains multiple paths; not validating local kubeconfig files"
        ;;
      *)
        if [ -f "$KUBECONFIG" ]; then
          pass "KUBECONFIG points to an existing file"
        else
          warn "KUBECONFIG is set but the file does not exist"
        fi
        ;;
    esac
  elif [ -f "${HOME:-}/.kube/config" ]; then
    pass "default kubeconfig exists at ~/.kube/config"
  else
    warn "no local kubeconfig detected; this is optional before deployment"
  fi

  if command -v k3s >/dev/null 2>&1; then
    pass "k3s command found locally"
  else
    warn "k3s command not found locally; the lifecycle playbook installs it on the target VM"
  fi
}

printf 'Checking local prerequisites for oran-xapp-lifecycle-lab\n'
printf 'Repository: %s\n\n' "$REPO_ROOT"

check_cmd_optional git "recommended for normal repository work"
check_cmd_optional gh "optional GitHub CLI; not required for local validation"
check_cmd_optional make "optional wrapper for local repository checks"
check_cmd_required ansible-playbook "required for documented local syntax checks"
check_cmd_required ansible-galaxy "required to install documented Ansible collections"
check_cmd_optional ansible "Ansible ad-hoc CLI; ansible-playbook is the required entry point"
check_cmd_required python3 "required for documented plotting/script checks"
check_cmd_optional kubectl "optional for manual cluster inspection"
check_cmd_optional helm "used by the deployed workflow on the target VM; optional on the controller"
check_container_runtime
check_kubeconfig_optional
check_python_module_optional plotly "required only for optional HTML chart rendering"

printf '\nChecking files used by documented commands\n'
check_file_required Makefile "local check targets"
check_file_required scripts/check-prereqs.sh "this preflight script"
check_file_required scripts/check-public-safety.sh "public safety scanner"
check_file_required ansible/ric-lifecycle/collections/requirements.yml "main Ansible collection requirements"
check_file_required ansible/ric-lifecycle/inventory/hosts.ini.example "main inventory template"
check_file_required ansible/ric-lifecycle/site.yml "main lifecycle playbook"
check_file_required ansible/ric-lifecycle/reset.yml "main teardown playbook"
check_file_required ansible/ric-lifecycle/playbooks/validate.yml "main lifecycle validator"
check_file_required ansible/istio-ab-testing/inventory/hosts.ini.example "A/B inventory template"
check_file_required ansible/istio-ab-testing/playbooks/run_demo.yml "Time-Based Switching entry point"
check_file_required ansible/istio-ab-testing/scripts/plot_ab.py "A/B plotting script"
check_file_required results/sample/ab-testing/csv/ABTesting_kpimonV2.csv "documented A/B sample input"
check_file_optional ansible/istio-rate-limit-demo/collections/requirements.yaml "optional rate-limit demo requirements"
check_file_optional ansible/istio-rate-limit-demo/site.yaml "optional rate-limit demo bring-up"
check_file_optional ansible/istio-rate-limit-demo/site-reset.yaml "optional rate-limit demo teardown"
check_file_optional ansible/istio-rate-limit-demo/scripts/plot_rate_limit.py "optional rate-limit plotting script"

printf '\nSummary: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
