# Architecture, Version Currency & Code Quality: highcountrypainrelief.com

**Date:** 2026-07-31 · **versions and byte tables reconciled to 2026-08-13**
**Scope:** platform architecture, plugin inventory, version currency, per-asset byte accounting, and code-quality indicators. Metric findings and the remediation sequence live in `audit/01-page-speed-performance-audit.md`; caching and third-party behaviour live in `audit/03-page-load-caching-deep-dive.md`. **This document does not restate their findings** — where a measurement here became a finding there, the finding ID is cited.

**Evidence:** live GET of `/` and `/knee-pain-lp/`, `GET /wp-json/`, per-asset `content-length` under two encodings, `api.wordpress.org` version APIs. All 2026-07-30.

> **Method note.** Every claim below is a header, markup or byte measurement, and every count used as evidence was taken with two independent patterns with both results recorded. Figures marked **[LH]** come from `audit/data/lighthouse-mobile-2026-07-30.md`; the 2026-08-13 re-measurement is in `audit/data/lighthouse-mobile-2026-08-13.md`.

---

## 1. Executive Summary

**WordPress core and the plugins are current.** `7.0.4` as at 2026-08-13 (`7.0.2` on 07-30) is what `api.wordpress.org` reports as `current`. Yoast 28.1 is the latest release. Beaver Builder 2.10.3 sits ahead of the public lite build. The premise that this site runs stale software does not survive measurement.

**What is stale is vendored inside those current plugins.** Bootstrap 3.4.1 (EOL July 2019), Font Awesome 5.15.4, Swiper 8.4.7, fancyBox 3.5.7, Animate.css 3.5.1, jquery.fitvids 1.2. None can be reached by a plugin update. §2.

**Ten plugins are loaded, and one of them is a page-speed optimiser producing no measurable effect.** No prior document in this repository contained a plugin inventory. §3. That finding is `audit/01` **C0** and is step 3 of the remediation sequence.

**Brotli hides a ~5.4× gap between what is transferred and what is parsed.** ~278,042 B on the wire, ~1,512,102 B through the parser (283,722 / 1,550,595 B on 2026-07-30, before the three assets noted in §4 shrank). Per-asset accounting in §4. The framing consequence is `audit/01` **H1**. Raw bytes are still a poor CPU proxy here: Script Parse & Compile is only 383 ms of 36,900.

**Ten code-quality indicators**, of which one is an operational trap: two assets carry a `?ver=` that never changes when the file does, so an edit to the child theme's CSS will not reach a returning visitor for 30 days. §6.

---

## 2. Version Currency

### Core and plugins — current

| Component | Installed | Evidence | Latest | Verdict |
|---|---|---|---|---|
| WordPress | **7.0.4** | `<meta name="generator" content="WordPress 7.0.4" />`; `wp-emoji-release.min.js?ver=7.0.4` | **7.0.4** — `api.wordpress.org/core/version-check/1.7/` returns `"current":"7.0.2"` | current |
| Yoast SEO | 28.1 | `yoast/v1` REST namespace; version from audit 04 | 28.1, released 2026-07-21 | current |
| Beaver Builder | 2.10.3 | `?ver=2.10.3` on 9 first-party assets | wp.org lite build is 2.10.2.2 (2026-06-08); premium tracks ahead | current |
| Beaver Themer | 1.5.3.2 | `…-layout-bundle.css?ver=2.10.3-1.5.3.2` | — | not independently checkable |
| BB Theme | 1.7.19.2 | `?ver=1.7.19.2` on 4 theme assets | — | not independently checkable |
| PowerPack for BB | **2.40.1.6** | inline `var bb_powerpack = { version: '2.40.1.6' }` | — | premium, no public API — **unverified** |
| Ultimate Addons for BB | **undetermined** | its only frontend asset carries the WP core fallback `?ver=`, not a plugin version | — | see B3 |

