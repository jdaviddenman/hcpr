#!/usr/bin/env bash
# verify-live.sh — independent census of highcountrypainrelief.com against the 2026-08-13 baseline.
# No site access required. Run before and after any asserted change.
#   bash audit/data/verify-live.sh
# See VERIFYING-BACKEND-CLAIMS.md for why each check is written the way it is.

set -uo pipefail

BASE="https://www.highcountrypainrelief.com"
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
CB="$BASE/?cb=$(date +%s)-$$"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

say() { printf '%-42s %10s   %-10s %s\n' "$1" "$2" "$3" "$4"; }
cmp_() { # label  actual  baseline
  local flag="ok"
  [ "$2" = "$3" ] || flag="CHANGED"
  say "$1" "$2" "$3" "$flag"
}

echo "=== origin (cache-busted) — what the server generates now ==="
curl -sS --max-time 30 --compressed -A "$UA" "$CB" -o "$TMP/cb.html" || { echo "fetch failed"; exit 1; }
echo "=== canonical URL — what visitors actually receive ==="
curl -sS --max-time 30 --compressed -A "$UA" "$BASE/" -o "$TMP/plain.html" || true
curl -sS --max-time 30 --compressed -A "$UA" -D "$TMP/plain.hdr" -o /dev/null "$BASE/" || true

H="$TMP/cb.html"
c()  { grep -o "$1" "$H" | wc -l | tr -d ' '; }

printf '\n%-42s %10s   %-10s %s\n' "CHECK" "TODAY" "2026-08-13" "STATUS"
printf -- '-%.0s' {1..80}; echo

cmp_ "scripts with defer or async"      "$(grep -oE '<script[^>]*(\sdefer|\sasync)[ =>]' "$H" | wc -l | tr -d ' ')" "0"
cmp_ "<script> tags"                    "$(c '<script')"                      "32"
cmp_ "<link rel=stylesheet>"            "$(grep -oE "rel=['\"]stylesheet['\"]" "$H" | wc -l | tr -d ' ')" "13"
cmp_ "<img> tags"                       "$(c '<img')"                         "22"
cmp_ "loading=\"lazy\""                 "$(c 'loading="lazy"')"               "16"
cmp_ "fetchpriority=\"high\""           "$(c 'fetchpriority="high"')"         "1"
echo
cmp_ "data-video-mobile=\"yes\"  [T1]"  "$(c 'data-video-mobile="yes"')"      "1"
cmp_ "fl-bg-video-play-pause    [T1]"   "$(c 'fl-bg-video-play-pause')"       "2"
echo
cmp_ "GTM container GTM-WGXQKR5 [T2]"   "$(c 'GTM-WGXQKR5')"                  "2"
cmp_ "cdn.userway.org/widget.js [T2]"   "$(c 'cdn.userway.org/widget.js')"    "1"
cmp_ "rw-embed-data (S3 config) [T2]"   "$(c 'rw-embed-data')"                "1"
cmp_ "requestIdleCallback       [T2]"   "$(c 'requestIdleCallback')"          "0"
echo
cmp_ "i.ytimg.com references    [T3]"   "$(c 'i.ytimg.com')"                  "35"
cmp_ "gallery swiper-slides     [T3]"   "$(c 'pp-video-gallery-item swiper-slide')" "35"
cmp_ "swiper.min references     [T3]"   "$(c 'swiper.min')"                   "2"
cmp_ "VideoObject blocks        [T3]"   "$(c 'VideoObject')"                  "33"
echo
cmp_ "global-styles-inline-css   [H7]"  "$(c 'global-styles-inline-css')"     "2"

# NB: measured via ?cb=, which is ~51 B smaller than the canonical 216,956 B
# because the query string is echoed into an inline block. Baseline below is the ?cb= value.
RAW=$(curl -sS --max-time 30 -H 'Accept-Encoding: identity' -A "$UA" -o /dev/null -w '%{size_download}' "$CB")
say "homepage HTML, raw bytes (via ?cb=)" "$RAW" "216905" "$([ "$RAW" -lt 210000 ] && echo SHRANK || echo '~')"

VER=$(grep -o 'bb-theme-child/style.css?ver=[^"'"'"']*' "$H" | head -1 | sed 's/.*ver=//')
say "child theme style.css ?ver=" "${VER:-none}" "7.0.4" \
    "$([ "${VER:-7.0.4}" = "7.0.4" ] && echo 'STILL WP VERSION — css edits will not reach returning visitors' || echo 'ok: versioned')"

LSC=$(grep -i '^x-litespeed-cache:' "$TMP/plain.hdr" | tr -d '\r' | awk '{print $2}')
CC=$(grep -ic '^cache-control:' "$TMP/plain.hdr" | tr -d ' ')
say "canonical URL cache state" "${LSC:-none}" "hit|miss" "-"
say "Cache-Control on HTML" "$([ "$CC" = "0" ] && echo absent || echo present)" "absent" "-"

if ! cmp -s "$TMP/cb.html" "$TMP/plain.html"; then
  A=$(wc -c < "$TMP/cb.html" | tr -d ' '); B=$(wc -c < "$TMP/plain.html" | tr -d ' ')
  echo
  echo "NOTE: cache-busted and canonical responses differ ($A vs $B bytes)."
  echo "      ~58 bytes is expected (the URL is echoed into an inline block)."
  echo "      A LARGER gap means the canonical URL is serving a STALE cached page —"
  echo "      the change may be live at the origin but not yet reaching visitors."
fi

echo
echo "Cold/warm TTFB baseline 2026-08-13: cold median 1.054s (12/12 MISS), warm median 0.076s"
echo "Lighthouse mobile median of 3, 2026-08-13: score 33, LCP 12.2s, TBT 1684ms, CLS 0.000 (0.184 cold)"
