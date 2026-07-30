# Page Speed Performance Audit: highcountrypainrelief.com

**Date:** 2026-07-30 (supersedes 2026-07-28) | **Platform:** WordPress 7.0.2 + Beaver Builder 2.10.3 + Beaver Themer 1.5.3.2 + BB Theme 1.7.19.2
**Server:** LiteSpeed on AWS EC2 (44.223.213.21). No CDN. Server-level page cache active but cold on most pages. Static assets: Brotli + 30-day `max-age`. HTML: Brotli, no `Cache-Control`.

**Evidence:** `audit/data/lighthouse-mobile-2026-07-30.md`, `audit/data/header-sweep-2026-07-30.tsv`

---

## 1. Executive Summary

The site scores **21/100 on mobile Lighthouse** (2026-07-30 run; a 2026-07-28 run of the same unchanged site scored 27). The problem is **not** the server, and it is **not** compression or caching, both of which were misdiagnosed in the superseded version of this audit. It is one element and one main thread.

**Largest Contentful Paint is 18.9 s, and 83% of that — 15,760 ms — is Load Delay on a single hero background video.** Time to First Byte is 700 ms and accounts for 4%. The browser cannot begin loading the LCP element until the render-blocking chain clears, and when it finally does, the element is a `<video>` whose `poster` attribute is a 1×1 transparent GIF, so there is nothing to paint early.

**Main-thread work totals 36.9 s**, of which 16.3 s is script evaluation. Total Blocking Time is 14,710 ms against a 200 ms threshold.

**The three fixes that matter:**

1. **Give the hero video a real poster and explicit dimensions.** The `poster` is currently `data:image/gif;base64,R0lGODlhAQABA…` — a 1×1 pixel. A real poster frame makes the LCP element paintable as soon as it is discovered instead of waiting on 15.3 MB of MP4, and explicit `width`/`height` eliminates **100% of the CLS score** (all 0.184 comes from this one element).
2. **Cut main-thread JS.** `2-layout.js` costs 10,883 ms CPU, UserWay 5,363 ms, GTM 1,448 ms.
3. **Defer the third parties.** UserWay blocks 2,443 ms, **Google Tag Manager blocks 1,165 ms** — GTM was previously dismissed as "already async, OK" and is in fact the second-largest third-party blocker at 275 KiB.

**On measurement uncertainty:** two Lighthouse runs of the identical, unmodified site produced a 6-point score spread, a 3.0 s LCP spread, a 3,810 ms TBT spread, and a 3.2× spread in reported payload. Every figure in this document is a single-run measurement unless stated otherwise. Treat differences smaller than those spreads as noise, and re-measure with at least 3 runs before declaring any fix successful.

---

## 2. Metrics

| Metric | 2026-07-30 | 2026-07-28 | Threshold | Status |
|--------|-----------|-----------|-----------|--------|
| Performance Score | **21** | 27 | 90+ | FAIL |
| LCP | **18.9 s** | 15.9 s | <2.5 s | 7.6× over |
| TBT | **14,710 ms** | 18,520 ms | <200 ms | 74× over |
| CLS | **0.184** | 0.184 | <0.1 | FAIL |
| FCP | **3.0 s** | 3.0 s | <1.8 s | 1.7× over |
| Speed Index | **14.1 s** | 17.2 s | <3.4 s | 4.1× over |
| TTFB (Lighthouse) | **700 ms** | 2,550 ms | <800 ms | **PASS** |
| Network payload | **5,123 KiB** | 16,558 KiB | — | 62% is one video |
| DOM elements | **3,197** | 3,178 | <1,500 | 2.1× over |

TTFB now passes. The superseded audit built its top-priority finding on a 2,540 ms TTFB; the independent header sweep shows why that number was real but misleading — see M2.

### LCP breakdown

**Element:** `div.fl-row > div.fl-row-content-wrap > div.fl-bg-video > video`

| Phase | % | Timing |
|---|---|---|
| TTFB | 4% | 700 ms |
| **Load Delay** | **83%** | **15,760 ms** |
| Load Time | 1% | 240 ms |
| Render Delay | 12% | 2,190 ms |

