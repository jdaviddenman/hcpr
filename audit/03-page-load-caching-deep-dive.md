# Page Load Performance, Caching & Third-Party Deep-Dive: highcountrypainrelief.com

**Date:** 2026-07-28
**POCs:** James David Enman (jdaviddenman@gmail.com) | Amy Denman (amydenman@gmail.com)

---

## 1. CDN Cache Policy Analysis

Every third-party domain on the page — what it caches, for how long, and whether that's a problem.

| Domain | Service | Cache-Control | Max-Age | Problem? |
|--------|---------|--------------|---------|----------|
| `i.ytimg.com` | YouTube thumbnails | `public, max-age=21600` (varies) | **~6 hours** | **YES — severe.** 35+ thumbnails reload every ~6 hours for returning visitors. 455 KB re-downloaded per session. Combined with eager loading of all 35, this is a top-3 performance issue. |
| `i.vimeocdn.com` | Vimeo thumbnails/video | `max-age=2592000` | 30 days | No. Generous cache. Only 1-2 Vimeo embeds on site. |
| `cdn.userway.org` | UserWay accessibility widget | `max-age=3600, public` | 1 hour (browser). CloudFront edge caches ~21 days. | Low. Short browser cache is acceptable for a widget that updates. CloudFront absorbs repeat requests. Main issue is payload size, not cache TTL. |
| `cdn.reviewwave.com` | ReviewWave reviews + chat | Likely `max-age=3600` (S3+CloudFront, same infra as UserWay) | ~1 hour | Low. Same S3+CloudFront architecture. |
| `rw-embed-data.s3.amazonaws.com` | ReviewWave config JS | **None** (S3 default) | **0 — no Cache-Control at all** | **YES.** S3 objects without Cache-Control headers get no browser caching. If behind CloudFront: CloudFront applies 24-hour default. Either way, suboptimal. Should be `max-age=31536000, immutable` for these hashed config files. |
| `fonts.gstatic.com` | Google Font files (woff2) | `max-age=31536000` | 1 year | No. Optimal. Versioned URLs, immutable. |
| `fonts.googleapis.com` | Google Font CSS | `private, max-age=86400` | 1 day | Minor. 1-day is fine for repeat visits. `private` is correct (user-agent sniffing). The performance issue is loading 5 font families, not the cache TTL. |
| `googletagmanager.com` | GTM container JS | `private, max-age=931` | ~15 minutes | No (by design). Short TTL lets Google push container updates. Served from fast edge, pre-gzipped. Lighthouse flags it but it's intentional. |
| `chiro.inceptionimages.com` | Practice imagery CDN | LiteSpeed server, no CDN headers observed | Unclear — same LiteSpeed origin as main site | **YES if uncached.** Same missing security/caching headers as origin. 30-day static asset cache observed on main domain — verify this domain inherits same. |
| `highcountrypainrelief.com` (origin) | HTML, CSS, JS, images | **None on HTML**. Static assets: `max-age=2592000` | 30 days (static), 0 (HTML) | **YES — HTML has no cache at all.** Every page load hits PHP. Static asset caching is fine (30 days) but lack of ETag means revalidation uses only Last-Modified. |

### The Two Real Cache Problems

1. **Origin HTML: no cache.** Fixed by LiteSpeed Cache plugin (page cache at server level). Not a header-config fix — needs a caching layer.

2. **YouTube thumbnails: ~6-hour expiry × 35+ images × ~13 KB = 455 KB per session.** Fixed by facade pattern — don't load thumbnails until click. Eliminates the problem entirely rather than trying to cache around it.

3. **S3 config JS: no Cache-Control.** Fixed by adding S3 object metadata. Control depends on ReviewWave's S3 bucket access. If they won't fix it, CloudFront in front of the site will apply its own 24-hour minimum.

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
| **Total LCP** | **15,940ms** | **~950ms** | **Well under the 2.5s threshold** |

This one change — static poster + page cache — produces a 16× LCP improvement. The CLS also improves because the video element gets explicit dimensions.

---

## 3. YouTube Facade Implementation

### Current State

- 35+ YouTube video thumbnails loaded as CSS `background-image` on `<div class="pp-video-image-overlay">`
- Each thumbnail: ~13 KB from `i.ytimg.com`
- Total per page load: **~455 KB**
- YouTube CDN cache: **~6 hours** (`max-age=21600`)
- All loaded **eagerly** — every thumbnail downloads on every page load
- Lighthouse "Defer offscreen images" audit: **758 KiB estimated savings**

### The Facade Pattern

Instead of loading the YouTube thumbnail + iframe on page load, display a static placeholder. Only load the real YouTube embed when the user clicks.

### Implementation Options

| Option | Size | Complexity | BB Compatible? | Best For |
|--------|------|------------|----------------|----------|
| **A) `lite-youtube` web component** | 15 KB JS | Drop-in — replace `<div>` with `<lite-youtube videoid="...">` | Requires template override or shortcode | Developers comfortable with custom elements |
| **B) Custom facade** (static img + onclick) | ~2 KB inline JS | Build once, reuse | Requires BB module customization | Full control, minimal overhead |
| **C) WP YouTube Lyte plugin** | Plugin overhead (~50 KB) | Install + configure | Plugin-level, may conflict with BB pp-video module | Non-technical users, quick setup |

