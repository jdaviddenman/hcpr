# Page Speed Performance Audit: highcountrypainrelief.com

**Date:** 2026-07-31
**Platform:** WordPress 7.0.2 + Beaver Builder 2.10.3 + Beaver Themer 1.5.3.2 + BB Theme 1.7.19.2 + PowerPack for BB 2.40.1.6 + Ultimate Addons for BB
**Server:** LiteSpeed on AWS EC2 (`44.223.213.21`), HTTP/2, HTTP/3 advertised. No CDN. Server-level page cache active but cold on nearly every page. Static assets: Brotli + 30-day `max-age`, no ETag. HTML: Brotli, no `Cache-Control`.

**Evidence**

| Source | Freshness |
|---|---|
| `audit/data/lighthouse-mobile-2026-07-30.md` | 2026-07-30 18:13 EDT — **carried forward, not re-measured** |
| `audit/data/header-sweep-2026-07-30.tsv` | sweep 1, 44 URLs, 21:46 UTC |
| `audit/data/header-sweep-2026-07-30-run2.tsv` | sweep 2, same 44 URLs, 23:04 UTC |
| Live source, headers, and per-asset bytes for `/` and `/knee-pain-lp/` | 2026-07-30 |
| **Beaver Builder's own `2-layout.js` and `2-layout.css`, read from the origin** | 2026-07-30 |
| `audit/05-architecture-and-code-quality.md` | platform, plugin inventory, per-asset byte tables |

> **What is fresh and what is not.** Every markup fact, header, byte count and plugin fact in this document was measured directly on 2026-07-30. **Every Lighthouse number comes from the single 2026-07-30 18:13 EDT run**, is marked **[LH]**, and is one sample — see §9.
>
> **A three-run re-measurement of 2026-08-13 supersedes the [LH] figures**: `audit/data/lighthouse-mobile-2026-08-13.md`. Its CPU figures are not comparable to July's, which were taken on a different machine. Use it for payload, LCP and CLS; use this document for the findings and the sequence.

> **Treat anything marked *inferred from code* as inference.** Where a claim was read from Beaver Builder
> or WordPress source rather than executed, it says so, and §4 flags each one for DevTools confirmation.

---

## 1. Executive Summary

The site scored **21/100 on mobile Lighthouse** on 2026-07-30; a run two days earlier of the same unchanged site scored 27. The problem is not the server, not compression, and not the absence of caching. It is one element, one main thread, and one plugin whose state nobody has checked.

**The four things that matter, in order:**

1. **One Beaver Builder row setting removes 60.7% of mobile payload and swaps the LCP element for a 77 KB first-party image.** The hero row carries `data-video-mobile="yes"`. On a mobile user agent BB's else-branch sets `src=""` on the `<video>` instead of leaving the two `<source>` children active, so neither video file is fetched — and the fallback WebP that BB has already attached as a background paints instead. Setting **Show Video On Mobile = No** costs about five minutes and needs no design approval. It does **not** remove the `<video>` element — verify by the absent *request*, not the absent element. See **C1-A**.
2. **CLS does not come from a missing row height. It comes from Beaver Builder sizing the video twice.** The row already has explicit padding at all three breakpoints. The served markup carries no `data-width`/`data-height`, so BB inserts the video at one size and re-sizes it on `loadedmetadata` — a shift gated on the video download. See **C1-B**.
3. **A page-speed plugin is loaded and the frontend shows no sign of it.** 10Web Booster's REST routes are registered — `set_critical`, `page_cache`, `regenerate_webp` among them — on a page with zero `defer`, zero `async`, no critical CSS, and no CDN. There are at least three explanations and this audit cannot distinguish them from outside. Check it before hand-writing work it may already do. See **C0**.
4. **Main-thread work totals 36.9 s [LH]**, of which 16.3 s is script evaluation. TBT is 14,710 ms against a 200 ms threshold. See **C2**.

**Between 3 h 25 min and 4 h 25 min needs no design approval, no plugin installs, and no page rebuilds** — steps 1-8 of §8. The first two steps are 20 minutes of that and carry most of the value.

**There is no configuration path to a green score.** The ceiling is 3,197 rendered DOM elements [LH], a 10,883 ms Beaver Builder layout bundle, four libraries doing two jobs, and 3,820 ms of third-party main-thread blocking.

---

## 2. Metrics

All **[LH]**. Single runs; see §9.

| Metric | 2026-07-30 | 2026-07-28 | Threshold | Status |
|--------|-----------|-----------|-----------|--------|
| Performance Score | **21** | 27 | 90+ | FAIL |
| LCP | **18.9 s** | 15.9 s | <2.5 s | 7.6× over |
| TBT | **14,710 ms** | 18,520 ms | <200 ms | 74× over |
| CLS | **0.184** | 0.184 | <0.1 | FAIL |
| FCP | **3.0 s** | 3.0 s | <1.8 s | 1.7× over |
| Speed Index | **14.1 s** | 17.2 s | <3.4 s | 4.1× over |
| TTFB | **700 ms** | 2,550 ms | <800 ms | **PASS** |
| Network payload | **5,123 KiB** | 16,558 KiB | — | 60.7% is one video |
| Rendered DOM elements | **3,197** | — | <1,500 | 2.1× over |

Measured directly, not from Lighthouse:

| Measure | Value | Method |
|---|---|---|
| TTFB, cold cache | **0.406-4.946 s** | 86 cold requests across two sweeps, M1 |
| TTFB, warm cache | **0.052-0.113 s** | 90 warm requests across two sweeps |
| First-party bytes parsed | **1,550,595 B** (1,514 KiB) | `Accept-Encoding: identity` per asset |
| First-party bytes transferred | **283,722 B** (277 KiB) | `Accept-Encoding: br,gzip` per asset |
| Source-HTML elements | 1,792 | `html.parser` start tags |
| Scripts / with `defer` or `async` | **19 / 0** | live source; `/knee-pain-lp/` is 12 / 0 |
| Stylesheets | 13 (12 first-party) | live source; `/knee-pain-lp/` is 11 |

**The rendered DOM is 1.8× the source DOM.** Lighthouse counts 3,197 elements; the delivered HTML contains 1,792. About 1,400 elements are created by JavaScript — the hero `<video>`, the ReviewWave chat widget, the UserWay widget, and Beaver Builder's own construction. DOM reduction cannot be assessed from the HTML alone.

### LCP breakdown [LH]

**Element:** `div.fl-row > div.fl-row-content-wrap > div.fl-bg-video > video` — as reported by Lighthouse, which inspects the **rendered DOM**. This element does not exist in the HTML.

| Phase | % | Timing |
|---|---|---|
| TTFB | 4% | 700 ms |
| **Load Delay** | **83%** | **15,760 ms** |
| Load Time | 1% | 240 ms |
| Render Delay | 12% | 2,190 ms |

Load Delay is the gap between navigation start and the browser beginning to fetch the LCP resource. C1 explains why it is that large.

---

## 3. Payload

### On the wire — 5,123 KiB [LH]

| Source | KiB | % | Controllable? |
|---|---|---|---|
| **inceptionimages.com** | 3,196 | 62.4% | Partial — the CDN is agency-managed; the video is a BB setting |
| — `hiking.mp4` (transferred) | 3,112 | **60.7%** | Yes |
| — footer booking image | 84 | 1.6% | Yes |
| **highcountrypainrelief.com** (1st party) | ~910 | ~17.8% | **Yes — full control** |
| **YouTube thumbnails** (35 × `i.ytimg.com`) | 459 | 9.0% | Yes — facade pattern |
| **Google Tag Manager** | 275 | 5.4% | Yes — audit container |
| **UserWay** | 137 | 2.7% | Yes — defer |
| **AWS S3** (ReviewWave config) | 58 | 1.1% | No — third-party |
| **Google Fonts** | 57 | 1.1% | Yes — reduce families |
| **ReviewWave** | 16 | 0.3% | Partial — can defer |
| **Vimeo** | 15 | 0.3% | Thumbnail only; the iframes are template-deferred |

The Google Maps embed carries `loading="lazy"` and does not load on view. It is correctly absent from this table.

**On the ReviewWave S3 object.** It appears at 58 KiB here, 55.7 KiB in H2, and 56 KiB in §6. All three are faithful transcriptions of *different Lighthouse rows* describing the same object, whose actual `Content-Length` is **56,589 B** (55.3 KiB). The spread is Lighthouse's, not this document's; no row has been altered to hide it.

### Through the parser — 1,514 KiB

Every first-party asset fetched twice, `Accept-Encoding: br,gzip` and `identity`. Per-file tables: `audit/05-architecture-and-code-quality.md` §4.

```
              wire (br)        parsed (raw)     ratio
HTML             33,546            218,440       6.5x
JS              160,061            618,211       3.9x   (16 files)
CSS              90,115            713,944       7.9x   (12 files)
TOTAL           283,722 B        1,550,595 B     5.5x
                (277 KiB)        (1,514 KiB)
```

Compression ratios range from 1.8× to 14.1× across individual files, so transfer size is a poor predictor of the work a change removes. What follows from that is H1.

### The hero video

