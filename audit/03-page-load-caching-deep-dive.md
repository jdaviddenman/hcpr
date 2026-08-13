# Page Load, Caching & Third-Party Deep-Dive: highcountrypainrelief.com

**Date:** 2026-07-31 · **figures reconciled to the 2026-08-13 re-measurement**
**Scope:** caching layers, third-party behaviour, the YouTube facade. Metric findings and the remediation
sequence live in `audit/01-page-speed-performance-audit.md`.
**Evidence:** `audit/data/header-sweep-2026-07-30.tsv`, `…-run2.tsv`,
`audit/data/lighthouse-mobile-2026-07-30.md`

> **Verify headers with GET, not HEAD.** This LiteSpeed server omits `content-encoding` from HEAD
> responses. Every header claim below is from a GET.

---

## 1. Cache Policy by Domain

| Domain | Service | Cache-Control | Verified | Problem? |
|---|---|---|---|---|
| `highcountrypainrelief.com` — **HTML** | WordPress pages | **none** | GET sweep, 44/44 URLs | **YES.** No `Cache-Control` on any HTML response, so no visitor caches the document. The server-level LiteSpeed cache is active (`x-litespeed-cache`), Brotli is applied, and `ETag` is present. |
| `highcountrypainrelief.com` — **static** | CSS, JS, fonts, images | `public, max-age=2592000` + `content-encoding: br` | 6 assets sampled | No. 30-day cache and Brotli both working. **No `ETag`**, so revalidation falls back to `Last-Modified` at 1-second granularity. |
| `chiro.inceptionimages.com` | Practice imagery + hero video | `public, max-age=2592000` | direct GET on `hiking.mp4`, `hiking.webm` | No. A **separate host** (`18.214.60.67`) from the main origin (`44.223.213.21`). |
| `i.ytimg.com` | YouTube thumbnails | `public, max-age=7200` | direct GET | **YES**, but not for the TTL. 35 thumbnails load eagerly on every page view, 457.8 KiB. The cost is 35 requests on first visit. The facade eliminates them — §3. |
| `googletagmanager.com` | GTM + gtag | short TTL by design | Lighthouse | **YES**, for size not caching. 275 KiB and 1,165 ms of blocking. The short TTL is correct; the container is the problem. Audit 01 H6. |
| `cdn.userway.org` | Accessibility widget | `max-age=3600, public` | direct GET | Low. 137 KiB and 2,443 ms blocking are the issue, not the TTL. |
| `cdn.reviewwave.com` | Reviews + chat | S3 + CloudFront | — | Low. 16 KiB, 196 ms blocking. |
| `rw-embed-data.s3.amazonaws.com` | ReviewWave config JS | **none** | direct GET, 2026-07-30 and 08-13 | **YES, twice over.** `Content-Length: 56,589` on 07-30 and **57,267 B** on 08-13 — a live data file and **no `Content-Encoding`** — the same bytes are returned whether or not `gzip` is requested. It is the only entry in Lighthouse's text-compression audit (36.6 KiB available) and the largest render-blocking resource at 1,570 ms. **No `Cache-Control`**, so browsers do not cache it between visits; `ETag` and `Last-Modified` are present, so revalidation costs a round trip every time. The object metadata belongs to ReviewWave; `gzip -9` would take it to 19,115 B. The fix available here is `defer`; the compression ask has to come from the practice as account holder. **ReviewWave is six resources, not three** — the two embed scripts each inject a stylesheet at runtime and `chat_embed.js` fetches a second S3 config, totalling 73,995 B transfer / 120,119 B uncompressed, none carrying `Cache-Control`. |
| `fonts.gstatic.com` | Font files | `max-age=31536000` | direct GET | No. 1 year, immutable, versioned URLs. |
| `fonts.googleapis.com` | Font CSS | `private, max-age=86400` | direct GET | Minor. `private` is correct — the CSS varies by user agent. The issue is 5 families and no `display=swap`. |
| `i.vimeocdn.com` | Vimeo thumbnail | `max-age=2592000` | direct GET | No. 30 days, 15 KiB, one embed. |

> The ReviewWave S3 endpoint returned 403 to a direct request on 2026-07-28 and 200 to both GET and HEAD
> on 2026-07-30. If a future check hits 403, the endpoint is inconsistent — the figures above are
> measured.

### The actual cache gaps

1. **HTML has no `Cache-Control`.** 44/44 URLs.
2. **The page cache is cold, not missing.** §2.
3. **Static assets have no `ETag`.** A working 30-day cache with coarser revalidation than it needs.
4. **35 YouTube thumbnails on a 2-hour TTL.** Fix by not requesting them — §3.
5. **No CDN.** Both hosts serve directly from AWS EC2. Lower priority than it appears at 52–113 ms warm
   TTFB, and it does nothing for a cache MISS, which is the path that costs seconds.