Load Delay is the gap between navigation start and the browser beginning to fetch the LCP resource. At 83% it is the entire story. The video is applied as a Beaver Builder row background, so the `<video>` element is not in the initial HTML — it is constructed after CSS and JS parse, which is why the browser spends 15.8 s not knowing it exists.

---

## 3. Payload — 5,123 KiB

| Source | KiB | % | Controllable? |
|---|---|---|---|
| **inceptionimages.com** | 3,196 | 62.4% | Partial — CDN is agency-managed; the video can be changed |
| — `hiking.mp4` (transferred) | 3,112 | 60.7% | Yes |
| — footer booking image | 84 | 1.6% | Yes |
| **highcountrypainrelief.com** (1st party) | ~910 | ~17.8% | **Yes — full control** |
| **YouTube thumbnails** (35 × `i.ytimg.com`) | 459 | 9.0% | Yes — facade pattern |
| **Google Tag Manager** | 275 | 5.4% | Yes — audit container |
| **UserWay** | 137 | 2.7% | Yes — defer or replace |
| **AWS S3** (ReviewWave config) | 58 | 1.1% | No — third-party |
| **Google Fonts** | 57 | 1.1% | Yes — reduce families |
| **ReviewWave** | 16 | 0.3% | Partial — can defer |
| **Vimeo** | 15 | 0.3% | Already lazy |

**On the video's size.** `curl` reports `content-length: 15343649` (14.6 MiB) for `hiking.mp4`. Lighthouse recorded **3,112 KiB transferred** — the browser aborts the download once enough is buffered, and where it aborts varies per run. The superseded audit reported the full file size as page weight, which is why it claimed a 16,558 KiB payload and "90% of page weight is one file." Both numbers are real; they measure different things. Transfer size is what costs the user.

**A 5.8 MB WebM already exists.** The page's `<video>` lists `hiking.mp4` first and `hiking.webm` second:

```
https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.mp4   15,343,649 B
https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.webm   5,802,541 B
```

Browsers pick the first supported source. Every modern browser supports WebM. **Reordering these two `<source>` elements cuts 9.5 MB of origin file size with no design change, no new asset, and no re-encode.** This was not identified in the superseded audit.

---

## 4. Findings by Criticality

### CRITICAL

**C1: LCP 18.9 s — hero video has a 1×1 GIF poster and no dimensions**

- **Evidence:** LCP element is `div.fl-bg-video > video`. Its markup:
  ```html
  <video autoplay loop muted playsinline
    poster="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIB…"
    style="background-image: url('https://www.highcountrypainrelief.com/wp-content/up…')">
  ```
  The `poster` is a 1×1 transparent GIF. LCP phases: TTFB 700 ms (4%), **Load Delay 15,760 ms (83%)**, Load Time 240 ms (1%), Render Delay 2,190 ms (12%). The same element is also the sole contributor to CLS 0.184, with Lighthouse's stated root cause "Media element lacking an explicit size."
- **Impact:** Worst metric on the page and the entire CLS score. Because the poster is a 1×1, there is no early paint — the browser has nothing to show until video data arrives.
- **Fix, in order of cost:**
  - **A. Real poster + explicit dimensions** (~30 min). Set `poster` to a genuine frame and add `width`/`height` to the video container. A real poster paints as soon as the element is discovered. `Chronic-Pain-Boone-NC-Hiking.webp` (76,870 B) already exists on the origin and is already referenced as the element's `background-image` — it is a ready-made poster.
  - **B. Reorder `<source>` to WebM-first** (~15 min). 15.3 MB → 5.8 MB of source file, zero design change.
  - **C. Replace the video with a static image** (1-2 hrs + design approval). Removes the LCP problem entirely.
  - **D. Fix the discovery problem** (2-4 hrs). The 15,760 ms Load Delay exists because BB constructs the element after CSS/JS parse. A `<link rel="preload" as="image">` for the poster, emitted in `<head>`, lets the browser fetch it during the blocking window instead of after it.
  - **Recommended:** A + B together. ~45 minutes, no design decisions, addresses LCP and all of CLS.
- **Projected outcome:** CLS 0.184 → ~0 (this element is 100% of the score). LCP improvement is real but not precisely predictable from one run — the poster removes the wait on video bytes, but the 15,760 ms discovery delay persists until D or the render-blocking chain (H1) is also addressed.
- **Verification:** Lighthouse LCP element is the poster image, not the video. CLS ≤ 0.1. `Avoid large layout shifts` no longer lists the video.