```
https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.mp4    15,343,649 B
https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.webm    5,802,541 B
                                            both: cache-control: public, max-age=2592000
```

`hiking.mp4` is 14.6 MiB on disk; Lighthouse recorded **3,112 KiB transferred**, because the browser aborts once enough is buffered and where it aborts varies per run. Transfer size is what costs the user; file size is what an encode decision is about.

---

## 4. Findings by Criticality

### CRITICAL

---

**C1: LCP 18.9 s and CLS 0.184 — the hero video is built by JavaScript, sized twice, and shown on mobile**

- **Evidence — the markup.** Measured live:

  ```
  <video>  elements in the HTML:   0
  <source> elements in the HTML:   0
  poster=  attributes in the HTML: 0
  ```

  What is served:

  ```html
  <div class="fl-bg-video"
    data-video-mobile="yes"
    data-fallback="https://www.highcountrypainrelief.com/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp"
    data-mp4="https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.mp4"
    data-mp4-type="video/mp4"
    data-webm="https://www.chiro.inceptionimages.com/wp-content/uploads/2018/02/hiking.webm"
    data-webm-type="video/webm"
  >
  ```

  Note there is **no `data-width` and no `data-height`**. That absence is what causes CLS — see C1-B.

- **Evidence — Beaver Builder's own code**, read from `2-layout.js` on the origin:

  ```js
  videoTag=$('<video autoplay loop muted playsinline></video>');

  // the poster is hardcoded 1x1; the real fallback is a CSS background on the element BB creates
  if('undefined'!=typeof fallback&&''!=fallback){
    videoTag.attr('poster','data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
    videoTag.css({backgroundImage:'url("'+fallback+'")',backgroundSize:'cover',backgroundPosition:'center center'})}

  // both <source> children are attached BEFORE the mobile gate
  if('undefined'!=typeof mp4 &&''!=mp4 ){mp4Tag =$('<source />');mp4Tag.attr('src',mp4);  videoTag.append(mp4Tag);}
  if('undefined'!=typeof webm&&''!=webm){webmTag=$('<source />');webmTag.attr('src',webm);videoTag.append(webmTag);}

  // the mobile gate — note BOTH branches append
  if(!FLBuilderLayout._isMobile()||(FLBuilderLayout._isMobile()&&"yes"==videoMobile)){
    … wrap.append(videoTag); …        // sources live: the browser picks one and downloads it
  } else {
    videoTag.attr('src','')           // src beats <source>: neither file is fetched
    wrap.append(videoTag);            // the element is STILL appended
  }
  _isMobile:function(){return/Mobile|Android|Silk\/|Kindle|BlackBerry|Opera Mini|Opera Mobi|webOS/i.test(navigator.userAgent);}

  // sizing: with no data-width/height, the video is sized once, then again on metadata
  if(vidHeight===''||typeof vidHeight==='undefined'||vidWidth===''||typeof vidWidth==='undefined'){
    vid.css({'left':'0px','top':'0px','width':newWidth+'px'});
    vid.on('loadedmetadata',FLBuilderLayout._resizeOnLoadedMeta);
    return;}
  // …and again on every resize
  win.on('resize.fl-bg-video',function(e){clearTimeout(resizeBGTimer);
    resizeBGTimer=setTimeout(function(){FLBuilderLayout._resizeBgVideos(e);},100);});
  ```

  And from `2-layout.css` — the hero row already has a deterministic height at every breakpoint:

  ```css
  .fl-node-49vu6prnm80g > .fl-row-content-wrap {padding-top:250px;padding-bottom:375px;…}
  .fl-node-49vu6prnm80g.fl-row > .fl-row-content-wrap {padding-top:150px;padding-bottom:200px;}
  .fl-node-49vu6prnm80g.fl-row > .fl-row-content-wrap {padding-top:100px;padding-bottom:100px;}
  .fl-bg-video video {min-width:100%;min-height:100%;width:auto;height:auto;}
  ```

- **Impact:** The 15,760 ms Load Delay exists because the LCP element does not exist until `2-layout.js` (10,883 ms CPU [LH]) has evaluated. The 0.184 CLS is the `loadedmetadata` re-size of an absolutely-positioned `<video>` sized from its own intrinsic dimensions. Because the poster is a hardcoded 1×1 GIF and the real fallback is a background on that same JS-created element, **nothing paints early no matter how fast the image arrives.**

- **Fixes, in value order:**

  - **A. Set Show Video On Mobile = No** (~5 min). BB row → Style → Background → Video → "Show Video On Mobile". Largest change available on this page, and it is one dropdown. **What it actually does, from the code above:**

    | | Mobile, before | Mobile, after |
    |---|---|---|
    | `hiking.mp4` / `hiking.webm` fetched | yes, 3,112 KiB | **no** — `src=""` on the `<video>` makes the browser ignore both `<source>` children |
    | `<video>` in `.fl-bg-video` | present | **still present**, with `src=""` |
    | What paints | 1×1 GIF, then video frames | the fallback WebP, already set as `background-image` on the same element — **76,870 B, first-party** |
    | LCP element | the video | the fallback WebP |
    | `loadedmetadata` → second sizing pass | fires | no media loads, so it should not fire — *inferred from the code, not measured* |

    **Do not verify this by checking for the absence of a `<video>`.** `wrap.append(videoTag)` appears in **both** branches — `grep -c 'wrap.append(videoTag)' 2-layout.js` returns 2 — so a correctly fixed page still has one, with `src=""`. Check that no request for `hiking.mp4` or `hiking.webm` is made.

    *Verify while doing it:* an empty `src` resolves against the document URL, and some browsers issue a request for the page itself as media. Confirm in DevTools. This is small but real, and it is the one part of C1-A that could go wrong.

  - **B. Override both BB sizing passes** (~15 min). In the child theme — **`!important` is load-bearing**:
    ```css
    .fl-bg-video video{
      width:100% !important; height:100% !important;
      left:0 !important; top:0 !important;
      min-width:0 !important; min-height:0 !important;
      max-width:none; object-fit:cover; transform:none !important;}
    ```
    **Every declaration needs `!important`, and the rule does not turn BB's two passes into no-ops.** Both are jQuery `.css()` calls, which write the inline `style` attribute:
    ```js
    vid.css({'left':'0px','top':'0px','width':newWidth+'px'});                    // pass 1
    video.css({'left':…,'top':…,'width':…,'height':…});                           // pass 2, on loadedmetadata
    ```
    An inline declaration beats any author stylesheet rule that is not `!important`, and BB re-applies both on a 100 ms-debounced `resize` handler, so the rule must win on every re-application. `object-fit:cover` would have applied regardless — BB never sets it — but it governs painting inside the box, not the box geometry, and the geometry is the shift.

    This is the CLS fix on **desktop**, where A does not apply. If `!important` is unacceptable, the alternative is to unbind `loadedmetadata` on `.fl-bg-video video` after BB initialises; that is more fragile and needs a load-order guarantee.

    *Not the fix:* setting a row height (the row is already sized by padding at all three breakpoints), or `aspect-ratio` on `.fl-bg-video` (`position:absolute` with all four insets `0`, so both axes are already definite and `aspect-ratio` is ignored). Rev. 2 recommended both.

  - **C. Make something paint early** (~20 min). Move the fallback onto an element that exists in the served HTML, and warm its connection:
    ```html
    <link rel="preconnect" href="https://www.chiro.inceptionimages.com" crossorigin>
    <link rel="preload" as="image" fetchpriority="high"
          href="…/wp-content/uploads/2026/02/Chronic-Pain-Boone-NC-Hiking.webp">
    ```
    ```css
    .fl-node-49vu6prnm80g .fl-bg-video{background:url(…/Chronic-Pain-Boone-NC-Hiking.webp) center/cover no-repeat;}
    ```
    **The preload alone paints nothing.** It warms the HTTP cache for an image that only ever gets applied to an element BB creates later. The CSS rule is the half that makes it visible. The poster file is 76,870 B, confirmed live.

    **Scope note.** The poster is on `www.highcountrypainrelief.com` — **first-party, already connected**. The `preconnect` above is for the *video* host and is justified by H5, not by this poster. Once C1-A ships, that preconnect is **inert on mobile**, because nothing on `chiro.inceptionimages.com` is fetched there. It still earns its place on desktop. Rev. 3 bundled the two without saying so.

  - **D. Serve WebM only** (~15 min, **with a caveat**). Clearing the MP4 field in the BB row leaves a 5.8 MB source instead of 15.3 MB, and BB accepts it (`if('undefined'!=typeof mp4&&''!=mp4)`). **But iOS Safari only gained full WebM support in 17.4**, and macOS Safari in 16.0 — below those, visitors get the fallback image instead of the video. That is a design change on a real slice of a local practice's traffic. If A ships, D matters only on desktop.

  - **E. Replace the video with a static image** (1-2 hrs + design approval). Removes the problem outright on all profiles.

  - **Recommended:** **A + B + C.** About 40 minutes, no design approval, and between them they cover mobile and desktop.

