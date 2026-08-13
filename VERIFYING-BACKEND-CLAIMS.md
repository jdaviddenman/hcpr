# Verifying what the backend team says they changed

Confirming from outside that an asserted fix is live and reaching visitors. No site access needed —
everything here runs from any laptop with `curl`.

This server has four behaviours that make a correct fix look failed, and an unshipped fix look
successful. Three have already caused a wrong conclusion in this project. All measured 2026-08-13.

---

## Trap 1 — the page cache has no WordPress control

`server: LiteSpeed`, `x-litespeed-cache: miss` on a first fetch and `hit` on the second. **HTML carries no
`Cache-Control` header** — verified across 15 distinct responses in every state.

The LiteSpeed Cache **plugin is not installed** (`/wp-content/plugins/litespeed-cache/readme.txt` returns
the WordPress 404 page), so there is no "Purge All" button, no WP-CLI purge, and no post-publish
auto-purge. Eviction is server-level only.

After the team says "it's live", a plain `curl` may return the old page for minutes.

```bash
curl -sS --max-time 30 --compressed "https://www.highcountrypainrelief.com/?cb=$(date +%s)"
```

A unique query string forces a fresh render. Use a new value every time — the same string twice returns a
`hit` on its own cache entry.

**The trap inside the bypass:** `?cb=` creates its own cache entry, the response differs from the
canonical page by ~58 bytes, and it tells you what the origin generates, **not what visitors receive**. A
change can be live on `?cb=` and absent from the plain URL for as long as the cached copy survives.

```bash
U=https://www.highcountrypainrelief.com
curl -sS --compressed "$U/?cb=$(date +%s)" | grep -c 'THING'   # did the origin change?
curl -sS --compressed "$U/"                | grep -c 'THING'   # are visitors getting it?
```

Step 1 passing and step 2 failing after ~10 minutes means the change is real and the cache is stale. That
is a hosting question, not a "they didn't do it" question.

## Trap 2 — the ETag is a cache-entry ID, not a content fingerprint

**Do not use ETag changes to detect content changes here.** The format is
`"<serial>-<unix-time-of-cache-write>;<encoding>"`. Proven three ways:

1. Twelve consecutive misses got sequential serials `5476`–`5487` with mtimes `1786618204`–`1786618216` —
   the second each request was served.
2. The homepage ETag `"5470-1786617827"` decodes to the exact second an earlier fetch wrote that entry.
3. Across the two 30 July sweeps, **44 of 44 URLs had byte-identical content and 44 of 44 had different
   ETags** (homepage `424-1785448018` → `496-1785452695` on unchanged 218,440 B).

A changed ETag means the cache entry was rewritten. Compare content — `md5sum` the bodies, or grep for
the specific string.

## Trap 3 — file edits do not reach returning visitors for 30 days

`bb-theme-child/style.css` is enqueued as `style.css?ver=7.0.4`. **That is the WordPress version, not the
file's** — Beaver Builder's theme enqueues it with no version argument, so it changes only when WordPress
updates. The file is served `max-age=2592000` (30 days) with no ETag and `last-modified: Mon, 08 May 2017`.

The team edits the stylesheet, the origin serves new bytes, and every browser that visited in the last 30
days keeps its cached copy. Fetching the file with a cache-buster of your own bypasses exactly the cache
in question and returns a false pass.

```bash
U=https://www.highcountrypainrelief.com
# 1. What version is the page telling browsers to use?
curl -sS --compressed "$U/?cb=$(date +%s)" | grep -o 'bb-theme-child/style.css?ver=[^"'"'"']*'
# 2. Fetch THAT url — with its ver, not one you invented
curl -sS --compressed "$U/wp-content/themes/bb-theme-child/style.css?ver=<value from step 1>" \
  | grep -c 'the-thing-you-expect'
```

**If step 1 still returns `ver=7.0.4` after a CSS change, the fix cannot reach returning visitors**,
however correct the CSS. The value must become a Unix timestamp — see `PRIORITY-FIXES.md` note B.

All five sampled first-party CSS/JS assets carry the same `max-age=2592000`, Brotli, and no ETag.

