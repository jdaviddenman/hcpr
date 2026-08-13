# High Country Pain Relief — the three highest-value speed fixes

**Prepared:** 13 August 2026 · **Site:** highcountrypainrelief.com
**For:** Sara (Inception) and the practice owner — Part 1. Inception's technical team — Part 2.

**How to read this.** Part 1 is plain English and is one page. Part 2 is three work tickets written for
whoever does the work; it is deliberately detailed, because the person who wrote it has no access to the
site and cannot answer questions. Every instruction and every check in Part 2 can be run by Inception
alone.

**Where the numbers come from.** Everything here was measured against the live site on **13 August 2026**,
including three fresh Lighthouse runs. Figures are marked **[LH Aug, median of 3]** where they come from
those runs and **[LH 30 Jul]** where a July figure is quoted for comparison.

Three runs of the untouched site scored **27, 33 and 34**. That spread — 7 points, 2.0 s of LCP, and all
of the layout shift — is why this document quotes medians and why no single run should be treated as the
answer.

**Companion documents:**
- `VERIFYING-BACKEND-CLAIMS.md` — how to confirm from outside that an asserted fix is actually live and
  actually reaching visitors. Four traps on this server make a correct fix look failed, and an unshipped
  fix look successful. **Read it before signing off on any of this work.**
- `SECURITY-FINDINGS.md` — a separate register. Two items surfaced while measuring and are worth folding
  into Ticket 2, since it already touches the same plugin.
- `audit/data/lighthouse-mobile-2026-08-13.md` — the three runs in full, with their limits.
- `audit/data/verify-live.sh` — one command, prints today's census beside the 13 August baseline.

---

# Part 1 — for Sara and the practice owner

## Where the site stands today

**The mobile speed score is 33 out of 100** [LH Aug, median of 3]. Google's own testing tool, simulating a
phone on a slow mobile connection.

Of Google's three official "Core Web Vitals", one fails outright and one fails intermittently:

| Google's measure | This site | Google's published target |
|---|---|---|
| **Largest Contentful Paint** — when the main image finishes drawing | **12.2 s** [LH Aug, median of 3] | under 2.5 s |
| **Cumulative Layout Shift** — how much the page jumps while loading | **0.184 on a cold cache**, 0.000 when warm | 0.1 or less |
| **Interaction to Next Paint** — how fast the page answers a tap | cannot be measured without real visitors | under 200 ms |

**The page jump only happens to first-time visitors, which makes it worse than it looks.** It appeared in
one of our three runs — the one where the server had to build the page from scratch rather than serve a
saved copy. That is the path a new visitor takes: **12 of 12 first requests to this site were cache
misses.** A returning visitor sees a stable page; the person arriving from Google sees it jump.

**The page downloads about 17 MB on a phone, and roughly 88% of that is one background video.** The video
file is 15 MB and it now downloads in full. (The July audit recorded 5 MB total, because that run's
browser gave up on the video partway. Where it gives up varies. This is the same file either way.)

> **One number from the July audit should not be repeated: "14.7 seconds frozen."** We measured 1.7
> seconds for the same thing today. Neither figure describes a real phone — this particular measurement
> scales with whatever computer runs the test, and the two tests ran on different machines. What holds
> across both is the **ranking** of what costs the most, and that is identical in July and August.

## What has changed in the two weeks since the audit

The site is being maintained — WordPress was updated, Beaver Builder was updated, and someone re-saved
the theme settings. **None of the problems below has been touched.** The hero video still plays on
phones, no script has been deferred, and every first request to a page still misses the cache.

## Why this matters for search, stated honestly

**Google ranks this site from its mobile version.** Google's documentation says it "uses the mobile
version of a site's content, crawled with the smartphone agent, for indexing and ranking." We confirmed
on 13 August that Google's mobile crawler receives exactly the same page a phone does. So what a phone
experiences is what Google evaluates.

**Speed helps, but only at the margin — and we should not sell it as a ranking fix.** Google says
plainly that "Core Web Vitals are used by our ranking systems," and in the same document says "there is
no single signal" and that Search "always seeks to show the most relevant content, even if the page
experience is sub-par." Google publishes no weight and no penalty. The honest position: speed can help
decide between pages that are otherwise similar on content, and nothing more than that.

**One thing worth checking before anyone leans on the search argument at all.** The ranking systems read
speed data from real Chrome visitors, not from the test we ran. A single-location practice may not have
enough visitors for Google to hold that data. Inception can settle it in about a minute in Google Search
Console under Experience → Core Web Vitals, which will either show mobile data or say "not enough data."
That answer decides whether the search argument has any basis in fact here. **We recommend doing that
check first.**

**The stronger case is the visitor, not the ranking.** Someone who searches for a chiropractor in Boone,
taps this result, and waits while a 15 MB video downloads is a booking the practice already won in the
search results. The best controlled evidence Google publishes is Vodafone's A/B test: a 31% improvement
in load time produced 8% more sales. That is one company, one page, in 2021 — directional, not a forecast
for this practice. We are not projecting a number for High Country Pain Relief, because nothing we
measured supports one.

## The three fixes, in plain English

**1. The background video at the top of the home page.** A 15 MB video plays behind the hero on phones.
It is the single biggest cost on the page, it is the reason the top of the page takes so long to appear,
and it is the entire cause of the page jumping as it loads. Turning it off on phones is one dropdown in
Beaver Builder. **Desktop and laptop visitors keep the video.**

> **A decision for the owner:** on phones the top of the home page becomes a still photo of the hiking
> scene instead of a moving video. It is the same photo already sitting behind the video, so nothing has
> to be designed or chosen — but phone visitors will notice the top of the page no longer moves. This
> needs a yes from the practice before it ships.

**2. Code from three outside companies.** The review-and-chat widget (ReviewWave), the accessibility
toolbar (UserWay) and Google Tag Manager all run on the home page. The ReviewWave code sits at the very
top and the phone must fetch it before it can draw anything. The other two compete with the page for the
phone's processor.

