# Page Load, Caching & Third-Party Deep-Dive: highcountrypainrelief.com

**Date:** 2026-07-30 (supersedes 2026-07-28)
**Scope:** caching layers, third-party behaviour, and the YouTube facade. Metric findings and the remediation sequence live in `audit/01-page-speed-performance-audit.md`; this document does not restate them.
**Evidence:** `audit/data/header-sweep-2026-07-30.tsv`, `audit/data/lighthouse-mobile-2026-07-30.md`

> **Method note.** The superseded version of this document verified headers with `curl -sI` (HEAD). This LiteSpeed server omits `content-encoding` from HEAD responses, which produced a false "HTML is uncompressed" finding. Every header claim below is from a **GET**. See `audit/data/README.md`.

---

## 1. Cache Policy by Domain

| Domain | Service | Cache-Control | Verified | Problem? |
|---|---|---|---|---|
| `highcountrypainrelief.com` — **HTML** | WordPress pages | **none** | GET sweep, 44/44 URLs | **YES.** No `Cache-Control` on any HTML response. No visitor caches the document. Server-level LiteSpeed cache is active (`x-litespeed-cache`), Brotli is applied, and `ETag` is present — but browser-side HTML caching is entirely absent. |
| `highcountrypainrelief.com` — **static** | CSS, JS, fonts, images | `public, max-age=2592000` + `content-encoding: br` | 4 assets sampled | No — correctly configured. 30-day cache and Brotli both working. **No `ETag`**, so revalidation falls back to `Last-Modified` (1-second granularity). |
| `chiro.inceptionimages.com` | Practice imagery + hero video | `public, max-age=2592000` | direct GET on `hiking.mp4`, `hiking.webm` | No — 30 days, confirmed. This is a **separate host** (`18.214.60.67`) from the main origin (`44.223.213.21`), not the same server. The superseded audit left this unresolved and described it as the same origin; both were wrong. |
| `i.ytimg.com` | YouTube thumbnails | `public, max-age=7200` | direct GET | **YES**, but not for the cache TTL. 35 thumbnails load eagerly on every page view, 457.8 KiB. A 2-hour TTL means repeat visitors revalidate; the real cost is 35 requests on first visit. Facade eliminates the requests entirely — see §3. |
| `googletagmanager.com` | GTM + gtag | short TTL by design | Lighthouse | **YES**, but for size, not caching. 275 KiB and 1,165 ms of main-thread blocking. Short TTL is intentional and correct; the container is the problem. See audit 01 H3. |
| `cdn.userway.org` | Accessibility widget | `max-age=3600, public` | direct GET | Low. 1-hour browser cache is reasonable for a widget. 137 KiB and 2,443 ms blocking are the issue, not the TTL. |
| `cdn.reviewwave.com` | Reviews + chat | S3 + CloudFront | — | Low. 16 KiB, 196 ms blocking. |
| `rw-embed-data.s3.amazonaws.com` | ReviewWave config JS | **none** — no `Cache-Control` at all | direct GET, 2026-07-30 | **YES, twice over.** `Content-Length: 56,589` (55.3 KiB, matching Lighthouse exactly) and **no `Content-Encoding`** — the same 56,589 bytes are returned whether or not `gzip` is requested. It is the only entry in Lighthouse's text-compression audit (36.6 KiB available) and the single largest render-blocking resource at 1,570 ms. It also carries **no `Cache-Control`**, so browsers do not cache it between visits; `ETag` and `Last-Modified` are present, so revalidation works but costs a round trip every time. None of this is fixable from this site — the S3 object metadata belongs to ReviewWave. The available fix is to `defer` the script so it stops blocking first paint. |
| `fonts.gstatic.com` | Font files | `max-age=31536000` | direct GET | No. 1 year, immutable, versioned URLs. Optimal. |
| `fonts.googleapis.com` | Font CSS | `private, max-age=86400` | direct GET | Minor. `private` is correct — the CSS varies by user agent. The issue is 5 families and no `display=swap`, not the TTL. |
| `i.vimeocdn.com` | Vimeo thumbnail | `max-age=2592000` | direct GET | No. 30 days, 15 KiB, one embed. |

