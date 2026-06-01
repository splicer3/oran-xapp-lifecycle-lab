#!/bin/sh

set -u

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd "$SCRIPT_DIR/.." && pwd)
TMP_BASE="${TMPDIR:-/tmp}/oran-public-safety.$$"
MAX_BYTES=${PUBLIC_SAFETY_MAX_BYTES:-5242880}

fail_count=0
warn_count=0

cleanup() {
  rm -rf "$TMP_BASE"
}

trap cleanup EXIT HUP INT TERM

if ! (umask 077 && mkdir "$TMP_BASE"); then
  printf 'FAIL: could not create temporary directory\n'
  exit 1
fi

pass() {
  printf 'PASS: %s\n' "$1"
}

warn() {
  warn_count=$((warn_count + 1))
  printf 'WARN: %s\n' "$1"
}

record_fail_file() {
  path=$1
  printf '%s\n' "$path" >> "$2"
}

report_failures() {
  label=$1
  file=$2

  if [ -s "$file" ]; then
    fail_count=$((fail_count + 1))
    printf 'FAIL: %s\n' "$label"
    sed -n '1,30p' "$file" | sed 's/^/  /'
    total=$(wc -l < "$file" | tr -d ' ')
    if [ "$total" -gt 30 ]; then
      printf '  ... %s more\n' "$((total - 30))"
    fi
  else
    pass "$label"
  fi
}

scan_files="$TMP_BASE/files"
find "$REPO_ROOT" \
  \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/.codex-local" \) -prune -o \
  -type f ! -path "$REPO_ROOT/AGENTS.override.md" -print > "$scan_files"

secret_names="$TMP_BASE/secret-names"
private_key_names="$TMP_BASE/private-key-names"
kubeconfig_names="$TMP_BASE/kubeconfig-names"
captures_logs="$TMP_BASE/captures-logs"
large_files="$TMP_BASE/large-files"
personal_artifacts="$TMP_BASE/personal-artifacts"
secret_content="$TMP_BASE/secret-content"
kubeconfig_content="$TMP_BASE/kubeconfig-content"

: > "$secret_names"
: > "$private_key_names"
: > "$kubeconfig_names"
: > "$captures_logs"
: > "$large_files"
: > "$personal_artifacts"
: > "$secret_content"
: > "$kubeconfig_content"

printf 'Checking public safety for oran-xapp-lifecycle-lab\n'
printf 'Repository: %s\n' "$REPO_ROOT"
printf 'Large file threshold: %s bytes\n\n' "$MAX_BYTES"

while IFS= read -r path; do
  rel=${path#"$REPO_ROOT/"}
  name=${rel##*/}
  lower=$(printf '%s' "$rel" | tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz')

  case $lower in
    *.env|*.env.*|*/.env|*/.env.*|*/vault.yaml|*.vault-pass)
      case $lower in
        *.env.example|*/.env.example)
          ;;
        *)
          record_fail_file "$rel" "$secret_names"
          ;;
      esac
      ;;
  esac

  case $name in
    id_rsa|id_dsa|id_ecdsa|id_ed25519|*.pem|*.key|*.p12|*.pfx)
      record_fail_file "$rel" "$private_key_names"
      ;;
  esac

  case $lower in
    */.kube/*|*/kubeconfig|*.kubeconfig)
      record_fail_file "$rel" "$kubeconfig_names"
      ;;
  esac

  case $lower in
    *.pcap|*.pcapng|*.log)
      record_fail_file "$rel" "$captures_logs"
      ;;
  esac

  case $lower in
    *.pdf|*.doc|*.docx|*.ppt|*.pptx|*bachelorthesis*|*bachelor_thesis*|*thesis*.pdf|*tesi*|*acknowledg*|*matteodiiorio*)
      record_fail_file "$rel" "$personal_artifacts"
      ;;
  esac

  size=$(wc -c < "$path" | tr -d ' ')
  if [ "$size" -gt "$MAX_BYTES" ]; then
    printf '%s (%s bytes)\n' "$rel" "$size" >> "$large_files"
  fi

  case $rel in
    scripts/check-public-safety.sh)
      continue
      ;;
  esac

  if grep -Eq -- '-----BEGIN [A-Z0-9 ]*[P]RIVATE KEY-----' "$path" 2>/dev/null; then
    printf '%s: private key block\n' "$rel" >> "$secret_content"
  fi

  if grep -Eq 'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|glpat-[A-Za-z0-9_-]{20,}|xox[baprs]-[A-Za-z0-9-]{20,}|AKIA[0-9A-Z]{16}' "$path" 2>/dev/null; then
    printf '%s: token-like value\n' "$rel" >> "$secret_content"
  fi

  if grep -EIn '(password|passwd|secret|token|api[_-]?key|access[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*['"'"'"]?[A-Za-z0-9_./+=:@-]{12,}' "$path" 2>/dev/null | sed 's/^/  /' > "$TMP_BASE/grep.out"; then
    if [ -s "$TMP_BASE/grep.out" ]; then
      printf '%s:\n' "$rel" >> "$secret_content"
      sed -n '1,5p' "$TMP_BASE/grep.out" >> "$secret_content"
    fi
  fi

  if grep -Eq '^[[:space:]]*clusters:' "$path" 2>/dev/null && grep -Eq '^[[:space:]]*users:' "$path" 2>/dev/null; then
    printf '%s: kubeconfig-like content\n' "$rel" >> "$kubeconfig_content"
  fi
done < "$scan_files"

report_failures "no secret-like filenames found" "$secret_names"
report_failures "no private key-like files found" "$private_key_names"
report_failures "no kubeconfig-like filenames found" "$kubeconfig_names"
report_failures "no packet captures or log files found" "$captures_logs"
report_failures "no files exceed the configured size threshold" "$large_files"
report_failures "no personal thesis document artifacts found" "$personal_artifacts"
report_failures "no likely secret values found in file contents" "$secret_content"
report_failures "no kubeconfig-like content found" "$kubeconfig_content"

if command -v gitleaks >/dev/null 2>&1; then
  pass "gitleaks found; optional stronger check: gitleaks detect --source ."
else
  warn "gitleaks not found; optional stronger check: gitleaks detect --source ."
fi

printf '\nSummary: %s failure(s), %s warning(s)\n' "$fail_count" "$warn_count"

if [ "$fail_count" -gt 0 ]; then
  exit 1
fi

exit 0
