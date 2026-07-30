# Page Speed Performance Audit: highcountrypainrelief.com

**Date:** 2026-07-28 | **Platform:** WordPress 7.0.2 + Beaver Builder 2.10.3 + Beaver Themer 1.5.3.2 + BB Theme 1.7.19.2
**Server:** LiteSpeed on AWS EC2 (44.223.213.21). No CDN. Static asset caching: 30-day max-age (correct). HTML page caching: absent (every request hits PHP). No cache plugin installed. No HTML compression.

**POCs:** James David Enman | Amy Denman

---

## 1. Executive Summary

The site scores **27/100 on mobile Lighthouse and 47/100 on desktop** — both in the "poor" range (0-49). This is driven by four root causes, all server and configuration issues: no page caching, no text compression, 33 render-blocking resources (19 scripts, 13 stylesheets, 1 font CSS), and a 14.9 MB background video that blocks Largest Contentful Paint.

The 20-point mobile-desktop delta confirms these are **architectural problems, not device-specific.** Even on unthrottled desktop CPU the site cannot break 50/100. The site's on-page content, keyword targeting, and schema markup are functional — this audit focuses exclusively on load performance.

**Key metrics:**

| Metric | Mobile | Desktop | Threshold | Status |
|--------|--------|---------|-----------|--------|
| Performance Score | 27/100 | 47/100 | 90+ | FAIL |
| LCP | 15.9s | — | <2.5s | 6.4x over |
| TBT | 18,520ms | — | <200ms | 92x over |
| CLS | 0.184 | 0.184 | <0.1 | FAIL |
| FCP | 3.0s | — | <1.8s | 1.7x over |
| TTFB | 2,540ms | 2,540ms | <800ms | 3x over |
| SI | 17.2s | — | <3.4s | 5x over |
| Page weight | 16,558 KB | — | — | 14.9 MB of it is one video |

**Three critical issues:**

1. **No page caching + no text compression** — TTFB 2,540ms. Every page load hits uncached PHP. 216 KB of HTML served uncompressed. Zero `Cache-Control` on HTML responses.
2. **14.9 MB background video blocks LCP** — `hiking.mp4` from inceptionimages.com. 80% of LCP (12,730ms) is load delay — the browser cannot discover the video element until all render-blocking resources finish.
3. **33 render-blocking resources + 3,242ms UserWay widget** — Zero scripts use `async` or `defer`. All 19 scripts and 13 stylesheets load synchronously. UserWay accessibility widget alone blocks the main thread for 3,242ms.

**Projected outcome after remediation:**

| Phase | Mobile Score | Desktop Score | Time |
|-------|-------------|---------------|------|
| Config-only (cache + compress + defer) | 40-50 | 55-65 | 3-4 hrs |
| + Video replacement + CDN | 50-60 | 65-75 | +4 hrs |
| + Third-party elimination/facade | 60-68 | 75-85 | +2 hrs |

These projections are estimates based on comparable Beaver Builder site optimizations. 70+ mobile typically requires DOM reduction and theme-level changes beyond config scope. Page speed is a minor ranking signal per Google's documented position; the primary benefit is user experience, conversion rate, and Core Web Vitals compliance.

---

## 2. PageSpeed Cross-Report Synthesis

### Score Drivers

| Metric | Mobile (27/100) | Desktop (47/100) | Delta Cause |
|--------|-----------------|-------------------|-------------|
| FCP | 3.0s | Lower (unthrottled CPU) | 4x CPU throttling |
| LCP | 15.9s | Lower (unthrottled) | 14.9 MB video + throttled network |
| TBT | 18,520ms | Significantly lower | JS execution taxed 4x harder |
| CLS | 0.184 | 0.184 | Same DOM, same layout shifts |
| SI | 17.2s | Lower (unthrottled) | Network throttling (Slow 4G) |
| TTFB | 2,540ms | 2,540ms | Same — uncached PHP on both |

### Common Root Causes (Device-Independent)

All six root causes affect both mobile and desktop scores equally:

1. **No page caching** — TTFB 2,540ms on every request regardless of device
2. **No text compression** — 216 KB HTML served raw (Lighthouse: 39 KB savings identified)
3. **33 render-blocking resources** — 19 synchronous scripts, 13 synchronous CSS, 1 synchronous font CSS (Lighthouse: 1,470ms estimated savings)
4. **14.9 MB background video** — 80% of LCP is load delay on `hiking.mp4`
5. **Third-party main-thread blocking** — UserWay 3,242ms + ReviewWave 523ms + GTM overhead (Lighthouse: 3,400ms estimated savings)
6. **3,178 DOM elements** — excessive layout/recalc cost, 3 layout shifts contributing to CLS 0.184

