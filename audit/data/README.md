# Measured Evidence

| File | Contents |
|---|---|
| `lighthouse-mobile-2026-07-30.md` | full Lighthouse extract, both runs compared |
| `header-sweep-2026-07-30.tsv` | GET sweep run 1, 44 sitemap URLs, 14 columns |
| `header-sweep-2026-07-30-run2.tsv` | GET sweep run 2, same 44 URLs, 1 h 18 min later |
| `header-sweep.sh` | reproducer for both sweeps |

---

## Header Sweeps

**Method:** GET (not HEAD) | **Scope:** all 44 URLs in `page-sitemap.xml`, two passes each plus an uncompressed-size pass.
Reproduce with `curl -s https://www.highcountrypainrelief.com/page-sitemap.xml | grep -oP '<loc>\K[^<]+' > /tmp/urls.txt && ./header-sweep.sh`.

### Why GET, not HEAD

Audits 01 and 03 originally verified server headers with `curl -sI` — a HEAD request. On this LiteSpeed server, HEAD responses **omit `content-encoding`** (reproduced 4/4 runs). That single method choice produced a false negative that became a CRITICAL finding.

| Method | `etag` | `x-litespeed-cache` | `content-encoding` |
|---|---|---|---|
| `curl -sI` (HEAD) | present | present | **absent** |
| `curl` (GET) | present | present | `br` |

All header claims in the audits use GET.

### Stable across both runs

```
status            44/44  200            (zero 404s)
content-encoding  44/44  br             raw 5,874,729 B -> br ~1,097,220 B = 81.3% saved (both runs)
cache-control     44/44  absent on HTML
vary              44/44  Accept-Encoding,User-Agent
etag (HTML)       44/44  present
cache state       pass 2: 44/44 HIT
```

`size_raw` totals **5,874,729 B in both runs, to the byte** — the sweeps measured identical content.

### Not stable — the cold-cache path

The two sweeps ran at 21:46 UTC and 23:04 UTC — **78 minutes apart**, derived from the LiteSpeed ETag mtimes in the `etag` column of both files. The format is `<counter>-<mtime>;br`: the first field is a monotonic counter, not a byte size (the homepage has `size_raw=218440` and an ETag of `424-1785448018;br`), and it increases across rows within a sweep — 424→467 in sweep 1, 496→540 in sweep 2. Only the second field is used for the timing derivation.

| | Run 1 | Run 2 | Ratio |
|---|---|---|---|
| Cache state, pass 1 | 44/44 MISS | 42/44 MISS, 2 HIT | — |
| TTFB MISS — min | 0.406 s | 0.475 s | 1.2× |  ← **combined minimum is 0.406 s**
| TTFB MISS — median | 0.845 s | **1.788 s** | **2.1×** |  ← lower-middle value; `statistics.median` gives 0.8577 / 1.7882
| TTFB MISS — mean | 1.204 s | **2.231 s** | **1.9×** |
| TTFB MISS — p90 | 2.277 s | **4.293 s** | **1.9×** |  ← `sorted[int(0.9*(n-1))]`
| TTFB MISS — max | 2.654 s | **4.946 s** | **1.9×** |
| TTFB HIT — range | 0.052-0.073 s | 0.053-0.113 s | stable — **combined 0.052-0.113 s across 90 observations** |

**Five slowest pages on MISS — the two runs share none:**

| Run 1 | Run 2 |
|---|---|
| `/hipaa-privacy-policy/` 2.654 s | `/contact-us/` 4.946 s |
| `/accessibility/` 2.537 s | `/testimonials/` 4.936 s |
| `/pain-management-center/` 2.460 s | `/office-tour/` 4.738 s |
| `/terms-service/` 2.408 s | `/chiropractic-care/` 4.589 s |
| `/knee-pain-lp/` 2.317 s | `/anti-discrimination/` 4.341 s |

**Conclusion.** Which page is slowest on a cache miss is not a property of the page — it is queueing variance on uncached PHP. Any per-page cold-cache claim is noise. The *shape* of the finding holds across both runs and is what audit 01 M1 rests on: nearly every page is cold on first request, the cold path costs seconds, and the warm path costs milliseconds.

## Supplementary checks

**UA cache-key bucketing** (run 1) — 8 distinct User-Agent strings, first request each: **7 HIT, 1 MISS**. LiteSpeed buckets UAs into groups; it does not key on the full string. `vary: User-Agent` is emitted but is not fragmenting the cache. A per-UA-fragmentation hypothesis was tested and refuted.

**Static assets** — 6 sampled (4 CSS, 2 JS), 2026-07-30: `cache-control: public, max-age=2592000` + `expires` + `last-modified` + `content-encoding: br` when requested. **No `etag` on any of the 6.**

**Caching plugins** — none installed. `wp-content/plugins/<slug>/readme.txt` returns the rendered WordPress 404 page (~93.6 KB) for `litespeed-cache`, `wp-rocket`, `autoptimize`, `wp-super-cache`, `w3-total-cache`. The probe is validated against a control slug (`definitely-not-installed-xyz`, also 404) and against slugs whose file genuinely exists (`bb-plugin`, `wordpress-seo`, `tenweb-speed-optimizer` — all **403**, 1,242 B). Caching is server-level, not plugin-level.