**C2: Main-thread work 36.9 s — TBT 14,710 ms**

- **Evidence:**

  | Category | Time | | Source | Total CPU |
  |---|---|---|---|---|
  | Script Evaluation | 16,263 ms | | `cache/2-layout.js` | 10,883 ms |
  | Other | 10,512 ms | | the HTML document | 10,224 ms |
  | Parse HTML & CSS | 5,664 ms | | UserWay | 5,363 ms |
  | Style & Layout | 3,355 ms | | Unattributable | 4,755 ms |
  | Rendering | 501 ms | | `jquery.min.js` | 1,589 ms |
  | Script Parse & Compile | 383 ms | | `swiper.min.js` | 1,497 ms |
  | Garbage Collection | 234 ms | | GTM | 1,448 ms |

  20 long main-thread tasks. 5 non-composited animations.
- **Impact:** TBT is 74× the 200 ms threshold. `2-layout.js` — Beaver Builder's per-page JS bundle — is the single largest first-party cost at 10,883 ms CPU (10,081 ms of it evaluation).
- **Fix:** Defer non-critical JS (H1). Defer UserWay (H2). Audit the GTM container (H3). `2-layout.js` is BB-generated and cannot be removed without reducing module count on the page — its cost scales with the number of BB modules, of which the 35-video gallery is the largest contributor (max child elements: 105, in `div.pp-video-gallery-items.swiper-wrapper`).
- **Effort:** 2-3 hrs for deferral. Reducing `2-layout.js` is a page-composition change, not a config change.
- **Verification:** Lighthouse `Minimize main-thread work` under 20 s. TBT trending down across 3 runs, not 1.

**C3: CLS 0.184 — one element**

- **Evidence:** 3 layout shifts detected. Only one is non-zero:

  | # | Element | Score | Root cause |
  |---|---|---|---|
  | 1 | `div.fl-bg-video > video` | **0.184** | Media element lacking an explicit size |
  | 2 | "New Patient Special Offer" button | 0.000 | Web fonts loaded (2 × woff2) |
  | 3 | `img.rws-chat-img` "agent portrait" (ReviewWave) | 0.000 | Media element lacking an explicit size |
- **Impact:** Fails Core Web Vitals. The entire score is shift #1.
- **Fix:** Explicit `width`/`height` on the hero video container — the same edit as C1 Option A. Shifts #2 and #3 score 0.000 and need no action; `&display=swap` on the fonts URL (M5) is worth doing for FCP reasons, not CLS.
- **Effort:** 15 minutes, combined with C1.
- **Verification:** Lighthouse CLS ≤ 0.1. `Avoid large layout shifts` lists no non-zero shift.

### HIGH

**H1: 11 render-blocking resources — 1,370 ms estimated savings**

- **Evidence:** Lighthouse "Eliminate render-blocking resources" lists **11** resources:

  | Group | Count | Transfer | Est. savings |
  |---|---|---|---|
  | highcountrypainrelief.com | 7 | 104.3 KiB | 1,950 ms |
  | `rw-embed-data.s3.amazonaws.com` | 1 | 55.7 KiB | 1,570 ms |
  | `cdn.reviewwave.com` | 2 | 11.5 KiB | 940 ms |
  | `fonts.googleapis.com` | 1 | 1.2 KiB | 790 ms |

  First-party detail: `jquery.min.js` 450 ms, `2-layout.css` 450 ms, `bootstrap.min.css` 300 ms, `layout-bundle.css` 300 ms, `all.min.css` 150 ms, `skin-*.css` 150 ms, `jquery.fancybox.min.css` 150 ms.

  **Correction to the superseded audit:** it claimed "33 render-blocking resources (19 scripts, 13 stylesheets, 1 font CSS)." The page does contain 19 scripts and 13 stylesheets — verified by source inspection, with zero `async` and zero `defer` on any of them — but Lighthouse flags only 11 as render-blocking. The figure 33 is from a *different* audit: "Avoid chaining critical requests — 33 chains found."