### The actual cache gaps

1. **HTML has no `Cache-Control`.** 44/44 URLs. Fix at the server or via LSCache.
2. **The page cache is cold, not missing.** See §2.
3. **Static assets have no `ETag`.** Working 30-day cache, but revalidation is coarser than it needs to be.
4. **35 YouTube thumbnails on a 2-hour TTL.** Fix by not requesting them — §3.
5. **No CDN.** Both hosts serve directly from AWS EC2. Lower priority than it appears given 52-73 ms warm TTFB.

---

## 2. The Cache Is Working. It Is Cold.

This is the correction that matters most in this document. The superseded version claimed there was no page caching and that every request cost 2,540 ms. Neither holds.

### Measured, all 44 sitemap URLs, two passes each

```
cache state    44/44  MISS on 1st request, HIT on 2nd
content-encoding 44/44  br        raw 5,874,729 B -> 1,097,229 B  (81% saved)
cache-control  44/44  absent on HTML
etag           44/44  present
vary           44/44  Accept-Encoding,User-Agent

TTFB  MISS   min 0.406  median 0.845  mean 1.204  p90 2.277  max 2.654 s
TTFB  HIT    min 0.052  mean  0.059                          max 0.073 s
                                                        ratio 20.2x
```

Every page was cold. Every page warmed on the second request and served in 52-73 ms.

**Where the 2,540 ms came from.** It is a real number from the MISS distribution — near its p95. It was measured, not invented. It was then generalised to "every page load," which the data does not support. Lighthouse's TTFB in the current run is **700 ms, 4% of LCP, and passing**.

**Why it still matters.** A brochure site for a local practice has low per-page traffic. Cache entries expire before the next visitor arrives, so a real first visitor to `/knee-pain-lp/` genuinely pays 2.3 s. The problem is real; the diagnosis and therefore the fix were wrong.

**Fix: pre-warm and hold, not "install a page cache."**

| Action | Why |
|---|---|
| Install LiteSpeed Cache plugin | Not for its cache — server-level caching already works. For its **crawler**, which walks the sitemap and warms every entry. |
| Point the crawler at `page-sitemap.xml` | 44 URLs, all currently cold |
| Raise Default Public TTL to 604800 s (7 days) | Content changes rarely; long TTL plus purge-on-change beats short TTL |
| Front Page TTL 86400 s (24 h) | Homepage carries promos |
| Add `Cache-Control: public, max-age=3600` to HTML | Currently absent on 44/44 |
| **Add `fl_builder` to Page Optimization → Tuning → URI Excludes first** | Without this the Beaver Builder editor breaks |

**Note on UA-keyed caching.** Responses carry `vary: Accept-Encoding, User-Agent`. A per-User-Agent cache-fragmentation hypothesis was tested — 8 distinct UA strings, first request each — and **refuted**: 7 returned HIT. LiteSpeed buckets user agents into groups rather than keying on the full string. `Vary: User-Agent` is not fragmenting this cache and needs no action.

---

## 3. YouTube Facade

### Current state

- 35 thumbnails as CSS `background-image` on `div.pp-video-image-overlay` — `loading="lazy"` does not apply to CSS backgrounds
- **457.8 KiB** total, 11.4-15.2 KiB each, all eager
- `i.ytimg.com` serves `cache-control: public, max-age=7200`
- The gallery container `div.pp-video-gallery-items.swiper-wrapper` holds **105 child elements** — the densest structure on the page, and a direct contributor to the 3,197-element DOM

The iframes themselves are already lightbox-deferred and cost 0 KiB until click. **This is worth stating plainly because the superseded audit implied otherwise:** it claimed the facade saves "up to 17.5 MB per page view" by avoiding 35 full iframes. That saving does not exist — the iframes were never loading. The real, measured saving is **457.8 KiB and 35 requests**.

### Options