## Trap 4 — the mobile split is by user agent, not screen size

Beaver Builder's hero-video gate tests `navigator.userAgent` against
`/Mobile|Android|Silk\/|Kindle|BlackBerry|Opera Mini|Opera Mobi|webOS/i`. **Resizing a desktop window
proves nothing.**

```bash
UA='Mozilla/5.0 (Linux; Android 11; moto g power) AppleWebKit/537.36 Chrome/138 Mobile Safari/537.36'
curl -sS --compressed -A "$UA" "$U/?cb=$(date +%s)"
```

The server advertises `vary: Accept-Encoding,User-Agent`, but **the page cache is not keyed on user
agent** — mobile and desktop UAs returned the same ETag and byte-identical bodies. The UA matters for the
site's JavaScript, not for which cached copy you get.

---

## Checks that cannot fail

A verification that passes on the unmodified site is worse than none. Three shipped in earlier revisions
of this audit.

| Check | Why it is broken | Use instead |
|---|---|---|
| `grep -c 'defer\|async'` > 0 | Returns **24** unmodified — core emits `decoding="async"` on 22 images, and `grep -c` counts lines | `grep -oE '<script[^>]*(\sdefer\|\sasync)[ =>]' \| wc -l` — returns **0** today |
| "No `<video>` in `.fl-bg-video`" | Beaver Builder appends the `<video>` in **both** branches of its mobile gate; the fix sets `src=""` | Check for the absent **request**: DevTools Network, filter `hiking` |
| Network filter on `chiro.inceptionimages` = 0 rows | **Six `<img>`** on the homepage legitimately load from that host and always will | Filter on `hiking` |
| `grep -c '!important' style.css` | Counts lines; a reflowed paste changes the answer | `grep -o '!important' file \| wc -l` |
| Any CLS check on a warm cache | CLS appeared in **1 of 3** runs on 13 Aug — the cold one. Both warm runs scored 0.000 | Test CLS against a **cold** cache |

**Record the pre-change value first.** A check with no stated "before" cannot distinguish a fix from a
no-op. Every check in `PRIORITY-FIXES.md` carries today's value for this reason.

---

## Baseline — 2026-08-13

```
Homepage HTML, raw (identity)            216,956 B
Homepage HTML, transferred (brotli)       33,290 B
<script> tags                                   32   (19 with src)
scripts with defer or async                      0
<link rel=stylesheet>                           13
<img>                                           22   (6 eager, 16 lazy)
fetchpriority="high"                             1   (award ribbon)
data-video-mobile="yes"                          1
i.ytimg.com references                          35
pp-video-gallery-item swiper-slide              35
swiper.min references                            2
VideoObject blocks                              33   (31 in the gallery)
global-styles-inline-css                    17,714 B
tenweb REST namespaces                           2
Cache-Control on HTML                        absent
ETag on static assets                        absent
WordPress                                    7.0.4
Beaver Builder                             2.10.3.1

First requests that were cache MISSES     12 of 12
Cold TTFB   median 1.054 s   min 0.592 s   max 2.225 s
Warm TTFB   median 0.076 s   min 0.068 s   max 0.103 s

Lighthouse mobile, median of 3 (12.8.2, benchmarkIndex ~1,300):
score 33   LCP 12.2 s   TBT 1,684 ms   CLS 0.000 warm / 0.184 cold   payload 16,986 KiB
```

Run `bash audit/data/verify-live.sh` to print today's values beside this baseline.

---

## When the numbers disagree with the team

Three reasons a change can be real but invisible, in the order to check them:

1. **Server cache not yet evicted.** `?cb=` shows it, plain URL does not. Wait, or ask the host to flush.
2. **Asset version string unchanged** (trap 3). This one is a real defect and needs the `functions.php` fix.
3. **The change is user-agent gated** (trap 4). You used the wrong UA.

And one reason it can look successful when it is not: **you checked a URL that bypasses the cache the
change has to travel through.** `?cb=` and a hand-written `?ver=` both do this. Finish on the plain,
canonical URL a visitor would request.
