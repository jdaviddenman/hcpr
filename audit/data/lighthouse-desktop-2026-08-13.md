# Lighthouse Desktop — 3 runs, 2026-08-13

**15:33–15:35 UTC** · Lighthouse 12.8.2, Chrome for Testing 152.0.7977.42 (`chrome-headless-shell`,
Debian 12) · `--preset=desktop` (desktop form factor, no CPU throttle, desktop network) ·
`https://www.highcountrypainrelief.com/`

This is the first desktop measurement in the project. The 2026-07-28 audit reported "47/100 desktop" from
a single run with no detail; audit 01 limitation #4 recorded desktop as unmeasured. It is measured now.

## The three runs

| | Run 1 | Run 2 | Run 3 | **Median** | Threshold |
|---|---|---|---|---|---|
| Performance | 57 | 57 | 51 | **57** | 90+ |
| FCP | 0.8 s | 0.8 s | 0.8 s | **0.8 s** | <1.8 s — **pass** |
| LCP | 2.4 s | 2.3 s | 2.6 s | **2.4 s** | <2.5 s — **pass (borderline)** |
| **CLS** | **0.199** | **0.212** | **0.199** | **0.199** | <0.1 — **FAIL** |
| TBT | 360 ms | 383 ms | 478 ms | **383 ms** | host-dependent |
| Speed Index | 2.3 s | 2.0 s | 2.1 s | **2.1 s** | <3.4 s — **pass** |
| Server response | 5 ms | 8 ms | 5 ms | **5 ms** | warm |
| Total payload | 18,639 KiB | 17,584 KiB | 17,181 KiB | **17,584 KiB** | — |
| `benchmarkIndex` | 1,252 | 1,244 | 1,232 | — | — |

## The finding: CLS is desktop's only failing vital, and it fails every run

**Desktop CLS is 0.199 — nearly 2× the 0.1 threshold — on all three runs, all warm cache.** The source is
the same element as on mobile: `div.fl-row > div.fl-row-content-wrap > div.fl-bg-video > video`, the hero
video's `loadedmetadata` resize.

This is worse and more reliable than the mobile shift:

| | Mobile (2026-08-13) | Desktop (2026-08-13) |
|---|---|---|
| CLS | 0.184, on **1 of 3** runs (the cold-cache run only) | **0.199, on 3 of 3** runs, all warm |
| Why | tied to cold-document timing | the video always loads on desktop, so the resize always fires |

On desktop the mobile gate does not apply, so the video loads on every visit and shifts the page every
time. FCP, LCP and Speed Index all pass on desktop; **CLS is the one thing failing.** The fix is the
child-theme `!important` rule (PRIORITY-FIXES.md, Ticket 1 step 1B). Because the video is not being removed
on desktop, that rule is the **only** remedy for the desktop shift.

## Everything else, desktop

- **LCP 2.4 s, passing but borderline** (run 3 was 2.6 s). Load Delay is 82% (1,948 ms) — same
  build-the-video-in-JS cause as mobile, smaller because desktop has no CPU throttle.
- **Payload ~17.5 MB** — the hero video loads on desktop too (~10.5 MB transferred here). C1's payload
  argument applies to desktop as well, though there is no equivalent of the mobile "video off" switch.
- **DOM 3,180 elements, depth 28, max child 105** — identical gallery-clone structure. The Loop/Autoplay
  fix (Ticket 3 part 1) applies to desktop unchanged.
- **Third-party blocking:** UserWay 127 ms, GTM 29 ms — same ranking as mobile, smaller absolute numbers.
- Main-thread work 3.0 s; render-blocking headline 400 ms.

## Caveats

1. Three runs, one host, one hour. `benchmarkIndex` ≈ 1,240. TBT and main-thread totals are not comparable
   to the mobile runs (different form factor and throttle) or to any other machine.
2. `chrome-headless-shell`, not full desktop Chrome.
3. Lab data. Google's desktop ranking reads desktop CrUX field data, not this. Whether CrUX holds a desktop
   record for this origin is unknown — check Search Console.

## Reproducing

```bash
export CHROME_PATH=<path>/chrome-headless-shell
for i in 1 2 3; do
  npx --yes lighthouse@12 https://www.highcountrypainrelief.com/ \
    --preset=desktop --only-categories=performance \
    --output=json --output-path=lhd-$i.json --quiet \
    --chrome-flags="--headless --no-sandbox --disable-dev-shm-usage"
done
```