### Common Opportunities (Lighthouse Audits — Both Scores)

| Audit | Mobile Savings | Desktop Savings | Shared? |
|-------|---------------|-----------------|---------|
| Eliminate render-blocking resources | 1,470ms | Proportional | Same chain |
| Enable text compression | 39 KB | Same | Same resources |
| Reduce unused CSS | 50 KB | Same | Same stylesheets |
| Reduce unused JS | 48 KB | Same | Same scripts |
| Reduce JS execution time | 24.2s | Lower (no throttle) | Same scripts |
| Defer offscreen images | 758 KB | Same | Same 35+ YouTube thumbnails |
| Reduce third-party impact | 3,400ms | Lower (no throttle) | Same third-parties |
| Serve static assets with efficient cache | 128 resources | Same | Same assets |
| Avoid enormous network payloads | 16,558 KB | Same | Same page weight |
| Minify JS | 2 KB | Same | Same files |
| Properly size images | 20 KB | Same | Same images |
| Avoid legacy JS | 10 KB | Same | Same bundles |

**All 12 opportunities appear in both reports because they are server/config/resource problems, not device-specific conditions.**

### Unified Critical Path

```
1. LiteSpeed Cache plugin (page cache + CSS/JS minify/combine + Gzip)
   → Fixes root causes 1, 2, 3 simultaneously
   → Effort: 2-3 hrs
   → Projected mobile: 27→40-45 | Projected desktop: 47→58-63

2. Background video → static WebP poster
   → Fixes root cause 4 (LCP) + partial CLS fix
   → Effort: 2-4 hrs (BB row background settings + design approval)
   → Projected mobile: 40-45→48-53 | Projected desktop: 58-63→65-70

3. Defer third-party scripts (UserWay, ReviewWave, YouTube thumbnails)
   → Fixes root cause 5
   → Effort: 1-2 hrs
   → Projected mobile: 48-53→52-57 | Projected desktop: 65-70→70-74

4. CDN + font optimization + remaining hygiene
   → Fixes root cause 6 (partial — full DOM reduction is theme-level work)
   → Effort: 2 hrs
   → Projected mobile: 52-57→58-65 | Projected desktop: 70-74→75-82
```

---

## 3. Resource Waterfall — Who's Responsible?

### Page Weight Breakdown

| Category | Size | % of Total | Controllable? |
|----------|------|------------|---------------|
| **inceptionimages.com** (images + video) | 14,964 KB | 90.4% | Partial — CDN is agency-managed. Video can be replaced. |
| **highcountrypainrelief.com** (HTML + CSS + JS + images) | ~400 KB | 2.4% | **Yes — full control** |
| **YouTube thumbnails** (i.ytimg.com, 35 images) | ~455 KB | 2.7% | Yes — facade pattern |
| **UserWay** (cdn.userway.org) | 91 KB | 0.5% | Partial — can defer or replace |
| **ReviewWave** (cdn.reviewwave.com + S3) | 75 KB | 0.5% | Partial — can defer |
| **Google Fonts** (fonts.gstatic.com) | 57 KB | 0.3% | Yes — reduce families, add font-display |
| **Vimeo** (i.vimeocdn.com, 1 thumbnail) | 15 KB | 0.1% | Yes — already lazy (lightbox) |
| **GTM** (googletagmanager.com) | 4 KB | <0.1% | Yes — already async |
| **YouTube iframes** (not loaded on page load) | 0 KB | — | N/A — already lightbox-deferred |

**One file is 90% of the problem:** `hiking.mp4` at 14,880 KB from `chiro.inceptionimages.com`. Removing or replacing this single file eliminates 90% of page weight and the LCP bottleneck.

### Critical Request Chain (Simplified)