**On reading versions off `?ver=` strings.** On this site a `?ver=` reports one of three different things: the plugin version (`bb-plugin` assets), the *bundled library* version (`swiper.min.js?ver=8.4.7`, `jquery.fancybox.min.css?ver=3.5.4`), or the WordPress core version where a script was enqueued with no version argument (`js_cookie.js?ver=7.0.4`, which read `7.0.2` before the core update — evidence that the string tracks core, not the file). This resolves the version confusion flagged in `audit/04-seo-content-findings.md` — "Ultimate Addons at 2.10.3, probably a copy-paste error." It was a misread of a `?ver=` string, and the plugin's actual version still cannot be determined from the frontend.

### Vendored libraries — stale, and unreachable by a plugin update

Versions read from each file's own banner comment, not from its `?ver=` string.

| Library | Version | Age | Current line | Raw bytes | Ships with |
|---|---|---|---|---|---|
| Bootstrap | **3.4.1** | EOL Jul 2019 | 5.x | 121,412 CSS + 39,681 JS | BB Theme |
| Swiper | **8.4.7** | Nov 2022 | 11.x / 12.x | 143,660 | PowerPack |
| fancyBox | **3.5.7** | ~2019, EOL | v5 / v6 | 68,253 | PowerPack |
| Font Awesome Free | **5.15.4** | Nov 2021 | 6.x / 7.x | 59,305 | Beaver Builder |
| Animate.css | **3.5.1** | 2016 | 4.x | 52,789 | PowerPack |
| bxSlider | bundled | abandoned ~2019 | — | 24,191 | Beaver Builder |
| Magnific Popup | bundled | abandoned 2016 | — | 21,145 | Beaver Builder |
| jquery.fitvids | **1.2** | 2013, abandoned | CSS `aspect-ratio` | 1,782 | Beaver Builder |
| jQuery | 3.7.1 | Aug 2023 | 3.7.1 | 87,553 | WP core — current |
| jQuery Migrate | 3.4.1 | shim | — | 13,577 | WP core — see B2 |

Swiper 8→12 and fancyBox 3→5 each cross multiple majors with breaking API changes; Bootstrap 3→5 is a theme rewrite. **There is no update path to current libraries that does not replace the plugin or the theme.** This generalises the note in `audit/04-seo-content-findings.md` that Swiper "is a JavaScript library bundled inside a Beaver Builder addon, not an independently updatable WordPress plugin" — the same is true of every row above except jQuery.

---

## 3. Plugin Inventory

`GET /wp-json/` returns the registered REST namespaces, and **a namespace registers only when the code that declares it is loaded**. That is a weaker statement than "the plugin is active": a must-use plugin registers routes with no activation state at all, and `/wp-content/mu-plugins/` returns the same 403-exists signature here as every other real directory. Read these as *loaded*, not as *active in wp-admin*.

| Namespace | Plugin | Corroboration |
|---|---|---|
| `tenweb_so/v1`, `tenwebio/v2` | **10Web Speed Optimizer** | `/wp-content/plugins/tenweb-speed-optimizer/readme.txt` → 403. See `audit/01` **C0**. |
| `ithemes-security/rpc`, `/v1` | Solid Security Pro | `/wp-content/plugins/ithemes-security-pro/` returns 200 with body `<!-- You don't belong here. -->` |
| `featured-image-from-url/v1`, `/v2` | Featured Image from URL (FIFU) | dir → 403. Explains the `chiro.inceptionimages.com` image host. |
| `userway/v1` | UserWay accessibility widget | `plugins/userway-accessibility-widget/` → 403 (the bare slug `userway/` returns 404) |
| `liquidweb/harbor/v1` | Liquid Web Harbor (hosting plugin) | see A1 |
| `inception-office-hours/v1` | custom agency plugin | 5 routes, including `/uploads/image` |
| `bsf-core/v1` | Brainstorm Force core (UABB licensing) | — |
| `nps-survey/v1` | NPS Survey (Brainstorm Force telemetry) | — |
| `fl-controls/v1` | Beaver Builder | — |
| `yoast/v1` | Yoast SEO | — |