---

## 2. The Cache Is Working. It Is Cold.

### All 44 sitemap URLs, two passes each, twice, 1 h 18 min apart

```
                            run 1                    run 2
cache state, pass 1    44/44 MISS               42/44 MISS, 2 HIT
cache state, pass 2    44/44 HIT                44/44 HIT
content-encoding       44/44 br  (81% saved)    44/44 br  (81.3% saved)
cache-control          44/44 absent on HTML     44/44 absent
etag                   44/44 present            44/44 present
vary                   44/44 Accept-Encoding,User-Agent  (both)
size_raw total         5,874,729 B              5,874,729 B   <- identical content

TTFB MISS   min 0.406  median 0.845  mean 1.204  p90 2.277  max 2.654 s   (run 1)
TTFB MISS   min 0.475  median 1.788  mean 2.231  p90 4.293  max 4.946 s   (run 2)
TTFB HIT    0.052-0.073 s (run 1)   0.053-0.113 s (run 2)   <- stable
```

Nearly every page was cold. Every page warmed on the second request and served in **52–113 ms** across all
90 warm observations.

**The cold path is far less predictable than a single sweep suggests.** Run 2's MISS median is 2.1× run
1's and its maximum 1.9×, on byte-identical content. The two runs share **none** of their five slowest
pages:

| Run 1 slowest on MISS | Run 2 slowest on MISS |
|---|---|
| `/hipaa-privacy-policy/` 2.654 s | `/contact-us/` 4.946 s |
| `/accessibility/` 2.537 s | `/testimonials/` 4.936 s |
| `/pain-management-center/` 2.460 s | `/office-tour/` 4.738 s |
| `/terms-service/` 2.408 s | `/chiropractic-care/` 4.589 s |
| `/knee-pain-lp/` 2.317 s | `/anti-discrimination/` 4.341 s |

**Which page is slowest on a cache miss is not a property of the page.** What holds across both runs is
the shape: nearly every page cold, seconds on the cold path, milliseconds on the warm one.

Lighthouse's TTFB of 700 ms — 4% of LCP, passing — is one sample of a distribution spanning 0.406 s to
4.946 s across 86 cold requests.

**Why it matters.** A brochure site for a local practice has low per-page traffic, so cache entries expire
before the next visitor arrives and a real first visitor to some page pays seconds. Which page pays most
is not predictable, so pre-warming has to cover the whole sitemap rather than a shortlist.

**Fix: pre-warm and hold.**

| Action | Why |
|---|---|
| **First: a cron'd `curl`/`wget --spider` loop over the 44 sitemap URLs** on the same EC2 box | Warms the identical server-level cache. No plugin, no `.htaccess` rewrite, no exposure to the BB-editor breakage in §4. ~15 min. |
| Only if that is insufficient: LiteSpeed Cache plugin | **Not an inert addition.** The plugin is the control plane for the server module — installing it rewrites `.htaccess` and takes over cache rules, TTLs, purge behaviour and vary logic. Its crawler warms only what its own rules deem cacheable, needs the plugin's cache enabled, needs the crawler switched on at the **LiteSpeed server admin** level (routinely off), and needs a working cron. |
| Point the crawler at `page-sitemap.xml` | 44 URLs, all currently cold |
| Raise Default Public TTL to 604800 s (7 days) | Content changes rarely; long TTL plus purge-on-change beats short TTL |
| Front Page TTL 86400 s (24 h) | Homepage carries promos |
| Add `Cache-Control: no-cache` to HTML | Currently absent on 44/44. **`no-cache`, not `max-age=3600`** — HTML already carries an ETag on 44/44, so `no-cache` gives near-free 304 revalidation with no staleness window. `max-age=3600` caches a document that cannot be purged, including for logged-in editors and on booking and form pages. |
| **Add `fl_builder` to Page Optimization → Tuning → URI Excludes first** | Without this the Beaver Builder editor breaks |

**UA-keyed caching is not fragmenting this cache.** Responses carry `vary: Accept-Encoding, User-Agent`.
Tested with 8 distinct UA strings, first request each: 7 returned HIT. LiteSpeed buckets user agents into
groups rather than keying on the full string. No action.

---

## 3. YouTube Facade

### Current state

- 35 thumbnails as CSS `background-image` on `div.pp-video-image-overlay` — `loading="lazy"` does not
  apply to CSS backgrounds
- **457.8 KiB** total, 11.4–15.2 KiB each, all eager
- `i.ytimg.com` serves `cache-control: public, max-age=7200`
- The gallery container `div.pp-video-gallery-items.swiper-wrapper` holds **105 child elements** on both
  measurement dates — the densest structure on the page, and a direct contributor to the 3,181-element DOM.
  **70 of the 105 are Swiper loop clones and are removable by unticking Loop** — see `audit/01` H8(0)

