# High Country Pain Relief — the three highest-value speed fixes

**13 August 2026** · highcountrypainrelief.com
Part 1 is for Sara and the practice owner. Part 2 is the work, written for whoever implements it.

Measured live on 13 August, including three Lighthouse mobile runs. Figures marked **[Aug]** are the
median of those three; **[Jul]** figures appear only for comparison.

Companion docs: `VERIFYING-BACKEND-CLAIMS.md` (confirming a fix is live), `SECURITY-FINDINGS.md`,
`audit/data/lighthouse-mobile-2026-08-13.md`, `audit/data/verify-live.sh`.

---

# Part 1 — for Sara and the practice owner

## Where the site stands

**Mobile speed score: 33 out of 100** [Aug]. Individual runs scored 27, 33 and 34.

| Google's measure | This site | Target |
|---|---|---|
| **Largest Contentful Paint** — when the main image finishes drawing | **12.2 s** [Aug] | under 2.5 s |
| **Cumulative Layout Shift** — how much the page jumps while loading | **0.184 cold**, 0.000 warm | 0.1 or less |
| **Interaction to Next Paint** — how fast the page answers a tap | needs real visitors to measure | under 200 ms |

**The page jump only hits first-time visitors.** It appeared in the one run where the server built the
page from scratch instead of serving a saved copy — the path a new visitor takes. 12 of 12 first requests
to this site were cache misses. Returning visitors see a stable page; the person arriving from Google
sees it jump.

**The page downloads about 17 MB on a phone. Roughly 88% is one background video** — a 15 MB file that
now downloads in full. (July measured 5 MB total because that run's browser gave up on the video partway.
Same file either way.)

Do not repeat the July figure of "14.7 seconds frozen". The same measurement gave 1.7 seconds today.
It scales with whatever computer runs the test, and the two tests ran on different machines.

## What changed in the two weeks since the audit

WordPress and Beaver Builder were both updated and the theme settings re-saved, so the site is being
maintained. **None of the problems below has been touched.**

## Why this matters for search

**Google ranks this site from its mobile version** — its documentation says it "uses the mobile version
of a site's content, crawled with the smartphone agent, for indexing and ranking." Google's mobile
crawler receives exactly the same page a phone does, confirmed 13 August. What a phone experiences is
what Google evaluates.

**Speed helps at the margin. It is not a ranking fix.** Google says "Core Web Vitals are used by our
ranking systems" and, in the same document, "there is no single signal" and that Search "always seeks to
show the most relevant content, even if the page experience is sub-par." No weight is published and no
penalty exists.

**Check this before leaning on the search argument at all.** Google's ranking systems read speed data
from real Chrome visitors, not from the test we ran. A single-location practice may not have enough
visitors for Google to hold that data. Search Console → Experience → Core Web Vitals will either show
mobile data or say "not enough data". That answer decides whether the search case has any basis here.

**The stronger case is the visitor.** Someone who searches for a chiropractor in Boone, taps this result
and waits while a 15 MB video downloads is a booking already won in the search results. The best
controlled evidence Google publishes is Vodafone's A/B test: a 31% improvement in load time produced 8%
more sales — one company, one page, 2021. Directional, not a forecast for this practice.

## The three fixes

**1. The background video at the top of the home page.** 15 MB, plays on phones, and is the single
biggest cost on the page. It is why the top takes so long to appear and the entire cause of the page
jumping. Turning it off on phones is one dropdown. Desktop keeps the video.

> **Owner's decision:** phones get a still photo of the hiking scene instead of a moving video. It is the
> same photo already sitting behind the video, so nothing needs designing — but phone visitors will
> notice the top of the page no longer moves.

**2. Code from three outside companies.** ReviewWave's review-and-chat widget sits at the top of the page
and the phone must fetch it before drawing anything. UserWay's accessibility toolbar and Google Tag
Manager compete for the phone's processor.

> Moving code later is not the same as removing it. Most of this ticket makes the page usable sooner
> without reducing total work. Only two parts genuinely remove work: retiring Google Tag Manager, and
> switching the accessibility toolbar off on phones.

> **Owner's decision:** UserWay is an accessibility toolbar. Delaying it, or switching it off on phones,
> takes it from the visitors who most need it.

**3. The 35-video testimonial slideshow.** Thirty-five YouTube preview images download on every visit
whether or not anyone scrolls to them. **The slideshow is also set to loop and to advance itself every
three seconds, forever** — looping makes the browser build 105 slides instead of 35, and the automatic
advance keeps animating for as long as the page is open. Both are tick-boxes, and turning them off costs
a fraction of the full rebuild.

> **SEO decision:** the slideshow publishes video information Google reads. A rebuild removes it unless
> deliberately put back. Settle this before the rebuild, not after.

## What we are asking for

| | Work | Time | Blocked on |
|---|---|---|---|
| **Now** | Search Console → Core Web Vitals | 5 min | — |
| **Ticket 1** | Hero video | ~1.5 hrs | Owner's yes on the still photo |
| **Ticket 2** | Third-party code | 3–5 hrs | Accessibility decision; GTM account owner's sign-off |
| **Ticket 3a** | Slideshow loop and autoplay off | ~30 min | — |
| **Ticket 3b** | Rebuild the slideshow | 4–8 hrs | SEO sign-off |