**Directory probe method.** `/wp-content/plugins/<slug>/readme.txt` returns **403 (1,242 B)** when the file exists and a security rule denies it, and **404 (~93.6 KB — the rendered WordPress 404 page)** when it does not. Validated against a control: `definitely-not-installed-xyz` → 404. This independently confirms `audit/data/README.md`'s finding that no caching plugin is installed:

```
litespeed-cache  404      wp-rocket        404      akismet   404
autoptimize      404      wp-super-cache   404
w3-total-cache   404      (control slug)   404
bb-plugin        403      wordpress-seo    403      tenweb-speed-optimizer  403
```

**Presence claims from this method are stronger than absence claims** — a plugin that ships no `readme.txt` returns 404 while being present. `bb-ultimate-addon` does exactly this. The probe also cannot distinguish a plugin directory from an mu-plugins directory, which is why C0's inference is stated as "loaded".

**Two consequences for the other audits.** UserWay reaches the page through a WordPress plugin, not a hand-placed snippet, so the deferral fix in `audit/01` H3 must be applied wherever the plugin emits it. And ten active plugins on a brochure site is itself a maintenance surface worth periodic review, independent of performance.

---

## 4. Per-Asset Byte Accounting

Every first-party asset fetched twice — `Accept-Encoding: br,gzip` and `Accept-Encoding: identity`. All 28 per-file pairs below were independently re-measured and reproduced exactly. This table is the evidence behind `audit/01` **H1**, and it exists nowhere else in the repository.

### JavaScript — 618,211 B parsed, 160,061 B transferred

| File | Raw | Brotli | Ratio |
|---|---:|---:|---:|
| `swiper.min.js` | 143,660 | 38,121 | 3.8× |
| `2-layout.js` (BB, per-page) | **72,591** | **15,884** | 4.6× |
| `jquery.min.js` | 87,553 | 29,744 | 2.9× |
| `…-layout-bundle.js` (Themer) | 86,001 | 11,285 | 7.6× |
| `jquery.fancybox.min.js` | 68,253 | 20,999 | 3.3× |
| `bootstrap.min.js` | 39,681 | 10,519 | 3.8× |
| `jquery.bxslider.min.js` | 24,191 | 6,031 | 4.0× |
| `theme.min.js` | 23,369 | 5,466 | 4.3× |
| `jquery.magnificpopup.min.js` | 21,145 | 7,240 | 2.9× |
| `jquery-migrate.min.js` | 13,577 | 4,678 | 2.9× |
| `jquery.waypoints.min.js` | 8,833 | 2,540 | 3.5× |
| `jquery.imagesloaded.min.js` | 5,595 | 1,714 | 3.3× |
| `js_cookie.js` | 3,545 | 1,275 | 2.8× |
| `jquery.easing.min.js` | 2,539 | 797 | 3.2× |
| `jquery.fitvids.min.js` | 1,782 | 661 | 2.7× |
| `jquery.ba-throttle-debounce.min.js` | 731 | 408 | 1.8× |
| **Total (16 files)** | **618,211** | **160,061** | **3.9×** |

The homepage carries 19 `<script src>` tags; the three not listed are third-party (ReviewWave ×2 and its S3 config). `wp-emoji-release.min.js` (22,752 B) is **not** in this total — it is injected at runtime by an inline script, and is accounted for in `audit/01` H7 instead. No double-counting.

### CSS — 713,944 B parsed, 90,115 B transferred