- **Projected outcome:** on the emulated-mobile profile Lighthouse measures, A removes the LCP element and the CLS contributor outright. Do not project a score — see §9.
- **Verification:** with a mobile UA, DevTools Network shows **no request to `hiking.mp4` or `hiking.webm`**, and the LCP element is `Chronic-Pain-Boone-NC-Hiking.webp`. Do **not** check for the absence of a `<video>` element — one remains, with `src=""`. With a desktop UA, CLS ≤ 0.1 and `Avoid large layout shifts` lists no non-zero shift.
- **Rollback:** all of these are a BB row setting or child-theme lines. Revert the file, or the page revision.

---

**C0: 10Web Booster is loaded and the frontend shows no sign of it**

- **Evidence:** `GET /wp-json/` registers `tenweb_so/v1` and `tenwebio/v2`. The routes identify the product unambiguously — `set_critical`, `regenerate_critical`, `page_cache`, `get_page_cache_status`, `get_modes`/`set_modes`, `get_webp_status`, `regenerate_webp`, `delete_webp_images`, `get_incompatible_active_plugins`. `/wp-content/plugins/tenweb-speed-optimizer/readme.txt` returns 403 (file present); `tenweb-manager`, `tenweb-booster`, and `10web-booster` all return 404.

  On the same site, measured live:

  | Signal a working optimiser produces | `/` | `/knee-pain-lp/` |
  |---|---|---|
  | Scripts with `defer` or `async` | **0 of 19** | **0 of 12** |
  | Critical / inlined CSS | none; 13 sync stylesheets | none; 11 sync stylesheets |
  | Images loading eagerly | 7 of 23 | 9 of 12 |
  | CDN hostname | none | none |
  | Any `tenweb` string in HTML | 0 | 0 |

- **What the evidence does and does not establish.** It establishes that **10Web's code is loading**. It does **not** establish that the plugin is "active" in the wp-admin sense — a must-use plugin registers routes with no activation state, and `/wp-content/mu-plugins/` returns the same 403-exists signature as every other real directory here. Rev. 2 asserted "REST namespaces register only for active plugins"; that is over-general.

- **Three explanations, and this audit cannot distinguish them from outside:**
  1. **Optimisation features are switched off.** Fix: turn them on one at a time.
  2. **It is configured but not serving.** 10Web Booster serves optimised HTML *from its own page cache*, generated asynchronously — hence `page_cache` and `get_page_cache_status`. M1 establishes that 86 of 88 first requests to this site are cold. A cache-served optimiser on a permanently-cold site produces exactly the observed signature. **If this is the explanation, the fix is M1 (pre-warming), not a wp-admin toggle**, and this finding drops down the sequence.
  3. **It is a dead installation.** A lapsed API token cannot generate critical CSS. The repo already documents one migration leftover — Liquid Web Harbor running on AWS (`audit/05` A1).

- **Counter-evidence the site itself provides.** `tenwebio/v2` exposes `compress`, `compress-custom`, and `only_convert_webp`. The site serves `Chronic-Pain-Boone-NC-SoftWave-Video-Overlay.jpg.webp` and **the `.jpg` original returns 404** — the signature of a WebP conversion pass that ran. "Zero `tenweb` strings in the HTML" is not evidence of inertness for a feature whose output is `.webp` files, not strings. This also makes L2's rename riskier than it looks.

- **Fix:** open wp-admin and determine which explanation applies. Check `get_incompatible_active_plugins` output while there — Beaver Builder is a common entry on such lists.
- **Effort:** 30 min to determine state. Unknown thereafter.
- **Verification:** `curl -s https://www.highcountrypainrelief.com/ | grep -oE '<script[^>]+(defer|async)' | wc -l` returns > 0.
  **Do not use `grep -c 'defer\|async'`** — it returns **25 on the unmodified site**, because WordPress core emits `decoding="async"` on 23 images and `grep -c` counts lines, not matches. That criterion cannot fail.
- **Caution:** 10Web's CSS/JS combining is the class of change `audit/03` §4 documents as breaking the Beaver Builder editor. Enable page-level features first; leave combining last or never.

---

**C2: Main-thread work 36.9 s — TBT 14,710 ms** [LH]

- **Evidence:**

  | Category | Time | | Source | Total CPU |
  |---|---|---|---|---|
  | Script Evaluation | 16,263 ms | | `cache/2-layout.js` | 10,883 ms |
  | Other | 10,512 ms | | the HTML document | 10,224 ms |
  | Parse HTML & CSS | 5,664 ms | | UserWay | 5,363 ms |
  | Style & Layout | 3,355 ms | | Unattributable | 4,755 ms |
  | Rendering | 501 ms | | `jquery.min.js` | 1,589 ms |
  | Script Parse & Compile | **383 ms** | | `swiper.min.js` | 1,497 ms |
  | Garbage Collection | 234 ms | | GTM | 1,448 ms |

  20 long main-thread tasks. 5 non-composited animations.

- **Impact:** TBT is 74× the threshold. `2-layout.js` is the largest first-party cost at 10,883 ms, of which 10,081 ms is *evaluation* — and much of that evaluation is DOM construction (M2), not parsing. **Script Parse & Compile is 383 ms, about 1% of the total** — the basis for H1.
- **Fix:** C0 first. Then H2, H3, H6. `2-layout.js` shrinks only when the page carries fewer modules.
- **Verification:** `Minimize main-thread work` under 20 s; TBT trending down across a median of 3 runs, not 1.

---

### HIGH

---

**H1: Rank by measured CPU. Transfer bytes understate the work; raw bytes are not a substitute**

- **Evidence:** the ratio table in §3, plus C2's category breakdown.
- **The claim, stated precisely.** Brotli compresses 1,550,595 B of first-party text to 283,722 B, and per-file ratios vary from 1.8× to 14.1×. A remediation list ordered by *transfer* bytes is therefore ordered by a number whose relationship to the underlying asset varies almost sixfold. That much is solid.
- **Why raw bytes are not the ranking unit either.** C2's table settles it: Script Parse & Compile is **383 ms of 36,900 — about 1%.** Evaluation is 16,263 ms. Swiper's 1,497 ms is initialising 105 slides, not parsing 143 KB. Raw bytes proxy the 1% category, not the 44% one.
- **What to do instead:** this page already has per-script CPU attribution from Lighthouse — the right-hand column of C2. Rank by that. Use raw bytes only where no CPU figure exists, and as a tiebreaker. Treat §7's byte rows as *hygiene targets*, not as predictors of TBT.
- **Verification:** for any change, compare the per-script CPU column across 3 runs — not the payload figure.

---

**H2: 11 render-blocking resources — 1,370 ms estimated savings** [LH]

- **Evidence:**

  | Group | Count | Transfer | Est. savings |
  |---|---|---|---|
  | highcountrypainrelief.com | 7 | 104.3 KiB | 1,950 ms |
  | `rw-embed-data.s3.amazonaws.com` | 1 | 55.7 KiB | 1,570 ms |
  | `cdn.reviewwave.com` | 2 | 11.5 KiB | 940 ms |
  | `fonts.googleapis.com` | 1 | 1.2 KiB | 790 ms |

  Lighthouse's headline "1,370 ms" does not equal the sum of its own per-group rows, which total 5,250 ms. Both are transcribed as reported; the discrepancy is Lighthouse's, and it means neither figure should be treated as a prediction.

  First-party detail: `jquery.min.js` 450 ms, `2-layout.css` 450 ms, `bootstrap.min.css` 300 ms, `layout-bundle.css` 300 ms, `all.min.css` 150 ms, `skin-*.css` 150 ms, `jquery.fancybox.min.css` 150 ms.

  Verified live: **19 scripts, 0 `defer`, 0 `async`**, and 12/0 on `/knee-pain-lp/`. Five scripts sit in `<head>`: `jquery.min.js`, `jquery-migrate.min.js`, and all three ReviewWave scripts.
- **Fix:** `defer` on `reviews_embed.js`, `chat_embed.js`, and the S3 config — all three are in `<head>` and none is needed before first paint. `&display=swap` on the fonts URL (M5). Combine the four BB/theme stylesheets. **Keep `jquery.min.js` synchronous** unless every interaction is regression-tested; jQuery Migrate loading alongside it (L6) is direct evidence of legacy call sites.
- **Risk, and it is not small:** `defer` breaks any third-party embed that uses `document.write`, and two of these three scripts are the **review carousel and the chat widget** — a lead channel for a medical practice. Budget a regression pass on both, not just a Lighthouse re-run. Rev. 2 listed this step at 20 minutes with no risk note.
- **Effort:** 30 min for the change, plus regression testing.
- **Verification:** render-blocking savings ≤ 200 ms **and** the chat widget still opens and submits.

---

**H3: UserWay — 2,443 ms main-thread blocking, 137 KiB** [LH]

- **Evidence:** `widget_app_base_178….js` (47 KiB) blocks 2,354 ms; `widget_base.css` (71 KiB) 87 ms; `widget.js` (2 KiB) 2 ms. Total CPU 5,363 ms. Lighthouse's own 137 KiB total exceeds its sub-rows' 120 KiB; both are transcribed as reported. Injected by this inline block, captured verbatim:

  ```js
  (function(e){
    var el = document.createElement('script');
    el.setAttribute('data-account', 'Vgm0gbMRdF');
    el.setAttribute('src', 'https://cdn.userway.org/widget.js');
    document.body.appendChild(el);
  })();
  ```

  UserWay is a **WordPress plugin** here (`userway/v1` in `/wp-json/`, with `/save` and `/debug` routes), not a hand-placed snippet.