> Be clear about what this achieves: **moving code later is not the same as removing it.** Most of this
> ticket makes the page usable sooner without reducing the total work the phone does. Only two parts are
> a genuine removal — retiring Google Tag Manager, and switching the accessibility toolbar off on phones.
>
> **A decision for the owner:** UserWay is an accessibility toolbar. Switching it off on phones, or
> delaying it, takes it away from the visitors who most need it. That is the practice's call, not a
> technical one. See Ticket 2 for what is actually being traded.

**3. The 35-video testimonial slideshow.** Thirty-five YouTube preview images download on every visit
whether or not anyone scrolls to them. **We also found something the earlier audit missed: the slideshow
is set to loop and to advance itself every three seconds, forever.** Looping makes the browser build 105
slides instead of 35, and the automatic advance keeps animating for as long as the page is open. Both are
tick-boxes in the slideshow settings, and turning them off is a fraction of the cost of the full rebuild.

> **A decision for whoever owns SEO:** the slideshow also publishes video information that Google reads
> for search results. A full rebuild removes it unless it is deliberately put back. Ticket 3 says exactly
> how. This must be agreed before the rebuild, not discovered after.

## What we are asking Inception to do

| | Work | Time | Blocked on |
|---|---|---|---|
| **Now** | Check Search Console → Core Web Vitals for field data | 5 min | — |
| **Ticket 1** | Hero video | ~1.5 hrs | Owner's yes on the still photo |
| **Ticket 2** | Third-party code | 3–5 hrs | Owner's decision on the accessibility toolbar; sign-off from whoever owns the Google Tag Manager account |
| **Ticket 3, part 1** | Turn off slideshow loop and autoplay | ~30 min | — |
| **Ticket 3, part 2** | Rebuild the slideshow | 4–8 hrs | SEO sign-off on the video data |

**What this will not do.** It will not produce a green score. Reaching 90 needs the page rebuilt — 3,197
elements, four JavaScript libraries doing two jobs, and outside code the practice does not control. That
is a separate conversation. We are also not projecting a score, a ranking, or a number of enquiries,
because nothing measured supports one.

---
---

# Part 2 — work tickets for Inception's technical team

## Read this first — three things that will otherwise waste your afternoon

**A. There is a server-side page cache and no WordPress control for it.**
Measured 13 Aug: the homepage returns `server: LiteSpeed` with `x-litespeed-cache: miss` on a first fetch
and `hit` on the second. **The LiteSpeed Cache plugin is not installed** —
`/wp-content/plugins/litespeed-cache/readme.txt` returns the WordPress 404 page — so there is no "Purge
All" button and no WP-CLI purge. HTML carries **no `Cache-Control` header at all** (verified on 15
distinct HTML responses today).

Consequence: after any change, a plain re-fetch may serve you the old page and you will think the fix
failed. Use a unique query string to force a fresh render:

```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
curl -sS --max-time 30 --compressed -A "$UA" "https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

Use a **new** value every time. Note the query-string URL creates its own cache entry, and the response
differs from the canonical page by about 58 bytes because the URL is echoed into an inline block. So:
**verify on `?cb=` to see what the origin now generates, then confirm on the plain URL that visitors are
getting it.** If the plain URL is still stale after ~10 minutes, whoever holds server access must flush
the LiteSpeed cache from the hosting console.

**B. Editing the child theme's CSS does not reach returning visitors.** This blocks Tickets 1 and 3.
Measured 13 Aug: `bb-theme-child/style.css` is enqueued as `style.css?ver=7.0.4` — that is the **WordPress
version**, not the file's — and served `cache-control: public, max-age=2592000` (30 days) with **no
ETag** and `last-modified: Mon, 08 May 2017`. Editing the file changes neither the URL nor the version
string, so every browser that loaded the site in the last 30 days keeps using its cached copy.

**Fix this before any CSS work, or your CSS fix will appear not to work.** In
`/wp-content/themes/bb-theme-child/functions.php`:

```php
add_action( 'wp_enqueue_scripts', function () {
    $h = 'fl-child-theme';
    if ( wp_style_is( $h, 'registered' ) ) {
        wp_styles()->registered[ $h ]->ver = (string) filemtime( get_stylesheet_directory() . '/style.css' );
    }
}, 100 );
```

Verify: `curl -sS --compressed "https://www.highcountrypainrelief.com/?cb=$(date +%s)" | grep -o 'bb-theme-child/style.css?ver=[^"'"'"']*'`
must show a Unix timestamp, **not** `7.0.4`. Re-check after your next CSS edit — the number must change.

**C. `bb-theme-child/style.css` and `bb-theme-child/functions.php` are the only two files these tickets
have to work with.** If two people edit them in the same window over SFTP, one will silently overwrite
the other. Do the tickets in separate sessions, and download the current copy of each file immediately
before every edit.

**Platform, as measured today (the audit's header is stale):** WordPress **7.0.4** (was 7.0.2), Beaver
Builder **2.10.3.1** (was 2.10.3), Beaver Themer 1.5.3.2, BB Theme 1.7.19.2, PowerPack, Ultimate Addons.
Beaver Builder's compiled bundles were regenerated 11 Aug and are **smaller** than the audit recorded:
`2-layout.js` 87,756 → 72,591 B raw, `2-layout.css` 185,968 → 164,124 B raw. Homepage HTML 216,956 B raw
/ 33,290 B Brotli.

---

## TICKET 1 — Hero background video

**Covers:** audit finding C1. **Effort:** ~80 min, plus an optional 30 min on the media host.
**Blocked on:** the practice's yes (phones lose the motion). **Independent** of Tickets 2 and 3 — but see
note C above; it edits both child-theme files.

### Why this is first

| | Measured 13 Aug, 3 runs |
|---|---|
| Share of mobile payload | **~88%** — `inceptionimages.com` served **15,060–15,122 KiB** of a ~17,000 KiB page. **The whole video now downloads**, in two range requests |
| The LCP element | the video, at **12.2 s** median, of which **65–73% (7,527–7,901 ms) is Load Delay** |
| Share of the CLS score | **100%** — 0.1841 of 0.1841, one element, **on the cold-cache run**. Both warm runs scored 0.000 |
| `hiking.mp4` on disk | **15,343,649 B**, 1920×1080, 15.67 s — **and not faststart** (see step 1D) |
| `hiking.webm` on disk | **5,802,541 B** |
| The fallback still | **76,870 B**, first-party |

> **July recorded 3,112 KiB transferred and 60.7% of payload; August recorded the full ~15 MB and ~88%.**
> Nothing changed on the site. The browser aborts the download at a different point each run, so **no
> single payload figure from this page is reliable** — but the conclusion holds harder than the audit
> stated, not softer.

> **Verify CLS against a cold cache only.** A warm-cache run scores 0.000 today, before any fix. Testing
> warm will "confirm" a fix that did nothing. See `VERIFYING-BACKEND-CLAIMS.md`, trap 1.

Load Delay is that large because **nothing about the video is in the HTML.** Measured today: `<video>` 0,
`<source>` 0, `poster=` 0. Beaver Builder builds all of it in JavaScript from `data-` attributes on
`div.fl-bg-video`, so the browser cannot discover the LCP element until `2-layout.js` has run.

### Evidence, measured 13 August

The served hero row still carries `data-video-mobile="yes"` — unchanged, nobody has touched it:

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

No `data-width`, no `data-height` anywhere in the document. That absence is what causes the layout shift.

From `2-layout.js` on the origin, verbatim — **note both branches append**:

```js
if(!FLBuilderLayout._isMobile()||(FLBuilderLayout._isMobile()&&"yes"==videoMobile)){
  … else{wrap.append(videoTag); … play/pause wiring … }}