| File | Raw | Brotli | Ratio |
|---|---:|---:|---:|
| `2-layout.css` (BB, per-page) | **164,124** | **17,986** | 9.1× |
| `…-layout-bundle.css` (Themer) | 183,112 | 15,073 | 12.1× |
| `bootstrap.min.css` | 121,412 | 18,239 | 6.7× |
| `all.min.css` (Font Awesome 5) | 59,305 | 12,370 | 4.8× |
| `animate.min.css` | 52,789 | 3,733 | 14.1× |
| `skin-*.css` (BB theme skin) | 50,813 | 7,261 | 7.0× |
| `ultimate-icons/style.css` | 21,667 | 3,061 | 7.1× |
| `jquery.fancybox.min.css` | 12,795 | 2,897 | 4.4× |
| `jquery.magnificpopup.min.css` | 5,788 | 1,463 | 4.0× |
| `swiper.min.css` | 16,494 | 4,259 | 3.9× |
| `jquery.bxslider.css` | 3,446 | 866 | 4.0× |
| `bb-theme-child/style.css` | 355 | 182 | 2.0× |
| **Total (12 files)** | **713,944** | **90,115** | **7.9×** |

### The document itself

| | Raw | Brotli |
|---|---:|---:|
| HTML | **216,956** | **33,290** |
| — of which inline `<style>` (6 blocks) | 29,946 | — |
| — of which inline `<script>` (13 blocks) | 16,026 | — |

**Compression ratios vary from 1.8× to 14.1×.** That is why transfer size does not predict CPU saving: `animate.min.css` costs 3,733 B on the wire and 52,789 B through the parser, while `jquery.min.js` costs 29,744 B on the wire and 87,553 B parsed. A remediation list ranked by transfer bytes puts these in the wrong order.

**Grand total: ~1,512,102 B parsed, ~278,042 B transferred — a ~5.4× gap.**

> **Three assets were re-measured on 2026-08-13 and all three shrank.** The HTML by 1,484 B raw, and Beaver Builder's two compiled bundles — regenerated 2026-08-11 by the 2.10.3.1 upgrade — by 15,165 B and 21,844 B raw. Their rows above carry the August figures; every other row is from 2026-07-30, so the totals are approximate. The BB theme skin file was also regenerated (`skin-6a6bcbee4c24e.css` → `skin-6a7c9951a3254.css`), which means the theme customiser settings were re-saved at some point between the two dates.

> **Measure in bytes, not characters.** Python `len(str)` undercounts this document — it contains CRLF
> pairs and multi-byte characters. The sweep TSVs independently record `size_raw=218440` for `/`.

---

## 5. Architecture Findings

Findings that are *not* page-speed findings and therefore do not live in `audit/01`.

**A1: Liquid Web Harbor is active on an AWS-hosted site**

- **Evidence:** `liquidweb/harbor/v1` in the REST namespace list. The origin is `44.223.213.21` — AWS EC2, LiteSpeed (`audit/01` §preamble), with no CDN and no Liquid Web infrastructure anywhere in the response headers (`audit/03` §6).
- **Impact:** A hosting-provider integration plugin loading on every request against infrastructure it does not manage. Almost certainly a migration leftover.
- **Fix:** Deactivate and delete — **after** confirming with the host that nothing depends on it. Hosting plugins occasionally carry backup or staging hooks.
- **Effort:** 5 min plus the confirmation.
- **Verification:** `liquidweb/harbor/v1` absent from `GET /wp-json/`.

**A2: REST user enumeration is open**

- **Evidence:** `GET /wp-json/wp/v2/users` returns **200** with `[{"id":1,"name":"inception","slug":"inception", …}]`. By contrast `/?author=1` → 301 to the homepage, `/xmlrpc.php` → 403, `/wp-login.php` → 302 to `/not_found`, `/readme.html` → 403. Solid Security is hardening those paths and not this one.
- **Impact:** Supplies a valid username for credential-stuffing against whatever the real login URL is. Low severity given the login URL is hidden, but it is a gap in an otherwise-configured hardening posture and it is free to close.
- **`xmlrpc.php` is blocked** — 403. The RSD `<link>` may still be emitted in `<head>`, but it points at a blocked target. Closes the open item in `audit/04`.
- **Fix:** Solid Security → disable REST API user enumeration, or filter `rest_endpoints` to require authentication on `/wp/v2/users`.
- **Verification:** `curl -s -o /dev/null -w '%{http_code}' <site>/wp-json/wp/v2/users` returns 401.
- Re-verified 2026-08-13, still open. Fix and verification in `SECURITY-FINDINGS.md` **S2**.