- **Impact:** largest single third party — 64% of all third-party blocking, for 2.7% of payload. Loads for every visitor whether or not accessibility features are used.
- **Fix, in order of preference:**
  1. **Check the plugin's own settings first.** It has a settings endpoint; many accessibility-widget plugins ship a defer or on-demand mode. If one exists, that is the whole fix.
  2. Otherwise dequeue the plugin's output and re-emit on idle **with a timeout**:
     ```js
     (window.requestIdleCallback || function (cb) { setTimeout(cb, 2000); })(function () {
       var s = document.createElement('script');
       s.src = 'https://cdn.userway.org/widget.js';
       s.setAttribute('data-account', 'Vgm0gbMRdF');
       document.body.appendChild(s);
     }, {timeout: 3000});
     ```
     The `{timeout: 3000}` is not optional here. Without it `requestIdleCallback` can be starved indefinitely, and this page has 36.9 s of main-thread work and 20 long tasks — close to the worst realistic case for idle ever arriving. Dynamically-created scripts are already async, so setting `.defer = true` on one is a no-op — which is what the 2026-07-28 original's snippet did.
- **Effort:** 15 min if the plugin has a setting. **60-90 min if not** — removing a plugin's `wp_head`/`wp_footer` output needs the exact hook, priority, and callback, and a closure or object-method callback cannot be removed by name at all. Rev. 2's "30 minutes" assumed a hand-placed snippet.
- **Accessibility note, stated honestly:** UserWay is an accessibility overlay. With `{timeout: 3000}` it is unavailable for at least three seconds, and on a cold load plausibly longer. That is a real cost to the users who most need it, and it is a decision for whoever owns accessibility — not a free win. Removing the overlay entirely is a separate question with legal dimensions, out of scope here.
- **Verification:** third-party audit shows UserWay under 200 ms blocking, **and** the widget still appears within 5 s.

---

**H4: `fetchpriority="high"` is on an award badge — and it comes from WordPress core, not Beaver Builder**

- **Evidence:** exactly one `fetchpriority` on the page:

  ```html
  <img fetchpriority="high" decoding="async" class="fl-photo-img wp-image-24374 size-full"
       src="…/wp-content/uploads/2025/08/Best-of-Watauga-County-2025-Ribbon.webp"
  ```

  That file is 86,826 B and is the one Lighthouse flags as 19.9 KiB oversized (L3). WordPress core emits this via `wp_get_loading_optimization_attributes()`, which marks the first non-lazy content image as the LCP candidate — core also emitted all 23 `decoding="async"` on this page. Beaver Builder's photo module has no `fetchpriority` field.

  Separately, two `<link rel="preload" as="font">` tags preload Font Awesome 5 webfonts ahead of the LCP element.
- **Impact:** an award badge gets priority over the element that determines LCP, in exactly the window C1 is protecting.
- **Fix:** filter core's heuristic — `wp_get_loading_optimization_attributes` or `wp_content_img_tag` in the child theme. **Not** a BB module setting.
- **Coupled to H8, and the coupling is the point.** Once H8 adds `loading="lazy"` to the eager images, core hands `fetchpriority="high"` to whatever image is *next* first-and-not-lazy. Verifying "the ribbon has no fetchpriority" would pass while the defect simply moved. Do H4 and H8 in the same pass and confirm the attribute lands on the hero poster (C1-C) or nowhere.
- **Effort:** 30 min including the H8 interaction.
- **Verification:** `fetchpriority="high"` appears zero times, or exactly once on the hero poster preload.

---

**H5: No resource hint for the host that serves the LCP element**

- **Evidence:** the entire set of resource hints in `<head>`:

  ```html
  <link rel='dns-prefetch' href='//fonts.googleapis.com' />
  <link href='https://fonts.gstatic.com' crossorigin rel='preconnect' />
  <link rel="preload" as="font" href="…/fontawesome/5.15.4/webfonts/fa-solid-900.woff2" …>
  <link rel="preload" as="font" href="…/fontawesome/5.15.4/webfonts/fa-regular-400.woff2" …>
  ```

  There is **nothing** for `chiro.inceptionimages.com` — a separate host on a separate IP (`18.214.60.67`) serving the LCP hero video and 62.4% of payload. Nothing for `cdn.userway.org`, `rw-embed-data.s3.amazonaws.com`, or `cdn.reviewwave.com` either.
- **Impact:** a full DNS + TCP + TLS round trip sits on the LCP critical path — typically 100-300 ms on mobile — while the two hints that *do* exist point at icon fonts, which compete with the LCP element rather than helping it.
- **Fix:** one line in the child theme, folded into C1-C:
  ```html
  <link rel="preconnect" href="https://www.chiro.inceptionimages.com" crossorigin>
  ```
  Consider dropping the two Font Awesome font preloads, or ordering them after the hero poster.
- **Effort:** 5 min.
- **Verification:** the hint is present, and DevTools shows connection setup for `chiro.inceptionimages.com` complete before the poster or video request starts.

> **The Google Maps embed needs no action.** The iframe carries `loading="lazy"` alongside `referrerpolicy`, `width` and `height` — verified with three independent patterns. Classify iframes on the full element: truncating before the deciding attribute makes a lazy iframe look eager.

---

**H6: Google Tag Manager — 1,165 ms blocking, 275 KiB** [LH]

- **Evidence:** `gtm.js?id=GTM-WGXQKR5` — 115 KiB, 831 ms blocking. `gtag/js?id=G-CW4KKYCP1V` — 159 KiB, 334 ms. Total CPU 1,448 ms. `GTM-WGXQKR5` appears in live source; `G-CW4KKYCP1V` does not, so it is loaded by the container at runtime — i.e. a container tag, not a separate install.
- **Impact:** second-largest third-party blocker, and the largest third-party payload after the image CDN — more than UserWay and ReviewWave combined. The 2026-07-28 original called it "4 KB, minimal, already async — OK, 0 savings," understating transfer by roughly 70× and missing the blocking cost entirely.
- **Fix:** an async loader does not make a container's contents cheap. Audit the container: remove unused tags, unfired triggers, duplicate analytics; deduplicate if more than one tag pulls gtag. Consider server-side tagging if it cannot be slimmed.
- **Effort:** 1-2 hrs. A container audit, not a code change.
- **Verification:** GTM transfer under 100 KiB; blocking under 300 ms.

---

**H7: 25,169 B per page of WordPress core CSS/JS this site cannot use**

- **Evidence:** measured on `/`, confirmed present on `/knee-pain-lp/`, so this applies to all 44 sitemap URLs.

  **Always delivered — inline in every document:**

  | Item | Raw bytes | Why unused here |
  |---|---|---|
  | `global-styles-inline-css` | **17,714** | `theme.json` preset custom properties for the block editor. BB Theme is a classic theme; every page is built from Beaver Builder modules. |
  | emoji detection inline script | 2,982 | — |
  | `wp-block-library-inline-css` | 3,648 | Gutenberg block styles; the sampled pages contain no blocks |
  | `classic-theme-styles-inline-css` | 350 | — |
  | `wp-emoji-styles-inline-css` | 340 | — |
  | `wp-img-auto-sizes-contain-inline-css` | 135 | — |
  | **Total, always delivered** | **25,169 B** | |

  **Conditional — usually not fetched:** `wp-emoji-release.min.js`, 22,752 B. It is **not** a `<script src>`. Its only occurrence is inside the inline `wp-emoji-settings` JSON as `concatemoji`, and the loader fetches it **only if the browser fails the emoji support test**. Real iOS, Android, Windows, and macOS browsers pass. Headless Chrome on a font-less container fails, which is why Lighthouse saw it.

  **Do not sum the two groups.** For real visitors the figure is **25,169 B**; the other 22,752 B inflates Lighthouse and not user experience.

- **Fix:** in the child theme, **hooked correctly** — a bare `wp_dequeue_style` outside an enqueue hook is a no-op:
  ```php
  add_action('wp_enqueue_scripts', function () {
      wp_dequeue_style('global-styles');
      wp_dequeue_style('wp-block-library');
      wp_dequeue_style('classic-theme-styles');
  }, 100);
  remove_action('wp_print_styles', 'print_emoji_styles');
  remove_action('wp_head', 'print_emoji_detection_script', 7);
  ```

  **Use `wp_print_styles`, not `wp_enqueue_emoji_styles`.** WordPress 7.0.2 `wp-includes/default-filters.php`:

  ```php
  add_action( 'wp_enqueue_scripts', 'wp_enqueue_emoji_styles' );
  add_action( 'wp_print_styles', 'print_emoji_styles' ); // Retained for backwards-compatibility. Unhooked by wp_enqueue_emoji_styles().
  ```

  and `wp-includes/formatting.php`:

  ```php
  function wp_enqueue_emoji_styles() {
      // Back-compat for plugins that disable functionality by unhooking this action.
      $action = is_admin() ? 'admin_print_styles' : 'wp_print_styles';
      if ( ! has_action( $action, 'print_emoji_styles' ) ) { return; }
      remove_action( $action, 'print_emoji_styles' );
  ```

  The `wp_print_styles` hook **is** registered, and core's own comment plus that early return document unhooking it as the supported disable path. Unhooking `wp_enqueue_emoji_styles` instead leaves `print_emoji_styles` hooked, so the **deprecated** function runs and prints the same rules as an unlabelled `<style>`, firing `_deprecated_function()` on every page load under `WP_DEBUG`.

  The deprecation is real (`@deprecated 6.4.0`) but does not make the removal a no-op. Priority `7` on `print_emoji_detection_script` and priority `100` on the dequeues are both correct — all three style handles register at priority 10. `wp-img-auto-sizes-contain` (135 B) has no clean removal and is not worth one.