This will not produce a green score. Reaching 90 needs the page rebuilt — 3,181 elements, four JavaScript
libraries doing two jobs, and outside code the practice does not control. No score, ranking or enquiry
figure is projected here, because nothing measured supports one.

---

# Part 2 — the work

## Before you start

**A. The page cache has no WordPress control.** `server: LiteSpeed`, `x-litespeed-cache: miss` then `hit`.
HTML carries no `Cache-Control` at all. The LiteSpeed Cache plugin is **not** installed
(`/wp-content/plugins/litespeed-cache/readme.txt` returns the WordPress 404 page), so there is no "Purge
All" button and no WP-CLI purge.

```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
curl -sS --max-time 30 --compressed -A "$UA" "https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

Use a new `?cb=` value every time. It creates its own cache entry and the response differs from the
canonical page by ~58 bytes. **`?cb=` shows what the origin generates; the plain URL shows what visitors
get. Check both.** If the plain URL is still stale after ~10 minutes, whoever holds server access must
flush the cache.

**B. CSS edits do not reach returning visitors.** `bb-theme-child/style.css` is enqueued as
`style.css?ver=7.0.4` — the WordPress version, not the file's — and served `max-age=2592000` (30 days)
with no ETag. Editing the file changes neither URL nor version string. **Fix this first or your CSS work
will appear not to work.** In `bb-theme-child/functions.php`:

```php
add_action( 'wp_enqueue_scripts', function () {
    $h = 'fl-child-theme';
    if ( wp_style_is( $h, 'registered' ) ) {
        wp_styles()->registered[ $h ]->ver = (string) filemtime( get_stylesheet_directory() . '/style.css' );
    }
}, 100 );
```

Verify the enqueued `?ver=` becomes a Unix timestamp, and that it changes after your next edit.

**C. `style.css` and `functions.php` are the only two files these tickets touch.** Two people editing
them over SFTP in the same window will overwrite each other. Separate sessions; download the current copy
immediately before each edit.

**Platform:** WordPress 7.0.4, Beaver Builder 2.10.3.1, Beaver Themer 1.5.3.2, BB Theme 1.7.19.2,
PowerPack, Ultimate Addons. BB bundles regenerated 11 Aug: `2-layout.js` 72,591 B raw,
`2-layout.css` 164,124 B raw. Homepage HTML 216,956 B raw / 33,290 B Brotli.

---

## Do these first — none needs an owner decision

Ticket 1's headline change (hero video off on phones) is **parked**: it changes what phone visitors see, so
it waits on the owner. Two parts of Ticket 2 are parked for the same reason — delaying the accessibility
toolbar needs the practice's call, and retiring Google Tag Manager needs the account owner's sign-off. The
fixes below are pure performance work with no aesthetic or business decision. Hand them to Inception now, in
this order.

| # | Fix | From | Win | Effort | Owner decision? |
|---|---|---|---|---|---|
| **1** | **Gallery: untick Loop and Autoplay**, on `/` and `/testimonials/` | Ticket 3, part 1 | removes ~910 rendered DOM elements on the homepage (105 → 35 slides) **and** a perpetual animation | 15 min | none¹ |
| 2 | Stop the hero video shifting the page (child-theme `!important` rule) | Ticket 1, step 1B | fixes CLS on **both** device classes — measured 0.199 on desktop (every run) and 0.184 on mobile (cold run) | 15 min | none |
| 3 | Dequeue unused WordPress core CSS/JS | audit 01 H7 | ~25 KB off every page | 30 min | none |
| 4 | Pre-warm the page cache (cron `curl` loop over the sitemap) | audit 01 M1 | fixes cold-cache TTFB on first visits (up to 2.2 s today, 12/12 first requests cold) | 15 min | none² |
| 5 | Defer the three ReviewWave scripts | Ticket 2, step 1 | removes the largest single render-blocker (1,451 ms) | 20 min + regression test | none³ |

¹ Loop-off is invisible to visitors — it only stops Beaver Builder cloning the 35 slides into 105. Autoplay-off
stops the carousel auto-advancing: a minor UX change, and an accessibility improvement (WCAG 2.2.2, Pause/Stop/Hide).
The owner has agreed to autoplay off, so both settings go.
² Needs server/cron access, not a design decision.
³ No design decision, but the review carousel and chat widget are a lead channel — regression-test both on a phone.

**Number 1 is the biggest unblocked win.** It attacks the 3,181-element DOM and the Swiper CPU cost the audit
names as the ceiling, and it is two Beaver Builder checkboxes — settings-only, no code, no visual change on the
page. Live-confirmed still applicable on 2026-08-13: `loopedSlides` = 35, `autoplay={delay:3000}`, 105 slide
children. Full detail in Ticket 3, part 1 below.

The CLS fix (item 2) is separable from Ticket 1's parked hero-video change and can ship on its own. It is
not a "desktop-only" nicety: **CLS is the single failing Core Web Vital on desktop — 0.199, on every run
(measured 2026-08-13, `audit/data/lighthouse-desktop-2026-08-13.md`)** — and because the video is not
removed on desktop, this rule is the only remedy there. On mobile it fixes the measured 0.184 shift while
Ticket 1A is parked. Same rule, both device classes.

---

## TICKET 1 — Hero background video *(headline change PARKED — waiting on the owner's call on the still photo)*

**Effort:** ~80 min, plus optional 30 min on the media host. **Blocked on:** the practice's yes.
Independent of Tickets 2 and 3, but see note C.

### Why this is first

| | Measured, 3 runs |
|---|---|
| Share of mobile payload | **~88%** — `inceptionimages.com` served 15,060–15,122 KiB of a ~17,000 KiB page. The whole video downloads, in two range requests |
| LCP element | the video, **12.2 s** median, **65–73% (7,527–7,901 ms) Load Delay** |
| CLS | **100%** — 0.1841 of 0.1841, one element, on the cold-cache run. Warm runs scored 0.000 |
| `hiking.mp4` | **15,343,649 B**, 1920×1080, 15.67 s, **not faststart** |
| `hiking.webm` | 5,802,541 B |
| Fallback still | 76,870 B, first-party |

Load Delay is that large because nothing about the video is in the HTML: `<video>` 0, `<source>` 0,
`poster=` 0. Beaver Builder builds it in JavaScript from `data-` attributes, so the browser cannot
discover the LCP element until `2-layout.js` has run.

> July measured 3,112 KiB and 60.7% of payload; August measured the full ~15 MB and ~88%. Nothing changed
> on the site — the browser aborts the download at a different point each run. No single payload figure
> from this page is reliable.

> **Verify CLS against a cold cache only.** A warm run scores 0.000 today, before any fix.

### Evidence

The hero row, unchanged:

```html
<div class="fl-bg-video"
  data-video-mobile="yes"
  data-fallback="https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp"
  data-mp4="https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.mp4"
  data-mp4-type="video/mp4"
  data-webm="https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.webm"
  data-webm-type="video/webm" >
  <div class="fl-bg-video-play-pause">
    <span><i class="fas fa-play fl-bg-video-play-pause-control"></i></span>
  </div>