else{videoTag.attr('src','')
wrap.append(videoTag);}
```

`grep -o -F 'wrap.append(videoTag)' 2-layout.js | wc -l` returns **2**. Setting the row to No does **not**
remove the `<video>` element — it sets `src=""`, which makes the browser ignore both `<source>` children,
so neither file is fetched. **Do not verify by looking for the absence of a `<video>` element.**

The mobile gate is **user-agent based**, not viewport based:
`_isMobile:function(){return/Mobile|Android|Silk\/|Kindle|BlackBerry|Opera Mini|Opera Mobi|webOS/i.test(navigator.userAgent);}`
A desktop browser at a narrow window still gets the video.

Sizing, when `data-width`/`data-height` are absent — this is the layout shift:

```js
vid.css({'left':'0px','top':'0px','width':newWidth+'px'});   // pass 1
vid.on('loadedmetadata',FLBuilderLayout._resizeOnLoadedMeta); // pass 2, when the video's own size arrives
win.on('resize.fl-bg-video', … 100 ms debounce … );           // and again on every resize
```

Both are jQuery `.css()` calls, which write the **inline `style` attribute**, and BB re-applies them on a
debounced resize. **This is why `!important` is load-bearing in step 1B.**

The served stylesheet rule is `.fl-row-bg-video .fl-bg-video video` — specificity (0,3,1), **not** the
(0,1,1) the audit quoted. A plain `.fl-bg-video video {…}` override without `!important` loses twice: to
this rule and to the inline styles.

### Proposed solution

**Step 1A — Show Video On Mobile = No.** *10 min. This is the whole payload win and it is safe alone.*

1. wp-admin → Pages → Home → **Launch Beaver Builder**.
2. Hover the top hero row (node `49vu6prnm80g`) → click the **wrench** on the row's blue toolbar → **Row
   Settings**.
3. **Style** tab → **Background** section → Background Type is **Video** → set **Show Video On Mobile**
   to **No**.
4. **Save** → **Done** → **Publish**.

**Step 1A2 — turn off the play/pause button, in the same session.** The `<div class="fl-bg-video-play-pause">`
above is real markup in the served HTML, and its click handler is bound **only inside the if-branch** of
the mobile gate. After 1A, phone visitors get a play triangle that does nothing. In the same Row Settings
→ Background panel, turn the play/pause control off. If your BB version has no such option, add to the
child theme CSS in step 1B: `@media (max-width:767px){.fl-bg-video-play-pause{display:none;}}`

**Step 1B — stop the layout shift (desktop).** *10 min. Do note B above first.*
Append to `/wp-content/themes/bb-theme-child/style.css`:

```css
/* Hero video: defeat Beaver Builder's two inline sizing passes. Every !important is required —
   BB writes these as inline styles via jQuery .css() and re-applies them on a debounced resize.
   MAINTENANCE: see the note under step 1C about the hero photo being defined in three places. */
.fl-row-bg-video .fl-bg-video video{
  width:100% !important; height:100% !important;
  left:0 !important; top:0 !important;
  min-width:0 !important; min-height:0 !important;
  max-width:none !important; transform:none !important;
  object-fit:cover;
}
```

**Step 1C — make something paint early.** *25 min. SFTP. Back up `functions.php` first.*

Half one, in `style.css`:

```css
.fl-node-49vu6prnm80g .fl-bg-video{
  background:url(https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp) center/cover no-repeat;
}
```

Half two, in `functions.php`. **A preload on its own paints nothing** — it warms the cache for an image
that is otherwise only applied to an element JavaScript creates later. The CSS above is the half that
makes it visible.

```php
add_action( 'wp_head', function () {
    if ( ! is_front_page() ) { return; }
    echo '<link rel="preload" as="image" fetchpriority="high" href="https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp">' . "\n";
    echo '<link rel="preconnect" href="https://www.chiro.inceptionimages.com" crossorigin>' . "\n";
}, 2 );
```

> **Placement.** Open `functions.php` over SFTP and download a copy named `functions.php.bak-2026-08-13`
> **before** editing. If the last line of the file is `?>`, insert immediately **above** it. If there is
> no closing `?>`, append at the end. Do not add a second `<?php`. Immediately after uploading run
> `curl -sS -o /dev/null -w '%{http_code}\n' https://www.highcountrypainrelief.com/` — it must return
> `200`. A PHP syntax error here whites out the whole site.