- **Effort:** 30 min.
- **Verification:** `curl -s <url> | grep -c global-styles-inline-css` returns 0, **and** raw HTML drops by ~25,000 B — from 218,440 B to roughly 193,000 B. Rev. 2 set the target at "<175,000 B", which its own itemisation cannot reach; an implementer following it would have gone hunting for a bug that does not exist.
- **Risk:** low but non-zero. Check any page using a Gutenberg block or core block pattern first. Neither sampled page contains one, and `sitemap_index.xml` lists only `page-sitemap.xml` — there are no posts — which narrows the exposure further.

---

**H8: 758 KiB of offscreen images loaded eagerly** [LH]

- **Evidence:**

  | Group | KiB |
  |---|---|
  | YouTube — 35 thumbnails via `i.ytimg.com` | 457.8 |
  | highcountrypainrelief.com — 5 images | 202.4 |
  | inceptionimages.com — 1 image | 83.6 |
  | Vimeo — 1 thumbnail | 14.7 |

  The YouTube thumbnails are CSS `background-image` on `div.pp-video-image-overlay`, so `loading="lazy"` does not apply. `i.ytimg.com` serves `cache-control: public, max-age=7200` and 11,641 B for the sampled thumbnail.

  Measured live: **7 of 23 `<img>` lack `loading="lazy"`**, and **6 of those 7 also lack `width`/`height`**:

  ```
  Best-of-Watauga-County-2025-Ribbon.webp              has width=500 height=792   <- the exception
  Chiropractic-Boone-NC-ASMST-Logo.webp                no dimensions
  1006263104-c80f682014e15f08…  (inceptionimages)      no dimensions
  Chronic-Pain-Boone-NC-Knee-Pain-Red.webp             no dimensions
  Chronic-Pain-Boone-NC-Back-Pain.webp                 no dimensions
  Chronic-Pain-Boone-NC-Woman-With-Shoulder-Pain.webp  no dimensions
  Chronic-Pain-Boone-NC-Neuropathy.webp                no dimensions
  ```

  **Rev. 3 claimed that correlation was probably causal. It is not, on this page.** The core mechanism is real — `wp-includes/media.php` in WP 7.0.2 returns early from the loading-optimization pass unless the tag already has both `width` and `height`. But it is not what governs these images. Of the **16 images that already have `loading="lazy"`, 6 have no `width`/`height` at all.** Those six carry `loading="lazy"` at the *end* of the tag and no `wp-image-NNNN` class; the ten that do have dimensions carry it *prepended*, which is core's `str_replace` signature. Beaver Builder emits lazy itself on external-URL photos. Adding dimensions will therefore **not** make lazy appear for free.

  **And the 6 targets are not one editable field.** They span three plugins:

  ```
  fl-photo-img                 Chiropractic-Boone-NC-ASMST-Logo.webp        Beaver Builder photo
  pp-video-default-thumbnail   1006263104-c80f682014e15f08…                 PowerPack video
  uabb-new-ib-img  x4          Knee-Pain-Red, Back-Pain, Shoulder-Pain,     Ultimate Addons Info Box
                               Neuropathy
  ```

  The four UABB Info Box images need a template override or an output filter, not an attribute edit. Rev. 3 scoped this at 20 minutes on the strength of the causal claim.
- **Fix:** **(a)** Add `width`/`height` to the 6 that lack them, then check whether lazy appears on its own. Leave the ribbon eager if it is above the fold — but strip its `fetchpriority` (H4). **(b)** YouTube facade for the 35 thumbnails: `lite-youtube-embed` (~3 KiB JS + ~1 KiB CSS, Apache-2.0, no dependencies). See `audit/03` §3.
- **Effort:** (a) **1-2 hrs** — one BB photo module, one PowerPack module, and four UABB Info Box images needing a template override or filter. (b) 2-3 hrs for 35 replacements, or 1-2 hrs via WP YouTube Lyte if its shortcode renders inside BB text modules.
- **Verification:** zero `i.ytimg.com` requests on load; `Defer offscreen images` savings under 100 KiB.
- **Worth more than it looks:** the gallery is a PowerPack module and is what pulls `swiper.min.js` (143,660 B raw, 1,497 ms CPU). After the facade, check whether Swiper still enqueues — see M4.

---

### MEDIUM

---

**M1: The page cache works. It is cold — and the cold path is worse and less predictable than one sweep shows**

- **Evidence:** two full GET sweeps of all 44 sitemap URLs, **1 h 18 min apart** (21:46 UTC and 23:04 UTC, derived from the LiteSpeed ETag mtimes recorded in both TSVs), on byte-identical content — `size_raw` totals match exactly at 5,874,729 B.

  | | Sweep 1 | Sweep 2 |
  |---|---|---|
  | HTTP status | 44/44 → 200 | 44/44 → 200 |
  | `content-encoding` | 44/44 `br`, 81.3% saved | 44/44 `br`, 81.3% saved |
  | `cache-control` on HTML | 44/44 **absent** | 44/44 **absent** |
  | `etag` on HTML | 44/44 present | 44/44 present |
  | Cache state, pass 1 | 44/44 MISS | **42/44 MISS, 2 HIT** |
  | Cache state, pass 2 | 44/44 HIT | 44/44 HIT |
  | TTFB MISS — median | 0.845 s | **1.788 s** |
  | TTFB MISS — p90 | 2.277 s | **4.293 s** |
  | TTFB MISS — max | 2.654 s | **4.946 s** |

  Combined: **86 cold requests spanning 0.406-4.946 s; 90 warm requests spanning 0.052-0.113 s.**

  **The per-page ranking is not reproducible.** Sweep 1's five slowest were `/hipaa-privacy-policy/`, `/accessibility/`, `/pain-management-center/`, `/terms-service/`, `/knee-pain-lp/`. Sweep 2's were `/contact-us/`, `/testimonials/`, `/office-tour/`, `/chiropractic-care/`, `/anti-discrimination/` — **no overlap**. Which page is slowest on a miss is queueing variance, not a property of the page.

  No caching plugin is installed: `litespeed-cache`, `wp-rocket`, `autoptimize`, `wp-super-cache`, and `w3-total-cache` all return the WordPress 404 page, against a control slug that also 404s and against slugs that 403 because the file genuinely exists.

- **Impact:** low per-page traffic means entries expire before the next visitor arrives, so real first visitors routinely pay seconds. With no `Cache-Control` on HTML, no visitor caches the document browser-side either. Lighthouse's 700 ms TTFB is one sample of that distribution, not a description of it.

- **Fix — pre-warm, and start with the cheap option:**

  | Option | Cost | Notes |
  |---|---|---|
  | **A cron'd `curl`/`wget --spider` loop over the 44 sitemap URLs**, on the same EC2 box | ~15 min | Warms the identical server-level cache. No plugin, no `.htaccess` change, no exposure to the BB-editor breakage in `audit/03` §4. **Try this first.** |
  | LiteSpeed Cache plugin + crawler | 2-3 hrs | More capable — see the caveat |

  **LSCache cannot be installed "just for the crawler."** The plugin is the **control plane for the server module** — installing it rewrites `.htaccess` and takes over cache rules, TTLs, purge behaviour, and vary logic. Its crawler only warms what its own rules deem cacheable and requires the plugin's cache enabled. It also requires the crawler enabled at the **LiteSpeed server admin** level, which is routinely off, and a working cron. This is a control-plane swap on a currently-working cache, not an inert addition. If you do it, add `fl_builder` to Page Optimization → Tuning → URI Excludes **first**.

  **On HTML `Cache-Control`:** prefer **`no-cache`** (or `max-age=0, must-revalidate`) over `public, max-age=3600`. HTML already carries an ETag on 44/44 URLs, so `no-cache` gives near-free 304 revalidation with **no staleness window**. `max-age=3600` caches a document in browsers that cannot be purged — including for logged-in editors and on any form or booking page. Rev. 2 recommended the riskier option without saying why the safer one was insufficient.

- **Effort:** 15 min for the cron option; 2-3 hrs for LSCache including BB editor verification.
- **Verification:** re-run `audit/data/header-sweep.sh`; `lsc1` reads `hit` for most URLs rather than `miss` for 42 of 44.
- **Interaction with C0:** if 10Web Booster is serving from its own page cache, pre-warming may resolve C0 as a side effect. Do the cheap cron option and re-check both at once.
- **Note on `vary: User-Agent`:** a cache-fragmentation hypothesis was tested in sweep 1 with 8 distinct UA strings — 7 returned HIT. LiteSpeed buckets user agents into groups rather than keying on the full string. Not fragmenting this cache; no action.