</div>
```

No `data-width`, no `data-height` anywhere in the document — that absence causes the layout shift.

From `2-layout.js`, **both branches append**:

```js
if(!FLBuilderLayout._isMobile()||(FLBuilderLayout._isMobile()&&"yes"==videoMobile)){
  … else{wrap.append(videoTag); … play/pause wiring … }}
else{videoTag.attr('src','')
wrap.append(videoTag);}
```

`grep -o -F 'wrap.append(videoTag)' 2-layout.js | wc -l` returns **2**. Setting the row to No sets
`src=""`, which makes the browser ignore both `<source>` children. **The `<video>` element remains. Do
not verify by looking for its absence.**

The gate is user-agent based, not viewport based —
`/Mobile|Android|Silk\/|Kindle|BlackBerry|Opera Mini|Opera Mobi|webOS/i` — so a desktop browser at a
narrow window still gets the video.

Sizing, with no `data-width`/`data-height`:

```js
vid.css({'left':'0px','top':'0px','width':newWidth+'px'});   // pass 1
vid.on('loadedmetadata',FLBuilderLayout._resizeOnLoadedMeta); // pass 2
win.on('resize.fl-bg-video', … 100 ms debounce … );           // and on every resize
```

Both are jQuery `.css()` calls writing the inline `style` attribute, re-applied on a debounced resize.
**This is why `!important` is required in step 1B.** The served stylesheet rule is
`.fl-row-bg-video .fl-bg-video video` — specificity (0,3,1), so a plain `.fl-bg-video video` override
without `!important` loses twice.

### Steps

**1A — Show Video On Mobile = No.** *10 min. The whole payload win, safe alone.*

1. wp-admin → Pages → Home → **Launch Beaver Builder**
2. Hover the top hero row (node `49vu6prnm80g`) → **wrench** icon → **Row Settings**
3. **Style** → **Background** → **Show Video On Mobile** → **No**
4. **Save** → **Done** → **Publish**

**1A2 — turn off the play/pause button, same session.** Its click handler is bound only inside the
if-branch of the mobile gate, so after 1A phones get a play triangle that does nothing. Same Background
panel. If your BB version has no such option, add to step 1B's CSS:
`@media (max-width:767px){.fl-bg-video-play-pause{display:none;}}`

**1B — stop the layout shift.** *10 min. Do note B first.* Append to `bb-theme-child/style.css`:

```css
/* Hero video: defeat Beaver Builder's two inline sizing passes. Every !important is required —
   BB writes these as inline styles via jQuery .css() and re-applies them on a debounced resize. */
.fl-row-bg-video .fl-bg-video video{
  width:100% !important; height:100% !important;
  left:0 !important; top:0 !important;
  min-width:0 !important; min-height:0 !important;
  max-width:none !important; transform:none !important;
  object-fit:cover;
}
```

**1C — make something paint early.** *25 min. SFTP.* In `style.css`:

```css
.fl-node-49vu6prnm80g .fl-bg-video{
  background:url(https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp) center/cover no-repeat;
}
```

In `functions.php`. **A preload alone paints nothing** — it warms the cache for an image otherwise only
applied to an element JavaScript creates later. The CSS above is the half that makes it visible.

```php
add_action( 'wp_head', function () {
    if ( ! is_front_page() ) { return; }
    echo '<link rel="preload" as="image" fetchpriority="high" href="https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp">' . "\n";
    echo '<link rel="preconnect" href="https://www.chiro.inceptionimages.com" crossorigin>' . "\n";
}, 2 );
```

> **Placement.** Download a copy as `functions.php.bak-2026-08-13` before editing. If the file's last line
> is `?>`, insert above it; otherwise append. Do not add a second `<?php`. After uploading, run
> `curl -sS -o /dev/null -w '%{http_code}\n' https://www.highcountrypainrelief.com/` — must return `200`.
> A syntax error here whites out the site.

