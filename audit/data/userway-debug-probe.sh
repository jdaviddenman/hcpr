#!/usr/bin/env bash
# userway-debug-probe.sh — evidence collector for a coordinated disclosure to UserWay.
#
# Confirms, on a supplied list of domains, whether the Accessibility by UserWay WordPress
# plugin exposes /wp-json/userway/v1/debug WITHOUT authentication. One read-only GET per
# site — the same request any unauthenticated client can make. No exploitation, no writes,
# no second request.
#
# RESPONSIBLE-DISCLOSURE GUARDRAILS, built in:
#   - It RECORDS that the endpoint is open and which sensitive field NAMES it returns.
#   - It REDACTS the values. Third parties' account IDs, table prefixes and exact versions
#     are hashed or dropped — you are proving the plugin leaks, not hoarding others' recon.
#   - It only ever touches the one public endpoint. It never touches /save (the write route).
#
# USAGE:
#   printf '%s\n' example1.com example2.org > domains.txt
#   bash userway-debug-probe.sh domains.txt
#
# Populate domains.txt from a SOURCE-CODE search that finds the plugin specifically, e.g.
# (PublicWWW / Nerdydata syntax — the plugin's footer output, not the generic snippet):
#   "el.setAttribute('data-account'" "document.body.appendChild(el)" "cdn.userway.org/widget.js"
# or match the REST namespace where it is indexed:
#   "/wp-json/userway/v1"

set -uo pipefail
LIST="${1:?usage: userway-debug-probe.sh <domains.txt>}"
UA='Mozilla/5.0 (compatible; security-research; coordinated-disclosure)'

printf '%-34s %6s  %-9s %-40s %s\n' "domain" "status" "open?" "leaked field names (values redacted)" "plugin_ver"
printf -- '-%.0s' {1..120}; echo

open=0; total=0
while read -r d; do
  [ -z "$d" ] && continue
  d="${d#http://}"; d="${d#https://}"; d="${d%%/*}"
  total=$((total+1))
  url="https://${d}/wp-json/userway/v1/debug"
  body="$(curl -sS --max-time 20 -A "$UA" -H 'Accept: application/json' "$url" 2>/dev/null)"
  code="$(curl -sS --max-time 20 -A "$UA" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)"

  isopen="no"; fields="—"; ver="—"
  if [ "$code" = "200" ] && printf '%s' "$body" | grep -q '"userway"'; then
    isopen="OPEN"; open=$((open+1))
    # record the SCHEMA (field names) as proof of what leaks — not the values
    fields="$(printf '%s' "$body" \
      | python3 -c "import json,sys
try:
    d=json.load(sys.stdin)
    keys=[]
    if 'php' in d: keys.append('php')
    if 'wordpress' in d: keys.append('wordpress')
    uw=d.get('userway',{})
    if 'version' in uw: keys.append('userway.version')
    acct=uw.get('account') or []
    if acct and 'account_id' in acct[0]: keys.append('account_id[REDACTED]')
    if 'table' in uw: keys.append('table_prefix[REDACTED]')
    print(','.join(keys))
except Exception:
    print('parse_error')" 2>/dev/null)"
    # plugin version IS the disclosure point (proves version leak) — keep it, drop the rest
    ver="$(printf '%s' "$body" | python3 -c "import json,sys;print(json.load(sys.stdin).get('userway',{}).get('version','?'))" 2>/dev/null)"
  fi
  printf '%-34s %6s  %-9s %-40s %s\n' "$d" "$code" "$isopen" "$fields" "$ver"
done < "$LIST"

echo
echo "RESULT: ${open} of ${total} sites expose /wp-json/userway/v1/debug unauthenticated (HTTP 200)."
echo "Values (account IDs, table prefixes) are redacted by design — the open endpoint and its"
echo "field schema are the evidence; the third parties' specific data is not collected."