---

**M2: 3,197 rendered DOM elements — 44% of them do not exist in the HTML** [LH + fresh]

- **Evidence:** Lighthouse: 3,197 elements, max depth 28 (`div.pp-video-play-icon > svg > g > path`), max child elements 105 (`div.pp-video-gallery-items.swiper-wrapper`). The delivered HTML contains **1,792** start tags (`html.parser`). About 1,400 elements are created by JavaScript.

  Of the 1,792, **218 are `<meta>` and 198 of those are microdata `itemprop`** — six per video across 33 `VideoObject` blocks, emitted by PowerPack's video module. 760 are `<div>`. (The gallery carries 35 YouTube thumbnails and 35 `data-src` iframes but only 33 `VideoObject` blocks; the two-video gap is unexplained and worth a look if the microdata matters to you.)
- **Impact:** drives Parse HTML & CSS (5,664 ms) and Style & Layout (3,355 ms), and explains why `2-layout.js` costs 10,883 ms — much of that is DOM construction.
- **Fix:** the H8 facade removes markup as well as requests. Consolidate duplicated desktop/mobile navigation into one responsive nav. Reduce footer widget areas.
- **Tradeoff, not a defect:** the 198 microdata tags are valid `VideoObject` structured data that Google reads — about 11% of source elements. Do not remove them as a performance measure without an SEO decision, and note the H8 facade may remove them as a side effect. Flag that before it happens.
- **Effort:** 3-4 hrs; more if theme-level changes are needed.
- **Verification:** rendered DOM under 2,500 as a realistic first target.

---

**M3: 197 resources flagged for inefficient cache policy** [LH]

- **Evidence:** first-party static assets carry `cache-control: public, max-age=2592000` plus Brotli — verified on 6 sampled files — so the bulk of the 197 are third-party: YouTube's 2-hour TTL across 35 thumbnails, GTM's short TTL, UserWay's 1 hour (`max-age=3600, public`).
- **Impact:** mostly outside the site's control. The controllable part is the 35 YouTube thumbnails, which the H8 facade eliminates outright.
- **Fix:** H8. Optionally raise first-party `max-age` to 1 year, but **only** if hash-based busting is verified end-to-end — BB uses `?ver=` query strings, some CDNs strip them, and two assets carry a `?ver=` that never changes (M6).
- **Effort:** covered by H8.

---

**M4: Four libraries doing two jobs — 251 KiB raw, 41.6% of all JavaScript**

- **Evidence:**

  ```
  lightbox    jquery.magnificpopup.min.js    21,145 B   (Beaver Builder)
              jquery.fancybox.min.js         68,253 B   (PowerPack)
                                          =  89,398 B

  carousel    jquery.bxslider.min.js         24,191 B   (Beaver Builder)
              swiper.min.js                 143,660 B   (PowerPack)
                                          = 167,851 B

                                    total    257,249 B  of  618,211 B total JS
  ```

  CSS counterparts load alongside: magnific 5,788 B and fancybox 12,795 B; bxslider 3,446 B and swiper 16,494 B.
- **Impact under H1's corrected framing:** Swiper is the largest single JS file on the page — larger than jQuery — and costs 1,497 ms CPU [LH]. That cost is slide initialisation across 105 children, not parsing, so track the CPU figure rather than the byte figure.
- **Fix:** not resolvable by configuration; the duplication is structural to running both plugins. The reachable version is to stop using the modules that pull the heavier libraries — the 35-video gallery is a PowerPack module and is what pulls Swiper. See H8.
- **Verification:** after the facade, `curl -s <url> | grep -c swiper.min.js` returns 0.

---

**M5: No `font-display` — 5 font families**

- **Evidence, live:**

  ```
  //fonts.googleapis.com/css?family=Raleway:700,400,300,800,600|Work%20Sans:700|Inter:600|Audiowide:400|Oxygen:300,700&ver=7.0.2
  ```

  No `display` parameter. `Ensure text remains visible during webfont load` fails. Font files total 57 KiB, cached 1 year at `fonts.gstatic.com`. Web font loading is the stated root cause of layout shift #2 — which scores **0.000**, so this is an FCP fix, not a CLS fix.

  A `preconnect` to `fonts.gstatic.com` already exists; `fonts.googleapis.com` has only `dns-prefetch`.
- **Fix:** append `&display=swap`; upgrade the `fonts.googleapis.com` hint to `preconnect crossorigin`; reduce 5 families to 2.
- **Effort:** 15 min, plus 1 hr for the family reduction, which is a design decision.
- **Verification:** the fonts URL contains `display=swap`; the webfont audit passes.

---

**M6: Two assets carry a `?ver=` that never changes when the file does**

- **Evidence:**

  ```html
  <link rel='stylesheet' id='fl-child-theme-css' href='…/themes/bb-theme-child/style.css?ver=7.0.2' media='all' />
  …/plugins/bb-ultimate-addon/modules/modal-popup/js/js_cookie.js?ver=7.0.2
  ```

  `7.0.2` is the WordPress core version — the fallback when a script is enqueued with no version argument.
- **Impact:** static assets carry `max-age=2592000`. **An edit to the child theme's `style.css` will not reach a returning visitor for 30 days**, or until WordPress core updates for unrelated reasons. Anyone making CSS fixes here will watch them ship and appear not to work.
- **Fix — and the mechanism here is inferred, not verified.** The handle is `fl-child-theme`. The `fl-` prefix is the parent theme's namespace, which *suggests* BB Theme registers the child stylesheet itself; if so, enqueuing it again from the child is a duplicate or a no-op. But BB Theme's parent is premium and not publicly readable, and Beaver Builder's own published starter child theme does the opposite — it enqueues under handle `child-style` with an explicit version. **Check `bb-theme-child/functions.php` before choosing.** If the child registers it, adding a `$ver` argument is the whole fix. If the parent registers it, use one of:
  - dequeue and re-register under the same handle at a late priority with `filemtime()` as the version, or
  - a `style_loader_src` filter that rewrites the `ver` parameter for that handle.

  The UABB file is a plugin defect — report it upstream; it is 3,545 B and low-impact.
- **Effort:** 20 min.
- **Verification:** `style.css?ver=` shows a timestamp **and** the value changes after an edit.

---

**M7: No CDN**

- **Evidence:** `highcountrypainrelief.com` → `44.223.213.21`; `chiro.inceptionimages.com` → `18.214.60.67`. Both AWS EC2, both LiteSpeed, no CDN headers (`cf-cache-status`, `x-cache`, `age`, `via`, `x-amz-cf-id`) on any response. Two distinct hosts, not one origin.
- **Impact:** geographically distant visitors pay full origin latency. Warm TTFB from the test location is already 52-113 ms, so this matters less than it appears — and it does nothing for a cache MISS, which is the path that costs seconds.
- **Fix:** Cloudflare free tier or QUIC.cloud. Complementary to M1, not a substitute.
- **Precondition:** do **L2** first — a filename on this site would break under a CDN that keys MIME type on the first extension.
- **Effort:** 1-2 hrs.

---

### LOW

---

**L1: Static assets have no ETag**

- **Evidence:** 6 static assets sampled (4 CSS, 2 JS): `cache-control: public, max-age=2592000`, `expires`, `last-modified`, `content-encoding: br` when requested — and **no `etag`**. Revalidation falls back to `If-Modified-Since`, 1-second granularity. HTML, by contrast, carries an ETag on 44/44 URLs in both sweeps.
- **Fix:** enable ETag in LiteSpeed config.
- **Verification:** `curl -sD - -o /dev/null <static-asset-url> | grep -i etag` returns a value.

---

**L2: `.jpg.webp` double extension — and the `.jpg` original is gone**

- **Evidence:** `Chronic-Pain-Boone-NC-SoftWave-Video-Overlay.jpg.webp`, 8,706 B, returns `content-type: image/webp` — correct. **The `.jpg` original returns 404.** That filename pattern, plus C0's `tenwebio/v2/compress` and `only_convert_webp` routes, is the signature of an automated WebP conversion pass.
- **Status:** not a current defect. It becomes one if a CDN is placed in front (M7) and that CDN keys MIME type on the first extension.
- **Fix — not a 20-minute job:** renaming means updating `_wp_attached_file`, every generated size, and any reference inside Beaver Builder's serialised module settings — on a live page, with **no origin fallback if a reference is missed**, since the `.jpg` no longer exists. Plan a redirect. Confirm first whether 10Web regenerates the file, or the rename will simply be undone.
- **Effort:** 1 hr with a redirect and a reference sweep.

---

**L3: One oversized image — 20 KiB** [LH]

- **Evidence:** `Best-of-Watauga-County-2025-Ribbon.webp`, **86,826 B measured live**, of which Lighthouse reports 19.9 KiB is unnecessary at rendered size. Same file as H4.
- **Fix:** regenerate at display dimensions, in the same pass as H4.

---