> **The preconnect is still worth it after 1A.** This page loads **6 `<img>` elements** from
> `www.chiro.inceptionimages.com` on every device, plus CSS background images from the same host. That
> host is a second DNS + TLS handshake on the critical path whether or not the video is disabled.

> **MAINTENANCE — the hero photo is now defined in three places:** the Beaver Builder row background
> setting, the CSS rule above, and the preload. If anyone later changes the hero photo in Beaver Builder,
> all three must change together or the page will flash the old photo and preload a file it never uses.
> Search the child theme for `Chronic-Pain-Boone-NC-Hiking` before changing that row.

**Step 1D — optional, desktop only, 30 min: make the MP4 streamable.** The audit missed this.
`hiking.mp4` is **not faststart**: its 5,493-byte `moov` atom sits at the very end of the file, behind
15,338,116 bytes of `mdat`. The browser cannot begin playback until it has that atom. One lossless
command, no re-encode, no visible change:

```bash
cp hiking.mp4 hiking.mp4.bak-2026-08-13
ffmpeg -i hiking.mp4 -c copy -movflags +faststart hiking-faststart.mp4
# verify, then rename over the original
```

> **Preconditions and blast radius.** This needs shell access on the media host with ffmpeg. FTP only?
> Download, run it locally, upload as a new filename, confirm it plays, then rename. **This file sits in
> a shared Inception media library** (`chiro.inceptionimages.com` also serves this page's background
> images) and may be referenced by other client sites. The remux is lossless and the file stays
> byte-compatible, but keep the backup.

### Verification — every check discriminates

