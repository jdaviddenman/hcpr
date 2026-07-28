# Page Load Performance, Caching & Third-Party Deep-Dive: highcountrypainrelief.com

**Date:** 2026-07-28
**POCs:** James David Enman (jdaviddenman@gmail.com) | Amy Denman (amydenman@gmail.com)

---

## 1. CDN Cache Policy Analysis

Every third-party domain on the page — what it caches, for how long, and whether that's a problem.

| Domain | Service | Cache-Control | Max-Age | Problem? |
|--------|---------|--------------|---------|----------|
| `i.ytimg.com` | YouTube thumbnails | `public, max-age=7200` (verified via `curl -sI`) | **2 hours (browser cache), then conditional revalidation** | **YES.** 35+ thumbnails eagerly loaded. After 2 hours, browsers send conditional requests (304 Not Modified — thumbnails for old videos rarely change). Full re-download only occurs on first visit or if the creator updated the thumbnail. The real problem is 35 eager HTTP requests and ~455 KB on cache miss, not 455 KB re-downloaded every 2 hours. Fixed by facade pattern — eliminates requests entirely. |
| `i.vimeocdn.com` | Vimeo thumbnails/video | `max-age=2592000` | 30 days | No. Generous cache. Only 1-2 Vimeo embeds on site. |
| `cdn.userway.org` | UserWay accessibility widget | `max-age=3600, public` | 1 hour (browser). CloudFront edge caches ~21 days. | Low. Short browser cache is acceptable for a widget that updates. CloudFront absorbs repeat requests. Main issue is payload size, not cache TTL. |
| `cdn.reviewwave.com` | ReviewWave reviews + chat | Likely `max-age=3600` (S3+CloudFront, same infra as UserWay) | ~1 hour | Low. Same S3+CloudFront architecture. |
| `rw-embed-data.s3.amazonaws.com` | ReviewWave config JS | **Unable to verify** (endpoint returned 403) | Unknown — S3 default is no Cache-Control unless set at upload | **Likely suboptimal.** S3 objects without Cache-Control get no browser `max-age`. If CloudFront sits in front: CloudFront applies 24-hour default TTL at edge but serves `max-age=0` to browsers. Should be `max-age=31536000, immutable` if these are hashed/versioned config files. The site owner cannot fix third-party S3 metadata. |
| `fonts.gstatic.com` | Google Font files (woff2) | `max-age=31536000` | 1 year | No. Optimal. Versioned URLs, immutable. |
| `fonts.googleapis.com` | Google Font CSS | `private, max-age=86400` | 1 day | Minor. 1-day is fine for repeat visits. `private` is correct (user-agent sniffing). The performance issue is loading 5 font families, not the cache TTL. |
| `googletagmanager.com` | GTM container JS | `private, max-age=931` | ~15 minutes | No (by design). Short TTL lets Google push container updates. Served from fast edge, pre-gzipped. Lighthouse flags it but it's intentional. |
| `chiro.inceptionimages.com` | Practice imagery CDN | LiteSpeed server, no CDN headers observed | Unclear — same LiteSpeed origin as main site | **YES if uncached.** Same missing security/caching headers as origin. 30-day static asset cache observed on main domain — verify this domain inherits same. |
| `highcountrypainrelief.com` (origin) | HTML, CSS, JS, images | Static assets: `max-age=2592000` (30 days) — **correctly configured**. HTML: **no Cache-Control** | 30 days (static), 0 (HTML) | **Static asset caching is in place and working.** The gap is HTML page caching — every page load hits PHP (TTFB 2,540ms). No ETag means revalidation relies on Last-Modified only. LiteSpeed Cache plugin adds server-level HTML caching that bypasses PHP. |

### The Actual Cache Gaps

1. **Static asset caching: already in place.** 30-day `max-age` on all CSS, JS, images, fonts. This is correctly configured and working. LiteSpeed serves these directly from disk.

2. **HTML page caching: absent.** Every page load executes WordPress + Beaver Builder + Yoast from scratch. TTFB 2,540ms. Fixed by LiteSpeed Cache plugin (server-level HTML cache — bypasses PHP on cache hit). This is the single highest-impact fix.

3. **YouTube thumbnails: 2-hour expiry × 35 images.** Fixed by facade — eliminates requests entirely rather than trying to cache around YouTube's short TTL.

4. **No CDN layer.** Both domains (`highcountrypainrelief.com`, `chiro.inceptionimages.com`) resolve to AWS EC2 IPs with LiteSpeed serving directly. A CDN (Cloudflare free tier or QUIC.cloud) would add edge caching and reduce origin load.