**The iframes are already lightbox-deferred and cost 0 KiB until click.** The measured saving from a
facade is **457.8 KiB and 35 requests**, not the iframe payload.

### Options

| Option | Size | BB compatibility | Best for |
|---|---|---|---|
| **A. `lite-youtube-embed`** | ~3 KiB JS + ~1 KiB CSS gzipped | Works via BB HTML module; zero dependencies; Apache-2.0 | Recommended |
| B. WP YouTube Lyte | plugin overhead | May need `[lyte]` shortcode support in BB text modules | Non-technical editors; local thumbnail caching |
| C. Custom facade | ~2 KiB inline JS | Requires BB module work | Full control |
| D. Embed Plus | heavy | plugin-level | Overkill |

### Recommendation: Option A

35 instances share one JS/CSS load. The component renders its own thumbnail only after click, then swaps
itself for the real iframe (`youtube-nocookie.com`, `autoplay=1`). `playlabel` provides an accessible name.

```html
<!-- once, via child theme or BB global settings -->
<link rel="stylesheet" href="lite-yt-embed.css">
<script defer src="lite-yt-embed.js"></script>

<!-- per video, replacing each pp-video-image-overlay -->
<lite-youtube videoid="C7XENcnzvzc" playlabel="Play: Patient Testimonial"></lite-youtube>
```

Enqueue via child theme `functions.php` or BB global settings. Replace each `pp-video` module with an HTML
module, or write one small BB custom module and reuse it across all 35.

For WP YouTube Lyte, enable "Cache thumbnails locally" so the poster is self-hosted and `i.ytimg.com` is
never contacted:

```
[lyte id="C7XENcnzvzc" /]
```

> See `PRIORITY-FIXES.md` Ticket 3 before implementing: a naive `lite-youtube-embed` swap sets its own
> `i.ytimg.com` background *and* fetches a second image per video, taking 35 requests to about 70.

### Measured gain

- **457.8 KiB** deferred per page load, **35 requests** eliminated
- "Defer offscreen images" drops from 758.5 KiB toward ~300 KiB (the remainder is first-party — audit 01 H8(a))
- DOM reduction from replacing 35 overlay structures
- No cache-expiry exposure, since nothing is requested until a click

---

## 4. Beaver Builder and Plugin Caching

### What Beaver Builder already does

- **Location:** `/wp-content/uploads/bb-plugin/cache/`
- Generates per-page CSS and JS on save, named by post ID — `2-layout.css` and `2-layout.js` for the
  homepage (post ID 2)
- Selective enqueue: only modules present on the page load their assets
- Cache-busting via content-hash query strings (`?ver=bcd079b…`)
- Regenerates on page save, plugin update, site URL change, or `WP_DEBUG = true`

**What it costs.** `2-layout.js` is the most expensive script on the page on both measurement dates —
10,883 ms CPU in July, 2,371 ms in August, the difference being the test machine rather than the site.
Most of it is evaluation, i.e. DOM construction. This is the price of the page's module count, and it
shrinks only when the page carries fewer modules.

The 2.10.3.1 upgrade regenerated both bundles on 2026-08-11 and both shrank: `2-layout.js` 87,756 →
72,591 B raw, `2-layout.css` 185,968 → 164,124 B raw.

**What it does not do:** page caching, HTML caching, browser cache headers, object caching, minification
beyond its own files, or CDN integration.

### What LSCache would add

| Layer | Current | With LSCache |
|---|---|---|
| **Crawler** | none — 44/44 pages cold | pre-warms the sitemap. **The main reason to install it.** |
| **HTML `Cache-Control`** | absent on 44/44 | configurable per content type |
| **Page cache** | already active at server level | plugin-level control, purge rules, ESI |
| **ETag on static** | absent | added |
| **Object cache** | none | Redis/Memcached, needs a server daemon |
| **CSS/JS minify** | BB minifies its own | covers non-BB files too |
| **CSS/JS combine** | none | fewer requests — but see breakage below |
| **JS defer** | none; 19 scripts, 0 `defer`, 0 `async` | deferral without hand-editing |
| **Critical CSS** | none | requires QUIC.cloud |

### Known breakage

| Symptom | Fix |
|---|---|
| BB editor CSS breaks | Add `fl_builder` to **Page Optimization → Tuning → URI Excludes** — before enabling anything else |
| BB editor will not load after JS combine | Exclude `jquery.js` and `fl-builder` from JS optimization |
| Sliders break on mobile after defer | Exclude `bxslider.js`, `jquery.js`, `layout.js` |
| Header/footer break after several days | Enable BB "Inline CSS/JS"; purge all after any cache clear |
| 404s on BB cache files | Purge all caches after any BB update |

