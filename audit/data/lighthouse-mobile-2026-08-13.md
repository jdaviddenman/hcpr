# Lighthouse Mobile — 3 runs, 2026-08-13

**Captured:** 2026-08-13 12:02–12:04 UTC · **Tool:** Lighthouse 12.8.2, Chrome for Testing 152.0.7977.42
(`chrome-headless-shell`, Debian 12) · **Conditions:** `--form-factor=mobile --screenEmulation.mobile`,
simulated throttling (RTT 150 ms, 1,638 kbps down, **CPU slowdown ×4**), initial page load
**URL:** `https://www.highcountrypainrelief.com/`

This supersedes nothing. It sits **alongside** `lighthouse-mobile-2026-07-30.md`, and the two are **not
directly comparable** — see "Why the July and August numbers differ" below. Raw JSON was not committed
(3 × 1.4 MB); re-run with the command at the foot of this file.

## The three runs

| | Run 1 | Run 2 | Run 3 | **Median** |
|---|---|---|---|---|
| Performance | 27 | 33 | 34 | **33** |
| FCP | 3.0 s | 3.9 s | 3.9 s | **3.9 s** |
| LCP | 10.2 s | 12.2 s | 12.2 s | **12.2 s** |
| TBT | 1,604 ms | 1,830 ms | 1,684 ms | **1,684 ms** |
| CLS | **0.184** | 0.000 | 0.000 | **0.000** |
| Speed Index | 8.3 s | 7.1 s | 7.1 s | **7.1 s** |
| Server response | 2,037 ms | 6 ms | 6 ms | **6 ms** |
| Total payload | 16,925 KiB | 16,986 KiB | 17,388 KiB | **16,986 KiB** |
| Main-thread work | 11.2 s | 10.6 s | 10.2 s | **10.6 s** |
| `benchmarkIndex` | 1,317 | 1,293.5 | 1,338.5 | — |

**The spread across three runs of an unchanged site is 7 score points, 2.0 s of LCP, 226 ms of TBT, and
all of CLS.** Same warning as July: treat any single run as a wide-error-bar sample.

## Three findings that only appear with more than one run

### 1. The hero video now downloads in full — about 15 MB

| Run | `hiking.mp4` transferred |
|---|---|
| 1 | 14,392 KiB + 576 KiB (two range requests) |
| 2 | 9,813 KiB + 5,216 KiB |
| 3 | — same pattern |

`inceptionimages.com` totals **15,060–15,122 KiB**, i.e. essentially the whole 15,343,649-byte file.

**The video is ~88% of a ~17 MB page**, not "60.7% of 5,123 KiB". The July run recorded 3,112 KiB because
the browser aborted the download partway; it did not abort here. Where the abort lands is not stable, so
**payload figures from any single run are unreliable, and the July figure was the optimistic end.** The
directional claim is unaffected and gets stronger: this one file is the overwhelming majority of the page.

### 2. CLS is intermittent, and it appeared on the cold-cache run

| Run | Server response | CLS |
|---|---|---|
| 1 | **2,037 ms** (LiteSpeed MISS) | **0.184** |
| 2 | 6 ms (HIT) | 0.000 |
| 3 | 6 ms (HIT) | 0.000 |

The shift is the same element every time it appears — `div.fl-bg-video > video`, scoring 0.1841 of the
0.1841 total. **The one run that shifted is the one where the document arrived slowly**, which is the path
a first-time visitor takes: 12 of 12 first requests to this site are cache misses (measured 13 Aug).

*Mechanism is inference, not measurement.* The plausible reading is that a slow document changes when the
video's metadata arrives relative to Beaver Builder's first sizing pass, so the second pass produces a
visible reflow. **Do not treat "CLS 0.000" from a warm run as evidence the problem is gone.** Any CLS
verification must be run against a cold cache.

Run 1 also recorded a second, smaller shift the July run did not itemise: **0.0080** on
`div.uabb-infobox-title-wrap > p` — a web-font shift, consistent with the missing `font-display: swap`
(audit M5).

### 3. Absolute CPU numbers are host-dependent; the ranking is not

TBT of **1,684 ms** here against **14,710 ms** in July, and main-thread work of **10.6 s** against
**36.9 s**, on a site whose scripts barely changed. Lighthouse's simulated throttling calibrates the
*network* but applies a **fixed ×4 CPU multiplier to whatever host it runs on**. A fast host produces
optimistic CPU figures and a slow host pessimistic ones. `benchmarkIndex` was ~1,300 here; the July run's
index was not recorded, so the two cannot be reconciled.

