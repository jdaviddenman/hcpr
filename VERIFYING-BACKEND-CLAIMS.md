# Verifying what the backend team says they changed

**Purpose:** an independent way to confirm, from outside, that a change asserted by Inception's technical
team is actually live and actually reaching visitors. No site access, no wp-admin, no FTP — everything
here runs from any laptop with `curl`.

**Why this document exists.** This site has four separate traps that make a correct fix look like a
failure, and — worse — make an unshipped fix look like a success. Most developers know about caching in
general. These are the specific, measured behaviours of *this* server, and three of them have already
caused a wrong conclusion in this project's history.

Written 2026-08-13. Every behaviour below was measured on that date.

---

## The four traps

### Trap 1 — the page cache has no WordPress control, so a plain re-fetch can lie

Measured: the homepage returns `server: LiteSpeed` with `x-litespeed-cache: miss` on a first fetch and
`hit` on the second. **HTML carries no `Cache-Control` header at all** — verified across 15 distinct HTML
responses in every state (12 misses, 12 hits, both encodings, two user agents, a 304, and a cache bypass).

The LiteSpeed Cache **plugin is not installed** — `/wp-content/plugins/litespeed-cache/readme.txt`
returns the WordPress 404 page. So there is no "Purge All" button, no WP-CLI purge, and no post-publish
auto-purge. Cache eviction is at the server level only.

**What this means for you:** after the team says "it's live", a plain `curl` may return the pre-change
page for minutes. Concluding "they didn't do it" would be wrong.

**The bypass:**

```bash
curl -sS --max-time 30 --compressed "https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

A unique query string forces a fresh render (`x-litespeed-cache: miss`). Use a **new** value every time —
the same string twice returns a `hit` on its own cache entry.

> **The trap inside the bypass.** `?cb=` creates its own cache entry and the response differs from the
> canonical page by about **58 bytes**, because the URL is echoed into an inline block. More importantly:
> **`?cb=` tells you what the origin generates, not what visitors receive.** A change can be live on
> `?cb=` and absent from the plain URL for as long as the cached copy survives.

**So always do both, in this order:**

```bash
U=https://www.highcountrypainrelief.com
curl -sS --compressed "$U/?cb=$(date +%s)" | grep -c 'THING'   # 1. did the origin change?
curl -sS --compressed "$U/"                | grep -c 'THING'   # 2. are visitors getting it?
```

If step 1 passes and step 2 fails after ~10 minutes, the change is real but the cache is holding a stale
copy. That is a hosting question, not a "they didn't do the work" question.

### Trap 2 — the ETag is a cache-entry ID, not a content fingerprint

**Do not use ETag changes to detect content changes on this site. It does not work.**

The format is `"<serial>-<unix-time-of-cache-write>;<encoding>"`. Proven three ways:

1. Twelve consecutive cache misses were assigned strictly sequential serials `5476`–`5487` with mtimes
   `1786618204`–`1786618216` — the second each request was served.
2. The homepage ETag `"5470-1786617827"` decodes to the exact second an earlier fetch wrote that entry.
3. **Decisively:** across the two 30 July sweeps, **44 of 44 URLs had byte-identical content and 44 of 44
   had different ETags** (homepage `424-1785448018` → `496-1785452695` on unchanged 218,440 B).

A changed ETag means the cache entry was rewritten. It says nothing about whether the bytes differ.
**Compare content, not ETags** — `md5sum` the bodies, or grep for the specific string.

### Trap 3 — CSS and JS file edits do not reach returning visitors for 30 days

Measured: `bb-theme-child/style.css` is enqueued as `style.css?ver=7.0.4`. **That is the WordPress
version, not the file's** — Beaver Builder's theme enqueues it with no version argument, so the string
changes only when WordPress updates. The file itself is served `cache-control: public, max-age=2592000`
(30 days) with **no ETag** and `last-modified: Mon, 08 May 2017`.

Consequence: the team edits the stylesheet, the origin serves new bytes, and **every browser that visited
in the last 30 days keeps using its cached copy.** Fetching the file directly with a cache-buster of your
own bypasses precisely the cache in question and returns a false pass.

**Verify it properly — read the version off the live page, then fetch that exact URL:**

```bash
U=https://www.highcountrypainrelief.com
# 1. What version string is the page actually telling browsers to use?
curl -sS --compressed "$U/?cb=$(date +%s)" | grep -o 'bb-theme-child/style.css?ver=[^"'"'"']*'
# 2. Fetch THAT url — with its ver, not one you invented — and look for your change
curl -sS --compressed "$U/wp-content/themes/bb-theme-child/style.css?ver=<the value from step 1>" \
  | grep -c 'the-thing-you-expect'