**Sequencing:** enable page cache and the crawler first. Leave combine off. Enable minify and defer one at
a time, verifying the BB editor and the video gallery after each.

---

## 5. Third-Party Load — Measured

| Script | Source | Load | Blocking | Transfer | Render-block |
|---|---|---|---|---|---|
| UserWay `widget_app_base` | cdn.userway.org | inline-injected | **2,354 ms** | 47 KiB | — |
| UserWay `widget_base.css` | cdn.userway.org | injected | 87 ms | 71 KiB | — |
| **GTM `gtm.js`** | googletagmanager.com | async | **831 ms** | 115 KiB | — |
| **GTM `gtag/js`** | googletagmanager.com | async | **334 ms** | 159 KiB | — |
| ReviewWave `reviews_embed.js` | cdn.reviewwave.com | sync `<head>` | — | 4 KiB | **790 ms** |
| ReviewWave `chat_embed.js` | cdn.reviewwave.com | sync `<head>` | — | 7 KiB | **150 ms** |
| ReviewWave config | rw-embed-data.s3… | sync `<head>` | — | 56 KiB | **1,570 ms** |
| YouTube thumbnails ×35 | i.ytimg.com | eager CSS bg | 0 ms | 459 KiB | — |
| Google Maps embed | google.com/maps | `<iframe loading="lazy">` | 0 ms | 0 on load | **no action** |
| Google Fonts CSS | fonts.googleapis.com | sync | 0 ms | 1 KiB | **790 ms** |
| Font files ×2 | fonts.gstatic.com | — | 0 ms | 55 KiB | — |
| Vimeo thumbnail | i.vimeocdn.com | eager | 0 ms | 15 KiB | — |
| hero video | chiro.inceptionimages.com | CSS bg video | 0 ms | 3,112 KiB | — |

**Third-party main-thread blocking: 3,820 ms in July, ~810-880 ms in August** — a test-machine difference,
not a site change. UserWay 2,443 → 481-495 ms, GTM 1,165 → 297-351 ms, ReviewWave 196 → 33 ms. **The
ordering is identical on both dates**, and it is the ordering that decides what to fix first.

**Iframe census: 39 iframes.** 35 carry `data-src` (deferred). 4 carry a real `src` — the GTM noscript
pixel, two `player.vimeo.com` iframes inside an inert `<script type="text/html" class="pp-video-lightbox-content">`
template, and the Maps embed, which carries `loading="lazy"`:

```html
<iframe src="https://www.google.com/maps/embed?pb=…" width="100%" height="300"
        style="border:0;" allowfullscreen="" loading="lazy"
        referrerpolicy="no-referrer-when-downgrade">
```

`html.parser` sees 37 iframes because it treats `<script>` content as CDATA and cannot see the two inside
the template; a regex sees 39. Classify iframes on the full element — truncating before the deciding
attribute produced a false "Maps loads eagerly" finding in an earlier pass.

**What deferral achieves.** TBT counts main-thread blocking between FCP and TTI. Deferring moves work out
of that window; it does not delete it. UserWay is the clean win — 2,443 ms shifted, and nothing above the
fold depends on it. GTM is different: its cost is container size, so trimming the container is an actual
reduction. The ReviewWave scripts are cheap to execute (196 ms) but expensive to *wait for* (2,510 ms of
render-blocking across all three), so `defer` helps FCP far more than TBT.

---

## 6. Target Cache Hierarchy

| Layer | Current | Target |
|---|---|---|
| **CDN** | none — both hosts on AWS EC2, no CDN headers | Cloudflare free or QUIC.cloud. Low priority: warm TTFB is already 52–113 ms |
| **Page cache** | active at server level, **cold on 42–44 of 44 pages across two sweeps** | Same cache, pre-warmed. 7-day public TTL, 24 h front page |
| **HTML `Cache-Control`** | **absent on 44/44** | `no-cache` — §2 |
| **HTML compression** | **Brotli, working** — 81% saved | no change |
| **Static compression** | **Brotli, working** | no change |
| **Static browser cache** | `max-age=2592000` (30 days), working | Keep 30 days. Extend to 1 year **only if** `?ver=` hash-busting is verified end to end — some CDNs strip query strings, and BB relies on them |
| **Static ETag** | **absent** | add |
| **Object cache** | none | Redis via LSCache, if a daemon is available |
| **YouTube thumbnails** | 2 h TTL, 35 eager requests | eliminated by facade |

---

## 7. Where the Sequence Lives

The consolidated implementation sequence is **§8 of `audit/01-page-speed-performance-audit.md`**.

Caching-specific items in it: **step 13** (pre-warm via a cron'd `curl` loop), **step 14**
(`Cache-Control: no-cache` on HTML), **step 20** (static ETag), **step 23** (CDN, after the `.jpg.webp`
rename in step 22).
