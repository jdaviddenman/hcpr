#!/bin/bash
UA='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36'
OUT=/tmp/sweep.tsv
printf 'url\tstatus\tloc\tlsc1\tttfb1\tlsc2\tttfb2\tenc\tsize_enc\tsize_raw\tratio\tcache_control\tvary\tetag\n' > "$OUT"
while read -r u; do
  [ -z "$u" ] && continue
  h1=$(curl -s -o /dev/null -D - -A "$UA" -H 'Accept-Encoding: br,gzip' -w '\nTTFB:%{time_starttransfer}\nCODE:%{http_code}\nDL:%{size_download}\n' --max-time 30 "$u" 2>/dev/null)
  sleep 0.25
  h2=$(curl -s -o /dev/null -D - -A "$UA" -H 'Accept-Encoding: br,gzip' -w '\nTTFB:%{time_starttransfer}\nCODE:%{http_code}\nDL:%{size_download}\n' --max-time 30 "$u" 2>/dev/null)
  raw=$(curl -s -A "$UA" -H 'Accept-Encoding: identity' --max-time 30 "$u" 2>/dev/null | wc -c)
  sleep 0.25
  g(){ printf '%s' "$1" | grep -i "^$2:" | head -1 | cut -d: -f2- | tr -d '\r' | sed 's/^ *//;s/\t/ /g'; }
  code=$(printf '%s' "$h1" | grep -oP '^CODE:\K.*' | tail -1)
  t1=$(printf '%s' "$h1" | grep -oP '^TTFB:\K.*' | tail -1)
  t2=$(printf '%s' "$h2" | grep -oP '^TTFB:\K.*' | tail -1)
  dl=$(printf '%s' "$h1" | grep -oP '^DL:\K.*' | tail -1)
  ratio=$( [ "$raw" -gt 0 ] 2>/dev/null && awk -v a="$dl" -v b="$raw" 'BEGIN{if(b>0)printf "%.3f",a/b; else print "-"}' || echo "-" )
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$u" "$code" "$(g "$h1" location)" \
    "$(g "$h1" x-litespeed-cache)" "$t1" "$(g "$h2" x-litespeed-cache)" "$t2" \
    "$(g "$h1" content-encoding)" "$dl" "$raw" "$ratio" \
    "$(g "$h1" cache-control)" "$(g "$h1" vary)" "$(g "$h1" etag)" >> "$OUT"
done < /tmp/urls.txt
echo "rows: $(( $(wc -l < "$OUT") - 1 ))"