---

## 2. LCP Breakdown — The 14.9 MB Video Problem

### Current LCP: 15,940ms

| Phase | Time | % of LCP | What Happens |
|-------|------|----------|--------------|
| **TTFB** | 2,550ms | 16% | LiteSpeed server generates WordPress page with no cache |
| **Load Delay** | 12,730ms | 80% | Browser discovers the `<video>` element only after ALL 19 sync scripts and 13 sync CSS files download, parse, and execute. The video is a CSS background loaded via Beaver Builder's row background video feature — it's deep in the critical request chain. |
| **Load Time** | 140ms | 1% | Once started, the 14.9 MB MP4 begins downloading. This small % is misleading — the download continues long after LCP fires, consuming bandwidth. |
| **Render Delay** | 520ms | 3% | Browser decodes first frame and paints. |

### 80% Load Delay = Render-Blocking Resources

12.7 seconds of waiting before the browser even *starts* loading the LCP element. This is the render-blocking CSS/JS chain. The browser can't discover the video element until:
1. HTML parsed
2. All 13 CSS files in `<head>` downloaded and parsed (CSS blocks rendering)
3. All 19 synchronous `<script>` tags downloaded and executed (scripts block HTML parsing)

### Target LCP with Static Poster + Page Cache

Replace the 14.9 MB background video with a static WebP poster image (~50 KB):

| Phase | Current | Target | How |
|-------|---------|--------|-----|
| TTFB | 2,550ms | **~400ms** | LiteSpeed Cache page cache — serves pre-rendered HTML |
| Load Delay | 12,730ms | **~100ms** | Defer all non-critical scripts; CSS inlined or deferred; browser discovers image element immediately |
| Load Time | 140ms | **~50ms** | 50 KB WebP poster vs. 14.9 MB MP4 — 300× smaller |
| Render Delay | 520ms | **~400ms** | Image decode is faster than video first-frame decode |
| **Total LCP** | **15,940ms** | **<1,500ms** | **Passes the 2.5s Core Web Vitals threshold with margin** |

This one change — static poster + page cache — reduces LCP by ~90%. The CLS also improves because the video element gets explicit dimensions.

**Realism note:** Sub-1s LCP targets are achievable on near-empty pages on exceptional hosting. With 3,178 DOM elements, UserWay, ReviewWave, and 35 YouTube facades (even when deferred), this site's realistic LCP target is **1.0-1.5s** after all fixes. Achieving sub-1s would require eliminating UserWay entirely and significantly reducing DOM — work outside config scope.

---

## 3. YouTube Facade Implementation

### Current State

- 35+ YouTube video thumbnails loaded as CSS `background-image` on `<div class="pp-video-image-overlay">`
- Each thumbnail: ~13 KB from `i.ytimg.com`
- Total per page load: **~455 KB**
- YouTube CDN cache: **2 hours** (`max-age=7200`, verified via `curl -sI`)
- All loaded **eagerly** — every thumbnail downloads on every page load
- Lighthouse "Defer offscreen images" audit: **758 KiB estimated savings**

### The Facade Pattern

Instead of loading the YouTube thumbnail + iframe on page load, display a static placeholder. Only load the real YouTube embed when the user clicks.

### Implementation Options

| Option | Size | Complexity | BB Compatible? | Best For |
|--------|------|------------|----------------|----------|
| **A) `lite-youtube-embed` web component** | ~3 KB JS + ~1 KB CSS | Drop-in — replace `<div>` with `<lite-youtube videoid="...">` | Works via BB HTML module. Zero dependencies. Apache-2.0 by Paul Irish. | Developers; minimal overhead; 224× faster render claimed |
| **B) WP YouTube Lyte plugin** | Plugin overhead | Install + configure. 30,000+ active installs. Local thumbnail caching option. | May need `[lyte]` shortcode if BB bypasses `the_content` filter | Non-technical editors; WP-native; local thumbnail cache |
| **C) Custom facade** (static img + onclick) | ~2 KB inline JS | Build once, reuse | Requires BB module customization | Full control, minimal overhead |
| **D) Embed Plus for YouTube** | Heavy plugin | Facade mode available | Plugin-level | Overkill — gallery/livestream features not needed |

### Recommendation: Option A — `lite-youtube-embed` Web Component