> The preconnect still earns its place after 1A: **6 `<img>` elements** load from
> `chiro.inceptionimages.com` on every device, plus CSS backgrounds from the same host.

> **Maintenance:** the hero photo is now set in three places — the BB row setting, the CSS rule, and the
> preload. Change one and you must change all three, or the page flashes the old photo and preloads an
> unused file. Search the child theme for `Chronic-Pain-Boone-NC-Hiking` before editing that row.

**1D — optional, desktop, 30 min: make the MP4 streamable.** `hiking.mp4` is not faststart — its
5,493-byte `moov` atom sits behind 15,338,116 bytes of `mdat`, so playback cannot start until nearly the
whole file arrives.

```bash
cp hiking.mp4 hiking.mp4.bak-2026-08-13
ffmpeg -i hiking.mp4 -c copy -movflags +faststart hiking-faststart.mp4
# verify playback, then rename over the original
```

> Needs shell access on the media host with ffmpeg; with FTP only, run it locally and upload. **This file
> sits in a shared Inception media library** and may be referenced by other client sites. The remux is
> lossless. Keep the backup.

### Verification

```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
U="https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

| # | Check | Before | After |
|---|---|---|---|
| V1 | `curl -sS --compressed -A "$UA" "$U" \| grep -c 'data-video-mobile="yes"'` | **1** | **0** |
| V2 | DevTools → Network, phone UA, **filter `hiking`** | ≥1 row, megabytes | **0 rows** |
| V3 | `curl … \| grep -o 'fl-bg-video-play-pause' \| wc -l` | **2** | **0** |
| V4 | After 1B: `grep -o '!important' style.css \| wc -l` | baseline | **+8** |
| V5 | DevTools → Elements → the `<video>` → **Styles** pane | BB's `element.style` wins | BB's `left/top/width/height` **struck through** |
| V6 | Cold-cache Lighthouse → *Avoid large layout shifts* | 0.184 | no non-zero shift |

> **V2 is decisive, and has one trap: do not filter on the hostname.** Six product images on this page
> legitimately come from `chiro.inceptionimages.com` and always will. Filter on `hiking`.

> **V1:** after the change the attribute reads `"no"` or is absent — either passes, because BB's gate
> tests for the literal string `"yes"`. `grep -c 'hiking.mp4'` still returns 1 before and after: the
> `data-mp4` attribute stays, only the fetch stops.

> **V5:** do not use the Computed panel. It reports used values in pixels always, so a perfect fix looks
> like a failure.

Two claims are read from Beaver Builder's code, not executed. **Confirm both in DevTools on the first
pass:** that the fallback WebP becomes the LCP element on mobile, and that `loadedmetadata` never fires.
BB's first sizing pass still runs after this fix — its guard is
`if(0===$(this).find('video').length…){return;}` and a `<video src="">` passes it. One pass runs, the
second is bound but never fires.

**Rollback:** 1A and 1A2 via page revision history. 1B and 1C by restoring the backed-up files. 1D by
renaming the `.bak` back.

---

## TICKET 2 — ReviewWave, UserWay and Google Tag Manager

**Effort:** 3–5 hrs across four steps, shipped separately. **Blocked on:** the accessibility decision
(step 2) and the GTM account owner's sign-off (step 3).

### What this achieves

Quote the ranking, not the absolute milliseconds — the two Lighthouse runs disagree by ~5× on CPU
because they ran on different machines, while the ordering is identical:

| Third party | Jul | Aug | Rank |
|---|---|---|---|
| **UserWay** | 2,443 ms | **481–495 ms** | 1st, both |
| **Google Tag Manager** | 1,165 ms | **297–351 ms** | 2nd, both |
| ReviewWave | 196 ms | 33 ms | 3rd, both |

- **Removed** by step 3: 116,234 B of download per cold load and **333,526 B of JavaScript parsed and
  executed on every page view**, cached or not.
- **Removed** by step 2 Option B, if the practice agrees: 51,813 B transfer / 181,374 B parsed, mobile only.
- **Moved, not removed** by steps 1 and 2 Option A: first paint improves; total CPU does not fall.

Do not add render-blocking estimates to the blocking figure — they describe overlapping cost on the same
files. Lighthouse's headline for all render-blocking resources is 1,330 ms [Aug], and its per-row figures
sum to more. Neither is a prediction.

**The single largest render-blocker is ReviewWave's S3 config at 1,451 ms** — bigger than jQuery,
Bootstrap and the Beaver Builder bundle combined. Three of the top three are ReviewWave and Google Fonts.

### Step 0 — find the injection point. *20–45 min.*

All three vendors' tags sit in **one contiguous hand-authored block**, site-wide — byte-identical on `/`,
`/contact-us/`, `/testimonials/` and `/knee-pain-lp/`. It appears immediately after the closing `</style>`
of `<style id="wp-custom-css">`, which core prints on `wp_head` at priority 101, so the injector runs at
priority > 101. That rules out static markup in `header.php`.

Positions today: GTM inline loader is script tag **#5 of 32** at byte 39,732; ReviewWave's inline config
**#6** at 40,198; its three `src` tags **#7/#8/#9** at bytes 40,410 / 40,501 / 40,573, immediately before
`</head>`; the UserWay block opens at byte **205,885**, emitted on `wp_footer`.

Look in this order:

1. **wp-admin → Beaver Builder → Themer Layouts** — the header part, for an HTML module. Beaver Themer is
   installed and stores markup in the database. Check first; needs no shell.
2. **Appearance → Customize** → BB Theme's Code / Header Code panel
3. **Plugins** → any "Headers and Footers" plugin, **and the site's own custom plugin** — `/wp-json/`
   registers `inception-office-hours/v1`, an Inception-authored plugin and a prime candidate
4. Over FTP, download `themes/`, `mu-plugins/`, `plugins/` and grep locally for `reviews_embed.js` —
   **without** `--include="*.php"`, since it may sit in a non-PHP file
5. Only then is it elsewhere in the database, needing phpMyAdmin or SSH

**Before changing anything,** paste the entire field or file into a dated text file kept outside the site.
**This is the only rollback that exists** — there is no WordPress-side cache purge, so a bad edit stays
visible until the TTL expires or the host flushes it.

### Step 1 — defer the three ReviewWave tags. *20 min + 20 min phone regression.*

Add `defer` to:

```
rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js
cdn.reviewwave.com/js/reviews_embed.js
cdn.reviewwave.com/js/chat_embed.js
```

**The usual `defer` hazard does not apply here.** Zero `document.write` in all three. Both embeds
self-locate with `document.querySelectorAll('script[src*="…"]')` rather than `document.currentScript`,
which is defer-safe; `defer` preserves document order so the S3 config still runs before
`reviews_embed.js` consumes `window._rwReviewEmbed`; and `chat_embed.js` has a 500 ms `setTimeout`
fallback. **Regression-test anyway** — this is the review carousel and chat widget, a live lead channel.

ReviewWave is six resources, not three: the two embed scripts each inject a stylesheet at runtime and
`chat_embed.js` fetches a second S3 config. **73,995 B transfer / 120,119 B uncompressed over 6
requests**, none carrying `Cache-Control`. The main S3 config is 57,267 B served uncompressed; `gzip -9`
takes it to 19,115 B. Inception cannot fix that — see step 4.

| Check | Before | After |
|---|---|---|
| `curl … \| grep -oE '<script[^>]*(\sdefer\|\sasync)[ =>]' \| wc -l` | **0** | **exactly 3** |
| `curl … \| grep -o 'defer src="https://rw-embed-data' \| wc -l` | 0 | **1** |
| On a real phone: `/` and `/testimonials/` | — | badge appears; chat opens, accepts a message, submits |

> Do not use `grep -c 'defer\|async'` — it returns **24** on the unmodified site, because core emits
> `decoding="async"` on 22 images and `grep -c` counts lines.

> **Rollback trigger:** chat bubble not appearing within 10 s on a phone → remove `defer` from
> `chat_embed.js` only, re-verify, report.

**Then wait 24 hours before step 2.** Steps 1 and 3 edit the same block; shipping together means you
cannot tell which one broke something.

### Step 2 — UserWay. *45–90 min. Blocked on a written decision from the practice.*

A third-party commercial accessibility overlay from **userway.org** — not custom code and not built by
Inception. Installed as a WordPress plugin, version 2.4.8, account `Vgm0gbMRdF`.

- **The plugin has no defer setting.** Its entire frontend contribution is one echo of the inline
  snippet. `/userway/v1/debug` returns only `{account_id, state, created_time, updated_time}`. UserWay's
  help centre has 36 widget articles and none covers deferred loading.
- **Unhooking is one line, not 90 minutes.** The plugin registers output with
  `add_action('wp_footer','usw_addplugin_footer_notice')` — a named global function at default priority 10.

**Option A — delay it.**

```php
remove_action( 'wp_footer', 'usw_addplugin_footer_notice' );
add_action( 'wp_footer', function () { ?>
<script>
(window.requestIdleCallback||function(cb){setTimeout(cb,2000);})(function(){
  var s=document.createElement('script');
  s.src='https://cdn.userway.org/widget.js';
  s.setAttribute('data-account','Vgm0gbMRdF');
  document.body.appendChild(s);
},{timeout:3000});
</script>
<?php }, 20 );
```

`{timeout:3000}` is not optional — this page has 20 long tasks and bare `requestIdleCallback` can starve.
Setting `.defer = true` on a dynamically created script is a no-op; they are already async.

> UserWay's app script is already async and already waits for `DOMContentLoaded` inside `widget.js`.
> Option A is a CPU-contention fix, not a render-blocking one: it pushes ~2.4 s of phone processor work
> about three seconds later so it stops competing with the page becoming usable. It does not delete it.

**Option B — switch it off on phones.** `widget.js` has an undocumented kill switch: if
`window._userway_config.mobile` is `false` and the UA matches `/mobile/i`, `widget.js` exits without
loading the app. Removes **51,813 B transfer and 181,374 B parsed JS+CSS on mobile**.

```php
add_action( 'wp_footer', function () { ?>
<script>window._userway_config = window._userway_config || {}; window._userway_config.mobile = false;</script>
<?php }, 5 );
```

> **The decision.** Option A makes the toolbar unavailable for at least three seconds and on a cold load
> longer. Option B removes it from phones. Both cost the visitors who most need it. The practice decides,
> in writing, before the work. Removing the overlay entirely is a separate question with legal dimensions
> and is out of scope.

UserWay rolled a new build on 10 August, after the July run, so its CPU figures describe a bundle no
longer served. Treat them as indicative, not as targets.

| Check | Before | After |
|---|---|---|
| `curl … \| grep -o 'cdn.userway.org/widget.js' \| wc -l` | 1 | **exactly 1** |
| `curl … \| grep -c 'requestIdleCallback'` (Option A) | **0** | **1** |
| Cold phone load | — | toolbar still appears within 5 s (Option A) |

> If the first check returns **2**, the `remove_action` failed silently and the plugin's undeferred copy
> is still firing. The page looks fine and the fix is not applied.

### Step 3 — retire Google Tag Manager. *30 min. Blocked on the GTM account owner's sign-off.*

**The container holds exactly one tag** — `__googtag` → `G-CW4KKYCP1V`, `send_page_view=true` — one
variable, one trigger, one rule. There is nothing to prune and no duplicate analytics to deduplicate, so
"audit the container" would return nothing.

Retiring it removes 116,234 B of download per cold load (`gtm.js` is `private, max-age=900`, so reused
within a 15-minute session) and 333,526 B of JavaScript parsed and executed on every page view. Replace
the GTM inline snippet and its `<noscript>` iframe with:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-CW4KKYCP1V"></script>
<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
gtag('js',new Date());gtag('config','G-CW4KKYCP1V');</script>
```