Prefix each command with:
```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
U="https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

| # | Check | Before (today) | After |
|---|---|---|---|
| V1 | `curl -sS --compressed -A "$UA" "$U" \| grep -c 'data-video-mobile="yes"'` | **1** | **0** |
| V2 | DevTools → Network, phone UA, **filter on `hiking`** | ≥1 row, megabytes | **0 rows** |
| V3 | `curl -sS --compressed -A "$UA" "$U" \| grep -o 'fl-bg-video-play-pause' \| wc -l` | **2** | **0** |
| V4 | After 1B only: `grep -o '!important' style.css \| wc -l` | baseline | **baseline + 8** |
| V5 | DevTools → Elements → select the `<video>` → **Styles** pane | BB's `element.style` wins | BB's `left/top/width/height` shown **struck through** |
| V6 | Desktop Lighthouse → *Avoid large layout shifts* | 0.184 from this element | no non-zero shift listed |

> **V2 is the decisive check and it has one trap.** **Do not filter on the hostname.** Six product and
> lifestyle images on this page legitimately come from `chiro.inceptionimages.com` and will still be
> requested after a perfect fix. Filter on `hiking`. Only `hiking.mp4` and `hiking.webm` must be absent.

> **V1 note:** after the change the attribute reads `"no"` or is absent — either is a pass, because BB's
> gate tests for the literal string `"yes"`. Also expect `grep -c 'hiking.mp4'` to still return **1**
> both before and after: the `data-mp4` attribute stays in the markup, only the fetch stops.

> **V5 note:** do not use the Computed panel. It reports used values in pixels, always — you will never
> see "100%" there, and a perfect fix will look like a failure.

**Two claims here are read from Beaver Builder's code, not executed in a browser. Confirm both in
DevTools on the first pass:** (i) that the fallback WebP becomes the LCP element on mobile; (ii) that
`loadedmetadata` never fires. Note that BB's first sizing pass **still runs** after this fix — its guard
is `if(0===$(this).find('video').length…){return;}` and a `<video src="">` passes it. One pass runs, the
second is bound but never fires. (The old worry that an empty `src` causes the browser to re-request the
page as media is unfounded: the HTML spec jumps straight to the failure step for an empty `src`.)

**Rollback:** 1A and 1A2 revert through the page's revision history. 1B and 1C revert by restoring the
two backed-up files. 1D reverts by renaming the `.bak` back.

---

## TICKET 2 — Third-party code from ReviewWave, UserWay and Google Tag Manager

**Covers:** audit findings H2, H3, H6. **Effort:** 3–5 hrs across four steps, ship each separately.
**Blocked on:** the practice's accessibility decision (step 2); written sign-off from the Google Tag
Manager account owner (step 3).

### What this ticket actually achieves — read before quoting a number

**Deferring code moves work; it does not delete it.** And **quote the ranking, not the absolute
milliseconds** — the two Lighthouse runs disagree by roughly 5× on CPU figures because they ran on
different machines, while the ordering is identical:

| Third party | July | August (3 runs) | Rank |
|---|---|---|---|
| **UserWay** | 2,443 ms | **481–495 ms** | 1st, both |
| **Google Tag Manager** | 1,165 ms | **297–351 ms** | 2nd, both |
| ReviewWave | 196 ms | 33 ms | 3rd, both |

- **Genuinely removed** by step 3: `gtm.js` — 116,234 B of download per cold load and **333,526 B of
  JavaScript parsed and executed on every page view**, cached or not.
- **Genuinely removed** by step 2 Option B, if the practice agrees: 51,813 B transfer / 181,374 B parsed,
  on mobile only.
- **Moved, not removed** by steps 1 and 2 Option A: the phone does the same total work, later. First
  paint improves; total CPU does not fall.

Do not add render-blocking estimates to the blocking figure — they describe overlapping cost on the same
files. Lighthouse's headline for **all** render-blocking resources is **1,330 ms** (August; 1,370 ms in
July) and its per-row figures sum to more than that. Neither is a prediction.

**August confirms which resource to attack first.** The single largest render-blocker on the page is the
ReviewWave S3 config at **1,451 ms estimated savings** — bigger than jQuery, Bootstrap and the Beaver
Builder bundle combined. Three of the top three are ReviewWave and Google Fonts. That is step 1 below,
plus `&display=swap` (audit M5).

### Step 0 — find the injection point. *20–45 min.*

All three vendors' tags sit in **one contiguous hand-authored block**, site-wide — verified byte-identical
on `/`, `/contact-us/`, `/testimonials/` and `/knee-pain-lp/`. In the served HTML the block appears
immediately after the closing `</style>` of `<style id="wp-custom-css">`, which core prints on `wp_head`
at priority 101 — so the injector runs on `wp_head` at priority > 101. That rules out static markup in
`header.php`.

Measured positions today (the audit's positions are wrong): GTM inline loader is script tag **#5 of 32**
at byte 39,732; the ReviewWave inline config is **#6** at 40,198; the three ReviewWave `src` tags are
**#7/#8/#9** at bytes 40,410 / 40,501 / 40,573, immediately before `</head>`; the UserWay block opens at
byte **205,885** — 95% of the way down the document, emitted on `wp_footer`.

Look in this order, all from wp-admin or FTP:

1. **wp-admin → Beaver Builder → Themer Layouts** — open the header part, look for an HTML module.
   Beaver Themer is installed and stores markup in the database; check this first, it needs no shell.
2. **Appearance → Customize** → BB Theme's Code / Header Code panel.
3. **Plugins** list → any "Headers and Footers" / "Insert Scripts" plugin, **and the site's own custom
   plugin** — `/wp-json/` registers `inception-office-hours/v1`, an Inception-authored plugin and a prime
   candidate.
4. Still nothing? Over FTP, download `wp-content/themes/`, `wp-content/mu-plugins/` and
   `wp-content/plugins/` and grep locally for `reviews_embed.js` — **without** `--include="*.php"`, since
   the string may sit in a non-PHP file.
5. Only if all of that fails is it elsewhere in the database, which needs phpMyAdmin or SSH.

**Before changing anything:** select the entire contents of the field or file and paste it into a dated
text file kept outside the site — `rollback-2026-08-13-header-code.txt`. **This is the only rollback that
exists.** There is no WordPress-side cache purge on this server, so a bad edit stays visible until the
LiteSpeed TTL expires or the host flushes it.

### Step 1 — defer the three ReviewWave tags. *20 min + 20 min phone regression.*

Add `defer` to these three tags at the injection point:

```
rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js
cdn.reviewwave.com/js/reviews_embed.js
cdn.reviewwave.com/js/chat_embed.js
```

**The usual `defer` hazard does not apply here, and we checked.** Measured: **zero `document.write`** in
all three files. Both embeds self-locate with `document.querySelectorAll('script[src*="…"]')` rather than
`document.currentScript`, which is defer-safe; `defer` preserves document order so the S3 config still
runs before `reviews_embed.js` consumes `window._rwReviewEmbed`; and `chat_embed.js` carries a 500 ms
`setTimeout` fallback. **Regression-test anyway** — this is the practice's review carousel and chat
widget, a live lead channel.

**ReviewWave is bigger than the audit recorded.** Not three resources but **six**: the two embed scripts
each inject a stylesheet at runtime, and `chat_embed.js` fetches a second S3 config. Total **73,995 B
transfer / 120,119 B uncompressed over 6 requests**, none carrying `Cache-Control`. The main S3 config is
**57,267 B served uncompressed**; `gzip -9` takes it to 19,115 B — a 38,152 B saving per uncached visit.
Inception cannot fix that; see step 4.

**Verify:**

| Check | Before | After |
|---|---|---|
| `curl … \| grep -oE '<script[^>]*(\sdefer\|\sasync)[ =>]' \| wc -l` | **0** | **exactly 3** |
| `curl … \| grep -o 'defer src="https://rw-embed-data' \| wc -l` | 0 | **1** |
| **On a real phone:** load `/` and `/testimonials/` | — | ReviewWave badge appears; chat bubble opens, accepts a name and message, and submits |

> Do **not** use `grep -c 'defer\|async'` — it returns **24** on the unmodified site today, because core
> emits `decoding="async"` on 22 images and `grep -c` counts lines, not matches.

> **Rollback trigger:** if the chat bubble does not appear within 10 s on a phone, remove `defer` from
> `chat_embed.js` only, re-verify, and report.

**Then stop. Wait 24 hours before shipping step 2.** Steps 1 and 3 edit the same block; shipping them
together means you cannot tell which one broke something.

### Step 2 — UserWay. *45–90 min. BLOCKED on a written decision from the practice.*

**What UserWay is:** a third-party commercial accessibility overlay from **userway.org** — not custom
code, and not built by Inception. It is installed as a WordPress plugin (version **2.4.8**), registers
`userway/v1` with `/save` and `/debug` routes, and runs under account `Vgm0gbMRdF`.

**Two audit assumptions are now settled, and they point in opposite directions:**

- ❌ *"Check the plugin's settings for a defer mode first."* **Dead end.** The plugin's entire frontend
  contribution is one echo of the inline snippet. There is no defer, delay, async, mobile or loading
  option. `/userway/v1/debug` returns only `{account_id, state, created_time, updated_time}`. UserWay's
  public help centre has 36 widget articles and none covers deferred loading.
- ✅ *"60–90 min if the plugin's hook must be unhooked."* **Cheaper than feared.** The plugin registers
  its output with `add_action('wp_footer','usw_addplugin_footer_notice')` — a **named global function at
  default priority 10**, removable in one line.

**Option A — delay it (keeps the toolbar, moves the cost).** In the child theme:

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

`{timeout:3000}` is **not optional** — this page has 20 long tasks [LH 30 Jul] and bare
`requestIdleCallback` can starve indefinitely. Setting `.defer = true` on a dynamically created script
is a no-op; they are already async.

> **Be honest about what Option A buys.** UserWay's app script is *already* async and already waits for
> `DOMContentLoaded` inside `widget.js`. Option A is a CPU-contention fix, not a render-blocking fix: it
> pushes ~2.4 s of phone processor work about three seconds later so it stops competing with the page
> becoming usable. **It does not delete that work.**

**Option B — switch it off on phones (a genuine removal).** `widget.js` contains an undocumented mobile
kill switch: if `window._userway_config.mobile` is `false` and the user agent matches `/mobile/i`,
`widget.js` exits without loading the app. Five lines in the child theme, ahead of the snippet:

```php
add_action( 'wp_footer', function () { ?>
<script>window._userway_config = window._userway_config || {}; window._userway_config.mobile = false;</script>
<?php }, 5 );
```

Removes **51,813 B of transfer and 181,374 B of parsed JS+CSS on mobile** — where the failing measurement
lives.

> **The decision, stated plainly for the practice.** UserWay is an accessibility tool. Option A makes it
> unavailable for at least three seconds and on a cold load plausibly longer. Option B removes it from
> phones entirely. Both cost the visitors who most need it. This is the practice's call, in writing,
> before the work — not a technical trade-off Inception should make alone. Removing the overlay entirely
> is a separate question with legal dimensions and is out of scope here.

**Two measurement caveats.** UserWay rolled a **new build on 10 August** — eleven days *after* the
Lighthouse run — so the 2,443 ms CPU figure describes a bundle that is no longer served. And the audit's
`widget_base.css` at 71 KiB does not reconcile with today's 4,006 B transfer / 20,542 B uncompressed.
Treat the UserWay CPU numbers as indicative, not as targets.

**Verify:**

| Check | Before | After |
|---|---|---|
| `curl … \| grep -o 'cdn.userway.org/widget.js' \| wc -l` | 1 | **exactly 1** |
| `curl … \| grep -c 'requestIdleCallback'` (Option A) | **0** | **1** |
| Cold phone load | — | toolbar icon still appears within 5 s (Option A) |

> If the first check returns **2**, the `remove_action` failed silently and the plugin's undeferred copy
> is still firing. The page will look fine and the fix will not have been applied.

### Step 3 — retire Google Tag Manager. *30 min. BLOCKED on written sign-off from the GTM account owner.*

**We extracted the container's own resource JSON from `gtm.js`. It contains exactly one tag** —
`__googtag` → `G-CW4KKYCP1V`, `send_page_view=true` — one variable, one trigger, one rule. There are no
unused tags to prune and no duplicate analytics to deduplicate. **The audit's "audit the container"
recommendation would return nothing and burn the 1–2 hours budgeted for it.**

So the choice is binary: keep GTM for future flexibility, or retire it and load the one tag directly.
Retiring it removes **116,234 B of download per cold load** (`gtm.js` is `cache-control: private,
max-age=900`, so it is reused within a 15-minute session) and **333,526 B of JavaScript parsed and
executed on every single page view**, cached or not — about **831 ms** [LH 30 Jul].

Replace the GTM inline snippet and its `<noscript>` iframe with:

```html
<script async src="https://www.googletagmanager.com/gtag/js?id=G-CW4KKYCP1V"></script>
<script>window.dataLayer=window.dataLayer||[];function gtag(){dataLayer.push(arguments);}
gtag('js',new Date());gtag('config','G-CW4KKYCP1V');</script>
```

> **What the practice loses:** the ability to add or change tracking tags without a developer. That is a
> real capability. If anyone expects to add conversion tracking, ad pixels or call tracking soon, keep
> GTM and skip this step.

**Analytics verification is mandatory and blocking.** Solid Security is installed (`ithemes-security/v1`),
which raises the odds of a security plugin stripping a hand-placed script tag.

1. **Before** changing anything: open Google Analytics → Reports → **Realtime** for `G-CW4KKYCP1V`, load
   the homepage on your phone, confirm you appear.
2. Make the change. Cache-bust. Load the homepage from the same phone.
3. Confirm you appear in Realtime **within 60 seconds**. Also check DevTools → Network, filter `collect`,
   for a request to `/g/collect` with `tid=G-CW4KKYCP1V`.
4. **If you do not appear within 5 minutes, revert immediately** from the saved copy and report. Do not
   leave the site on an unverified analytics tag overnight.

Then: `grep -o 'GTM-WGXQKR5' | wc -l` → **0**, and `grep -o 'gtag/js?id=G-CW4KKYCP1V' | wc -l` → **1**.

### Step 4 — vendor ask. *Owner: the practice, not Inception.*

ReviewWave serves its 57,267 B config file uncompressed with no caching. ReviewWave will only act on a
request from the account holder. Inception supplies the wording; **the practice sends it** from the email
on the ReviewWave account, copying Inception:

> "Our website loads a review data file from your service —
> `rw-embed-data.s3.amazonaws.com/6809-a7ea-455a-196e-77a8.js`. It is served without compression or
> caching, which makes our pages slower. Could you enable gzip or Brotli compression and a
> `Cache-Control` header on that file? Our developers estimate it would cut it from 57 KB to about 19 KB."

### While you are in here — two security items, ten minutes

Both are in **`SECURITY-FINDINGS.md`** with fixes and verification. They are listed here because this
ticket already has the same plugin and the same file open:

- **S1** — `/wp-json/userway/v1/debug` is publicly readable and returns the PHP version, WordPress
  version, plugin version, UserWay account ID and the **database table prefix**. A UserWay defect, not a
  site defect, but blockable from the child theme.
- **S2** — `/wp-json/wp/v2/users` returns two valid usernames unauthenticated. One filter closes it.

Neither is urgent. Both are cheaper to do now than to schedule.

---

## TICKET 3 — The 35-video testimonial slideshow

**Covers:** audit findings H8b, M4, part of M2. **Effort:** part 1 ~30 min, part 2 4–8 hrs.
**Blocked on:** SEO sign-off before part 2 only. **Part 1 is not blocked on anything.**

### Part 1 — turn off Loop and Autoplay. Do this regardless. *~30 min.*

**The audit missed this and it is most of the CPU win for none of the cost.**

**Loop.** PowerPack passes `loopedSlides: this._getSlidesCount()` — that is **35** — to Swiper. Swiper
8.4.7's `loopCreate` then prepends *and* appends 35 deep clones each, producing **105 children**. Swiper's
own default with `slidesPerView: 1` would have been **2 clones**. Untick Loop and roughly **1,286
JavaScript-built DOM elements disappear**.

> Lighthouse reported "Maximum Child Elements: 105" on `div.pp-video-gallery-items.swiper-wrapper` in
> **both** the July and the August runs, and DOM depth 28 in both. This one is not host-dependent and not
> a single-run artefact.

**Autoplay.** The compiled bundle reads, in three consecutive statements:

```js
options.carousel={ … autoplay:false, … };
options.carousel.autoplay={delay:3000,disableOnInteraction:true,};
gallery_joy14c0h3re9=new PPVideoGallery(options);
```

The literal `autoplay:false` is **overwritten by a truthy object one statement later**, and
`_getSwiperOptions` contains `if(!this.isBuilderActive&&this.carousel.autoplay){options.autoplay=this.carousel.autoplay;}`
with `isBuilderActive:false` in the served bundle. **Autoplay is on.** The carousel runs a 1,000 ms
transform transition every 3,000 ms, forever, across 105 slides, each transition invoking Swiper's
`loopFix()`. That cost is not at load time — it continues for as long as the page is open.

Reproduce both:
```bash
curl -sS --max-time 30 --compressed 'https://www.highcountrypainrelief.com/wp-content/uploads/bb-plugin/cache/2-layout.js' \
  | grep -o 'options.carousel.autoplay={[^}]*}'