**A3: Security headers are absent**

- **Evidence:** `curl -D -` against `/` and `/knee-pain-lp/`. All absent on both:

  ```
  strict-transport-security    ABSENT
  content-security-policy      ABSENT
  x-content-type-options       ABSENT
  x-frame-options              ABSENT
  referrer-policy              ABSENT
  permissions-policy           ABSENT
  cross-origin-opener-policy   ABSENT
  cache-control                ABSENT     (independently confirms audit/03 §1)
  ```

- **Severity:** low-to-moderate for a marketing site with no PHI transmission. Re-verified 2026-08-13 and expanded in `SECURITY-FINDINGS.md` **S3**.
- **Fix:** Add via LiteSpeed config or the child theme. `x-content-type-options: nosniff` and `referrer-policy: strict-origin-when-cross-origin` are zero-risk. HSTS needs a rollback plan. **CSP will be laborious** given 13 inline script blocks and 6 inline style blocks (B9) — it would require nonces or hashes on all of them.
- **Effort:** 30 min for the two zero-risk headers; CSP is a project.

**A4: The rendered DOM is 1.8× the source DOM**

- **Evidence:** Lighthouse counts **3,181** elements on 2026-08-13 and 3,197 on 07-30 [LH]. The delivered HTML contains **1,774** start tags (1,792 in July) (`html.parser`; regex cross-check 1,800). About **1,400 elements are created by JavaScript at runtime** — the hero `<video>` (`audit/01` C1), the ReviewWave chat widget, the UserWay widget, and Beaver Builder's own layout construction.

  Composition of the source elements, 2026-07-30: 760 `<div>`, **218 `<meta>`**, 130 `<span>`, 118 `<p>`, 102 `<a>`, 76 `<li>`, 42 `<svg>`, 39 `<iframe>` (of which 35 are `data-src`-deferred), 32 `<script>`.

  **198 of the 218 `<meta>` tags are microdata `itemprop` attributes** — 6 per video (`name`, `description`, `uploadDate`, `thumbnailUrl`, `contentUrl`, `embedUrl`) across 33 videos, emitted by PowerPack's video module.
- **Impact:** Explains why `audit/01` M2's DOM finding cannot be assessed from the HTML alone, and why `2-layout.js` cost 10,883 ms [LH] — a large share of that bundle is DOM construction, not behaviour.
- **Tradeoff, not a defect:** the 198 microdata tags are valid `VideoObject` structured data that Google reads. They are ~11% of source elements. Do not remove them as a performance measure without an SEO decision — and note that the YouTube facade in `audit/01` H8 may remove them as a side effect. Flag that before it happens.

---

## 6. Code Quality Indicators