| Option | Size | BB compatibility | Best for |
|---|---|---|---|
| **A. `lite-youtube-embed`** | ~3 KiB JS + ~1 KiB CSS | Works via BB HTML module; zero dependencies; Apache-2.0 | Recommended |
| B. WP YouTube Lyte | plugin overhead | May need `[lyte]` shortcode support in BB text modules | Non-technical editors; local thumbnail caching |
| C. Custom facade | ~2 KiB inline JS | Requires BB module work | Full control |
| D. Embed Plus | heavy | plugin-level | Overkill |

### Recommendation: Option A

35 instances share one JS/CSS load. The component renders its own thumbnail only after click, then swaps itself for the real iframe (`youtube-nocookie.com`, `autoplay=1`). `playlabel` provides an accessible name.

```html
<!-- once, via child theme or BB global settings -->
<link rel="stylesheet" href="lite-yt-embed.css">
<script defer src="lite-yt-embed.js"></script>

<!-- per video, replacing each pp-video-image-overlay -->
<lite-youtube videoid="C7XENcnzvzc" playlabel="Play: Patient Testimonial"></lite-youtube>
```

Enqueue via child theme `functions.php` (`wp_enqueue_script` / `wp_enqueue_style`) or BB global settings. Replace each `pp-video` module with an HTML module, or write one small BB custom module and reuse it across all 35.

If WP YouTube Lyte is preferred, enable "Cache thumbnails locally" so the poster is self-hosted and `i.ytimg.com` is never contacted at all:

```
[lyte id="C7XENcnzvzc" /]
```

### Measured gain

- **457.8 KiB** deferred per page load, **35 requests** eliminated
- Lighthouse "Defer offscreen images" drops from 758.5 KiB toward ~300 KiB (the remainder is first-party images — see audit 01 H4(a))
- DOM element reduction from replacing 35 overlay structures
- No cache-expiry exposure, since nothing is requested until a click

---

## 4. Beaver Builder and Plugin Caching

### What Beaver Builder already does

- **Location:** `/wp-content/uploads/bb-plugin/cache/`
- Generates per-page CSS and JS on save, named by post ID — `2-layout.css` and `2-layout.js` for the homepage (post ID 2)
- Selective enqueue: only modules present on the page load their assets
- Cache-busting via content-hash query strings (`?ver=bcd079b…`)
- Regenerates on page save, plugin update, site URL change, or `WP_DEBUG = true`

**What it costs.** `2-layout.js` is the most expensive script on the page: **10,883 ms CPU, 10,081 ms of it evaluation.** `2-layout.css` is 20.3 KiB and render-blocking at 450 ms. This is not a misconfiguration — it is the price of the page's module count, and it shrinks only when the page carries fewer modules.

**What it does not do:** page caching, HTML caching, browser cache headers, object caching, minification beyond its own files, or CDN integration.

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
| BB editor CSS breaks | Add `fl_builder` to **Page Optimization → Tuning → URI Excludes** — do this before enabling anything else |
| BB editor will not load after JS combine | Exclude `jquery.js` and `fl-builder` from JS optimization |
| Sliders break on mobile after defer | Exclude `bxslider.js`, `jquery.js`, `layout.js` |
| Header/footer break after several days | Enable BB "Inline CSS/JS"; purge all after any cache clear |
| 404s on BB cache files | Purge all caches after any BB update |

**Sequencing:** enable page cache and the crawler first. Leave combine off. Enable minify and defer one at a time, verifying the BB editor and the video gallery after each.

---

## 5. Third-Party Load — Measured

