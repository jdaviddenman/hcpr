# Lighthouse Mobile Run — 2026-07-30

**Captured:** Jul 30, 2026, 6:13 PM EDT | **Tool:** Lighthouse 12.6.0, Chromium 138.0.0.0
**Conditions:** Emulated Moto G Power, Slow 4G throttling, single page session, initial page load
**URL:** `https://www.highcountrypainrelief.com/`

## Scores and metrics — both runs

| Metric | 2026-07-28 run | 2026-07-30 run | Delta |
|---|---|---|---|
| Performance | 27 | **21** | -6 |
| FCP | 3.0 s | 3.0 s | 0 |
| LCP | 15.9 s | **18.9 s** | +3.0 s |
| TBT | 18,520 ms | **14,710 ms** | -3,810 ms |
| CLS | 0.184 | 0.184 | 0 |
| Speed Index | 17.2 s | **14.1 s** | -3.1 s |
| Total network payload | 16,558 KiB | **5,123 KiB** | -11,435 KiB |

No remediation was performed between the two runs. **The deltas are run-to-run variance**, and they are large: 6 score points, 3.0 s of LCP, 3,810 ms of TBT, and a 3.2× swing in reported payload. Any single-run figure from this site carries at least that much uncertainty. Payload varies most because the browser aborts the hero video download at a different point each run.

## LCP breakdown

**Element:** `div.fl-row > div.fl-row-content-wrap > div.fl-bg-video > video`

```html
<video autoplay loop muted playsinline
  poster="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIB…"
  style="background-image: url('https://www.highcountrypainrelief.com/wp-content/up…')">
```

The `poster` attribute is a 1×1 transparent GIF data URI — a placeholder, not a real poster frame.

| Phase | % of LCP | Timing | 07-28 run |
|---|---|---|---|
| TTFB | 4% | 700 ms | 16% / 2,550 ms |
| Load Delay | 83% | 15,760 ms | 80% / 12,730 ms |
| Load Time | 1% | 240 ms | 1% / 140 ms |
| Render Delay | 12% | 2,190 ms | 3% / 520 ms |

TTFB dropped from 2,550 ms to 700 ms and from 16% of LCP to 4%. **TTFB is no longer a material LCP contributor.**

## Main-thread work — 36.9 s total

| Category | Time |
|---|---|
| Script Evaluation | 16,263 ms |
| Other | 10,512 ms |
| Parse HTML & CSS | 5,664 ms |
| Style & Layout | 3,355 ms |
| Rendering | 501 ms |
| Script Parsing & Compilation | 383 ms |
| Garbage Collection | 234 ms |

## JavaScript execution — 16.3 s

| Source | Total CPU | Script Eval | Script Parse |
|---|---|---|---|
| **highcountrypainrelief.com** | 24,252 ms | 12,288 ms | 88 ms |
| `cache/2-layout.js` | 10,883 ms | 10,081 ms | 10 ms |
| the document itself | 10,224 ms | 189 ms | 7 ms |
| `jquery.min.js?ver=3.7.1` | 1,589 ms | 1,315 ms | 11 ms |
| `swiper.min.js?ver=8.4.7` | 1,497 ms | 650 ms | 56 ms |
| `wp-emoji-release.min.js` | 59 ms | 53 ms | 4 ms |
| **userway.org** | 5,363 ms | 2,062 ms | 67 ms |
| **Unattributable** | 4,755 ms | 262 ms | 0 ms |
| **Google Tag Manager** | 1,448 ms | 1,231 ms | 144 ms |
| **reviewwave.com** | 584 ms | 160 ms | 19 ms |

## Third-party main-thread blocking — 3,820 ms total

| Third party | Transfer | Blocking |
|---|---|---|
| **userway.org** | 137 KiB | **2,443 ms** |
| `widget_app_base_178….js` | 47 KiB | 2,354 ms |
| `widget_base.css` | 71 KiB | 87 ms |
| `widget.js` | 2 KiB | 2 ms |
| **Google Tag Manager** | 275 KiB | **1,165 ms** |
| `gtm.js?id=GTM-WGXQKR5` | 115 KiB | 831 ms |
| `gtag/js?id=G-CW4KKYCP1V` | 159 KiB | 334 ms |
| **reviewwave.com** | 16 KiB | 196 ms |
| **rw-embed-data.s3.amazonaws.com** | 58 KiB | 14 ms |
| **inceptionimages.com** | 3,196 KiB | 0 ms |
| `2018/02/hiking.mp4` | 3,112 KiB | 0 ms |
| `Chiropractor-Near-Me-Book-Online-Moto-Footer.webp` | 84 KiB | 0 ms |
| **YouTube** (35 thumbnails) | 459 KiB | 0 ms |
| **Google Fonts** | 57 KiB | 0 ms |
| **Vimeo** | 15 KiB | 0 ms |

Note: `hiking.mp4` transferred **3,112 KiB**, not the full file. `curl` reports `content-length: 15,343,649` (14.6 MiB); the browser aborts the download partway. Transfer size and file size are different numbers and the audits conflated them.

