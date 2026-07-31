# HCPR — High Country Pain Relief

Page speed performance audit, architecture review, and remediation roadmap for [highcountrypainrelief.com](https://www.highcountrypainrelief.com).

## Documents

| # | Document | Scope |
|---|----------|-------|
| 1 | [Page Speed Performance Audit](audit/01-page-speed-performance-audit.md) | Lighthouse 21/100 mobile. LCP breakdown, main-thread analysis, 24 findings, 24-step implementation sequence. **Start here.** |
| 2 | [Spelling & Grammar Audit](audit/02-spelling-grammar-audit.md) | 35 confirmed errors, 4 style preferences, 1 unverified. Site-wide chrome plus 4 content pages. |
| 3 | [Page Load & Caching Deep-Dive](audit/03-page-load-caching-deep-dive.md) | Cache policy by domain, cold-cache analysis across two sweeps, YouTube facade, Beaver Builder cache behaviour, third-party load table. |
| 4 | [On-Page SEO & Content Findings](audit/04-seo-content-findings.md) | Metadata gaps, schema format errors, security register. Outside page speed scope. |
| 5 | [Architecture, Version Currency & Code Quality](audit/05-architecture-and-code-quality.md) | Full plugin inventory, WordPress and library version currency, per-asset byte accounting, 10 code-quality indicators. |
| — | [Measured evidence](audit/data/) | Lighthouse extract, two 44-URL header sweeps, reproducer script. |

## Current State

Measured 2026-07-30. **[LH]** = from the Lighthouse run of 18:13 EDT, carried forward and not re-measured. Everything else was measured directly against the live site.

| Metric | Current | Threshold | Notes |
|--------|---------|-----------|-------|
| Performance (mobile) | **21/100** [LH] | 90+ | 27 on a 2026-07-28 run of the same unchanged site |
| LCP | **18.9 s** [LH] | <2.5 s | 83% is Load Delay on the hero video |
| TBT | **14,710 ms** [LH] | <200 ms | main-thread work totals 36.9 s |
| CLS | **0.184** [LH] | <0.1 | 100% from one element — Beaver Builder re-sizing the hero video |
| FCP | **3.0 s** [LH] | <1.8 s | 11 render-blocking resources |
| Speed Index | **14.1 s** [LH] | <3.4 s | |
| TTFB, Lighthouse | **700 ms** [LH] | <800 ms | **passes** — but it is one sample of the distribution below |
| TTFB, cold cache | **0.406-4.946 s** | — | 86 of 88 first requests across two sweeps were cold |
| TTFB, warm cache | **0.052-0.113 s** | — | stable across 90 observations |
| Network payload | **5,123 KiB** [LH] | — | 60.7% is the hero video |
| First-party bytes parsed | **1,514 KiB** | — | 277 KiB on the wire; Brotli hides a 5.5× gap |
| DOM elements, rendered | **3,197** [LH] | <1,500 | source HTML contains 1,792 — the rest is built by JS |

## The Short Version

**One Beaver Builder dropdown removes 62% of mobile payload, the LCP element, and the entire CLS contributor.** The hero row carries `data-video-mobile="yes"`, and BB's own JavaScript appends the `<video>` only when `!_isMobile() || videoMobile == "yes"`. Setting **Show Video On Mobile = No** skips it on mobile user agents — the profile Lighthouse emulates and the profile that scores 21. Desktop keeps the video. About five minutes, no design approval. That is step 1.

**The CLS does not come from a missing row height.** The row already has explicit padding at all three breakpoints. The served markup carries no `data-width`/`data-height`, so BB inserts the video at one size and re-sizes it on `loadedmetadata` — a shift gated on the video download. The desktop fix is a CSS rule on `.fl-bg-video video`, not a row setting.

**Nothing about the hero is in the HTML.** Zero `<video>`, zero `<source>`, zero `poster` attributes. Beaver Builder builds all of it in JavaScript from `data-` attributes, hardcodes a 1×1 GIF poster, and applies the real fallback image as a CSS background on the element it just created. That is why discovery takes 15.8 seconds and why nothing paints early.

**A page-speed plugin is loaded and the frontend shows no sign of it.** 10Web Booster's REST routes are registered — `set_critical`, `page_cache`, `regenerate_webp` — on a page with zero `defer`, zero `async`, no critical CSS, and no CDN. There are three plausible explanations, one of which would reorder the whole sequence, and the audit cannot distinguish them from outside. Check it before hand-writing work it may already do.

**About 2 hours 45 minutes needs no design approval and no plugin installs** — steps 1-8 of audit 1 §8. The first two steps are 20 minutes of that and carry most of the value.

**Software is current; its dependencies are not.** WordPress 7.0.2 is the version `api.wordpress.org` reports as current, and Yoast 28.1 is the latest release. What is stale is vendored inside those current plugins — Bootstrap 3.4.1 (EOL 2019), Swiper 8.4.7, fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1 — and no plugin update reaches any of it.

**There is no configuration path to a green score.** The ceiling is 3,197 rendered DOM elements, a 10,883 ms Beaver Builder layout bundle, four libraries doing two jobs, and 3,820 ms of third-party main-thread blocking.

## Measurement Caveat

**Both measurement methods used here are noisy, and the audits say so at every figure.**

Two Lighthouse runs of the identical, unmodified site produced a **6-point score spread, 3.0 s of LCP, 3,810 ms of TBT, and a 3.2× swing in reported payload**. Two full header sweeps of identical content 78 minutes apart produced cold-cache TTFB medians of **0.845 s and 1.788 s**, maxima of 2.654 s and 4.946 s, and **completely disjoint lists of the five slowest pages**.

Take the median of 3+ Lighthouse runs and re-run the header sweep before declaring any fix successful. Treat single-run differences smaller than the spreads above as noise. The one figure stable across all 90 warm observations is warm-cache TTFB, at 52-113 ms.

## Revision History

Documents 1, 3, and 5 are at revision 3 (2026-07-30). Every revision has been a correction pass, and the corrections have gone in both directions — some findings were understated, several were simply wrong.

### rev. 3 — corrections to rev. 2, after adversarial review

Rev. 2 was reviewed by three independent critics chartered to refute it. Its **measurements** survived: versions, plugin inventory, headers, per-asset bytes, and the Lighthouse transcription were all reproduced. Its **recommendations** did not.

| Claim | Correction |
|---|---|
| **HIGH: a Google Maps iframe loads eagerly in live DOM** | **False. The iframe carries `loading="lazy"`.** Rev. 2 classified iframes on `src` vs `data-src` and truncated each element before the deciding attribute. Finding withdrawn, along with the dependent claim that the 3,820 ms third-party total was "a floor." |
| "Set a row height, or `aspect-ratio` on `.fl-bg-video`. Removes all of CLS." | Both inert. The row is already sized by padding; `.fl-bg-video` is `position:absolute` with all insets `0`, so `aspect-ratio` is ignored. The shift is Beaver Builder's `loadedmetadata` re-size. |
| "A preload lets the browser fetch the poster during the blocking window" | Preload warms the HTTP cache and paints nothing — BB applies the fallback as a background-image on the `<video>` it creates in JS. Needs a companion CSS rule. |
| The fix list omitted the mobile gate | `data-video-mobile="yes"` was quoted in rev. 2's own evidence block and never used. It is now step 1 and the largest single change available. |
| "REST namespaces register only for active plugins" | Over-general — mu-plugins register routes with no activation state, and `/wp-content/mu-plugins/` exists on this site. Reworded to "the code is loaded." |
| Step 1 verification: `grep -c 'defer\|async'` > 0 | **Returns 25 on the unmodified site** — core emits `decoding="async"` on 23 images and `grep -c` counts lines. The gate could not fail. |
| "Remove `fetchpriority` via the BB photo module" | It is emitted by WordPress core, not BB — and once the eager images become lazy, core moves the attribute to the next one. |
| "46.8 KiB per page of unused core assets" | **25,169 B.** The other 22,752 B is an emoji script fetched only when a browser fails the emoji test, which real browsers pass. The recommended `remove_action` was also a no-op — that function has been deprecated since WP 6.4. |
| Three byte budgets | All three unreachable by their own stated mechanisms. Recomputed. |
| "All 7 images lack `width`/`height`" | **6 of 7.** And the omission is probably causal — core declines to lazy-load images whose dimensions it cannot resolve. |
| "Install LSCache just for its crawler" | The plugin is the control plane for the server module and rewrites `.htaccess`. A cron'd `curl` loop warms the same cache in 15 minutes and is now the first option. |
| "Every modern browser supports WebM" | iOS Safari gained full support at 17.4. WebM-only is a design change on real traffic. |
| "Parse bytes are the operative unit" | Refuted by the audit's own main-thread table — Script Parse & Compile is 383 ms of 36,900, about 1%. Narrowed to: rank by measured per-script CPU. |
| Byte totals | Python `len(str)` character counts, not bytes. HTML is 218,440 B, not 217,984, and `swiper.min.css` was missing from the CSS total entirely. |
| "Sweeps ~5 hours apart"; cold TTFB "0.475 s" floor; warm "53-113 ms" | ETag mtimes put the sweeps **78 minutes** apart. Cold floor is 0.406 s; warm range is 0.052-0.113 s. |

### rev. 2 — corrections to rev. 1

| Claim | Correction |
|---|---|
| "Set the video's `poster`; reorder the two `<source>` elements" | The HTML has **0** `<video>`, **0** `<source>`, **0** `poster=`. Rev. 1 quoted Lighthouse's *rendered-DOM* snippet as if it were source markup. |
| Named the 5 slowest pages on cache MISS | A second sweep produced a **disjoint** set of 5 on identical content. Per-page cold-cache ranking is not reproducible; claim withdrawn. |
| No plugin inventory anywhere in the repo | 10 loaded plugins enumerated via `GET /wp-json/`, including the page-speed plugin that is loaded and inert. |
| `.jpg.webp` listed as a defect to fix | The origin returns `content-type: image/webp` correctly. Latent risk under a future CDN, not a current defect. |

### rev. 1 — corrections to the 2026-07-28 original

| Claim | Correction |
|---|---|
| "HTML served uncompressed, 216 KB raw" — CRITICAL | Wrong. 44/44 URLs serve Brotli, 81% saved. The original was verified with `curl -sI` (HEAD); this server omits `content-encoding` from HEAD responses. Finding deleted. |
| "No page caching, TTFB 2,540 ms on every load" — CRITICAL | Partly wrong. Server-level cache is active; warm TTFB is 52-113 ms. The 2,540 ms figure is on the cold-cache path, which real visitors do hit. Reframed as a pre-warming problem. |
| "33 render-blocking resources" | Wrong. Lighthouse flags 11. The figure 33 came from a different audit — "Avoid chaining critical requests: 33 chains". |
| "GTM — 4 KB, minimal, already async, OK" | Wrong. 275 KiB and 1,165 ms of blocking — the second-largest third-party cost. |
| "`/us/` returns 404" — CRITICAL | Wrong. Returns 200 with full content and is in the sitemap. The practitioner-schema gap survives; the broken-page claim does not. |
| "`/neuropathy-center-lp/` has zero metadata" | Mostly wrong. Meta description, OG tags, and canonical are all present. Only JSON-LD is missing. |
| "Page weight 16,558 KB, 90% one file" | Conflated file size with transfer size. The video is 15.3 MB on disk; 3,112 KiB actually transfers. Payload is 5,123 KiB. |
| "Estimated time-to-green: ~10-14 hours" | No projection in the repository reached green. Removed. |
| Duplicate `01-seo-performance-audit.md` | Deleted. It was unlinked from this README and still contained findings corrected in later commits. |

Full method notes: [audit/data/README.md](audit/data/README.md).