| Script | Source | Load | Blocking | Transfer | Render-block |
|---|---|---|---|---|---|
| UserWay `widget_app_base` | cdn.userway.org | inline-injected | **2,354 ms** | 47 KiB | — |
| UserWay `widget_base.css` | cdn.userway.org | injected | 87 ms | 71 KiB | — |
| **GTM `gtm.js`** | googletagmanager.com | async | **831 ms** | 115 KiB | — |
| **GTM `gtag/js`** | googletagmanager.com | async | **334 ms** | 159 KiB | — |
| ReviewWave `reviews_embed.js` | cdn.reviewwave.com | sync `<head>` | 117 ms | 4 KiB | **790 ms** |
| ReviewWave `chat_embed.js` | cdn.reviewwave.com | sync `<head>` | 11 ms | 7 KiB | **150 ms** |
| ReviewWave config | rw-embed-data.s3… | sync `<head>` | 14 ms | 56 KiB | **1,570 ms** |
| YouTube thumbnails ×35 | i.ytimg.com | eager CSS bg | 0 ms | 459 KiB | — |
| Google Fonts CSS | fonts.googleapis.com | sync | 0 ms | 1 KiB | **790 ms** |
| Font files ×2 | fonts.gstatic.com | — | 0 ms | 55 KiB | — |
| Vimeo thumbnail | i.vimeocdn.com | eager | 0 ms | 15 KiB | — |
| hero video | chiro.inceptionimages.com | CSS bg video | 0 ms | 3,112 KiB | — |

**Third-party main-thread blocking: 3,820 ms.** UserWay 2,443 ms (64%), GTM 1,165 ms (30%), ReviewWave 196 ms (5%), S3 14 ms.

**Corrections to the superseded table.** It listed GTM as "4 KB, minimal, already async — OK, 0 savings." GTM is 275 KiB and blocks 1,165 ms — the second-largest third-party cost on the page. It also listed per-row savings summing to roughly 9,400 ms beneath a stated total of 3,000-5,000 ms; the rows and the total contradicted each other. And it attributed 13,467 ms to "BB layout.js × 2" as a third-party item — `2-layout.js` is first-party BB output, not a third party, and is now reported in audit 01 C2.

**What deferral achieves.** TBT counts main-thread blocking between FCP and TTI. Deferring moves work out of that window; it does not delete it. UserWay is the clean win — 2,443 ms shifted, and nothing above the fold depends on it. GTM is different: its cost is container size, so trimming the container is an actual reduction rather than a deferral. The ReviewWave scripts are cheap to execute (196 ms) but expensive to *wait for* (2,510 ms of render-blocking across all three), so `defer` helps FCP far more than TBT there.

---

## 6. Target Cache Hierarchy

| Layer | Current | Target |
|---|---|---|
| **CDN** | none — both hosts on AWS EC2, no CDN headers | Cloudflare free or QUIC.cloud. Low priority: warm TTFB is already 52-73 ms |
| **Page cache** | active at server level, **cold on 44/44 pages** | Same cache, pre-warmed by the LSCache crawler. 7-day public TTL, 24 h front page |
| **HTML `Cache-Control`** | **absent on 44/44** | `public, max-age=3600` |
| **HTML compression** | **Brotli, working** — 81% saved | no change |
| **Static compression** | **Brotli, working** | no change |
| **Static browser cache** | `max-age=2592000` (30 days), working | Keep 30 days. Extend to 1 year **only if** `?ver=` hash-busting is verified end-to-end — some CDNs strip query strings, and BB relies on them |
| **Static ETag** | **absent** | add |
| **Object cache** | none | Redis via LSCache, if a daemon is available |
| **YouTube thumbnails** | 2 h TTL, 35 eager requests | eliminated by facade |

The superseded document gave three different positions on static asset TTL across two files — verify `max-age=2592000`, verify `max-age=31536000`, and "only extend if hash-busting is verified." The last one is correct and is the position above.

---

## 7. Where the Sequence Lives

The consolidated, ordered implementation sequence is **§7 of `audit/01-page-speed-performance-audit.md`**. It is not repeated here.

The superseded documents each carried their own sequence, and they disagreed — 17 steps totalling "~10-14 hours" in one, 15 steps totalling "~6-8 hours" in the other, for substantially the same work, with per-step times that summed to neither figure. One sequence, in one place, is the fix.

Caching-specific items in that sequence: **step 10** (LSCache plugin, `fl_builder` exclude, crawler), **step 11** (`Cache-Control` on HTML), **step 15** (static ETag), **step 16** (CDN).