> **What the practice loses:** the ability to add or change tracking tags without a developer. If anyone
> expects to add conversion tracking, ad pixels or call tracking soon, keep GTM and skip this step.

**Analytics verification is blocking.** Solid Security is installed, which raises the odds of a security
plugin stripping a hand-placed script tag.

1. **Before** changing anything: GA → Reports → **Realtime** for `G-CW4KKYCP1V`, load the homepage on
   your phone, confirm you appear
2. Make the change, cache-bust, load again from the same phone
3. Confirm you appear in Realtime **within 60 seconds**. Also check DevTools → Network, filter `collect`,
   for `/g/collect` with `tid=G-CW4KKYCP1V`
4. **Not there within 5 minutes → revert immediately** from the saved copy. Do not leave the site on an
   unverified analytics tag overnight

Then `grep -o 'GTM-WGXQKR5' | wc -l` → **0** and `grep -o 'gtag/js?id=G-CW4KKYCP1V' | wc -l` → **1**.

### Step 4 — vendor ask. *Owner: the practice.*

ReviewWave will only act on a request from the account holder. Inception supplies the wording; the
practice sends it from the email on the ReviewWave account, copying Inception:

> "Our website loads a review data file from your service —
> `rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js`. It is served without compression or
> caching, which makes our pages slower. Could you enable gzip or Brotli compression and a
> `Cache-Control` header on that file? Our developers estimate it would cut it from 57 KB to about 19 KB."