**HTML ETag mtimes advance as entries regenerate.** Within sweep 1 the 44 recorded mtimes span 82 seconds and increase monotonically in row order, consistent with every entry being generated at request time — which is what 44/44 MISS means. (An earlier revision of this file cited three mtimes, `1785442231 → 1785445430 → 1785448018`, as evidence of advance "during run 1"; only the third appears in either TSV. Replaced with the figure the evidence files actually support.)

## Effect on existing findings

| Audit claim | Verdict |
|---|---|
| 2026-07-28 "HTML carries zero caching headers" | CORRECT — 44/44 no `Cache-Control`, both runs |
| 2026-07-28 "No cache plugin installed" | CORRECT — plugin files 404, control-validated |
| 2026-07-28 "TTFB 2,540 ms" | CORRECT for the MISS path — it sits between sweep 1's p90 (2.277 s) and its maximum (2.654 s). (Rev. 2 of this file said "between run 1's p90 and run 2's median"; 2.540 is above both. Corrected.) |
| 2026-07-28 "no page caching / no `x-litespeed-cache` header" | **WRONG** — server-level cache active, 44/44 HIT on pass 2 in both runs |
| 2026-07-28 "HTML served uncompressed" | **WRONG** — 44/44 Brotli, 81% saved. HEAD artifact. Finding deleted. |
| "static assets have no ETag" | CORRECT — 6/6 sampled |
| "static assets 30-day + Brotli" | CORRECT |
| 2026-07-28 "`/us/` returns 404" | **WRONG** — 200, and it is in the sitemap |
| "sitemap = 44 URLs" | CORRECT — 44, dual-pattern confirmed |
| 2026-07-28 "`page-sitemap.xml` = 42 URLs" | **WRONG** — 44 |
| rev. 1 "44/44 MISS on first request" | Run-dependent. Run 1: 44/44. Run 2: 42/44. |
| rev. 1 "TTFB MISS 0.4-2.7 s" | Understates it. Across both runs the range is **0.406-4.946 s** over 86 cold requests. |
| rev. 1 named the 5 slowest pages | **WITHDRAWN** — the two runs share none of the five. |

## Revised diagnosis

The cache exists and is fast — **52-113 ms on HIT, stable across 90 observations**. Nearly every page is cold on first request (86 of 88). Low traffic plus no pre-warm means the first visitor to any page pays somewhere between 0.4 s and 4.9 s of uncached PHP, and with no `Cache-Control` on HTML no visitor caches the document browser-side either.

The remediation is **pre-warm + TTL + `Cache-Control` on HTML**, not "install a page cache."

## Findings verified live and unaffected by any of the above

Re-confirmed 2026-07-30, each with two independent patterns unless noted. Items marked **[rev. 3]** were re-measured after an adversarial review overturned the rev. 2 reading:

- 19 synchronous scripts, **0 `defer`, 0 `async`** — and 12 scripts, same zero, on `/knee-pain-lp/`
- 13 stylesheets
- **0 `<video>`, 0 `<source>`, 0 `poster=`** in the HTML — the hero is a `div.fl-bg-video` with `data-mp4` / `data-webm` / `data-fallback`
- `hiking.mp4` 15,343,649 B, `hiking.webm` 5,802,541 B, both `max-age=2592000`
- 35 `i.ytimg.com` thumbnail references; 35 YouTube iframes carry `data-src`, not `src`
- **4 iframes carry a real `src`**: GTM noscript, 2 Vimeo (inside an inert `<script type="text/html">` template), and 1 Google Maps embed in live DOM **which carries `loading="lazy"`** — verified with three patterns after an earlier revision reported it as eager
- 23 `<img>`, of which **7 lack `loading="lazy"`**, and **6 of those 7 also lack `width`/`height`** — `Best-of-Watauga-County-2025-Ribbon.webp` carries `width="500" height="792"`
- 1 `fetchpriority="high"`, on `Best-of-Watauga-County-2025-Ribbon.webp` (86,826 B) — emitted by WordPress core's `wp_get_loading_optimization_attributes()`, not by Beaver Builder
- **[rev. 3]** homepage HTML is **218,440 B** uncompressed — matching `size_raw` in both TSVs. Rev. 2 reported 217,984, a Python `len(str)` character count.
- **[rev. 3]** 12 first-party stylesheets, not 11: `swiper.min.css` (16,494 B raw / 4,259 br) was omitted from rev. 2's CSS accounting
- 5 Google Font families, no `display=swap`
- Source HTML: 1,792 start tags (`html.parser`; regex cross-check 1,800), of which 218 are `<meta>` and 198 of those are video microdata

**Correction to an earlier revision of this file:** it estimated the YouTube thumbnails at ~532 KB by sampling one thumbnail (15,585 B) and multiplying by 35. The Lighthouse run measures the actual set at **457.8 KiB** — individual thumbnails range from 11.4 to 15.2 KiB, so extrapolating from the largest overstated the total. Use the measured figure.

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