```

**If step 1 still returns `ver=7.0.4` after a CSS change, the fix cannot reach returning visitors**,
however correct the CSS is. The version string must become a Unix timestamp — see `PRIORITY-FIXES.md`,
note B, for the one-time fix.

The same applies to every static asset: 5 sampled first-party CSS/JS files all carry
`cache-control: public, max-age=2592000`, Brotli, and **no ETag**.

### Trap 4 — the mobile/desktop split is by user agent, not screen size

Beaver Builder's hero-video gate tests `navigator.userAgent` against
`/Mobile|Android|Silk\/|Kindle|BlackBerry|Opera Mini|Opera Mobi|webOS/i`. **Resizing a desktop browser
window proves nothing.** Any check on mobile behaviour must send a mobile UA:

```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
curl -sS --compressed -A "$UA" "$U/?cb=$(date +%s)"
```

Two things measured today that are worth knowing here: the server advertises
`vary: Accept-Encoding,User-Agent`, **but the page cache is not actually keyed on user agent** — a mobile
UA and a desktop UA returned the same ETag and byte-identical bodies. And the HTML served to Googlebot's
smartphone crawler is byte-identical to what a phone gets. So the UA matters for the site's *JavaScript*,
not for which cached copy you receive.

---

## Checks that cannot fail — and have already fooled this project

A verification that passes on the unmodified site is worse than no verification. Three shipped in earlier
revisions of this audit. Test every check against today's live site before trusting it.

| Check | Why it is broken | Use instead |
|---|---|---|
| `grep -c 'defer\|async'` > 0 | Returns **24** on the unmodified site — core emits `decoding="async"` on 22 images, and `grep -c` counts *lines*, not matches | `grep -oE '<script[^>]*(\sdefer\|\sasync)[ =>]' \| wc -l` — returns **0** today |
| "No `<video>` element in `.fl-bg-video`" | Beaver Builder appends the `<video>` in **both** branches of its mobile gate; the fix sets `src=""`. A correct fix leaves a `<video>` behind | Check for the absent **request**: DevTools Network, filter `hiking` |
| Network filter on `chiro.inceptionimages` = 0 rows | **Six `<img>` elements** on the homepage legitimately load from that host and always will | Filter on `hiking` — only `hiking.mp4` / `hiking.webm` must vanish |
| `grep -c '!important' style.css` | Counts lines; a minified or reflowed paste changes the answer | `grep -o '!important' file \| wc -l` — counts occurrences |
| Any CLS check on a warm cache | CLS appeared in **1 of 3** Lighthouse runs on 13 Aug — the one where the document was slow (cache MISS). Both warm runs scored 0.000 | Test CLS against a **cold** cache, or you will "confirm" a fix that did nothing |

**The general rule: record the pre-change value first.** A check with no stated "before" cannot
distinguish a fix from a no-op. Every check in `PRIORITY-FIXES.md` carries today's value for this reason.

---

## Baseline — what the live site returns today, 2026-08-13

Any of these changing is a real change. Any of them *not* changing after an asserted fix is a real
question.

```
Homepage HTML, raw (identity)            216,956 B
Homepage HTML, transferred (brotli)       33,290 B
<script> tags                                   32   (19 with src)
scripts with defer or async                      0
<link rel=stylesheet>                           13
<img>                                           22   (6 eager, 16 lazy)
fetchpriority="high" occurrences                 1   (still on the award ribbon)
data-video-mobile="yes"                          1   (hero video still on for phones)
i.ytimg.com references                          35
pp-video-gallery-item swiper-slide              35
swiper.min references                            2   (js + css)
VideoObject microdata blocks                    31   (in the gallery; 33 page-wide)
global-styles-inline-css                    17,714 B (still delivered)
tenweb REST namespaces registered                2   (tenweb_so/v1, tenwebio/v2)
Cache-Control on HTML                        absent
ETag on static assets                        absent
WordPress                                    7.0.4
Beaver Builder                             2.10.3.1
```

Cache and timing, 12 sitemap URLs, two passes:

```
First requests that were cache MISSES        12 of 12
Cold TTFB   median 1.054 s   min 0.592 s   max 2.225 s
Warm TTFB   median 0.076 s   min 0.068 s   max 0.103 s
```

Lighthouse mobile, 3 runs, median (Lighthouse 12.8.2, benchmarkIndex ~1,300):

```
Performance 33   LCP 12.2 s   TBT 1,684 ms   CLS 0.000 (0.184 on the cold run)   payload 16,986 KiB
```

---

## One-command baseline check

`audit/data/verify-live.sh` runs the whole census against the live site and prints today's values beside
the 13 August baseline. Run it before and after any asserted change.

```bash
bash audit/data/verify-live.sh
```

---

## When the numbers disagree with the team

Three legitimate reasons a change can be real but invisible to you, in the order to check them:

1. **Server page cache not yet evicted.** `?cb=` shows the change, plain URL does not. Wait, or ask the
   host to flush. *Not* the team's fault.
2. **Asset version string unchanged.** The origin has the new file; browsers are told it is the same
   file. See Trap 3. *This one is a real defect* and needs the `functions.php` fix.
3. **The change is user-agent gated.** You checked with the wrong UA. See Trap 4.

And one reason it can look successful when it is not: **you checked a URL that bypasses the cache the
change has to travel through.** `?cb=` and a hand-written `?ver=` both do this. Always finish on the
plain, canonical URL a visitor would request.

---

*Companion documents:* `PRIORITY-FIXES.md` (the work), `SECURITY-FINDINGS.md` (separate register),
`audit/01-page-speed-performance-audit.md` (full findings),
`audit/data/lighthouse-mobile-2026-08-13.md` (fresh measurement, with its limits).