**L4: Six images missing explicit width and height**

- **Evidence:** of the 7 images lacking `loading="lazy"`, **6 also lack `width`/`height`** — the award ribbon carries `width="500" height="792"` and is the exception. They contribute 0.000 to CLS in the current run but are latent shift sources. Rev. 2 said all 7 lacked dimensions.
- **Fix:** covered by H8(a). Adding dimensions does **not** make core add `loading="lazy"` for free — see H8. Both attributes have to be added deliberately, and four of the six sit in Ultimate Addons Info Box output.

---

**L5: 5 non-composited animations** [LH]

- **Evidence:** 5 animated elements off the compositor thread, forcing main-thread work per frame and compounding C2. Related: Animate.css 3.5.1 loads in full — 52,789 B raw against 3,733 B on the wire, a 14.1× ratio — for whatever those 5 animations use.
- **Fix:** restrict animation to `transform` and `opacity`. Subsetting Animate.css is separate hygiene.

---

**L6: jQuery Migrate is in the render path**

- **Evidence:** `jquery-migrate.min.js?ver=3.4.1`, 13,577 B raw, synchronous in `<head>` immediately after jQuery 3.7.1. WordPress ships it, but its presence means deprecated jQuery APIs are still being called somewhere on this site.
- **Impact:** small directly; larger indirectly — it is why H2 recommends *against* deferring jQuery.
- **Fix:** read the console migrate warnings; they name the call sites. Fixing them permits dropping Migrate, which in turn makes jQuery deferral testable.
- **Effort:** 1 hr to diagnose; remediation depends on what it finds.

---

## 5. Vendored Library Currency

WordPress core and the plugins are current — 7.0.2 is what `api.wordpress.org` reports as `current`, Yoast 28.1 is the latest release, Beaver Builder 2.10.3 sits ahead of the public lite build. **The stale code is bundled inside those current plugins**, and no plugin update reaches it:

| Library | Version | Age | Raw bytes | Ships with |
|---|---|---|---|---|
| Bootstrap | **3.4.1** | EOL Jul 2019 | 121,412 CSS + 39,681 JS | BB Theme |
| Swiper | **8.4.7** | Nov 2022 | 143,660 | PowerPack |
| fancyBox | **3.5.7** | ~2019, EOL | 68,253 | PowerPack |
| Font Awesome Free | **5.15.4** | Nov 2021 | 59,305 | Beaver Builder |
| Animate.css | **3.5.1** | 2016 | 52,789 | PowerPack |
| bxSlider | abandoned | ~2019 | 24,191 | Beaver Builder |
| Magnific Popup | abandoned | 2016 | 21,145 | Beaver Builder |
| jquery.fitvids | **1.2** | 2013 | 1,782 | Beaver Builder |

Versions read from each file's own banner comment, not from its `?ver=` string. Swiper 8→12 and fancyBox 3→5 each cross multiple majors with breaking API changes; Bootstrap 3→5 is a theme rewrite. **There is no update path to current libraries that does not replace the plugin or the theme.** Detail: `audit/05` §2.

---

## 6. Third-Party Load

| Script | Source | Current load | Blocking [LH] | Transfer | Recommended |
|---|---|---|---|---|---|
| UserWay `widget_app_base` | cdn.userway.org | inline-injected | **2,354 ms** | 47 KiB | plugin setting, else idle+timeout (H3) |
| UserWay `widget_base.css` | cdn.userway.org | injected | 87 ms | 71 KiB | loads with the widget |
| **GTM `gtm.js`** | googletagmanager.com | async | **831 ms** | 115 KiB | audit container (H6) |
| **GTM `gtag/js`** | googletagmanager.com | async | **334 ms** | 159 KiB | deduplicate |
| ReviewWave `reviews_embed.js` | cdn.reviewwave.com | sync `<head>` | — | 4 KiB | `defer` (H2) |
| ReviewWave `chat_embed.js` | cdn.reviewwave.com | sync `<head>` | — | 7 KiB | `defer` — regression-test the chat |
| ReviewWave config | rw-embed-data.s3… | sync `<head>` | — | 56 KiB | `defer` — 1,570 ms render-block |
| YouTube thumbnails ×35 | i.ytimg.com | eager CSS bg | 0 ms | 459 KiB | facade (H8) |
| Google Maps embed | google.com/maps | **`loading="lazy"`** | 0 ms | 0 on load | **no action** |
| Vimeo ×2 | player.vimeo.com | inside `<script type="text/html">` | 0 ms | 15 KiB thumb | already deferred |
| Google Fonts | fonts.gstatic.com | sync CSS | 0 ms | 57 KiB | `display=swap` (M5) |

**Third-party blocking measured by Lighthouse: 3,820 ms** — UserWay 2,443 ms (64%), GTM 1,165 ms (30%), ReviewWave 196 ms (5%), S3 14 ms. Lighthouse reports the ReviewWave figure only in aggregate; the per-file splits that circulated in earlier revisions do not appear in the source data and have been removed.

The ReviewWave S3 config, re-verified: `Content-Length: 56589` returned identically under `identity`, `gzip`, and `br,gzip` — no compression is available — with **no `Cache-Control`**, and `ETag` + `Last-Modified` present. The object metadata belongs to ReviewWave; the only fix available from this site is `defer`.

**What deferral does and does not do.** TBT counts blocking between FCP and TTI. Deferring moves work out of that window; it does not delete it. UserWay is a clean shift — nothing above the fold depends on it. GTM is different: its cost is container size, so trimming is a real reduction. The ReviewWave scripts are cheap to execute (196 ms total) but expensive to *wait for* — 2,510 ms of render-blocking across all three — so `defer` helps FCP far more than TBT there.

---

## 7. Performance Budget

Byte rows are **hygiene targets**, not TBT predictors — see H1. Each is reachable by the mechanism named beside it.

| Resource | Current raw | Current wire | Target (raw) | Reachable by |
|---|---|---|---|---|
| HTML document | 218,440 B | 33,546 B | **<195,000 B** | H7 removes 25,169 B → ~193,300 B |
| First-party CSS | 713,944 B | 90,115 B | **<600,000 B** | drop the full Font Awesome build (59,305) + Animate.css (52,789) → 601,850 B; subsetting either clears it |
| First-party JS | 618,211 B | 160,061 B | **<410,000 B** | drop the heavier of each duplicate pair — Swiper 143,660 + fancyBox 68,253 → 406,298 B (M4) |
| **First-party total** | **1,550,595 B** | **283,722 B** | **<1,205,000 B** | ~1.3× reduction, all three above |
| Hero video, mobile | — | 3,112 KiB | **0 KiB** | C1-A — the video is never appended |
| Hero video, desktop | — | 3,112 KiB | **<1,300 KiB** | C1-D. WebM is 38% of the MP4's bitrate and the browser aborts at a similar buffer point, so expect ≈1,180 KiB |
| YouTube thumbnails | — | 459 KiB | 0 KiB | facade (H8) |
| GTM | — | 275 KiB | <100 KiB | container audit (H6) |
| Google Fonts | — | 57 KiB | <25 KiB | 5 families → 2 (M5) |
| TBT | 14,710 ms | — | <5,000 ms | stretch; no configuration change reaches it |
| LCP | 18.9 s | — | <4.0 s | milestone, not a prediction |
| CLS | 0.184 | — | <0.1 | C1-A on mobile, C1-B on desktop |

**On targets.** CLS is the only metric with a mechanism that directly addresses its stated root cause. LCP and TBT are milestones. The 2026-07-28 original stated "<2.5 s LCP" and "TBT <5,000 ms via deferral" as outcomes while its own analysis projected TBT landing at 13,500-15,500 ms. Do not commit to a Core Web Vitals pass without DOM reduction and third-party removal, both beyond configuration.

**Gate:** any change adding >50 KiB of raw payload requires explicit approval.

---

## 8. Implementation Sequence

Ordered by value per hour, with C0 early because its outcome may make later steps unnecessary. Every verification below discriminates success from no-op.