**Rationale:**
- ~3 KB JS + ~1 KB CSS. Zero dependencies. Works in any HTML context. No plugin to maintain.
- 35 instances of `<lite-youtube>` on a page share one JS/CSS load
- Renders its own `background-image` internally using the standard `i.ytimg.com` URL — but **only after user click**, not on page load
- On click: replaces itself with real YouTube iframe (`youtube-nocookie.com`, `autoplay=1`)
- Accessible: `playlabel` attribute for screen readers
- Maintained by Paul Irish (Google Chrome team), Apache-2.0 license
- **Measurable benefit:** 0 KB loaded until click vs. 455 KB eagerly loaded

**Implementation:**

```html
<!-- Load once in <head> or footer -->
<link rel="stylesheet" href="lite-yt-embed.css">
<script defer src="lite-yt-embed.js"></script>

<!-- Replace each pp-video-image-overlay div: -->
<lite-youtube videoid="C7XENcnzvzc" playlabel="Play: Patient Testimonial"></lite-youtube>
```

**For Beaver Builder integration:**
- Add the JS/CSS via child theme `functions.php` (`wp_enqueue_script` + `wp_enqueue_style`) or via BB global settings (Settings → Beaver Builder → CSS/JS)
- Replace each `pp-video` module's output with an HTML module containing the `<lite-youtube>` tag
- Or: write a small BB custom module that outputs `<lite-youtube>` — reusable across all 35 instances

**For WP YouTube Lyte (if plugins preferred):**
```
[lyte id="C7XENcnzvzc" /]
```
Enable "Cache thumbnails locally" in plugin settings — eliminates i.ytimg.com requests entirely, even after click (the poster thumbnail is self-hosted).

**Performance gain:**
- 455 KB deferred per page load → **0 KB until first click**
- Lighthouse "Defer offscreen images" goes from 758 KiB savings → **fully resolved (0)**
- 35 fewer HTTP requests on page load
- No cache-expiry problem — thumbnails are never loaded until user interaction
- If WP YouTube Lyte with local cache: ~455 KB saved per click as well (poster served locally)

### What About the Full YouTube Iframe Penalty?

If these 35 embeds were full iframes (not just thumbnails), each would cost ~500 KB (player JS, CSS, fonts, tracking). The facade pattern avoids loading the iframe until click — saving up to **17.5 MB** per page view for 35 videos.

---

## 4. Plugin & Page Builder Caching

### Beaver Builder Cache (Current State)

- **Location:** `/wp-content/uploads/bb-plugin/cache/`
- **What it does:** On every page save, BB generates per-page CSS and JS files. Only modules actually used on the page load their assets (selective enqueue). Files are named by post ID (e.g., `2-layout.css` for the homepage, post ID 2).
- **Cache-busting:** Content-hash query strings (`?ver=c5bc882838ad92ad63b80ce6890bd11f`) — browser cache breaks automatically when content changes.
- **Auto-regeneration:** Page save, plugin update, site URL change, or `WP_DEBUG = true`.
- **What it does NOT do:** Page caching, HTML caching, browser cache headers, object caching, image optimization, CSS/JS minification beyond its own per-page files, CDN integration.

### LiteSpeed Cache Plugin (Target State)

| Layer | Current | With LSCache | Benefit |
|-------|---------|-------------|---------|
| **Page cache** | None — every request hits PHP | Full HTML cached at LiteSpeed server level. PHP bypassed on cache hit. | TTFB 2,540ms → ~400ms |
| **Browser cache** | 30 days on static assets (good). Zero on HTML (bad). No ETag. | Adds ETag. Adds `Cache-Control: max-age=86400` on HTML for returning visitors. Configurable TTLs per content type. | Repeat visits load from disk |
| **Object cache** | None | Redis/Memcached — reduces DB queries. Requires server-side daemon. | 30-50% DB query reduction |
| **CSS minify** | BB does its own. 4 of 13 CSS files on homepage are NOT minified (bb-plugin caches, skin, child theme). | Minifies all CSS including non-BB files. | ~25 KB CSS savings |
| **JS minify** | BB does its own. 6 of 21 JS files NOT minified (S3 scripts, ReviewWave, BB caches). | Minifies all JS. | ~15 KB JS savings |
| **CSS/JS combine** | None. 13 separate CSS files, 19 separate JS files. | Combines into 1-2 CSS and 1-2 JS bundles. | Eliminates ~28 HTTP requests |
| **JS defer** | None. All scripts synchronous. | Defers non-critical JS. | Render-blocking chain broken |
| **Image lazy-load** | 16/22 images have `loading="lazy"`. 6 missing. | Adds lazy-load to all below-fold images automatically. | Resolved |
| **Image WebP** | Most images already WebP. | Auto-converts to WebP on upload + serves WebP to supporting browsers. | Already done |
| **Critical CSS** | None. | Generates above-the-fold CSS, inlines it, defers the rest. Requires QUIC.cloud. | FCP improvement |
| **Crawler** | None. | Pre-warms cache by crawling sitemap. | First visitor always gets cache hit |

