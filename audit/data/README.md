# Header Sweep — Measured Evidence

**Date:** 2026-07-30 | **Method:** GET (not HEAD) | **Scope:** all 44 URLs in `page-sitemap.xml`

Raw data: `header-sweep-2026-07-30.tsv` (44 rows, 14 columns). Reproduce with `./header-sweep.sh` (reads a URL list from `/tmp/urls.txt`).

## Why this exists

Audits 01 and 03 verified server headers with `curl -sI` — a HEAD request. On this LiteSpeed server, HEAD responses **omit `content-encoding`** (reproduced 4/4 runs). That single method choice produced a false negative that became a CRITICAL finding.

| Method | `etag` | `x-litespeed-cache` | `content-encoding` |
|---|---|---|---|
| `curl -sI` (HEAD) | present | present | **absent** |
| `curl` (GET) | present | present | `br` |

All header claims in the audits should be re-verified with GET before republication.

## Results — 44/44 sitemap URLs

```
status            44/44  200            (zero 404s)
content-encoding  44/44  br             raw 5,874,729 B -> br 1,097,229 B = 81% saved
cache state       44/44  MISS on 1st request, HIT on 2nd
cache-control     44/44  absent on HTML
vary              44/44  Accept-Encoding,User-Agent
etag (HTML)       44/44  present
```

```
TTFB  MISS   min 0.406  median 0.845  mean 1.204  p90 2.277  max 2.654 s
TTFB  HIT    min 0.052  mean  0.059                          max 0.073 s
                                                        ratio 20.2x
```

Slowest on MISS: `/hipaa-privacy-policy/` 2.654s, `/accessibility/` 2.537s, `/pain-management-center/` 2.460s, `/terms-service/` 2.408s, `/knee-pain-lp/` 2.317s.

## Supplementary checks

**UA cache-key bucketing** — 8 distinct User-Agent strings, first request each: **7 HIT, 1 MISS**. LiteSpeed buckets UAs into groups; it does not key on the full string. `vary: User-Agent` is emitted but is not fragmenting the cache. A per-UA-fragmentation hypothesis was tested and refuted.

**Static assets** (4 sampled: 2 CSS, 2 JS) — `cache-control: public, max-age=2592000` + `expires` + `last-modified` + `content-encoding: br`. **No `etag`.**

**LiteSpeed Cache WordPress plugin** — `wp-content/plugins/litespeed-cache/readme.txt` and `litespeed-cache.php` both return 404; no plugin signature in page HTML. Caching is server-level, not plugin-level.

**HTML ETag mtime advanced during the session** (`1785442231` → `1785445430` → `1785448018`), consistent with cache entries expiring and regenerating.

## Effect on existing findings

| Audit claim | Verdict |
|---|---|
| 01 C1 "HTML carries zero caching headers" | CORRECT — 44/44 no `Cache-Control` |
| 01 C1 "No cache plugin installed" | CORRECT — plugin files 404 |
| 01 C1 "TTFB 2,540ms" | CORRECT for the MISS path — p90 2.277s, max 2.654s |
| 01 C1 "no page caching / no `x-litespeed-cache` header" | **WRONG** — server-level cache active, 44/44 HIT at 52-73ms |
| 01 C2 "HTML served uncompressed" | **WRONG** — 44/44 Brotli, 81% saved. HEAD artifact. Delete the finding. |
| 01 L4 "static assets have no ETag" | CORRECT — 4/4 sampled |
| 01 M4 / 03 §6 static assets 30-day + Brotli | CORRECT |
| 04 C1 / 01-seo C5 "`/us/` returns 404" | **WRONG** — 200, and it is in the sitemap |
| 01 §9 "sitemap = 44 URLs" | CORRECT |
| 02 "`page-sitemap.xml` = 42 URLs" | **WRONG** — 44 |

## Revised diagnosis

The cache exists and is fast (52-73ms on HIT). Every one of 44 pages was cold on first request. Low traffic plus no pre-warm means the first visitor to any page pays 0.4-2.7s of uncached PHP, and with no `Cache-Control` on HTML no visitor caches it browser-side either.

The audits' recommendation (LSCache crawler to pre-warm) is right; the diagnosis behind it is not. The remediation is **pre-warm + TTL + `Cache-Control` on HTML**, not "install a page cache."

Findings unaffected by this correction, verified live on 2026-07-30: 19 synchronous scripts with 0 `defer` and 0 `async`; 13 stylesheets; `hiking.mp4` 15,343,649 B with a 5,802,541 B `hiking.webm` already present beside it in the same `<video>` source list; 35 eager `i.ytimg.com` thumbnails at 15,585 B each (~532 KB, not the 455 KB stated); 5 Google Font families with no `display=swap`.

## Column reference

| Column | Meaning |
|---|---|
| `url` | sitemap URL |
| `status` | HTTP status, pass 1 |
| `loc` | `Location` header if redirected |
| `lsc1` / `lsc2` | `x-litespeed-cache` on pass 1 / pass 2 |
| `ttfb1` / `ttfb2` | `time_starttransfer` seconds, pass 1 / pass 2 |
| `enc` | `content-encoding` |
| `size_enc` / `size_raw` | bytes with `Accept-Encoding: br,gzip` / with `identity` |
| `ratio` | `size_enc / size_raw` |
| `cache_control` / `vary` / `etag` | response headers, pass 1 |