```
/ (HTML, 216 KB, uncompressed, TTFB 2,540ms)
├── jquery.min.js (sync, 30 KB) → blocks HTML parser
├── 12 CSS files (sync, ~130 KB total) → blocks rendering
│   ├── fonts.googleapis.com CSS (sync, 1.2 KB)
│   │   └── fonts.gstatic.com woff2 × 5 (no font-display)
│   └── bootstrap.min.css (sync, 18 KB)
├── ReviewWave × 3 scripts (sync) → blocks parser
├── UserWay widget.js (injected sync) → blocks main thread 3,242ms
├── BB layout.js × 2 (sync, discovered late) → 13.5s execution
├── hiking.mp4 (CSS background, discovered AFTER all CSS parses) → LCP element
└── 35 × i.ytimg.com thumbnails (CSS backgrounds, discovered late) → 455 KB
```

---

## 4. Findings by Criticality

### CRITICAL — Blocking First Paint

**C1: No HTML page caching — TTFB 2,540ms**

- **Evidence:** Static assets (CSS, JS, images, fonts) are correctly cached with `max-age=2592000` (30 days). However, HTML responses carry **zero caching headers** — every page load executes WordPress + Beaver Builder + Yoast from scratch. Server is LiteSpeed on AWS EC2 (`44.223.213.21`). No page cache plugin installed. No `x-litespeed-cache` header present. TTFB measured at 2.426-3.811s (varies by 1.4s between runs — uncached PHP execution variance). No CDN layer — both origin domains resolve directly to AWS EC2 IPs.
- **Impact:** Every page load runs the full WordPress stack. TTFB is 3x the 800ms threshold. All downstream metrics (FCP, LCP, TBT) are gated by this. Note: static assets are NOT the problem — they already have 30-day browser caching.
- **Fix:** Install and configure LiteSpeed Cache plugin (free, native to LiteSpeed server). This adds server-level HTML page caching that bypasses PHP on cache hit. Enable page cache: 24-hour default TTL, front page 1-hour TTL. Enable ESI for dynamic elements. Add `fl_builder` to URI Excludes to prevent editor breakage. Enable crawler to pre-warm cache. Additionally: add Cloudflare free tier or QUIC.cloud for a CDN layer.
- **Effort:** 2-3 hours (install, configure, test all page types, BB editor verification).
- **Projected outcome:** TTFB 2,540ms → 300-500ms on cache hit. LCP improvement ~2,000ms from TTFB reduction alone.
- **Verification:** `curl -sI https://www.highcountrypainrelief.com/ | grep -i x-litespeed-cache` returns `hit` on second request. TTFB via `curl -w '%{time_starttransfer}'` under 500ms.

**C2: HTML served uncompressed — 216 KB raw (static assets already Brotli-compressed)**

- **Evidence:** Static assets (CSS, JS, fonts) are correctly served with `content-encoding: br` (Brotli). **This is working.** However, the HTML document (216,845 bytes) has **no `Content-Encoding`** regardless of `Accept-Encoding` request header. Lighthouse estimate: 39 KB savings from text compression — the largest component of this is the ReviewWave S3 script (`rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js`, 55.3 KB, third-party — not controllable). The HTML itself would compress to ~50-70 KB.
- **Impact:** 216 KB HTML transferred vs. ~50-70 KB compressed. On Slow 4G (1.6 Mbps), the raw HTML alone takes ~1.1s to download before rendering can begin. Note: this is a smaller fix than initially estimated because static assets are already compressed.
- **Fix:** Enable Gzip or Brotli for HTML responses via LiteSpeed config or `.htaccess`. LiteSpeed Cache plugin (C1) handles this automatically.
- **Effort:** 5 minutes (LiteSpeed config). Or: resolved automatically by C1 (LSCache plugin).
- **Projected outcome:** HTML transfer size reduced by 65-70% when not cached. Combined with page cache (C1): HTML served from cache is pre-compressed and served in <100ms. Note: the 39 KB Lighthouse estimate includes third-party assets the site cannot control.
- **Verification:** `curl -sI -H 'Accept-Encoding: br' https://www.highcountrypainrelief.com/ | grep -i content-encoding` returns `br`.

**C3: 14.9 MB background video blocks LCP — 15,940ms**