| # | Indicator | Measured | Note |
|---|---|---|---|
| B1 | Zero `defer`, zero `async` | 0 of 19 scripts on `/`; 0 of 12 on `/knee-pain-lp/` | site-wide, not homepage-specific. `audit/01` H2. Five scripts sit in `<head>`: jQuery, jQuery Migrate, and all three ReviewWave scripts. |
| B2 | jQuery Migrate in the render path | 13,577 B raw, synchronous, `<head>` | WordPress ships it, but its presence means deprecated jQuery APIs are still being called. It is the reason `audit/01` H2 recommends *against* deferring jQuery. `audit/01` L6. |
| B3 | `?ver=` falls back to the WP core version | `bb-ultimate-addon/…/js_cookie.js?ver=7.0.4`; `bb-theme-child/style.css?ver=7.0.4` | Both enqueued with no version argument. With `max-age=2592000` on static assets, **a child-theme CSS edit stays stale for a returning visitor for 30 days.** Operational trap: the change ships and appears not to work. `audit/01` M6. |
| B4 | 138 occurrences of `!important` | in the delivered HTML alone | specificity conflicts between BB, PowerPack, the theme skin, and 7,759 B of `wp-custom-css` |
| B5 | 47 inline `style="` attributes | — | uncacheable; they defeat the CSS cache the site otherwise has correctly configured |
| B6 | 4,624 B of hand-written inline JS | `normalizeText()` / `getDuplicatePrefixLength()` | Walks the DOM on every page load to strip duplicated heading prefixes from grid titles. A content problem patched at runtime. Fixing the content removes the script. |
| B7 | Animate.css 3.5.1 loaded in full | 52,789 B raw, 3,733 B wire — a 14.1× ratio | The worst transfer-vs-parse gap on the site. Relates to `audit/01` L5, "5 non-composited animations". |
| B8 | Font Awesome loaded as full `all.min.css` | 59,305 B raw, plus 2 preloaded woff2 families | for an icon count in the low dozens; subsetting is the standard remedy. The preloads compete with the LCP element — `audit/01` H4. |
| B9 | 29,946 B inline `<style>` + 16,026 B inline `<script>` | 21.0% of the document | re-sent on every page view, and HTML carries no `Cache-Control` (`audit/03` §1). Also the main obstacle to a CSP (A3). |
| B10 | Static assets have no `ETag`; HTML has no `Cache-Control` | 6 static assets sampled; 88 HTML requests across two sweeps | confirms `audit/01` L1 and M1 |

**Architecture is consistent across pages.** `/knee-pain-lp/` shows the same shape as `/`: 12 scripts with 0 `defer`/`async`, 11 stylesheets, 6 inline `<style>` blocks including `global-styles-inline-css`, emoji scripts present, 9 of 12 images eager. B1, B3, B4, B9, and B10 are site-wide.

---

## 7. Sources & Limitations

- **Live source inspection** — `GET /` and `/knee-pain-lp/`, 2026-07-30, `--compressed`. Every count used as evidence taken with two independent patterns; both recorded.
- **Asset sizes** — each file fetched twice, `Accept-Encoding: br,gzip` and `identity`, `content-length` from `%{size_download}`.
- **Library versions** — read from each file's own banner comment.
- **Plugin inventory** — `GET /wp-json/` namespace list, corroborated by a `readme.txt` 403/404 directory probe validated against a known-absent control slug.
- **Version currency** — `api.wordpress.org/core/version-check/1.7/` and `api.wordpress.org/plugins/info/1.2/`.

### Known limitations

1. Figures marked **[LH]** come from the 2026-07-30 run and inherit the variance documented in `audit/01` §9. A three-run re-measurement of 2026-08-13 is in `audit/data/lighthouse-mobile-2026-08-13.md`; its CPU figures are not comparable to July's, which were taken on a different machine.
2. **PowerPack and Ultimate Addons currency is unverified.** Both are premium with no public version API. PowerPack 2.40.1.6 is what the site reports; whether it is current was not established. UABB's installed version could not be determined at all — see B3.
3. **10Web's configuration state is inferred, not observed.** The evidence establishes that the plugin's code is **loaded** — not that it is active in the wp-admin sense; see §3 — and that the frontend shows no optimisation. It does not establish which explanation applies; that requires wp-admin access. See `audit/01` C0.
4. **Two pages sampled, not 44.** Findings marked site-wide (B1, B3, B4, B9, B10) were confirmed on both `/` and `/knee-pain-lp/`. The rest are homepage measurements. Header facts come from all 44 URLs across two sweeps — `audit/data/README.md`.
6. **`readme.txt` probing infers presence from a 403.** The control test validates the discriminator, but a plugin shipping no `readme.txt` returns 404 while being present. Absence claims from this method are weaker than presence claims.