### Two security items — one of them is a plugin update

Both are in `SECURITY-FINDINGS.md` with fixes and verification. Listed here because this ticket already
has the same plugin open:

- **S1 — block `/wp-json/userway/v1/debug` with a child-theme filter.** It returns the PHP version,
  WordPress version, plugin version, account ID and the **database table prefix** to anyone.
  **Updating the plugin will not fix it**: the current release 2.6.6 registers the route with
  `'permission_callback' => function () { return true; }`, byte-identical to the 2.4.8 the site runs.
  Filter and verification in `SECURITY-FINDINGS.md` S1.
- **S2** — `/wp-json/wp/v2/users` returns two valid usernames unauthenticated. One filter, or a Solid
  Security toggle.

---

## TICKET 3 — The 35-video testimonial slideshow

**Effort:** part 1 ~30 min, part 2 4–8 hrs. **Blocked on:** SEO sign-off, part 2 only.

### Part 1 — turn off Loop and Autoplay. *~30 min. Do this regardless — no owner decision.*

The owner has agreed to Autoplay off, so both settings go on the homepage.

**The two modules** (both PowerPack Video Gallery, laid out as a carousel), live-confirmed 2026-08-13:

| Page | Module node | Slides | Loop | Autoplay | Change |
|---|---|---|---|---|---|
| `/` (home) | `fl-node-joy14c0h3re9` | 35 | **on** | **on** (3000 ms) | untick **Loop and Autoplay** |
| `/testimonials/` | `fl-node-numzt61c0a34` | 39 | **on** | **already off** | untick **Loop only** |

There is no autoplay to turn off on `/testimonials/` — do not hunt for one.

