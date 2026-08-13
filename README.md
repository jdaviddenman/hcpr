# HCPR — High Country Pain Relief

Page speed audit, architecture review and remediation plan for
[highcountrypainrelief.com](https://www.highcountrypainrelief.com).

## Documents

| # | Document | Scope |
|---|----------|-------|
| — | **[Priority Fixes](PRIORITY-FIXES.md)** | **The deliverable.** Plain-English summary for the practice and Inception, plus three self-contained work tickets. Measured live 2026-08-13. **Send this one.** |
| — | [Verifying Backend Claims](VERIFYING-BACKEND-CLAIMS.md) | Confirming from outside that an asserted fix is live and reaching visitors. Four traps on this server that make a correct fix look failed. Runnable census: [`audit/data/verify-live.sh`](audit/data/verify-live.sh). |
| — | [Security Findings](SECURITY-FINDINGS.md) | Four items found passively while measuring: REST user enumeration, no security headers, a migration leftover, one unassessed gap. |
| 1 | [Page Speed Performance Audit](audit/01-page-speed-performance-audit.md) | 24 findings, 26-step sequence, full evidence. Reconciled to the 2026-08-13 measurements. |
| 2 | [Spelling & Grammar Audit](audit/02-spelling-grammar-audit.md) | 35 confirmed errors across site chrome and 4 content pages. |
| 3 | [Page Load & Caching Deep-Dive](audit/03-page-load-caching-deep-dive.md) | Cache policy by domain, cold-cache analysis, Beaver Builder cache behaviour. |
| 4 | [On-Page SEO & Content Findings](audit/04-seo-content-findings.md) | Metadata gaps, schema format errors. |
| 5 | [Architecture & Code Quality](audit/05-architecture-and-code-quality.md) | Plugin inventory, version currency, per-asset byte accounting. |
| — | [Measured evidence](audit/data/) | Lighthouse mobile (Jul + Aug) and desktop (Aug), two 44-URL header sweeps, reproducer scripts. |

## Current State

Measured 2026-08-13, including three Lighthouse mobile runs (12.8.2, median of 3). July shown for
comparison.

| Metric | Aug 2026 | Jul 2026 | Threshold | Notes |
|--------|------|------|-----------|-------|
| Performance (mobile) | **33/100** | 21 | 90+ | Aug runs: 27 / 33 / 34 |
| LCP | **12.2 s** | 18.9 s | <2.5 s | 65–73% is Load Delay on the hero video; same element both months |
| CLS | **0.000 warm / 0.184 cold** | 0.184 | <0.1 | Appears only on a cache MISS — the path a first-time visitor takes |
| FCP | **3.9 s** | 3.0 s | <1.8 s | |
| Speed Index | **7.1 s** | 14.1 s | <3.4 s | |
| TBT | **1,684 ms** | 14,710 ms | — | Host-dependent, see below. Not a Core Web Vital |
| Main-thread work | **10.6 s** | 36.9 s | — | Host-dependent |
| Network payload | **16,986 KiB** | 5,123 KiB | — | **~88% is the hero video, now downloading in full (~15 MB)**. July's browser aborted it partway |
| TTFB, cold cache | **1.054 s** median | 0.845–1.788 s | — | 12 of 12 first requests were cold |
| TTFB, warm cache | **0.076 s** median | 0.052–0.113 s | — | Stable |
| DOM elements | **3,181** | 3,197 | <1,500 | Max child elements 105 in both months — the Swiper loop clones |

The CPU rows measure the test machine, not the site. Lighthouse calibrates the simulated network but
applies a fixed ×4 CPU multiplier to whatever host runs it; August ran at `benchmarkIndex` ≈ 1,300 and
July's was not recorded. Quote CPU figures with the host attached or not at all.

Identical across both months: the LCP element and its selector, CLS from that one element, 105 max child
elements, DOM depth 28, the render-blocking leader (ReviewWave's S3 config), and the third-party ranking
(UserWay 1st, GTM 2nd, ReviewWave 3rd).

## The Short Version

**One Beaver Builder dropdown stops ~88% of mobile payload being fetched.** The hero row carries
`data-video-mobile="yes"`. On a mobile user agent BB's else-branch sets `src=""` on the `<video>` instead
of leaving its two `<source>` children active, so neither file downloads — and the fallback WebP BB has
already attached as a background paints instead, becoming the LCP element at 77 KB, first-party. It does
**not** remove the `<video>` element; check for the absent *request*, not the absent element.

**Nothing about the hero is in the HTML.** Zero `<video>`, zero `<source>`, zero `poster`. Beaver Builder
builds all of it in JavaScript from `data-` attributes, hardcodes a 1×1 GIF poster, and applies the real
fallback as a CSS background on the element it just created. That is why the browser takes so long to
discover what to load, and why nothing paints early.

**The CLS does not come from a missing row height.** The row already has explicit padding at all three
breakpoints. The markup carries no `data-width`/`data-height`, so BB inserts the video at one size and
re-sizes it on `loadedmetadata`. The desktop fix is a CSS rule on `.fl-bg-video video` with every
declaration `!important` — BB writes both sizes through jQuery `.css()`, i.e. inline styles, and
re-applies them on a debounced resize.

**The video gallery has loop and autoplay switched on.** PowerPack passes `loopedSlides: 35` to Swiper,
which clones the set to 105 children; and `options.carousel.autoplay` is overwritten to `{delay:3000}`
one statement after the literal reads `autoplay:false`. Two tick-boxes remove ~1,286 DOM elements and a
perpetual animation, for a fraction of the rebuild's cost.

**`hiking.mp4` is not faststart.** Its 5,493-byte `moov` atom sits behind 15,338,116 bytes of `mdat`, so
playback cannot begin until nearly the whole file arrives. One lossless `ffmpeg -c copy -movflags
+faststart`.

**A page-speed plugin is loaded and the frontend shows no sign of it.** 10Web Booster's REST routes are
all still registered — on a page with zero `defer`, zero `async`, no critical CSS and no CDN. Settling
which of the three explanations applies needs wp-admin. Do it before hand-writing work the plugin may
already do.

**Software is current; its bundled libraries are not.** WordPress 7.0.4 and Yoast are current releases.
What is stale ships inside those current plugins — Bootstrap 3.4.1 (EOL 2019), Swiper 8.4.7, fancyBox
3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1 — and no plugin update reaches any of it.

**There is no configuration path to a green score.** The ceiling is 3,181 rendered DOM elements, a Beaver
Builder layout bundle, four libraries doing two jobs, and third-party code the practice does not control.

## Measurement variance

Three Lighthouse runs of the unmodified site scored **27, 33 and 34** — a 7-point spread, 2.0 s of LCP,
and all of the layout shift. July's two scored 21 and 27. Two header sweeps of identical content 78
minutes apart gave cold TTFB medians of **0.845 s and 1.788 s** and disjoint lists of the five slowest
pages.

Take the median of 3+ runs before declaring a fix successful. **Verify CLS on a cold cache** — a warm run
scores 0.000 today, before any fix.

Method notes: [audit/data/README.md](audit/data/README.md).