### Recommendation: Option B — Custom Facade (Beaver Builder Module Override)

**Rationale:**
- Option A (lite-youtube) requires replacing BB's `pp-video` module output with a custom web component — non-trivial template override.
- Option C (WP YouTube Lyte) adds plugin overhead and may not intercept BB's custom video module.
- Option B adds ~2 KB of inline JS, replaces the 455 KB thumbnail payload with a single local SVG play button, and works with any video module that outputs a known thumbnail URL.

**Implementation:**

```php
// In child theme functions.php — filter BB video module output
// Replace background-image with a static placeholder
// Add data-youtube-id attribute for click handler

add_filter('fl_builder_module_attributes', function($attrs, $module) {
    if ($module->slug === 'pp-video' && isset($attrs['data-youtube-id'])) {
        // Don't load thumbnail until click
        $attrs['data-thumbnail'] = ''; // clear eager thumbnail
        $attrs['class'] .= ' youtube-facade';
    }
    return $attrs;
}, 10, 2);
```

```css
/* youtube-facade.css — static play button overlay */
.youtube-facade {
    background: #000 center/cover no-repeat;
    position: relative;
    cursor: pointer;
}
.youtube-facade::after {
    content: '';
    position: absolute;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    width: 68px; height: 48px;
    background: url('data:image/svg+xml,...') center/contain no-repeat; /* inline SVG play button */
}
```

```js
// youtube-facade.js — ~1 KB
document.querySelectorAll('.youtube-facade').forEach(function(el) {
    el.addEventListener('click', function() {
        var videoId = this.getAttribute('data-youtube-id');
        var iframe = document.createElement('iframe');
        iframe.src = 'https://www.youtube.com/embed/' + videoId + '?autoplay=1';
        iframe.setAttribute('allowfullscreen', '');
        iframe.setAttribute('frameborder', '0');
        this.innerHTML = '';
        this.appendChild(iframe);
        this.classList.remove('youtube-facade');
    });
});
```

**Performance gain:**
- 455 KB deferred per page load → 0 KB until first click
- Lighthouse "Defer offscreen images" goes from 758 KiB savings → **fully resolved (0)**
- 35 fewer HTTP requests on page load
- No cache-expiry problem — no thumbnails loaded at all until interaction

### What About the 35 Vimeo/YouTube Thumbnails Used as Background Images?

The current approach uses CSS `background-image: url(i.ytimg.com/.../hqdefault.jpg)` inline on each `pp-video-image-overlay` div. These are NOT `<img>` tags — they're CSS backgrounds. The browser still downloads them, and `loading="lazy"` doesn't apply to CSS backgrounds.

The facade pattern above replaces these CSS background-images with a single inline SVG play button (zero HTTP requests). The YouTube thumbnail is never fetched until the user clicks.

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
| Browser Cache | 31536000s (1 year) | Static assets rarely change |
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

**Aggregate TBT savings from deferral: ~9,400ms** (from 18,520ms → ~9,000ms). Remaining TBT is primarily the 14.9 MB video and uncompressed assets.

---

## 6. Recommended Cache Hierarchy

| Layer | Current | Target | TTL |
|-------|---------|--------|-----|
| **CDN** | None | Cloudflare (free) or QUIC.cloud (LiteSpeed native) | Edge cache: 7 days for static, 24h for HTML |
| **Page Cache** | None | LiteSpeed Cache — server-level full HTML | 7 days (front page: 24h) |
| **Object Cache** | None | Redis via LSCache plugin | Persistent, invalidated on content change |
| **Browser Cache — HTML** | None | `Cache-Control: public, max-age=86400` | 24 hours |
| **Browser Cache — Static** | `max-age=2592000` (30 days) | `max-age=31536000` (1 year) + ETag | 1 year |
| **Browser Cache — Fonts** | 30 days (FA woff2 preloaded) | 1 year (versioned font URLs are immutable) | 1 year |
| **YouTube Thumbnails** | ~6 hours (i.ytimg.com) | **Eliminated via facade** — 0 KB loaded until click | N/A |

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
| 9 | **Replace background video with static WebP poster** | 2 hrs | Lighthouse: LCP element = small image, LCP <3s |
| 10 | **Implement YouTube facade** (custom or WP YouTube Lyte) | 1 hr | Network tab: zero i.ytimg.com requests until click |
| 11 | **Add security headers** (.htaccess) | 10 min | `curl -sI \| grep -iE 'hsts\|x-content\|x-frame'` returns all 6 |
| 12 | **Update Swiper 8.4.7 → 12.1.2+** | 30 min | CVE-2026-27212 resolved; sliders still functional |
| 13 | **Add CDN** (Cloudflare or QUIC.cloud) | 1-2 hrs | CDN headers present in response; TTFB <300ms |
| 14 | **Purge all caches + pre-warm via crawler** | 10 min | Crawler runs against sitemap; all URLs return cache HIT |
| 15 | **Run PageSpeed Insights to verify** | 5 min | Mobile ≥70, Desktop ≥85 |

**Total: ~6-8 hours.**