## Payload composition — 5,123 KiB total

| Source | KiB | % |
|---|---|---|
| inceptionimages.com | 3,196 | 62.4% |
| highcountrypainrelief.com (1st party) | ~910 | ~17.8% |
| YouTube thumbnails | 459 | 9.0% |
| Google Tag Manager | 275 | 5.4% |
| UserWay | 137 | 2.7% |
| AWS S3 (ReviewWave config) | 58 | 1.1% |
| Google Fonts | 57 | 1.1% |
| ReviewWave | 16 | 0.3% |
| Vimeo | 15 | 0.3% |

## Render-blocking resources — 1,370 ms estimated savings

**11 resources**, not 33.

| Group | Transfer | Est. savings |
|---|---|---|
| **highcountrypainrelief.com** (7 resources) | 104.3 KiB | 1,950 ms |
| `jquery.min.js?ver=3.7.1` | 29.1 KiB | 450 ms |
| `cache/2-layout.css` | 20.3 KiB | 450 ms |
| `bootstrap.min.css` | 17.9 KiB | 300 ms |
| `cache/834bc5f…-layout-bundle.css` | 14.8 KiB | 300 ms |
| `all.min.css?ver=2.10.3` | 12.1 KiB | 150 ms |
| `bb-theme/skin-6a6bcbee4c24e.css` | 7.1 KiB | 150 ms |
| `jquery.fancybox.min.css?ver=3.5.4` | 2.9 KiB | 150 ms |
| **rw-embed-data.s3.amazonaws.com** (1) | 55.7 KiB | 1,570 ms |
| **cdn.reviewwave.com** (2) | 11.5 KiB | 940 ms |
| `reviews_embed.js` | 4.1 KiB | 790 ms |
| `chat_embed.js` | 7.4 KiB | 150 ms |
| **fonts.googleapis.com** (1) | 1.2 KiB | 790 ms |

The page has 19 scripts and 13 stylesheets in total (verified by source inspection); Lighthouse flags 11 as render-blocking. The separate "Avoid chaining critical requests" audit reports **33 chains** — a different number for a different thing, and easily confused with a render-blocking count.

## Text compression — 37 KiB estimated savings

| URL | Transfer | Est. savings |
|---|---|---|
| `rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js` | 55.3 KiB | 36.6 KiB |

**One resource, third-party.** The site's own HTML is absent because it is already Brotli-compressed — 44/44 sitemap URLs serve `content-encoding: br`, 81% saved. (A HEAD request hides this: the server omits `content-encoding` from HEAD responses.)

## Cumulative Layout Shift — 0.184

| # | Element | Score | Root cause |
|---|---|---|---|
| 1 | `div.fl-bg-video > video` | **0.184** | Media element lacking an explicit size |
| 2 | "New Patient Special Offer" `<a class="uabb-button">` | 0.000 | Web fonts loaded (2 × woff2 from fonts.gstatic.com) |
| 3 | `img.rws-chat-img` "agent portrait" (ReviewWave chat) | 0.000 | Media element lacking an explicit size |

The entire CLS score comes from shift #1. The hero video has no explicit dimensions.

## Offscreen images — 758 KiB estimated savings

| Group | KiB |
|---|---|
| YouTube (35 thumbnails, `i.ytimg.com`) | 457.8 |
| highcountrypainrelief.com (5 images) | 202.4 |
| inceptionimages.com (1 image) | 83.6 |
| Vimeo (1 thumbnail) | 14.7 |
| **Total** | **758.5** |

1st-party offscreen images: `Chronic-Pain-Boone-NC-Knee-Pain-Red.webp` 53.6 KiB, `…Woman-With-Shoulder-Pain.webp` 50.8 KiB, `…Back-Pain.webp` 43.5 KiB, `…Neuropathy.webp` 40.8 KiB, `Chiropractic-Boone-NC-ASMST-Logo.webp` 13.7 KiB.

758 KiB is the total across all offscreen images; the YouTube thumbnails are 457.8 KiB of it.

## DOM

| Statistic | Value |
|---|---|
| Total DOM elements | 3,197 |
| Maximum DOM depth | 28 (`div.pp-video-play-icon > svg > g > path`) |
| Maximum child elements | 105 (`div.pp-video-gallery-items.swiper-wrapper`) |

## Remaining diagnostics

| Audit | Value |
|---|---|
| Serve static assets with an efficient cache policy | 197 resources |
| Reduce unused JavaScript | 127 KiB |
| Properly size images | 20 KiB (`Best-of-W….webp`, 84.8 KiB → 19.9 KiB savings) |
| Avoid serving legacy JavaScript | 7 KiB |
| Avoid long main-thread tasks | 20 long tasks |
| Avoid non-composited animations | 5 animated elements |
| Avoid chaining critical requests | 33 chains |
| Image elements do not have explicit width and height | fails |
| Ensure text remains visible during webfont load | fails |
| Passed audits | 19 |

"Reduce unused CSS" and "Minify JS" did **not** appear in this run.