### Recommended TTLs for a Medical Practice Marketing Site

Low-frequency-update brochure site — conservative TTLs work.

| Cache Type | TTL | Rationale |
|------------|-----|-----------|
| Default Public Cache | 604800s (7 days) | Content changes rarely |
| Front Page TTL | 86400s (24 hours) | Homepage may update with promos/announcements |
| Browser Cache | 31536000s (1 year) — **only if hash-based cache-busting verified through CDN** | BB uses `?ver=` query strings for cache-busting. Some CDNs strip query strings by default. If hash-busting cannot be verified through CDN: keep current 30-day setting. |
| Private Cache | 0 (disabled) | No logged-in user content to cache |

**Purge strategy:** Purge all on plugin/theme update. Auto-purge homepage + affected pages on post publish/update. No need for aggressive short TTLs — purge-on-change is more efficient.

### Known Breakage + Fixes

| Issue | Fix |
|-------|-----|
| BB editor CSS breaks (settings panel fullscreen) | Add `fl_builder` to URI Excludes in LSC Tuning tab |
| BB editor won't load after JS combine/minify | Exclude `jquery.js`, `fl-builder` from JS optimization |
| Sliders don't load on mobile after JS defer | Exclude `bxslider.js`, `jquery.js`, `layout.js` from defer |
| Headers/footers break after days (stale HTML cache) | Enable BB "Inline CSS/JS" + purge all after any cache clear |
| 404s on BB cache files after updates | Purge all caches after any BB update or BB cache clear |

**Critical setting:** Add `fl_builder` to **Page Optimization → Tuning → URI Excludes**. This disables CSS/JS optimization for the editor while keeping it active for frontend visitors.

---

## 5. Third-Party Script Deferral Strategy

| Script | Source | Current Load | Main-Thread Time | Recommended | Savings |
|--------|--------|-------------|------------------|-------------|---------|
| **UserWay widget.js** | cdn.userway.org | Synchronous (injected inline) | 3,242ms | `defer` with `data-account` attribute; load via `requestIdleCallback` | ~3,000ms TBT |
| **ReviewWave chat_embed.js** | cdn.reviewwave.com | Synchronous (`<script src>` in `<head>`) | 97ms | `defer` — chat widget is non-critical for LCP | ~100ms TBT |
| **ReviewWave reviews_embed.js** | cdn.reviewwave.com | Synchronous (in `<head>`) | 426ms | `defer` — reviews display is below-fold | ~430ms TBT |
| **ReviewWave config** | rw-embed-data.s3.amazonaws.com | Synchronous (in `<head>`) | Minimal | `defer` — config data, no execution needed before render | Negligible |
| **Google Tag Manager** | googletagmanager.com | Inline `<script>` + async iframe fallback | Minimal | Already async. OK as-is. | 0 |
| **Vimeo iframe** | player.vimeo.com | Inline template (2 embeds, hidden until lightbox click) | 0 until click | Already lazy. OK as-is. | 0 |
| **YouTube iframes** | youtube.com | 35+ inline templates (hidden until lightbox click) | 0 until click, but 455 KB of thumbnails load eagerly | Facade pattern (Section 3 above) | 455 KB deferred |
| **jQuery 3.7.1** | WordPress core | Synchronous in `<head>` | 996ms | Defer (or keep sync — many plugins depend on it). If deferring: test all page interactions. | ~700ms with async follow-up |
| **Bootstrap JS** | BB Theme | Synchronous in `<body>` | 162ms | `defer` — below-fold interactions only | ~160ms |
| **BB layout.js** (×2) | bb-plugin/cache/ | Synchronous in `<body>` | 13,467ms (throttled) | `defer` — these are page-specific layout scripts, no above-fold JS needed | ~5,000ms TBT |

**Projected TBT reduction from deferral: 3,000-5,000ms** (from 18,520ms → ~13,500-15,500ms). Deferral shifts script execution out of the FCP→TTI measurement window but does not eliminate the work. UserWay (3,242ms) is the single largest contributor and the highest-impact deferral target.

