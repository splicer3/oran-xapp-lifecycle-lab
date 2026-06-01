#!/usr/bin/env bash
set -euo pipefail

NS_ING="${NS_ING:-ingress-nginx}"
SVC_ING="${SVC_ING:-ingress-nginx-controller}"
APP_NS="${APP_NS:-demo-nginx}"
APP_SVC="${APP_SVC:-demo-nginx-svc}"
HOST="${HOST:-nginx.local.dev}"
REQS="${REQS:-30}"
CURL_TO="${CURL_TO:-3}"

echo "==> Ingress Service externalTrafficPolicy:"
kubectl -n "$NS_ING" get svc "$SVC_ING" -o jsonpath='{.spec.externalTrafficPolicy}'; echo
echo

echo "==> External addresses of the Ingress Service:"
IPS="$(kubectl -n "$NS_ING" get svc "$SVC_ING" -o jsonpath='{.status.loadBalancer.ingress[*].ip} {.status.loadBalancer.ingress[*].hostname}')"
echo "$IPS"; echo

echo "==> Backend endpoints (should list multiple addresses if multiple pods Ready):"
kubectl -n "$APP_NS" get endpoints "$APP_SVC" -o wide || true
echo

# Gather per-IP results
TMPDIR="$(mktemp -d)"
for IP in $IPS; do
  echo "==> Probing via $IP ($REQS requests)"
  OUT="$TMPDIR/$IP.out"
  : > "$OUT"
  for i in $(seq 1 "$REQS"); do
    HTML="$(curl --silent --max-time "$CURL_TO" --resolve "$HOST:80:$IP" "http://$HOST/")" || HTML=""
    POD="$(echo "$HTML" | grep -oE '<h1>Pod Name: [^<]+' | sed -E 's#<h1>Pod Name: ##' || true)"
    if [[ -n "$POD" ]]; then
      echo "$POD" | tee -a "$OUT" >/dev/null
    else
      echo "(no-match)" | tee -a "$OUT" >/dev/null
    fi
  done
  echo
  echo "Results for $IP:"
  echo "-------------------------------------"
  sort "$OUT" | uniq -c
  echo
done

echo "==> Pod placement (which node each app pod is on):"
kubectl -n "$APP_NS" get pods -o wide --no-headers | awk '{printf "%-40s %s\n",$1,$NF}'
echo