# returns: options.carousel.autoplay={delay:3000,disableOnInteraction:true,}
```

**Do it:** wp-admin → Pages → Home → Beaver Builder → the Video Gallery module → **untick Loop**, **untick
Autoplay** → Save → Publish. **Repeat on `/testimonials/`.** Then clear the Beaver Builder cache **and**
confirm the LiteSpeed page cache has caught up (see note A).

**Verify:** re-run the `grep -o 'options.carousel.autoplay=' ` command above against the regenerated
`2-layout.js` — it must return nothing.

### Part 2 — replace the slideshow with click-to-play. *4–8 hrs.*

**Why `loading="lazy"` cannot be the cheap fix.** All 35 thumbnails are inline-style **CSS
`background-image`** on `div.pp-video-image-overlay`. `loading="lazy"` is an attribute of `<img>` and
`<iframe>` elements; it has no effect on CSS backgrounds. That is why this needs a rebuild and not an
attribute.

**The real numbers, and one correction that halves a headline.**

| | Measured 13 Aug |
|---|---|
| Distinct videos site-wide | **39.** The homepage's 35 are a **strict subset** of the 39 on `/testimonials/` |
| Thumbnail weight, homepage | ~**460 KiB ± 30 KiB** (two samples: 13,394 B mean n=10; 13,512 B mean n=8) |
| A visitor who sees both pages within 2 hrs | **39 thumbnails, ~520 KB** — not 74. The URLs are identical and `i.ytimg.com` sets `max-age=7200` |
| Gallery markup | 69,368 B of the 216,956 B raw HTML (**31.97%**) — but **under 3 KB on the wire.** 35 near-identical templates compress almost away. The DOM and CPU win is the reason to do this; the download win is small |
| Swiper | `swiper.min.js` 143,660 B raw / 38,121 B Brotli; `swiper.min.css` 16,494 B. Loads on **exactly 2 of 44 pages** — this gallery is what pulls it |

**`/testimonials/` carries a second, larger instance of the same gallery** — 39 slides, its own copy of
Swiper, on a 224,593 B page **bigger than the homepage**. The audit never mentioned it. Do both pages or
you leave the worse one untouched.

**The SEO decision, with exact numbers.** The gallery emits **31** microdata `VideoObject` blocks across
**186** meta tags. (Not 33/198 — two standalone video modules outside the carousel are separate and keep
their markup. Four gallery slides — `cvbQYotHZb0`, `TGw16jnwcGE`, `TGm19YJWH8c`, `CGBDsDLkNIE` — carry no
`itemscope` at all, which is a content-entry gap worth fixing separately.)

A facade emits **zero** structured data. Not "may remove" — **will remove**. The mitigation is cheap: re-emit
one JSON-LD `ItemList` of `VideoObject` entries using the property values already in today's HTML.

> **Three rules for that JSON-LD, or it becomes a Google policy violation.**
> 1. **The JSON-LD must describe exactly the videos rendered on that page.** If the homepage shows 6, emit
>    6. Markup for videos not on the page is precisely what Google's structured-data guidelines prohibit.
>    Success criterion: **`VideoObject` count equals rendered poster count**, on each page.
> 2. **Drop `contentUrl`; keep `embedUrl` only.** These videos are hosted by YouTube, and Google asks for
>    `embedUrl` alone in that case. (The existing markup's `contentUrl` is a page URL, which is wrong now.)
> 3. **Do not invent `uploadDate`.** Today's values are four bulk placeholders across 33 videos — 22 of
>    them share `2025-02-21T10:00America/Chicago`, which is not valid ISO 8601 anyway. Get real dates from
>    YouTube (`curl "https://www.youtube.com/watch?v=<ID>" | grep -o '"uploadDate":"[^"]*"' | head -1`), or
>    **omit the key entirely**. An entry without `uploadDate` is not eligible for a video rich result —
>    which is exactly where the site already stands.

**If you use `lite-youtube-embed`** (0.3.4, released 2025-11-10, Apache-2.0, no dependencies — 10,630 B JS
+ 2,767 B CSS uncompressed, 3,960 B + 1,273 B gzipped):

- **A naive swap makes this worse, not better.** Its `connectedCallback` sets `style.backgroundImage` to
  the same `i.ytimg.com/vi/{id}/hqdefault.jpg` URL *and* fires a second request per video to
  `i.ytimg.com/vi_webp/{id}/sddefault.webp`. **35 requests become about 70.** Exploit its own guard —
  `if (!this.style.backgroundImage)` — by setting the poster yourself, or self-host the 35 posters.
- Enqueue the assets **conditionally**. Unconditional enqueue adds two requests to the 42 pages that have
  no video strip — worse-scoped than the thing it replaces:
  ```php
  function hcpr_yt_assets() {
      if ( ! is_front_page() && ! is_page( 'testimonials' ) ) { return; }
      /* wp_enqueue_style(...); wp_enqueue_script(...); */
  }
  ```
  Do **not** gate on `has_shortcode()` against `post_content` — Beaver Builder layout data lives in the
  `_fl_builder_data` postmeta, so it will never match.
- **`wp_script_add_data( $handle, 'defer', true )` is a no-op.** WordPress core reads the `strategy` key,
  not `defer`. Use the array form:
  ```php
  wp_enqueue_script( 'hcpr-yt', $d . '/js/hcpr-yt-facade.js', array(), '1.0.0',
      array( 'in_footer' => true, 'strategy' => 'defer' ) );
  ```

### Verification

Purge the LiteSpeed page cache **as well as** the Beaver Builder cache first — clearing BB's cache
regenerates `2-layout.js`, it does **not** evict the cached HTML that still contains the gallery block.

| # | Check | Before (13 Aug) | After |
|---|---|---|---|
| V1 | `curl … \| grep -c 'pp-video-gallery-item swiper-slide'` | **35** | **0** |
| V2 | `curl … \| grep -c 'swiper.min'` on `/` **and** `/testimonials/` | **2 each** (js + css) | **0 each** |
| V3 | `grep -o 'i.ytimg.com' \| wc -l` | 35 | the number of videos you kept — **and not 70** |
| V4 | DevTools → Network, filter `ytimg`, page at top | 35 | ≤ 3, rising only as you scroll |
| V5 | Click a thumbnail | — | a YouTube player appears and plays |
| V6 | `VideoObject` count vs rendered poster count | 31 vs 35 | **equal** |
| V7 | Homepage raw HTML | 216,956 B | ~148,000 B |

**Rollback:** restore the PowerPack gallery modules from the page revision history on both pages, remove
the child-theme files, purge both caches.

---

## Sources for Part 1's search claims

- Mobile-first indexing — "Google uses the mobile version of a site's content, crawled with the smartphone
  agent, for indexing and ranking":
  `developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing` (updated
  10 Dec 2025)
- Page experience and Core Web Vitals as ranking signals, including "there is no single signal":
  `developers.google.com/search/docs/appearance/page-experience` (updated 10 Dec 2025)
- Current thresholds — LCP 2.5 s, CLS 0.1, INP 200 ms, all at the 75th percentile of real users:
  `web.dev/articles/vitals`
- INP replaced FID on 12 March 2024: `web.dev/blog/inp-cwv-launch`
- TBT is a lab proxy for INP and is not itself a Core Web Vital: `web.dev/articles/vitals`
- Vodafone A/B test, 31% LCP improvement → 8% more sales: `web.dev/case-studies/vodafone` (2021). On
  Google's roll-up page this is the **only** entry run as a controlled A/B test; the other ~18 are
  before/after observations and cannot support a causal claim.

**Claims deliberately not made in this document, and why:** that this work will improve rankings (Google
publishes no weight and says good scores do not guarantee ranking); that Google penalises slow sites (no
such penalty is documented); the widely-quoted "53% of mobile visitors leave after 3 seconds" (a 2016
correlational sample of publisher sites, not this vertical, and Google's own current teaching page no
longer cites it); and any projected score, ranking, revenue or enquiry figure for this practice.

---

## Method and limits

- **Lighthouse was re-run on 13 August 2026** — three mobile runs, Lighthouse 12.8.2 on Chrome for
  Testing 152, median reported. Full data and limits: `audit/data/lighthouse-mobile-2026-08-13.md`.
  Scores were 27 / 33 / 34; the spread on an unchanged site is 7 points, 2.0 s of LCP and all of CLS.
- **The July and August runs are not directly comparable, and the difference is the measuring machine,
  not the site.** Lighthouse calibrates the simulated *network* but applies a fixed ×4 CPU multiplier to
  whatever host it runs on, so CPU figures scale with the test machine. August's host scored
  `benchmarkIndex` ≈ 1,300; July's was not recorded. **Quote CPU figures with the host attached, or not
  at all.** Everything structural reproduced exactly: same LCP element, same single CLS source, same 105
  child elements, same DOM depth, same render-blocking leader, same third-party ranking.
- **Everything else was measured live on 13 August 2026** with `curl`, and re-derived from the origin's
  own JavaScript and CSS: 216,956 B of homepage HTML, the Beaver Builder bundles, all six ReviewWave
  resources, UserWay's `widget.js`, the GTM container JSON, 12 sitemap URLs across two passes, and the
  video file containers.
- **Cache behaviour today:** 12 of 12 first requests were cache MISSes. Cold TTFB median **1.054 s**
  (n=12, min 0.592 s, max 2.225 s); warm median **0.076 s**. Consistent with the audit's finding that the
  cache works and is almost always cold.
- **This document was drafted, then attacked.** Three tickets were each reviewed by two independent
  adversarial passes — one on technical correctness, one standing in for a developer with no context. All
  six rejected their ticket: **19 fatal and 51 material defects**, every one in reasoning rather than
  measurement. The corrections are incorporated above. That is the fifth such round on this material and
  the pattern has held every time: **the measurements survive, the reasoning needs correcting.** Treat
  anything here marked *inferred* as exactly that.
- **Not verified from outside, and it needs wp-admin:** whether 10Web Booster is doing anything. All 27
  `tenweb_so/v1` routes and all 9 `tenwebio/v2` routes are still registered today, on a page with zero
  `defer`, zero `async`, no critical CSS and no CDN. That proves the code loads and nothing more. It is a
  30-minute check and it is worth doing before hand-writing work the plugin may already be configured to
  do.

Full findings, evidence and the 24-step sequence: `audit/01-page-speed-performance-audit.md`.