**Note on TBT measurement:** TBT is measured with 4x CPU throttling on mobile Lighthouse. Deferring a script does not eliminate its CPU time — it shifts execution to a later point. If deferred scripts execute during the TBT measurement window after deferral, TBT is unchanged from those scripts. The projected reduction assumes deferred scripts execute after TTI.

---

## 6. Recommended Cache Hierarchy

| Layer | Current | Target | TTL |
|-------|---------|--------|-----|
| **CDN** | None — both domains resolve to AWS EC2 IPs (44.223.213.21, 18.214.60.67), LiteSpeed directly | Cloudflare (free) or QUIC.cloud (LiteSpeed native) | Edge cache: 7 days for static, 24h for HTML |
| **Page Cache** | None — every request runs PHP | LiteSpeed Cache — server-level full HTML, bypasses PHP on hit | 24h default, 1h front page |
| **Object Cache** | None | Redis via LSCache plugin | Persistent, invalidated on content change |
| **Static Asset Compression** | **Brotli active** (`content-encoding: br` on CSS/JS/fonts) — already working | No change needed | N/A |
| **HTML Compression** | None — 216 KB raw | Brotli via LiteSpeed config or LSCache | N/A |
| **Browser Cache — HTML** | None | `Cache-Control: public, max-age=86400` for returning visitors | 24h |
| **Browser Cache — Static** | `max-age=2592000` (30 days) — **already correctly configured** | Add ETag for better revalidation. Extend to 1 year only if hash-busting verified through CDN. | 30 days (current, safe) or 1 year (if hash-verified) |
| **Browser Cache — Fonts** | 30 days (FA woff2 preloaded) | 1 year (versioned font URLs are immutable) | 1 year |
| **YouTube Thumbnails** | ~2 hours (i.ytimg.com) | **Eliminated via facade** — 0 KB loaded until click | N/A |

---

## 7. Implementation Sequence

| Step | Task | Time | Verification |
|------|------|------|-------------|
| 1 | **Install LiteSpeed Cache plugin** | 15 min | Plugin active, settings page loads |
| 2 | **Add `fl_builder` to URI Excludes** | 2 min | BB editor opens without CSS/JS breakage |
| 3 | **Enable page cache (7-day TTL, 24h front page)** | 5 min | `curl -sI \| grep x-litespeed-cache` shows `hit` on 2nd request |
| 4 | **Enable browser cache for static assets** | 2 min | `curl -sI [css-url] \| grep cache-control` shows `max-age=31536000` |
| 5 | **Enable CSS minify + combine** | 2 min | Test page: all CSS in 1-2 files in Network tab |
| 6 | **Enable JS minify (combine OFF initially)** | 2 min | Test page: no JS errors in console |
| 7 | **Defer non-critical JS** (exclude jquery.js, bxslider.js) | 5 min | Lighthouse: render-blocking audit passes |
| 8 | **Enable Gzip via LiteSpeed** (or .htaccess) | 5 min | `curl -sI -H 'Accept-Encoding: gzip' \| grep Content-Encoding` shows `gzip` |
| 9 | **Replace background video with static WebP poster** | 2-4 hrs | Lighthouse: LCP element is `<img>`, LCP <3s. BB row background video cannot be "replaced" in one click — requires: (1) remove BB row video background, (2) set static image as row background, (3) design approval for new static hero, (4) custom JS if video playback on interaction is desired |
| 10 | **Implement YouTube facade** (lite-youtube-embed or WP YouTube Lyte) | 2-3 hrs (manual HTML module replacement, 35 instances). 1-2 hrs if WP YouTube Lyte plugin works with BB text modules. | Network tab: zero i.ytimg.com requests until click |
| 11 | **Add security headers** (.htaccess) | 10 min | `curl -sI \| grep -iE 'hsts\|x-content\|x-frame'` returns all 6 |
| 12 | **Update Swiper 8.4.7 → 12.1.2+** | 30 min | CVE-2026-27212 resolved; sliders still functional |
| 13 | **Add CDN** (Cloudflare or QUIC.cloud) | 1-2 hrs | CDN headers present in response; TTFB <300ms |
| 14 | **Purge all caches + pre-warm via crawler** | 10 min | Crawler runs against sitemap; all URLs return cache HIT |
| 15 | **Run PageSpeed Insights to verify** | 5 min | Mobile ≥70, Desktop ≥85 |

**Total: ~6-8 hours.**
