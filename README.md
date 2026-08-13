# HCPR — High Country Pain Relief

Page speed performance audit, architecture review, and remediation roadmap for [highcountrypainrelief.com](https://www.highcountrypainrelief.com).

## Documents

| # | Document | Scope |
|---|----------|-------|
| — | **[Priority Fixes](PRIORITY-FIXES.md)** | **The deliverable.** Plain-English summary for the practice and Inception, plus three self-contained work tickets. Re-measured live 2026-08-13; survived six adversarial passes. **Send this one.** |
| — | [Verifying Backend Claims](VERIFYING-BACKEND-CLAIMS.md) | How to confirm from outside that an asserted fix is live and reaching visitors. Four traps on this server that make a correct fix look failed — and an unshipped one look successful. Runnable census: [`audit/data/verify-live.sh`](audit/data/verify-live.sh). |
| — | [Security Findings](SECURITY-FINDINGS.md) | Separate register. Five items surfaced passively while measuring: an unauthenticated debug endpoint, REST user enumeration, no security headers, a migration leftover, and one unassessed gap. |
| 1 | [Page Speed Performance Audit](audit/01-page-speed-performance-audit.md) | Lighthouse 21/100 mobile. LCP breakdown, main-thread analysis, 24 findings, 24-step implementation sequence. **Start here.** |
| 2 | [Spelling & Grammar Audit](audit/02-spelling-grammar-audit.md) | 35 confirmed errors, 4 style preferences, 1 unverified. Site-wide chrome plus 4 content pages. |
| 3 | [Page Load & Caching Deep-Dive](audit/03-page-load-caching-deep-dive.md) | Cache policy by domain, cold-cache analysis across two sweeps, YouTube facade, Beaver Builder cache behaviour, third-party load table. |
| 4 | [On-Page SEO & Content Findings](audit/04-seo-content-findings.md) | Metadata gaps, schema format errors, security register. Outside page speed scope. |
| 5 | [Architecture, Version Currency & Code Quality](audit/05-architecture-and-code-quality.md) | Full plugin inventory, WordPress and library version currency, per-asset byte accounting, 10 code-quality indicators. |
| — | [Measured evidence](audit/data/) | Lighthouse extract, two 44-URL header sweeps, reproducer script. |

## Current State

**Re-measured 2026-08-13**, including three fresh Lighthouse runs (12.8.2, Chrome for Testing 152, mobile,
median of 3). July figures shown for comparison — see the caveat below the table.

| Metric | Aug 2026 (median of 3) | Jul 2026 | Threshold | Notes |
|--------|------|------|-----------|-------|
| Performance (mobile) | **33/100** | 21 | 90+ | Aug runs: 27 / 33 / 34 |
| LCP | **12.2 s** | 18.9 s | <2.5 s | 65-73% is Load Delay on the hero video; same element both months |
| CLS | **0.000 warm / 0.184 cold** | 0.184 | <0.1 | Appears only on a cache MISS — the path a first-time visitor takes |
| FCP | **3.9 s** | 3.0 s | <1.8 s | |
| Speed Index | **7.1 s** | 14.1 s | <3.4 s | |
| TBT | **1,684 ms** | 14,710 ms | — | **host-dependent, see caveat.** Not a Core Web Vital; Google publishes no threshold |
| Main-thread work | **10.6 s** | 36.9 s | — | host-dependent |
| Network payload | **16,986 KiB** | 5,123 KiB | — | **~88% is the hero video, now downloading in full (~15 MB)**. July's browser aborted it partway |
| TTFB, cold cache | **1.054 s** median | 0.845-1.788 s | — | 12 of 12 first requests were cold |
| TTFB, warm cache | **0.076 s** median | 0.052-0.113 s | — | stable |
| DOM elements, rendered | **3,181** | 3,197 | <1,500 | max child elements 105 in both months — the Swiper loop clones |

> **The CPU rows are not comparable across the two months, and the site is not why.** Lighthouse
> calibrates the simulated *network* but applies a fixed ×4 CPU multiplier to whatever machine runs it.
> August ran at `benchmarkIndex` ≈ 1,300; July's index was not recorded. **Quote CPU figures with the
> host attached, or not at all.** What reproduced exactly across both: the LCP element and its selector,
> CLS coming from that one element, 105 max child elements, DOM depth 28, the render-blocking leader
> (ReviewWave's S3 config), and the third-party cost ranking (UserWay 1st, GTM 2nd, ReviewWave 3rd).

## The Short Version

**One Beaver Builder dropdown stops 60.7% of mobile payload being fetched.** The hero row carries `data-video-mobile="yes"`. On a mobile user agent BB's else-branch sets `src=""` on the `<video>` instead of leaving its two `<source>` children active, so neither video file is downloaded — and the fallback WebP that BB has already attached as a background paints instead, becoming the new LCP element at 77 KB, first-party. Setting **Show Video On Mobile = No** takes about five minutes and needs no design approval. It does **not** remove the `<video>` element; check for the absent video *request*, not the absent element. That is step 1.

**The CLS does not come from a missing row height.** The row already has explicit padding at all three breakpoints. The served markup carries no `data-width`/`data-height`, so BB inserts the video at one size and re-sizes it on `loadedmetadata` — a shift gated on the video download. The desktop fix is a CSS rule on `.fl-bg-video video`, **with every declaration `!important`**: BB writes both sizes through jQuery `.css()`, i.e. inline styles, and re-applies them on a debounced `resize`.

**Nothing about the hero is in the HTML.** Zero `<video>`, zero `<source>`, zero `poster` attributes. Beaver Builder builds all of it in JavaScript from `data-` attributes, hardcodes a 1×1 GIF poster, and applies the real fallback image as a CSS background on the element it just created. That is why discovery takes 15.8 seconds and why nothing paints early.

**A page-speed plugin is loaded and the frontend shows no sign of it.** 10Web Booster's REST routes are registered — `set_critical`, `page_cache`, `regenerate_webp` — on a page with zero `defer`, zero `async`, no critical CSS, and no CDN. There are three plausible explanations, one of which would reorder the whole sequence, and the audit cannot distinguish them from outside. Check it before hand-writing work it may already do.

**Between 3 h 25 min and 4 h 25 min needs no design approval and no plugin installs** — steps 1-8 of audit 1 §8. The first two steps are 20 minutes of that and carry most of the value.

**Software is current; its dependencies are not.** WordPress 7.0.2 is the version `api.wordpress.org` reports as current, and Yoast 28.1 is the latest release. What is stale is vendored inside those current plugins — Bootstrap 3.4.1 (EOL 2019), Swiper 8.4.7, fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1 — and no plugin update reaches any of it.

**There is no configuration path to a green score.** The ceiling is 3,197 rendered DOM elements, a 10,883 ms Beaver Builder layout bundle, four libraries doing two jobs, and 3,820 ms of third-party main-thread blocking.

## Measurement Caveat

**Both measurement methods used here are noisy, and the audits say so at every figure.**

Two Lighthouse runs of the identical, unmodified site produced a **6-point score spread, 3.0 s of LCP, 3,810 ms of TBT, and a 3.2× swing in reported payload**. Two full header sweeps of identical content 78 minutes apart produced cold-cache TTFB medians of **0.845 s and 1.788 s**, maxima of 2.654 s and 4.946 s, and **completely disjoint lists of the five slowest pages**.

Take the median of 3+ Lighthouse runs and re-run the header sweep before declaring any fix successful. Treat single-run differences smaller than the spreads above as noise. The one figure stable across all 90 warm observations is warm-cache TTFB, at 52-113 ms.

## Revision History

Documents 1, 3, and 5 are at revision 4 (2026-07-31). Every revision has been a correction pass, and the corrections have gone in both directions — some findings were understated, several were simply wrong, and rev. 4 had to undo one thing rev. 3 had "corrected" while it was already right.

**The pattern across four adversarial reviews is worth stating plainly: the measurements have survived every attack; the reasoning has needed correcting every time.** Byte accounting, sweep statistics, the markup census, and the Lighthouse transcription have been independently reproduced at each pass. Recommendations derived from reading Beaver Builder and WordPress source have not.

### rev. 4 — corrections to rev. 3, after a fourth adversarial review

Rev. 3 was reviewed by a critic chartered against **rev. 3's own new reasoning**, not the material three earlier critics had already checked. All four defects it found were in code-derived claims rev. 3 had added.

| Claim | Correction |
|---|---|
| "Show Video On Mobile = No **skips the append entirely**" — verified by "no `<video>` in `.fl-bg-video`" | `wrap.append(videoTag)` appears in **both** branches. The else-branch sets `src=""`, which stops both video files being fetched, and appends the element anyway. The verification would have reported failure on a correct fix. |
| The CSS rule makes BB's two sizing passes "**no-ops**" | Both are jQuery `.css()` inline writes, re-applied on a debounced `resize`. Every declaration now carries `!important`. |
| Adding `width`/`height` "**may make core add `loading="lazy"` by itself**" | Refuted by six counterexamples on the same page. Effort re-scoped 20 min → 1-2 hrs; the targets span three plugin templates. |
| "`remove_action('wp_print_styles','print_emoji_styles')` is a **silent no-op**" | Backwards. WP 7.0.2 still registers that hook and treats unhooking it as the supported disable path. Rev. 3's replacement left the deprecated function running. **Rev. 2 was right; reverted to it.** |
| "62% of mobile payload" | 60.7%. 62.4% is the whole image host, including a footer image the setting does not touch. |
| "16-20 hours" for the full sequence | Its own per-step figures summed to 14.1-18.3. Now 14.8-20.0. |
| `audit/03` labelled rev. 3 | It still prescribed both remedies rev. 3 withdrew, and three of its four step cross-references were wrong. |

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
