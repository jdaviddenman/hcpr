# Two quick wins — High Country Pain Relief

Two Beaver Builder **settings changes** — no code — fix the two biggest performance problems on the site.
~35 minutes total, any developer, fully reversible.

| # | Fix | Win | Effort | Tier |
|---|---|---|---|---|
| 1 | **Replace the hero video with a photo** — Beaver Builder row → Background → type **Photo** | removes the **~15 MB video on every device**, makes a static photo the largest element to paint (LCP), and **removes the layout shift outright** (no video = no resize) | 20 min | Settings — any dev |
| 2 | **Gallery: untick Loop and Autoplay**, on `/` and `/testimonials/` | removes **~910 duplicated page elements** (the slideshow clones 35 videos into 105) **and** a background animation that runs forever | 15 min | Settings — any dev |

## Who

- **Developer** (any, with Beaver Builder access): makes both changes. No PHP, no CSS, no plugin settings — just the two module panels. ~35 min.
- **Owner**: ✓ **approved** the hero photo (`Chronic-Pain-Boone-NC-Hiking.webp`) on 2026-08-13. No further owner decision needed — the change is cleared to build.

## Why these two

- The hero **video is ~88% of what a phone downloads (~15 MB)**, it's the slowest thing to appear, and it's **100% of the page's layout shift** — the jump a first-time visitor sees. Measured: shift of 0.199 on desktop (every load) and 0.184 on mobile, against Google's 0.1 limit.
- The **testimonial slideshow clones its 35 videos into 105** and runs a **transform every 3 seconds, forever** — a continuous drain on the phone's processor for as long as the page is open. Two checkboxes stop both.
- Both are **settings, not code**, so in this multi-plugin WordPress site they can't break anything else, and either reverts in one click.

## How

**Fix 1 — hero photo.** wp-admin → Pages → Home → Launch Beaver Builder → hover the top hero row (node `49vu6prnm80g`) → wrench → **Row Settings → Style → Background** → set **Type** from **Video** to **Photo** → choose `Chronic-Pain-Boone-NC-Hiking.webp` → turn **off** any background "lazy load" toggle → Save → Publish.

**Fix 2 — gallery.** In Beaver Builder, open the video-strip module and set **Loop** and **Autoplay** to **No**. Do it on **two pages**:
- **Home** (module `joy14c0h3re9`): untick **Loop and Autoplay**.
- **`/testimonials/`** (module `numzt61c0a34`): untick **Loop only** — autoplay is already off there.

**After both:** clear the Beaver Builder cache **and** purge the LiteSpeed page cache, or the site keeps serving the old version.

## Verify (no browser needed)

```bash
# Fix 1 — video gone (0, was 1)
curl -s "https://www.highcountrypainrelief.com/?cb=$(date +%s)" | grep -c 'data-mp4'
# Fix 2 — autoplay gone (returns nothing, was: {delay:3000,...})
curl -s 'https://www.highcountrypainrelief.com/wp-content/uploads/bb-plugin/cache/2-layout.js' \
  | grep -o 'options.carousel.autoplay={[^}]*}'
```

In Chrome DevTools, a page load should show **no request to `hiking.mp4` or `hiking.webm`**, and the gallery's slide count drops from 105 to 35.

## What a visitor notices — fix 1

The top of the home page currently shows a **moving video** of the hiking scene. After the change it shows the **same scene as a still photo** — the top of the page no longer moves. Everything over it (the headline, the buttons) stays exactly where it is; only the background stops playing. What a visitor feels: on a phone the hero appears almost at once instead of after a long wait, and the page stops downloading a 15 MB video.

The still the owner **approved ✓** — the hiking image already on the site (2000×1100):

![Proposed hero photo](https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp)

[Open the photo full size ↗](https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp)

## What a visitor notices — fix 2

The video-testimonials section **stops sliding on its own** and waits for the visitor. All 35 videos stay — reachable by the arrows, dots, or a swipe — and clicking one still plays it in the same pop-up; video playback doesn't change, and layout and styling are identical. The one trade-off: the auto-rotation used to hint "there's more here"; the arrows and dots still do, just without the motion. (The 105 → 35 element drop is invisible — those were off-screen duplicate slides the software built to fake the loop.)

## What this does not do

These two clear the biggest wins that carry no risk. They will not reach a green score on their own — that needs the deeper work (third-party scripts, render-blocking) on a staging site with a capable developer. Full detail and the rest of the plan: `PRIORITY-FIXES.md`.