| # | Task | Finding | Time | Verification |
|---|---|---|---|---|
| **1** | **BB hero row → Show Video On Mobile = No** | C1-A | 5 min | Mobile UA: **no `hiking.mp4`/`hiking.webm` request**; LCP element is the fallback WebP. A `<video src="">` remains — do not check for its absence |
| 2 | Child-theme rule sizing `.fl-bg-video video` to 100%/100%, **every declaration `!important`** | C1-B | 15 min | Desktop UA: CLS ≤ 0.1; no non-zero shift listed; computed width/height survive a window resize |
| 3 | **Establish 10Web Booster's state** — off, cache-not-warm, or dead | C0 | 30 min | `grep -oE '<script[^>]+(defer\|async)' \| wc -l` > 0, or the plugin is gone |
| 4 | `preconnect` to `chiro.inceptionimages.com`; background-image on `.fl-bg-video`; poster preload | C1-C, H5 | 20 min | Hint present; poster paints before video bytes arrive |
| 5 | Dequeue `global-styles`, `wp-block-library`, `classic-theme-styles`, emoji — **on `wp_enqueue_scripts`** | H7 | 30 min | `grep -c global-styles-inline-css` → 0; raw HTML ≈193,000 B |
| 6 | `width`/`height` + `loading="lazy"` on the 6 images — BB photo ×1, PowerPack ×1, **UABB Info Box ×4 (template override or output filter)** | H8a, L4 | 1-2 hrs | All 6 carry dimensions and lazy |
| 7 | Move `fetchpriority="high"` off the ribbon via a core filter — **do with step 6** | H4 | 30 min | Zero `fetchpriority="high"`, or exactly one, on the poster |
| 8 | `&display=swap`; `dns-prefetch` → `preconnect` for `fonts.googleapis.com` | M5 | 15 min | Webfont audit passes |
| 9 | **Re-measure: 3 Lighthouse runs, median. Re-run both sweep passes.** | — | 45 min | Establishes a real baseline |
| 10 | `defer` the three ReviewWave scripts | H2 | 30 min | Render-blocking savings **≤ 200 ms** (they are 2,510 ms today) **and** the chat widget opens and submits |
| 11 | UserWay: plugin setting if one exists, else idle + `{timeout:3000}` | H3 | 15-90 min | UserWay blocking <200 ms **and** widget appears within 5 s |
| 12 | Child-theme `style.css` versioning via dequeue/re-register or `style_loader_src` | M6 | 20 min | `?ver=` shows a timestamp **and** changes after an edit |
| 13 | Pre-warm: cron'd `curl` loop over `page-sitemap.xml` | M1 | 15 min | Sweep shows `hit` on first pass for most URLs |
| 14 | `Cache-Control: no-cache` on HTML | M1 | 15 min | Header present on all 44; 304s on revalidation |
| 15 | **Re-measure** | — | 45 min | Compare against step 9 |
| 16 | Audit the GTM container | H6 | 1-2 hrs | GTM <100 KiB |
| 17 | YouTube facade — 35 instances. Check whether Swiper still enqueues | H8b, M4 | 2-3 hrs | Zero `i.ytimg.com` on load |
| 18 | Reduce Google Fonts 5 families → 2 | M5 | 1 hr | 2 families in the URL |
| 19 | Regenerate the award ribbon at rendered size | L3 | 20 min | 20 KiB saved |
| 20 | Enable ETag on static assets | L1 | 10 min | `etag` present |
| 21 | Diagnose the jQuery Migrate warnings | L6 | 1 hr | Console lists the call sites |
| 22 | Rename `.jpg.webp` **with a redirect**, after confirming 10Web will not regenerate it | L2 | 1 hr | Correct MIME; no 404 on any reference |
| 23 | Add a CDN — **after step 22** | M7 | 1-2 hrs | CDN headers present |
| 24 | **Re-measure** | — | 45 min | Compare against step 15 |

**Steps 1-8 total about 3 hours 25 minutes to 4 hours 25 minutes**, of which **the first two are 20 minutes and carry most of the value** on the measured mobile profile. None of the eight requires design approval, a plugin install, or a page rebuild.

**Steps 1-24 total 14.8-20.0 hours** — the sum of the per-step figures above, not a rounded guess. (Rev. 3 said "16-20 hours"; its own per-step figures summed to 14.1-18.3.) Steps 17 and 23 are the largest. There is no configuration path to a green Lighthouse score — steps 16, 17, and DOM reduction are the ceiling-lifting work, and even then 70+ mobile would require removing third parties entirely.

### Rollback

| Change | Rollback |
|---|---|
| Show Video On Mobile, WebM-only | BB row settings — revert via page revision history |
| All child-theme CSS/PHP (steps 2, 4, 5, 7, 12) | Revert the file |
| `width`/`height` and lazy attributes | Remove the attributes |
| Script deferral | Remove `defer`; restore the inline UserWay snippet from revision history |
| 10Web toggles | Toggle back — record which toggle did what before changing the next |
| Cron pre-warm loop | Remove the cron entry; nothing else changes |
| `Cache-Control` header | Remove the directive; `no-cache` leaves no stale documents behind |
| YouTube facade | Restore `pp-video` modules from page revision history |
| GTM container | GTM keeps version history; restore any prior container version |
| `.jpg.webp` rename | Keep the redirect — the original `.jpg` no longer exists, so there is no file-level rollback |

---

## 9. Sources & Methodology

- **Lighthouse 12.6.0**, Chromium 138.0.0.0, emulated Moto G Power, Slow 4G throttling, single page session, initial page load. Captured 2026-07-28 and 2026-07-30 18:13 EDT. Extract: `audit/data/lighthouse-mobile-2026-07-30.md`. Re-measured 2026-08-13 with Lighthouse 12.8.2: `audit/data/lighthouse-mobile-2026-08-13.md`.
- **Header sweeps** — all 44 URLs from `page-sitemap.xml`, two passes each plus an uncompressed-size pass, via GET. `audit/data/header-sweep-2026-07-30.tsv` and `…-run2.tsv`. Reproducer: `audit/data/header-sweep.sh`.
- **Source inspection** — live HTML for `/` and `/knee-pain-lp/`, fetched with `Accept-Encoding: identity` and measured in **bytes**.
- **Beaver Builder behaviour** — read directly from `2-layout.js` and `2-layout.css` on the origin. Every claim in C1 about BB's video handling is quoted from that code.
- **Asset sizes** — each file fetched twice, `br,gzip` and `identity`, `content-length` from `%{size_download}`.
- **Platform facts** — `GET /wp-json/`, `api.wordpress.org` version APIs, and a `readme.txt` 403/404 directory probe validated against a control slug. Detail: `audit/05`.

### Known limitations

1. **Every [LH] figure here is from the single 2026-07-30 18:13 EDT run.** The 2026-08-13 re-measurement (3 runs, median) revises several of them materially — payload to ~17 MB with the hero video downloading in full, and CLS to 0.000 on a warm cache against 0.184 on a cold one. CPU figures from the two dates are not comparable: Lighthouse applies a fixed ×4 multiplier to whatever host runs it.
2. **Lighthouse figures are single runs and the variance is large.** Two runs of the unmodified site differed by 6 score points, 3.0 s of LCP, 3,810 ms of TBT, and 3.2× of reported payload. Payload varies most because the browser aborts the hero video download at a different point each time. Re-measure with 3+ runs and compare medians.
3. **Cold-cache TTFB is also highly variable.** Two sweeps of identical content 78 minutes apart gave MISS medians of 0.845 s and 1.788 s, maxima of 2.654 s and 4.946 s, and **disjoint** lists of the five slowest pages. Any per-page cold-cache claim is noise. The warm path — 0.052-0.113 s across 90 requests — is stable.
   *Method:* medians are the lower-middle value (sweep 1, n=44, true median 0.8577) and p90 is `sorted[int(0.9*(n-1))]`. Both are stated so the figures are reproducible; neither convention changes the 2.1× ratio the finding rests on.
4. **Desktop was not measured**, on either date. The 2026-07-28 run reported 47/100 desktop. This matters because C1-A applies only to mobile and C1-B is the desktop-side fix.
5. **10Web's configuration state is inferred, not observed.** C0 lists three explanations and cannot distinguish them without wp-admin access.
6. **Beaver Builder's behaviour was read, not executed.** Every claim in C1 is quoted from `2-layout.js` and `2-layout.css` on the origin. No browser ran that code in this environment. Three specific consequences are inference and are labelled as such in C1-A: that `loadedmetadata` will not fire with `src=""`, that the fallback WebP becomes the LCP element on mobile, and that the empty-`src` document fetch is harmless. Verify all three in DevTools on the first pass.
7. **M6's mechanism is unverified.** BB Theme's parent is premium and not readable from outside; the fix depends on which file registers `fl-child-theme`.
8. **Two pages sampled for source inspection, not 44.** Facts marked site-wide (H7, H2's zero-`defer` count, M6, L1) were confirmed on both `/` and `/knee-pain-lp/`. Header facts come from all 44 URLs across two sweeps.
9. **C1-A's mobile gate is user-agent based.** BB's `_isMobile()` tests `navigator.userAgent`. It fires under Lighthouse's Moto G emulation and on real phones, but a desktop browser at a narrow viewport still gets the video. This is a device-class fix, not a viewport-width fix.
10. **No competitor measurements.** Thresholds cited are Google's published Core Web Vitals values. No competitor sites were tested and no ranking or conversion outcomes are projected — page speed is a documented but minor ranking signal, and the case for this work is user experience.

---

## 10. Out of Scope

- **Platform architecture, plugin inventory, version currency, code quality** — `audit/05-architecture-and-code-quality.md`
- **On-page SEO and content** — metadata gaps, schema format errors: `audit/04-seo-content-findings.md`
- **Spelling and grammar** — `audit/02-spelling-grammar-audit.md`
- **Accessibility** — alt text and heading hierarchy: `audit/04` L3-L4. Note that H3's accessibility tradeoff is a live decision, not a documentation item.
- **Security** — HTTP security headers absent, verified on two URLs (`audit/05` **A3**); REST user enumeration open (`audit/05` **A2**); plugin CVEs unverified (`audit/04`). `xmlrpc.php` and `readme.html` both return 403 — the 2026-07-28 "xmlrpc exposed" item is closed.