**Loop.** The served options carry `loop:true`, so Swiper 8.4.7's `loopCreate` clones the whole set —
`loopedSlides = _getSlidesCount()` = 35, giving **105 rendered slide elements** on the homepage (35 real
+ 35 prepended + 35 appended; Swiper's default at `slidesPerView: 1` would be 2 clones). Each slide subtree
is ~13 elements, so unticking Loop removes **~910 rendered DOM nodes** on the homepage (70 clones × 13) and
~1,000 on `/testimonials/` (78 clones × 13, derived — that page was not Lighthouse'd). This is the direct
hit on the 3,181-element DOM.

> Lighthouse reported "Maximum Child Elements: 105" on `div.pp-video-gallery-items.swiper-wrapper` and DOM
> depth 28 in both July and August. Not host-dependent, not a single-run artefact.

**Autoplay** (homepage only). The compiled bundle, three consecutive statements:

```js
options.carousel={ … autoplay:false, … loop:true … };
options.carousel.autoplay={delay:3000,disableOnInteraction:true,};
gallery_joy14c0h3re9=new PPVideoGallery(options);
```

The literal `autoplay:false` is overwritten one statement later, and `_getSwiperOptions` contains
`if(!this.isBuilderActive&&this.carousel.autoplay){options.autoplay=this.carousel.autoplay;}` with
`isBuilderActive:false`. **Autoplay is on** — a 1,000 ms transform every 3,000 ms, forever, each cycle
calling Swiper's `loopFix()`. That cost runs for as long as the page is open.

**This does not remove Swiper.** `swiper.min.js` still loads — only Part 2 removes it. Part 1 cuts the
clone DOM and the animation, not the download.

**Steps**

1. wp-admin → **Pages → Home → Launch Beaver Builder**.
2. Hover the video-strip module (node `joy14c0h3re9`) → **wrench** → module settings.
3. In the **Carousel** settings, set **Loop** (may read "Infinite Loop") to **No** and **Autoplay** to
   **No**. Labels vary slightly by PowerPack version — the tells are the setting that produces `loop:true`
   and the one that produces the autoplay object.
4. **Save → Done → Publish.**
5. Repeat on **`/testimonials/`** (module `numzt61c0a34`) — **Loop → No** only.
6. Clear the **Beaver Builder cache** **and** purge the **LiteSpeed page cache** (note A) — both, or the
   page keeps serving the old bundle.

**Verify — browser-free, before/after.** Fetch the plain bundle path (no `?ver`, so you get the current
file):

```bash
# Homepage — autoplay gone
curl -s 'https://www.highcountrypainrelief.com/wp-content/uploads/bb-plugin/cache/2-layout.js' \
  | grep -o 'options.carousel.autoplay={[^}]*}'
#   BEFORE: options.carousel.autoplay={delay:3000,disableOnInteraction:true,}
#   AFTER:  (nothing)

# Homepage — loop off
curl -s 'https://www.highcountrypainrelief.com/wp-content/uploads/bb-plugin/cache/2-layout.js' \
  | grep -oE 'options\.carousel=\{[^;]*\}' | grep -o 'loop:false'
#   AFTER: loop:false   (BEFORE: nothing — it reads loop:true)

# Testimonials — loop off (post id 83)
curl -s 'https://www.highcountrypainrelief.com/wp-content/uploads/bb-plugin/cache/83-layout.js' \
  | grep -oE 'options\.carousel=\{[^;]*\}' | grep -o 'loop:false'
```

Then the DOM win, which shows only in the rendered page:

- DevTools → Elements → `div.pp-video-gallery-items.swiper-wrapper` child count is **35, not 105**; or
  Lighthouse "Max child elements" drops from 105.
- **Do not grep the served HTML for slide count** — it returns 35 before *and* after, because the 35 real
  slides are always in the HTML and Swiper adds the clones at runtime. That is the trap that makes a
  correct fix look failed.

Functional: the carousel still shows every video, swipe and click still work, and the homepage no longer
auto-advances.

**Rollback:** re-tick the settings, or restore the page from Beaver Builder revision history. Settings
only, no code.

### Part 2 — replace with click-to-play. *4–8 hrs.*

**Why `loading="lazy"` cannot be the cheap fix.** All 35 thumbnails are inline-style CSS
`background-image` on `div.pp-video-image-overlay`. `loading="lazy"` is an attribute of `<img>` and
`<iframe>`; it has no effect on CSS backgrounds.

| | Measured |
|---|---|
| Distinct videos site-wide | **39.** The homepage's 35 are a **strict subset** of the 39 on `/testimonials/` |
| Thumbnail weight, homepage | ~**460 KiB ± 30 KiB** (13,394 B mean n=10; 13,512 B mean n=8) |
| A visitor seeing both pages within 2 hrs | **39 thumbnails, ~520 KB** — not 74. URLs are identical and `i.ytimg.com` sets `max-age=7200` |
| Gallery markup | 69,368 B of 216,956 B raw HTML (**31.97%**) — but **under 3 KB on the wire.** 35 near-identical templates compress almost away. The DOM and CPU win is the reason to do this; the download win is small |
| Swiper | `swiper.min.js` 143,660 B raw / 38,121 B Brotli; `swiper.min.css` 16,494 B. Loads on **exactly 2 of 44 pages** |

**`/testimonials/` carries a second, larger instance** — 39 slides, its own copy of Swiper, on a 224,593 B
page bigger than the homepage. Do both or you leave the worse one untouched.

**The SEO decision.** The gallery emits **31** microdata `VideoObject` blocks across **186** meta tags.
(Not 33/198 — two standalone video modules outside the carousel keep their markup. Four gallery slides —
`cvbQYotHZb0`, `TGw16jnwcGE`, `TGm19YJWH8c`, `CGBDsDLkNIE` — carry no `itemscope`, a content-entry gap
worth fixing separately.) A facade emits **zero** structured data. Re-emit one JSON-LD `ItemList` using
the property values already in today's HTML.

> **Three rules, or the JSON-LD becomes a Google policy violation.**
> 1. **It must describe exactly the videos rendered on that page.** Show 6, emit 6. Markup for videos not
>    on the page is what the guidelines prohibit. Success criterion: **`VideoObject` count equals rendered
>    poster count.**
> 2. **Drop `contentUrl`; keep `embedUrl` only.** These are YouTube-hosted, and Google asks for `embedUrl`
>    alone in that case.
> 3. **Do not invent `uploadDate`.** Today's values are four bulk placeholders across 33 videos — 22 share
>    `2025-02-21T10:00America/Chicago`, which is not valid ISO 8601. Get real dates from YouTube
>    (`curl "https://www.youtube.com/watch?v=<ID>" | grep -o '"uploadDate":"[^"]*"' | head -1`) or **omit
>    the key**. An entry without `uploadDate` is not eligible for a video rich result — where the site
>    already stands.

**If you use `lite-youtube-embed`** (0.3.4, Apache-2.0, no dependencies; 10,630 B JS + 2,767 B CSS
uncompressed, 3,960 B + 1,273 B gzipped):

- **A naive swap makes this worse.** Its `connectedCallback` sets `style.backgroundImage` to the same
  `i.ytimg.com/vi/{id}/hqdefault.jpg` URL *and* fires a second request per video to
  `i.ytimg.com/vi_webp/{id}/sddefault.webp`. **35 requests become about 70.** Use its own guard —
  `if (!this.style.backgroundImage)` — by setting the poster yourself, or self-host the 35 posters.
- **Enqueue conditionally.** Unconditional enqueue adds two requests to the 42 pages with no video strip:
  ```php
  function hcpr_yt_assets() {
      if ( ! is_front_page() && ! is_page( 'testimonials' ) ) { return; }
      /* wp_enqueue_style(...); wp_enqueue_script(...); */
  }
  ```
  Do **not** gate on `has_shortcode()` against `post_content` — BB layout data lives in the
  `_fl_builder_data` postmeta and will never match.
- **`wp_script_add_data( $handle, 'defer', true )` is a no-op.** Core reads the `strategy` key:
  ```php
  wp_enqueue_script( 'hcpr-yt', $d . '/js/hcpr-yt-facade.js', array(), '1.0.0',
      array( 'in_footer' => true, 'strategy' => 'defer' ) );
  ```

### Verification

Purge the LiteSpeed page cache **as well as** the Beaver Builder cache — clearing BB's cache regenerates
`2-layout.js`, it does not evict the cached HTML containing the gallery block.

| # | Check | Before | After |
|---|---|---|---|
| V1 | `curl … \| grep -c 'pp-video-gallery-item swiper-slide'` | **35** | **0** |
| V2 | `curl … \| grep -c 'swiper.min'` on `/` **and** `/testimonials/` | **2 each** | **0 each** |
| V3 | `grep -o 'i.ytimg.com' \| wc -l` | 35 | videos kept — **and not 70** |
| V4 | DevTools → Network, filter `ytimg`, page at top | 35 | ≤ 3, rising as you scroll |
| V5 | Click a thumbnail | — | a YouTube player appears and plays |
| V6 | `VideoObject` count vs rendered poster count | 31 vs 35 | **equal** |
| V7 | Homepage raw HTML | 216,956 B | ~148,000 B |

**Rollback:** restore the PowerPack modules from page revision history on both pages, remove the
child-theme files, purge both caches.

---

## Sources for Part 1's search claims

- Mobile-first indexing: `developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing` (updated 10 Dec 2025)
- Page experience and Core Web Vitals as ranking signals: `developers.google.com/search/docs/appearance/page-experience` (updated 10 Dec 2025)
- Thresholds — LCP 2.5 s, CLS 0.1, INP 200 ms, at the 75th percentile of real users: `web.dev/articles/vitals`
- INP replaced FID, 12 March 2024: `web.dev/blog/inp-cwv-launch`
- Vodafone A/B test: `web.dev/case-studies/vodafone` (2021). The only entry on Google's roll-up page run
  as a controlled A/B test; the other ~18 are before/after observations and cannot support a causal claim.

**Claims deliberately not made:** that this work will improve rankings; that Google penalises slow sites;
the "53% of mobile visitors leave after 3 seconds" figure (2016, correlational, publisher sites, no longer
cited by Google's own teaching page); and any projected score, ranking, revenue or enquiry figure.

## Method and limits

- **Lighthouse re-run 13 August** — three mobile runs, 12.8.2 on Chrome for Testing 152, median reported.
  Full data: `audit/data/lighthouse-mobile-2026-08-13.md`. Scores 27 / 33 / 34.
- **July and August CPU figures are not comparable, and the site is not the reason.** Lighthouse
  calibrates the simulated network but applies a fixed ×4 CPU multiplier to whatever host runs it.
  August's host scored `benchmarkIndex` ≈ 1,300; July's was not recorded. Quote CPU figures with the host
  attached or not at all. Everything structural reproduced: same LCP element, same single CLS source,
  same 105 child elements, same DOM depth, same render-blocking leader, same third-party ranking.
- **Everything else measured live on 13 August** with `curl`, and re-derived from the origin's own
  JavaScript and CSS.
- **Cache behaviour:** 12 of 12 first requests were misses. Cold TTFB median **1.054 s** (n=12, 0.592–2.225 s);
  warm median **0.076 s**.
- **Not verifiable from outside — needs wp-admin:** whether 10Web Booster does anything. All 27
  `tenweb_so/v1` and 9 `tenwebio/v2` routes are registered, on a page with zero `defer`, zero `async`, no
  critical CSS and no CDN. That proves the code loads and nothing more. A 30-minute check, worth doing
  before hand-writing work the plugin may already be configured to do.

Full findings and the 26-step sequence: `audit/01-page-speed-performance-audit.md`, reconciled to these measurements.