**Neither figure is "what a Moto G Power does."** Quote TBT and main-thread totals only with the host
attached, or not at all. What survives across both runs is the **ranking**, and it is identical:

| | July | August | Rank |
|---|---|---|---|
| UserWay | 2,443 ms | **481–495 ms** | 1st third party, both runs |
| Google Tag Manager | 1,165 ms | **297–351 ms** | 2nd, both runs |
| ReviewWave | 196 ms | 33 ms | 3rd, both runs |
| `2-layout.js` (Beaver Builder) | 10,883 ms | **2,371 ms** (2,161 ms eval) | largest first-party script, both runs |

## What reproduced exactly

| Finding | July | August |
|---|---|---|
| LCP element | `div.fl-bg-video > video` | **identical selector** |
| LCP Load Delay share | 83% (15,760 ms) | **65–73% (7,527–7,901 ms)** |
| CLS source | one element, the hero video | **identical**, 0.1841 of 0.1841 |
| Max child elements | 105 | **105** — the Swiper loop clones |
| DOM elements | 3,197 | **3,181** |
| Max DOM depth | 28 | **28** |
| Render-blocking headline | 1,370 ms | **1,330 ms** |
| Largest render-blocker | S3 config, 1,570 ms | **S3 config, 1,451 ms** |

## Render-blocking, this run

| Est. savings | Transfer | Resource |
|---|---|---|
| **1,451 ms** | 56.3 KiB | `rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js` |
| 790 ms | 1.5 KiB | `fonts.googleapis.com/css?family=Raleway…` |
| 761 ms | 4.1 KiB | `cdn.reviewwave.com/js/reviews_embed.js` |
| 306 ms | 29.1 KiB | `jquery.min.js` |
| 306 ms | 17.9 KiB | `bootstrap.min.css` |
| 306 ms | 14.8 KiB | `layout-bundle.css` |
| 153 ms | 7.1 KiB | `bb-theme/skin-*.css` |
| 152 ms | 7.4 KiB | `cdn.reviewwave.com/js/chat_embed.js` |

Headline **1,330 ms**; the rows sum to more. Same internal inconsistency July showed. Neither is a
prediction. **Three of the top three are ReviewWave and Google Fonts** — which is Ticket 2, step 1 and
audit M5.

## Main-thread work — 11.2 s (run 1)

| Category | Time |
|---|---|
| Script Evaluation | 4,156 ms |
| Other | 3,260 ms |
| Style & Layout | 1,583 ms |
| Parse HTML & CSS | 1,395 ms |
| Rendering | 364 ms |
| Script Parsing & Compilation | **289 ms** |
| Garbage Collection | 125 ms |

Script Parsing & Compilation is **2.6% of the total** — August confirms July's H1 correction. Rank
remediation by measured CPU, never by raw bytes.

## Reproducing this

```bash
npx --yes @puppeteer/browsers install chrome-headless-shell@stable
sudo apt-get install -y libglib2.0-0 libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 \
  libatspi2.0-0 libdbus-1-3 libgbm1 libasound2 libx11-6 libxcb1 libxcomposite1 \
  libxdamage1 libxext6 libxfixes3 libxkbcommon0 libxrandr2 libcups2 libpango-1.0-0 libcairo2

export CHROME_PATH=<path>/chrome-headless-shell
for i in 1 2 3; do
  npx --yes lighthouse@12 https://www.highcountrypainrelief.com/ \
    --only-categories=performance --form-factor=mobile --screenEmulation.mobile \
    --output=json --output-path=lh-$i.json --quiet \
    --chrome-flags="--headless --no-sandbox --disable-dev-shm-usage"
done
```

**Record `environment.benchmarkIndex` from every run.** Without it the CPU metrics cannot be compared
against anyone else's.

## Limits

1. **Three runs, one host, one location, one hour.** Not a distribution.
2. **`chrome-headless-shell`, not full Chrome.** Adequate for these metrics; it is not the browser a
   visitor uses.
3. **No desktop run.** Ticket 1's CLS fix is the desktop-side fix and remains unmeasured on desktop.
4. **Lab data, not field data.** Google's ranking systems read the Chrome UX Report, not this. Whether
   CrUX holds any record for this origin is still unknown — check Search Console.
5. **CLS appeared in 1 of 3 runs.** n=1 for the positive observation. It reproduces July exactly, on the
   same element, which is why it is reported rather than dismissed as noise.