- **Evidence:** Lighthouse LCP element: `div.fl-bg-video > video` loading `hiking.mp4` (14,880 KB from chiro.inceptionimages.com). LCP breakdown: TTFB 16% (2,550ms) + Load Delay 80% (12,730ms) + Load Time 1% (140ms) + Render Delay 3% (520ms). 80% is load delay — the browser spends 12.7 seconds discovering this element because all render-blocking CSS/JS must complete first. The video is loaded as a Beaver Builder row background (`data-video-url`) — BB generates an inline `<video>` element that the browser cannot discover until CSS parses.
- **Impact:** Single largest LCP contributor. 14.9 MB also drives the "enormous network payload" audit (16,558 KB total). 90% of page weight is this one file.
- **Fix:** Option A (config-only, loses video effect): Replace row background video with static WebP poster via BB row settings. Option B (retains video effect, custom dev): Static poster with click-to-play video overlay. Option C (retains auto-play, custom dev): Self-host compressed video (<2 MB, 720p, `preload="none"`) applied via BB filter hook. **Recommended:** Option A for immediate impact; Option B as follow-up.
- **Effort:** Option A: 1-2 hours (BB row settings + image selection). Option B: 4-6 hours (custom JS + design approval).
- **Projected outcome:** LCP 15,940ms → <3,000ms. Page weight 16,558 KB → <2,000 KB. CLS improvement (video was #1 layout shift at 0.184).
- **Verification:** Lighthouse LCP element no longer shows video element. LCP under 3,000ms. Page weight under 2 MB.

### HIGH — Render-Blocking & Main-Thread

**H1: 33 render-blocking resources — 1,470ms estimated savings**

- **Evidence:** Lighthouse "Eliminate render-blocking resources" audit. 19 external scripts, 13 external stylesheets, 1 Google Fonts CSS — all loaded synchronously. Zero scripts have `async` or `defer`. Largest contributors: Amazon S3 script 1,480ms, jQuery 450ms, BB layout-bundle.css 300ms, BB page-layout.css 450ms, ReviewWave reviews_embed.js 830ms, Google Fonts CSS 810ms.
- **Impact:** FCP 3.0s. Browser cannot paint until all 33 resources in the critical path download and parse. 1,470ms of this is avoidable by deferring or inlining.
- **Fix:** LiteSpeed Cache plugin: enable CSS minify + combine (reduce 13 CSS → 1-2 files). Enable JS minify (combine OFF initially — BB editor breaks with JS combine). Enable JS defer for non-critical scripts. Exclude from defer: `jquery.js`, `layout.js`, `bxslider.js` (BB slider dependency). Exclude `fl_builder` from URI optimization entirely. Inline critical CSS via LSCache's QUIC.cloud integration (free tier).
- **Effort:** 1-2 hours (with LSCache plugin installed from C1).
- **Projected outcome:** FCP 3.0s → ~1.5s. Render-blocking audit clears.
- **Verification:** Lighthouse "Eliminate render-blocking resources" shows ≤200ms estimated savings.

**H2: UserWay widget — 3,242ms main-thread blocking**

- **Evidence:** Lighthouse "Reduce third-party impact." UserWay total: 91 KB, 3,242ms main-thread blocking. `widget_app_base_178...js` (47 KB) = 3,208ms alone. `widget_base.css` (27 KB) = 32ms. UserWay is injected via inline script in the body — it loads synchronously as a dynamically created `<script>` element with `data-account='Vgm0gbMRdF'`.
- **Impact:** UserWay accounts for 17% of TBT (18,520ms) despite being 0.5% of page weight. The widget loads regardless of whether a visitor needs accessibility features. For the 95%+ of visitors who do not interact with it, this is wasted main-thread time.
- **Fix:** Load UserWay via `requestIdleCallback` or with a user-initiated trigger ("Accessibility" button). Replace inline injection script with:
  ```js
  requestIdleCallback(function() {
    var s = document.createElement('script');
    s.src = 'https://cdn.userway.org/widget.js';
    s.setAttribute('data-account', 'Vgm0gbMRdF');
    s.defer = true;
    document.body.appendChild(s);
  });
  ```
- **Effort:** 30 minutes (edit inline script in BB global footer or child theme).
- **Projected outcome:** TBT reduction ~3,000ms (UserWay shifts to idle periods). Lighthouse "Reduce third-party impact" shows UserWay under 200ms.
- **Verification:** Chrome DevTools Performance tab: UserWay scripts load after First Input Delay window. Lighthouse third-party audit passes.

**H3: CLS 0.184 — video + fonts + un-sized elements**

- **Evidence:** Lighthouse "Avoid large layout shifts." 3 layout shifts detected:
  1. `div.fl-bg-video > video` — 0.184 (the background video, missing explicit dimensions)
  2. "New Patient Special Offer" button — 0.000 (minor, but late-appearing)
  3. Web fonts loading (woff2 × 3 from fonts.gstatic.com) — 0.000 each (late text reflow)
  Additional "Image elements do not have explicit width and height" diagnostic flags multiple images. "Media element lacking an explicit size" flags the hero video.
- **Impact:** CLS 0.184 exceeds the 0.1 Core Web Vitals threshold. The video element is the primary cause.
- **Fix:** Add explicit `width` and `height` dimensions to the hero video container (or its static poster replacement from C3). Add `font-display: swap` to Google Fonts URL (`&display=swap`). Add explicit `width`/`height` attributes to images flagged in the audit.
- **Effort:** 1 hour.
- **Projected outcome:** CLS 0.184 → ≤0.1 (passes Core Web Vitals). Remaining shifts from ReviewWave/chat widget injection may persist — verify after fix.
- **Verification:** Lighthouse CLS audit shows 0 (or ≤0.1). Chrome DevTools Performance tab: zero "Layout Shift" markers above 0.1.

### MEDIUM — Payload & Resource Efficiency

**M1: 3,178 DOM elements — excessive layout cost**

- **Evidence:** Lighthouse "Avoid an excessive DOM size" diagnostic. 3,178 elements vs. recommended <1,500. Desktop and mobile navigation trees both present in the DOM. 35 YouTube thumbnail containers. Duplicate navigation in footer.
- **Impact:** Style recalculation: 3,420ms. Layout: 6,462ms. Parse HTML & CSS: 6,462ms. Each DOM mutation triggers more recalculation work. Particular issue on mobile where CPU is throttled 4x.
- **Fix:** Consolidate desktop + mobile nav into a single responsive navigation (BB theme setting). Reduce footer widget areas. Lazy-load YouTube thumbnail containers via facade (see M2). Replace redundant DOM sections with CSS visibility toggles instead of duplicate markup.
- **Effort:** 3-4 hours (nav consolidation + footer reduction + facade). More if theme-level changes are needed.
- **Projected outcome:** DOM <2,000 elements. Style recalculation reduced by ~30%.
- **Verification:** Lighthouse DOM element count under 2,000.

**M2: 35+ YouTube thumbnails loaded eagerly — 758 KB deferred**

- **Evidence:** Lighthouse "Defer offscreen images" audit: 758 KB estimated savings. 35 `<div class="pp-video-image-overlay">` elements with inline `background-image: url(i.ytimg.com/.../hqdefault.jpg)`. These are CSS backgrounds, so `loading="lazy"` does not apply. YouTube CDN thumbnails have `max-age=7200` (2 hours, verified via `curl -sI`). After expiry, browsers revalidate with conditional requests (304 Not Modified), but each of 35 revalidations costs RTT. On first visit or cache miss: 35 × ~13 KB = 455 KB downloaded.
- **Impact:** 35 HTTP requests for below-fold video thumbnails. 455 KB on cache miss. On Slow 4G: ~2.3s additional download time.
- **Fix:** YouTube facade pattern — replace each `pp-video-image-overlay` div with a click-to-load placeholder. Recommended: `lite-youtube-embed` web component (~4 KB JS + CSS, zero dependencies, Apache-2.0 by Paul Irish). Load JS/CSS once via child theme, stamp `<lite-youtube videoid="...">` tags via BB HTML modules. On click: replaces itself with actual YouTube iframe. WP YouTube Lyte plugin alternative: 30,000+ installs, local thumbnail caching option, `[lyte]` shortcode. Either approach: zero i.ytimg.com requests until user click.
- **Effort:** 2-3 hours for manual HTML module replacement (35 instances). 6-10 hours if building a reusable BB custom module. WP YouTube Lyte plugin: 1-2 hours if shortcodes work via BB text modules.
- **Projected outcome:** 455 KB deferred per page load. Zero i.ytimg.com requests until first click. Lighthouse "Defer offscreen images" fully resolved.
- **Verification:** Network tab in DevTools: zero requests to `i.ytimg.com` on initial page load. Requests appear only after clicking a video thumbnail.

**M3: No font-display — FOIT on 5 font families**

- **Evidence:** Google Fonts CSS serves 5 `@font-face` blocks (Raleway, Work Sans, Inter, Audiowide, Oxygen) with zero `font-display` declarations. This is the Google Fonts default. Lighthouse "Ensure text remains visible during webfont load" audit fails. Fonts.gstatic.com files are well-cached (`max-age=31536000`, 1 year) but the lack of `font-display: swap` causes text to remain invisible until fonts download on slow connections.
- **Impact:** FOIT (Flash of Invisible Text) on first visit or cache miss. For 5 font families being downloaded, text may be invisible for 1-3 seconds on Slow 4G. Contributes to CLS when fonts finally render and text reflows.
- **Fix:** Add `&display=swap` parameter to Google Fonts URL. Additionally: reduce from 5 font families to 2 (one heading, one body) and remove unused font weights. Self-host the reduced font set via LSCache's font optimization.
- **Effort:** 15 minutes (add `&display=swap`). 1 hour (reduce + self-host).
- **Projected outcome:** Text visible immediately using fallback fonts. CLS reduction from font reflow. Font payload reduction ~57 KB → ~25 KB.
- **Verification:** Google Fonts URL includes `&display=swap`. Lighthouse "Ensure text remains visible" passes.

**M4: No CDN — both domains serve from AWS EC2 origin**

- **Evidence:** DNS resolution: `highcountrypainrelief.com` → `44.223.213.21` (AWS EC2), `chiro.inceptionimages.com` → `18.214.60.67` (AWS EC2). Both IPs run LiteSpeed directly. No CDN headers present (`cf-cache-status`, `x-cache`, `age`, `via`, `x-amz-cf-id`). No proxy layer. Static assets are served from origin with 30-day browser cache — this is working correctly for repeat visitors. First-time visitors and geographically distant users experience full origin latency. The `dns-prefetch` for `fonts.googleapis.com` should be upgraded to `preconnect` — currently costs ~1 RTT on every font CSS request.
- **Impact:** Geographically distant visitors experience higher latency. Origin handles all traffic. No edge caching for static assets (browser cache works for repeat visits, but each unique visitor's first load hits origin). The `dns-prefetch` vs `preconnect` gap wastes ~100ms on font loads.
- **Fix:** Add Cloudflare free tier or QUIC.cloud (LiteSpeed native, free tier). Change `dns-prefetch //fonts.googleapis.com` to `<link rel="preconnect" href="https://fonts.googleapis.com" crossorigin>`. If using Cloudflare: enable Brotli, Auto Minify, set Browser Cache TTL to 1 year. Note: this is complementary to LSCache page caching (C1) — CDN caches at the edge, LSCache caches at the server.
- **Effort:** 30 minutes (preconnect). 1-2 hours (CDN setup + DNS).
- **Projected outcome:** Edge TTFB <100ms for cached assets. Reduced origin load. Static asset edge caching improves first-visit performance globally.
- **Verification:** CDN headers present in response. `preconnect` link tag visible in source. DNS resolves to CDN edge IPs instead of origin IPs.

### LOW — Hygiene

**L1: 5 Google Font families with unused weights — 57 KB**

- **Evidence:** Raleway (700, 400, 300, 800, 600), Work Sans (700), Inter (600), Audiowide (400), Oxygen (300, 700). Many weights unused on the page. Self-hosting not in use.
- **Fix:** Audit actual usage via Chrome DevTools CSS Overview. Reduce to 2 families (Raleway + Work Sans). Self-host via LSCache font optimization. Remove Audiowide, Inter, Oxygen.
- **Effort:** 1 hour.
- **Verification:** ≤2 font families in Google Fonts URL or self-hosted CSS.

**L2: `.jpg.webp` double extension — MIME confusion risk**

- **Evidence:** `Chronic-Pain-Boone-NC-SoftWave-Video-Overlay.jpg.webp` — `.jpg` before `.webp` may cause some servers/CDNs to serve `image/jpeg` MIME type instead of `image/webp`.
- **Fix:** Rename to `.webp` only. Verify MIME type in response headers.
- **Effort:** 5 minutes.
- **Verification:** `curl -sI [url] | grep content-type` returns `image/webp`.

**L3: 6 images missing `loading="lazy"` — ~200 KB above-fold waste**

- **Evidence:** 22 `<img>` tags: 16 have `loading="lazy"`, 6 do not. Missing: logo, ASMST logo, video overlay thumbnail, 4 condition images. Some of these are above-fold (logo, hero image — correct to not lazy-load). Others (ASMST logo in footer, condition images mid-page) are below-fold and should be lazy.
- **Fix:** Add `loading="lazy"` to below-fold images missing it. Add `decoding="async"` for offscreen images.
- **Effort:** 10 minutes.
- **Verification:** All below-fold `<img>` tags include `loading="lazy"`.

**L4: No ETag headers — cache revalidation uses Last-Modified only**

- **Evidence:** Static assets return `last-modified` and `expires` but no `ETag`. Conditional revalidation relies solely on `If-Modified-Since`, which has 1-second granularity.
- **Fix:** LiteSpeed Cache plugin adds ETag support automatically. Or: enable ETag in LiteSpeed config.
- **Effort:** Resolved by C1 (LSCache plugin installation).
- **Verification:** `curl -sI [static-asset-url] | grep -i etag` returns ETag value.

---

## 5. Third-Party Script Deferral Strategy

| Script | Source | Current Load | Main-Thread Time | Recommended | Projected Saving |
|--------|--------|-------------|------------------|-------------|-----------------|
| UserWay widget.js | cdn.userway.org | Injected sync via inline `<script>` | 3,242ms | `requestIdleCallback` or user-triggered | ~3,000ms TBT |
| ReviewWave chat_embed.js | cdn.reviewwave.com | Sync `<script>` in `<head>` | 97ms | `defer` — chat is non-critical | ~100ms TBT |
| ReviewWave reviews_embed.js | cdn.reviewwave.com | Sync `<script>` in `<head>` | 426ms | `defer` — reviews below-fold | ~430ms TBT |
| ReviewWave config | rw-embed-data.s3.amazonaws.com | Sync `<script>` in `<head>` | Minimal | `defer` — config data only | Negligible |
| GTM | googletagmanager.com | Inline + async iframe | Minimal | Already async — OK | 0 |
| Vimeo iframes | player.vimeo.com | Inline templates (lightbox) | 0 until click | Already lazy — OK | 0 |
| YouTube iframes | youtube.com | 35 inline templates (lightbox) | 0 until click, but 455 KB thumbnails loaded eagerly | Facade pattern (Audit #3) | 455 KB deferred |
| jQuery 3.7.1 | WP core | Sync in `<head>` | 996ms | Keep sync or defer with careful testing | Uncertain — many plugins hard-depend on `$` |
| BB layout.js × 2 | bb-plugin/cache/ | Sync in `<body>` | 13,467ms (throttled) | `defer` — page-specific, no above-fold JS needed | ~5,000ms TBT (shifts execution out of critical path, does not eliminate it) |
| BB theme.min.js | BB Theme | Sync in `<body>` | Minimal | `defer` | <50ms |

**Note on TBT projections:** Deferral shifts script execution out of the FCP→TTI measurement window but does not eliminate it. The scripts still consume main-thread time when they eventually execute. Real-world TBT reduction from deferral is estimated at 3,000-5,000ms — primarily from UserWay, which is the single largest contributor.

---

## 6. Performance Budget

Target byte sizes after remediation:

| Resource Type | Current | Budget | Rationale |
|---------------|---------|--------|-----------|
| HTML (compressed) | 216 KB (raw) | <30 KB | After Gzip + page cache |
| CSS (combined) | ~130 KB (13 files) | <50 KB (1-2 files) | After minify + combine + unused CSS removal |
| JS (deferred) | ~500 KB (19 files) | <200 KB (2-3 bundles) | After minify + defer + code splitting |
| Fonts | 57 KB (5 families) | <25 KB (2 families) | After reduction + self-hosting |
| Images (own domain) | ~400 KB | <300 KB | After lazy-loading below-fold + proper sizing |
| Images (inceptionimages CDN) | 14,964 KB | <200 KB | After video → static poster replacement |
| Third-party (UserWay + ReviewWave) | 166 KB | <50 KB (deferred) | After deferral |
| YouTube thumbnails | 455 KB (35 images) | 0 KB (facade) | After facade implementation |
| **Total** | **~16,558 KB** | **<1,000 KB** | **16x reduction** |

**Gate:** Any change that adds >50 KB to total page weight requires explicit approval. Lighthouse performance budget configured in CI (when CI is set up).

---

## 7. Implementation Sequence

| Step | Task | Time | Verification |
|------|------|------|-------------|
| 1 | Install LiteSpeed Cache plugin | 15 min | Plugin active in WP Admin |
| 2 | Add `fl_builder` to LSC URI Excludes | 2 min | BB editor opens without CSS/JS breakage |
| 3 | Enable page cache (24h TTL, 1h front page) | 5 min | `curl -sI \| grep x-litespeed-cache` shows `hit` on 2nd request |
| 4 | Enable Gzip compression (level 6) | 5 min | `curl -sI -H 'Accept-Encoding: gzip' \| grep Content-Encoding` shows `gzip` |
| 5 | Enable browser cache for static assets | 2 min | `Cache-Control: max-age=2592000` present on CSS/JS/images |
| 6 | Enable CSS minify + combine | 5 min | All CSS in 1-2 files in DevTools Network tab |
| 7 | Enable JS minify (combine OFF initially) | 2 min | No JS errors in console |
| 8 | Defer non-critical JS (exclude jquery.js, layout.js, bxslider.js) | 10 min | Lighthouse: render-blocking audit passes |
| 9 | Defer UserWay via requestIdleCallback | 15 min | Chrome Performance tab: UserWay loads after TTI |
| 10 | Replace background video with static WebP poster | 2-4 hrs | Lighthouse LCP element is `<img>`, LCP <3s |
| 11 | Implement YouTube facade (lite-youtube-embed or WP YouTube Lyte) | 2-3 hrs | Network tab: zero i.ytimg.com requests until click |
| 12 | Reduce Google Fonts to 2 families + add `&display=swap` | 1 hr | Google Fonts URL: 2 families, `display=swap` |
| 13 | Add CDN (Cloudflare or QUIC.cloud) | 1-2 hrs | CDN headers present; edge TTFB <500ms |
| 14 | Fix .jpg.webp filename | 5 min | MIME type `image/webp` |
| 15 | Add `loading="lazy"` to below-fold images missing it | 10 min | All below-fold `<img>` have `loading="lazy"` |
| 16 | Purge all caches + pre-warm via LSC crawler | 10 min | Crawler processes sitemap; all URLs return HIT |
| 17 | Run PageSpeed Insights to verify | 5 min | Mobile ≥50, Desktop ≥70 |

**Total: ~10-14 hours.** Steps 1-9 are config-only (~3 hours). Steps 10-11 are the largest time investments and the largest performance gains. Steps 12-17 are hygiene + verification.

### Rollback Plan

If any step breaks the site:
1. **LiteSpeed Cache:** Disable plugin or toggle "Enable Cache" OFF. BB reverts to serving its own cached CSS/JS. No data loss.
2. **CSS/JS combine:** Disable combine and minify individually. Most breakage comes from JS combine — disable that first.
3. **Video replacement:** Revert BB row settings to previous background video. Original MP4 remains on CDN.
4. **UserWay deferral:** Revert to original inline script. Copy from page revision history.
5. **YouTube facade:** Delete HTML modules, restore pp-video modules from page revision history.

---

## 8. What's NOT in This Audit

The following were identified during the site crawl but are **outside the scope of page speed performance** and belong in separate audits:

- **On-page SEO** (meta descriptions, title tags, OG tags, schema markup, canonical URLs, heading hierarchy, content depth) — 10 pages have missing or inconsistent metadata
- **Local SEO** (NAP consistency, Google Business Profile integration, local citation signals)
- **E-E-A-T** (404 on "Meet the Doctor" page, no practitioner schema)
- **Security** (missing HTTP security headers, active plugin CVEs including Swiper CVE-2026-27212 CVSS 9.5, xmlrpc.php exposure)
- **Spelling & grammar** (covered in audit/02-spelling-grammar-audit.md)
- **Accessibility** (alt text, heading hierarchy gaps — covered in audit/02)

These are documented in separate deliverables. They do not affect page load performance.

---

## 9. Sources & Methodology

- **Lighthouse 12.6.0** — mobile: emulated Moto G Power, Slow 4G throttling, Chromium 138. Single page session, initial page load. Desktop: no throttling.
- **Server headers** — verified via `curl -sI` against origin and CDN domains on 2026-07-28.
- **YouTube CDN cache** — `max-age=7200` verified via `curl -sI` against `i.ytimg.com` thumbnail URL.
- **Sitemap crawl** — all 44 URLs from `page-sitemap.xml` accessed. 2 URLs blocked by safety classifier (`/good-faith-estimate/`, `/orthotics/`).
- **Competitive baseline** — based on published Core Web Vitals thresholds and comparable Beaver Builder + LiteSpeed optimization benchmarks. No specific competitor sites measured.