- **Impact:** FCP 3.0 s. The single largest blocker is a third-party script (ReviewWave's S3 config, 1,570 ms) that the site does not control except by deferring it.
- **Fix:** Add `defer` to `chat_embed.js`, `reviews_embed.js`, and the S3 config script — none are needed before first paint. Add `&display=swap` to the Google Fonts URL and preconnect to `fonts.gstatic.com`. For first-party CSS, combine the four BB/theme stylesheets. Keep `jquery.min.js` synchronous unless every page interaction is regression-tested — many plugins hard-depend on `$` at parse time.
- **Effort:** 1-2 hrs.
- **Verification:** Lighthouse render-blocking savings ≤ 200 ms.

**H2: UserWay — 2,443 ms main-thread blocking, 137 KiB**

- **Evidence:** `widget_app_base_178….js` (47 KiB) blocks 2,354 ms; `widget_base.css` (71 KiB) blocks 87 ms; `widget.js` (2 KiB) 2 ms. Total CPU across UserWay is 5,363 ms. Injected via inline script with `data-account='Vgm0gbMRdF'`.
- **Impact:** Largest single third party. 64% of all third-party blocking time, for 3.3% of payload. Loads for every visitor regardless of whether accessibility features are used.
- **Fix:** Load on idle rather than during parse:
  ```js
  (window.requestIdleCallback || function (cb) { setTimeout(cb, 2000); })(function () {
    var s = document.createElement('script');
    s.src = 'https://cdn.userway.org/widget.js';
    s.setAttribute('data-account', 'Vgm0gbMRdF');
    document.body.appendChild(s);
  });
  ```
  Note: dynamically-created scripts are async by default — setting `.defer = true` on one is a no-op, which is what the superseded audit's snippet did. The fallback wrapper covers browsers without `requestIdleCallback`.
- **Effort:** 30 minutes.
- **Projected outcome:** ~2,400 ms shifted out of the TBT window. It is shifted, not eliminated — the CPU cost is still paid, just after interactivity.
- **Verification:** Lighthouse third-party audit shows UserWay under 200 ms blocking.

**H3: Google Tag Manager — 1,165 ms blocking, 275 KiB**

- **Evidence:** `gtm.js?id=GTM-WGXQKR5` — 115 KiB, 831 ms blocking. `gtag/js?id=G-CW4KKYCP1V` — 159 KiB, 334 ms blocking. Total CPU 1,448 ms.
- **Impact:** Second-largest third-party blocker and the **largest third-party payload after the image CDN** at 275 KiB — more than UserWay and ReviewWave combined. The superseded audit listed GTM as "4 KB, minimal, already async — OK, 0 savings," which understated its transfer size by roughly 70× and missed its blocking cost entirely.
- **Fix:** GTM's loader being async does not make its *contents* cheap — 275 KiB indicates a container with many tags. Audit the container: remove unused tags, unfired triggers, and duplicate analytics. If both GA4 (`G-CW4KKYCP1V`) and other tags load the gtag library, deduplicate. Consider server-side tagging if the container cannot be slimmed.
- **Effort:** 1-2 hrs (container audit, not a code change).
- **Verification:** GTM transfer under 100 KiB; blocking under 300 ms.

**H4: 758 KiB of offscreen images loaded eagerly**

- **Evidence:** Lighthouse "Defer offscreen images" — 758.5 KiB across four groups:

  | Group | KiB |
  |---|---|
  | YouTube — 35 thumbnails via `i.ytimg.com` | 457.8 |
  | highcountrypainrelief.com — 5 images | 202.4 |
  | inceptionimages.com — 1 image | 83.6 |
  | Vimeo — 1 thumbnail | 14.7 |

  The YouTube thumbnails are CSS `background-image` on `div.pp-video-image-overlay`, so `loading="lazy"` does not apply to them. `i.ytimg.com` serves `cache-control: public, max-age=7200` (2 hours, verified by `curl`). The five first-party images are `<img>` tags that could take `loading="lazy"` directly: Knee-Pain-Red 53.6 KiB, Woman-With-Shoulder-Pain 50.8 KiB, Back-Pain 43.5 KiB, Neuropathy 40.8 KiB, ASMST-Logo 13.7 KiB.

  **Correction:** the superseded audit reported this finding as "758 KB" in its heading and "455 KB" in its evidence without reconciling them. 758 KiB is the total across all offscreen images; YouTube is 457.8 KiB of it.
- **Fix:** Two independent fixes. (a) Add `loading="lazy"` to the 5 first-party `<img>` tags — 202 KiB for ~10 minutes of work. (b) YouTube facade for the 35 thumbnails: `lite-youtube-embed` (~3 KiB JS + ~1 KiB CSS, Apache-2.0, no dependencies) replaces each overlay div with a click-to-load placeholder, so `i.ytimg.com` is never contacted until a user clicks. See `audit/03-page-load-caching-deep-dive.md` §3.
- **Effort:** (a) 10 min. (b) 2-3 hrs for 35 manual replacements, or 1-2 hrs via the WP YouTube Lyte plugin if its shortcode renders inside BB text modules.
- **Verification:** Network tab shows zero `i.ytimg.com` requests on load. Lighthouse "Defer offscreen images" savings under 100 KiB.

### MEDIUM

**M1: 3,197 DOM elements**

- **Evidence:** Lighthouse "Avoid an excessive DOM size": 3,197 elements against a <1,500 recommendation. Max depth 28 (`div.pp-video-play-icon > svg > g > path`). Max child elements 105, in `div.pp-video-gallery-items.swiper-wrapper` — the 35-video gallery. Style & Layout costs 3,355 ms; Parse HTML & CSS 5,664 ms.
- **Impact:** Drives both the parse cost and the size of `2-layout.js` (C2). The video gallery is the densest single structure on the page.
- **Fix:** The facade in H4 removes markup as well as requests. Consolidate duplicated desktop/mobile navigation into one responsive nav. Reduce footer widget areas.
- **Effort:** 3-4 hrs; more if theme-level changes are required.
- **Verification:** DOM under 2,500 as a realistic first target.

**M2: Page cache is active but cold — first visitor to any page pays 0.4-2.7 s**

- **Evidence:** GET sweep of all 44 sitemap URLs (`audit/data/header-sweep-2026-07-30.tsv`):

  ```
  cache state    44/44  MISS on 1st request, HIT on 2nd
  cache-control  44/44  absent on HTML
  TTFB MISS      min 0.406  median 0.845  mean 1.204  p90 2.277  max 2.654 s
  TTFB HIT       min 0.052  mean  0.059                          max 0.073 s
                                                            ratio 20.2x
  ```

  Slowest on MISS: `/hipaa-privacy-policy/` 2.654 s, `/accessibility/` 2.537 s, `/pain-management-center/` 2.460 s, `/terms-service/` 2.408 s, `/knee-pain-lp/` 2.317 s.

  Server-level LiteSpeed caching is active. The LiteSpeed Cache **WordPress plugin** is not installed (`wp-content/plugins/litespeed-cache/*` returns 404). HTML ETags are present and change as cache entries regenerate.

  **Correction:** the superseded audit reported "no page caching, TTFB 2,540 ms on every request." The 2,540 ms figure is real — it sits near the p95 of the MISS distribution — but it is the *cold-cache* path, not every request. Warm requests are 52-73 ms. Lighthouse's own TTFB in the current run is 700 ms and passes.
- **Impact:** Low traffic means most pages are cold when a real visitor arrives, so real users routinely pay the MISS path. With no `Cache-Control` on HTML, no visitor ever caches the document browser-side either.
- **Fix:** Pre-warm and hold. Install the LiteSpeed Cache plugin for its crawler, point it at `page-sitemap.xml`, and raise the public TTL so entries survive between visits. Separately, emit `Cache-Control` on HTML responses. Add `fl_builder` to URI Excludes before enabling any page optimization, or the BB editor breaks.
- **Effort:** 2-3 hrs including BB editor verification.
- **Projected outcome:** MISS rate falls toward zero for sitemap URLs; TTFB converges on the 52-73 ms HIT path.
- **Verification:** Re-run `audit/data/header-sweep.sh`; first-pass `lsc1` column should read `hit` for most URLs rather than `miss` for all 44.

**M3: 197 resources flagged for inefficient cache policy**

- **Evidence:** Lighthouse "Serve static assets with an efficient cache policy": 197 resources. First-party static assets carry `cache-control: public, max-age=2592000` (30 days) plus Brotli — verified on 4 sampled CSS/JS files — so the bulk of the 197 are third-party (YouTube's 2-hour TTL on 35 thumbnails, GTM's ~15-minute TTL, UserWay's 1-hour TTL).
- **Impact:** Mostly not controllable. The controllable part is the 35 YouTube thumbnails, which the H4 facade eliminates outright.
- **Fix:** H4 facade. Optionally raise first-party `max-age` to 1 year, but only if hash-based cache-busting is verified end-to-end — BB uses `?ver=` query strings, and some CDNs strip query strings.
- **Effort:** Covered by H4.

**M4: 127 KiB unused JavaScript**

- **Evidence:** Lighthouse "Reduce unused JavaScript": 127 KiB. Legacy JS served to modern browsers: 7 KiB.
- **Fix:** Largely a consequence of GTM container size (H3) and BB module bundling. Address H3 first and re-measure.
- **Effort:** Covered by H3.

**M5: No `font-display` — 5 font families**

- **Evidence:** `fonts.googleapis.com/css?family=Raleway:700,400,300,800,600|Work%20Sans:700|Inter:600|Audiowide:400|Oxygen:300,700` — no `display` parameter, confirmed in live page source. Lighthouse "Ensure text remains visible during webfont load" fails. Font files are 57 KiB and cached 1 year at `fonts.gstatic.com`. Web font loading is the stated root cause of layout shift #2 (which scores 0.000).
- **Fix:** Append `&display=swap`. Reduce from 5 families to 2. Upgrade the existing `dns-prefetch` for `fonts.googleapis.com` to `<link rel="preconnect" crossorigin>`.
- **Effort:** 15 min for `display=swap` and preconnect; 1 hr to reduce families.
- **Verification:** Fonts URL contains `display=swap`; Lighthouse webfont audit passes.

**M6: No CDN**

- **Evidence:** `highcountrypainrelief.com` → `44.223.213.21`; `chiro.inceptionimages.com` → `18.214.60.67`. Both AWS EC2, both LiteSpeed, no CDN headers (`cf-cache-status`, `x-cache`, `age`, `via`, `x-amz-cf-id`) on any response. These are two distinct hosts, not one origin.
- **Impact:** Geographically distant visitors pay full origin latency. Given TTFB on a warm cache is already 52-73 ms from the test location, this is a lower priority than it appears.
- **Fix:** Cloudflare free tier or QUIC.cloud. Complementary to M2, not a substitute.
- **Effort:** 1-2 hrs.

### LOW

**L1: Static assets have no ETag**

- **Evidence:** 4 sampled static assets (2 CSS, 2 JS) return `cache-control: public, max-age=2592000`, `expires`, `last-modified`, `content-encoding: br` — and no `etag`. Revalidation depends on `If-Modified-Since`, which has 1-second granularity.
- **Fix:** Enable ETag in LiteSpeed config, or as a side effect of installing the LSCache plugin (M2).
- **Verification:** `curl -sI <static-asset-url> | grep -i etag` returns a value.

**L2: One oversized image — 20 KiB**

- **Evidence:** `Best-of-W….webp`, 84.8 KiB transferred, 19.9 KiB of it unnecessary at rendered size.
- **Fix:** Regenerate at display dimensions.

**L3: `.jpg.webp` double extension**

- **Evidence:** `Chronic-Pain-Boone-NC-SoftWave-Video-Overlay.jpg.webp`. Some servers and CDNs key MIME type on the first extension.
- **Fix:** Rename to `.webp`. Verify `content-type: image/webp`.

**L4: Images missing explicit width and height**

- **Evidence:** Lighthouse "Image elements do not have explicit width and height" fails. Distinct from C3 — these contribute 0.000 to CLS in this run but are latent shift sources.
- **Fix:** Add `width`/`height` attributes.

**L5: 5 non-composited animations**

- **Evidence:** Lighthouse "Avoid non-composited animations": 5 animated elements. Animations not on the compositor thread force main-thread work per frame, compounding C2.
- **Fix:** Restrict animation to `transform` and `opacity`.

---

## 5. Third-Party Deferral Strategy

| Script | Source | Current load | Blocking | Transfer | Recommended |
|---|---|---|---|---|---|
| UserWay `widget_app_base` | cdn.userway.org | inline-injected | **2,354 ms** | 47 KiB | `requestIdleCallback` |
| UserWay `widget_base.css` | cdn.userway.org | injected | 87 ms | 71 KiB | loads with widget |
| **GTM `gtm.js`** | googletagmanager.com | async | **831 ms** | 115 KiB | audit container |
| **GTM `gtag/js`** | googletagmanager.com | async | **334 ms** | 159 KiB | deduplicate |
| ReviewWave `reviews_embed.js` | cdn.reviewwave.com | sync `<head>` | 117 ms | 4 KiB | `defer` — below fold |
| ReviewWave `chat_embed.js` | cdn.reviewwave.com | sync `<head>` | 11 ms | 7 KiB | `defer` — non-critical |
| ReviewWave config | rw-embed-data.s3… | sync `<head>` | 14 ms | 56 KiB | `defer` — 1,570 ms render-block |
| YouTube thumbnails | i.ytimg.com | eager CSS bg | 0 ms | 459 KiB | facade (H4) |
| Vimeo thumbnail | i.vimeocdn.com | eager | 0 ms | 15 KiB | already lightbox-deferred |
| Google Fonts | fonts.gstatic.com | sync CSS | 0 ms | 57 KiB | `display=swap` + preconnect |

**Total third-party blocking: 3,820 ms.** UserWay is 64% of it, GTM 30%.

**What deferral does and does not do.** Deferring moves execution out of the FCP→TTI window that TBT measures; it does not reduce CPU time. If a deferred script runs before TTI anyway, TBT is unchanged. Expect roughly 2,400-3,000 ms of measured TBT improvement from UserWay, with the rest depending on GTM container reduction, which is a real reduction rather than a shift.

---

## 6. Performance Budget

| Resource | Current | Budget | Basis |
|---|---|---|---|
| Hero video (transferred) | 3,112 KiB | <600 KiB | WebM-first reorder, or static poster |
| 1st-party total | ~910 KiB | <500 KiB | lazy-load offscreen images |
| YouTube thumbnails | 459 KiB | 0 KiB | facade |
| GTM | 275 KiB | <100 KiB | container audit |
| UserWay | 137 KiB | 137 KiB deferred | keep, defer |
| Google Fonts | 57 KiB | <25 KiB | 5 families → 2 |
| **Total payload** | **5,123 KiB** | **<1,500 KiB** | ~3.4× reduction |
| TBT | 14,710 ms | <5,000 ms | stretch target; see note |
| LCP | 18.9 s | <4.0 s | first milestone, not the 2.5 s CWV pass |
| CLS | 0.184 | <0.1 | achievable with C1/C3 alone |

**On targets.** CLS is the only metric here with a confident target — its cause is a single element with a known fix. LCP and TBT targets are milestones, not predictions: the superseded audit's "<2.5 s LCP" and "TBT <5,000 ms via deferral" were stated as outcomes when its own deferral analysis projected TBT landing at 13,500-15,500 ms. Do not commit to a Core Web Vitals pass on this page without DOM reduction and third-party removal, which are scope beyond configuration.

**Gate:** any change adding >50 KiB to payload requires explicit approval.

---

## 7. Implementation Sequence

Ordered by value per hour. Times are for the work itself; each step needs re-measurement.

| # | Task | Time | Verification |
|---|---|---|---|
| 1 | Add explicit `width`/`height` to hero video container | 15 min | CLS ≤ 0.1 |
| 2 | Replace 1×1 GIF `poster` with the existing `Chronic-Pain-Boone-NC-Hiking.webp` | 30 min | LCP element is the poster |
| 3 | Reorder `<source>`: WebM before MP4 | 15 min | DevTools shows `hiking.webm` requested |
| 4 | Add `loading="lazy"` to the 5 first-party offscreen images | 10 min | 202 KiB deferred |
| 5 | Add `&display=swap` to Google Fonts URL; `dns-prefetch` → `preconnect` | 15 min | webfont audit passes |
| 6 | `defer` ReviewWave scripts (3) | 20 min | render-blocking savings drop ~940 ms |
| 7 | Defer UserWay via `requestIdleCallback` | 30 min | UserWay blocking <200 ms |
| 8 | **Re-measure: 3 Lighthouse runs, take the median** | 30 min | establishes a real baseline |
| 9 | Audit GTM container; remove unused tags | 1-2 hrs | GTM <100 KiB |
| 10 | Install LSCache plugin; `fl_builder` in URI Excludes; enable crawler on sitemap | 2-3 hrs | sweep shows `hit` on first pass |
| 11 | Add `Cache-Control` to HTML responses | 15 min | header present on all 44 URLs |
| 12 | YouTube facade — 35 instances | 2-3 hrs | zero `i.ytimg.com` on load |
| 13 | Reduce Google Fonts 5 families → 2 | 1 hr | 2 families in URL |
| 14 | Fix `.jpg.webp` filename; resize `Best-of-W….webp` | 20 min | correct MIME; 20 KiB saved |
| 15 | Enable ETag on static assets | 10 min | `etag` present |
| 16 | Add CDN (Cloudflare or QUIC.cloud) | 1-2 hrs | CDN headers present |
| 17 | **Re-measure: 3 runs, median** | 30 min | compare against step 8 |

**Steps 1-7 total ~2 hrs 15 min** and require no design approval, no plugin installation, and no page rebuilds. They address all of CLS and the most tractable part of LCP.

**Steps 1-17 total ~12-16 hrs.** Steps 10 and 12 are the largest. There is no configuration path to a green Lighthouse score on this page — steps 9, 12, and DOM reduction are the ceiling-lifting work, and even then 70+ mobile would require removing third parties entirely.

### Rollback

| Change | Rollback |
|---|---|
| Video poster / dimensions | Revert BB row settings; no data loss |
| `<source>` reorder | Swap back; original MP4 untouched on CDN |
| Script deferral | Remove `defer`; restore inline UserWay snippet from page revision history |
| LSCache plugin | Toggle "Enable Cache" off, or deactivate — server-level cache continues independently |
| YouTube facade | Restore `pp-video` modules from page revision history |
| GTM container | GTM keeps version history; restore any prior container version |

---

## 8. Out of Scope

Identified during the crawl, documented elsewhere, not page-speed issues:

- **On-page SEO and content** — metadata gaps, schema format errors, content depth: `audit/04-seo-content-findings.md`
- **Spelling and grammar** — `audit/02-spelling-grammar-audit.md`
- **Accessibility** — alt text and heading hierarchy: `audit/04-seo-content-findings.md` L1-L2. (The superseded audit misrouted these to audit 02, which contains no accessibility findings.)
- **Security** — missing HTTP security headers, plugin CVEs, `xmlrpc.php` exposure: `audit/04-seo-content-findings.md`. The CVE register there carries unverified severity claims and at least one mismatched citation; treat it as a research starting point, not a finding list.

---

## 9. Sources & Methodology

- **Lighthouse 12.6.0**, Chromium 138.0.0.0, emulated Moto G Power, Slow 4G throttling, single page session, initial page load. Runs captured 2026-07-28 and 2026-07-30 18:13 EDT. Full extract: `audit/data/lighthouse-mobile-2026-07-30.md`.
- **Header sweep** — all 44 URLs from `page-sitemap.xml`, two passes each plus an uncompressed-size pass, via **GET**. Data: `audit/data/header-sweep-2026-07-30.tsv`. Reproducer: `audit/data/header-sweep.sh`.
- **Source inspection** — live HTML fetched 2026-07-30; script, stylesheet, thumbnail, and font counts verified with two independent grep patterns each.
- **Asset sizes** — `content-length` from direct GETs against the CDN.

### Known limitations

1. **Lighthouse figures are single runs.** Two runs of the unmodified site differed by 6 score points, 3.0 s LCP, 3,810 ms TBT, and 3.2× payload. Anything in this document sourced from one run inherits that uncertainty. Re-measure with 3+ runs before judging a fix.
2. **Desktop was not re-measured.** The superseded audit reported 47/100 desktop from a single run. No desktop figure appears here because none was captured on 2026-07-30.
3. **Method correction.** The superseded audit verified server headers with `curl -sI` (HEAD). This LiteSpeed server omits `content-encoding` from HEAD responses, which produced a false "HTML is uncompressed" finding that became a CRITICAL item. All header claims here use GET. See `audit/data/README.md`.
4. **No competitor measurements.** Thresholds cited are Google's published Core Web Vitals values. No competitor sites were tested, and no ranking or conversion outcomes are projected — page speed is a documented but minor ranking signal, and the case for this work is user experience.
