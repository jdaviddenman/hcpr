# Page Speed Performance Audit: highcountrypainrelief.com

**Date:** 2026-07-28 | **Platform:** WordPress 7.0.2 + Beaver Builder 2.10.3 + Beaver Themer 1.5.3.2 + BB Theme 1.7.19.2
**Server:** LiteSpeed (no CDN, no page cache) | **Scope:** Homepage + all 44 sitemap pages

**POCs:** James David Enman (jdaviddenman@gmail.com) | Amy Denman (amydenman@gmail.com)

---

## 1. Executive Summary

High Country Pain Relief's on-page SEO is functional — Yoast v28.1 provides baseline schema, meta tags are present on most pages, and local keyword targeting is directionally correct. **The critical failure is page speed.** The site scores 27/100 on mobile and 47/100 on desktop Lighthouse — both in the "poor" range (0-49). This is not a content problem. It is a server configuration, caching, and resource-loading problem.

The 20-point mobile-desktop delta confirms the root causes are **architectural, not situational** — even on unthrottled desktop CPU, the site cannot break 50/100.

**Three critical issues:**

1. **Performance collapse (27/100 mobile, 47/100 desktop)** — No page caching, no text compression, no async/defer, no CDN, no font-display. Direct revenue impact: 53% of mobile users abandon at 3s+ load.
2. **Inconsistent page-level SEO** — `/neuropathy-center-lp/` missing all metadata (no meta description, no OG tags, no JSON-LD, no canonical). `/shockwave-therapy/` missing og:image. `/us/` (Meet the Doctor) returns 404. Yoast SEO v28.1 is installed but pages aren't configured.
3. **Active plugin CVEs** — Swiper 8.4.7 has CVE-2026-27212 (CVSS 9.5, Prototype Pollution). ReviewWave has CVE-2025-39442 (CVSS 7.1, unpatched CSRF→Stored XSS). Fancybox 3.5.7 has CVE-2024-5020 (Stored XSS). No security headers on any response.

**Estimated impact if fixed:** Config-only fixes (caching, compression, deferral) lift mobile score from 27→45-55 and desktop from 47→65-75 in ~4 hours. Full remediation (video, CDN, content, schema) targets 70+ mobile / 85+ desktop, correlating with top-3 local pack ranking for "chronic pain Boone NC" and 20-40% bounce rate reduction.

---

## 2. PageSpeed Cross-Report Synthesis

### Score Drivers

| Metric | Mobile (27/100) | Desktop (47/100) | Delta Cause |
|--------|-----------------|-------------------|-------------|
| FCP | 3.0s | Lower (unthrottled) | CPU throttling 4x |
| LCP | 15.9s | Lower (unthrottled) | 14.9MB video + throttled network |
| TBT | 18,520ms | Significantly lower | JS execution taxed 4x harder |
| CLS | 0.184 | 0.184 | Same DOM, same layout shifts |
| SI | 17.2s | Lower (unthrottled) | Network throttling |
| TTFB | 2,540ms | 2,540ms | Same — uncached PHP |

### Common Root Causes (Both Scores)

6 of 10 root causes are server/config issues — not theme, not plugins, not content:

1. **No page caching** → TTFB 2,540ms (both scores)
2. **No text compression** → 39 KB savings identified (both scores)
3. **19 synchronous scripts, 13 synchronous CSS** → 1,470ms render-blocking (both scores)
4. **14.9 MB background video** → LCP 15.9s (both scores)
5. **UserWay (3,242ms) + ReviewWave + YouTube** → third-party blocking (both scores)
6. **3,178 DOM elements** → excessive layout cost (both scores)

### Unified Critical Path

```
1. LiteSpeed Cache plugin (page cache + CSS/JS minify/combine + Gzip)
   → Fixes root causes 1, 2, 3 simultaneously
   → Mobile: 27→40-45 | Desktop: 47→58-63
   → Effort: 2-3 hrs

2. Background video → static WebP poster + lazy-loaded video
   → Fixes LCP (80% of LCP is load delay on this element)
   → Mobile: 40-45→48-53 | Desktop: 58-63→65-70
   → Effort: 2 hrs

3. Defer third-party scripts (UserWay, ReviewWave, YouTube thumbnails)
   → Mobile: 48-53→52-57 | Desktop: 65-70→70-74
   → Effort: 1 hr

4. CDN + font optimization + remaining hygiene
   → Mobile: 52-57→60-68 | Desktop: 70-74→78-85
   → Effort: 2 hrs
```

**Total: ~8 hours config work for a 33-41 point mobile gain and 31-38 point desktop gain.**

---

## 3. Gap Analysis

**Current state vs. competitive baseline for local chiropractic SEO in Boone NC:**

| Dimension | Current State | Competitive Baseline | Gap Severity |
|-----------|--------------|---------------------|--------------|
| Page speed | 27/100 mobile, 2.4s TTFB, no cache, no CDN, no compression | 70+ mobile, sub-1s TTFB, CDN, full-page cache | **CRITICAL** |
| E-E-A-T signals | About page 404, no practitioner schema, no credentials markup | Physician/MedicalOrganization schema, active bio page | **CRITICAL** |
| Content depth | 42 pages, 0 blog posts, service pages 420-870 words | Active blog, 1,200-2,000 word service pages, FAQ content | **HIGH** |
| Caching infrastructure | No CDN, no page cache, no object cache, 30-day static only | CDN active, HTML cached, Redis object cache | **HIGH** |
| Schema coverage | Spotty (3/6 key pages), wrong @type, broken openingHours | All pages with correct schema, FAQ/Review rich results | **MEDIUM** |
| Technical hygiene | Zero security headers, 4 active CVEs, xmlrpc.php exposed | HSTS + X-Content-Type-Options minimum, plugins current | **MEDIUM** |
| Local SEO | NAP present but inconsistent telephone, no GBP integration visible | GBP connected, local citation consistency, review schema | **MEDIUM** |
| Page-level SEO | 3/6 key pages missing meta description or OG image | All pages configured with unique meta + social tags | **MEDIUM** |
| Keyword targeting | Homepage effective, contact page omits location, cannibalization risk | Clean one-page-per-cluster mapping, consistent location modifiers | **MEDIUM** |
| Font performance | 5 Google Font families, no font-display, dns-prefetch only | 2-3 fonts, font-display:swap, preconnect | **LOW** |

---

## 4. Findings by Criticality

### CRITICAL — Immediate Revenue Impact

| # | Issue | Evidence | Fix | Effort | Expected Gain | Verification |
|---|---|---|---|---|---|---|
| C1 | **Performance 27/100 mobile** — LCP 15.9s, TBT 18,520ms | Lighthouse 12.6.0; 14.9MB hiking.mp4; 19 sync scripts; zero async/defer | Install LiteSpeed Cache plugin; enable page cache + CSS/JS minify/combine + Gzip | 2-3 hrs | Mobile 27→40-45; Desktop 47→58-63; ~30% bounce reduction | Lighthouse mobile ≥40 |
| C2 | **No page caching** — TTFB 2,540ms, no Cache-Control on HTML | `curl -sI` shows zero caching headers; no `x-litespeed-cache` despite LiteSpeed server | LiteSpeed Cache plugin: page cache (2hr TTL), ESI for dynamic elements | 1-2 hrs | TTFB 2,540ms→<600ms | `curl -sI` shows `x-litespeed-cache: hit` |
| C3 | **No text compression** — 216 KB HTML, 55 KB JS uncompressed | `Content-Encoding` absent on all responses; ReviewWave S3 script 55 KB raw | Enable Gzip/Brotli in LiteSpeed; set compression on S3 assets | 1 hr | 75 KB+ HTML savings; 36.6 KB S3 JS | `Content-Encoding: gzip` present |
| C4 | **14.9 MB background video blocks LCP** | 80% of LCP is load delay on `hiking.mp4`; autoplay hero video | Replace with static WebP poster + lazy-loaded video; compress to <2MB | 2 hrs | LCP 15.9s→~4s; CLS 0.184→~0.05 | Lighthouse LCP element = text or small image |
| C5 | **"Meet the Doctor" page 404** | `/us/` returns 404; main nav link dead; no practitioner schema anywhere | Find correct slug or rebuild page; add Physician + MedicalOrganization schema | 1-3 hrs | E-E-A-T signal restored; branded search ranking | `/us/` returns 200 or 301 |

### HIGH — Significant Ranking Potential

| # | Issue | Evidence | Fix | Effort | Expected Gain | Verification |
|---|---|---|---|---|---|---|
| H1 | **Render-blocking CSS/JS chain** | 1,470ms estimated savings; 19 sync scripts, 13 sync CSS | LiteSpeed Cache: CSS/JS combine + minify + defer; async GTM; defer ReviewWave/UserWay | 1-2 hrs | 1,470ms render-blocking eliminated; FCP 3.0s→~1.5s | Lighthouse: 0ms render-blocking savings |
| H2 | **Neuropathy page: zero SEO metadata** | No meta description, no OG tags, no Twitter cards, no JSON-LD, no canonical; title≠H1 | Configure Yoast: meta description, focus keyphrase, social image, canonical | 30 min | SERP CTR from generic→controlled snippet; rich-result eligibility | View-source: all meta/OG/schema present |
| H3 | **UserWay: 3,242ms main-thread blocking** | widget_app_base_178...js = 3,208ms alone; 91 KiB transfer | Defer UserWay script loading; evaluate native accessibility replacement | 30 min (defer) | TBT 18,520ms→~15,000ms (defer only) | Lighthouse third-party: UserWay <200ms |
| H4 | **Yoast page-level gaps** | Shockwave missing og:image; Contact og:type="article" (should be "website"); Knee Pain thin | Configure all pages in Yoast; set social defaults; fix Contact page type | 2-3 hrs | Controlled SERP snippets on all pages; valid social sharing | View-source: all pages have complete meta |
| H5 | **CLS 0.184 — video + fonts + missing dimensions** | Video lacks explicit size; 3 web fonts load without font-display; images missing width/height | Add width/height to video container; `&display=swap` on Google Fonts; explicit image dimensions | 1 hr | CLS 0.184→<0.1; passes Core Web Vitals | Lighthouse CLS = 0 |

### MEDIUM — Optimization

| # | Issue | Fix | Effort |
|---|---|---|---|
| M1 | **3,178 DOM elements** — desktop + mobile nav both rendered | Consolidate nav; lazy-load YouTube thumbnails | 3-4 hrs |
| M2 | **35+ YouTube thumbnails not deferred** — 758 KiB | Lazy-load via JS or `loading="lazy"` with placeholders | 1-2 hrs |
| M3 | **No font-display** — FOIT on 5 font families | `&display=swap` on Google Fonts URL; local font-display override | 15 min |
| M4 | **Schema issues** — broken openingHours, wrong telephone format, empty fields, mixed protocol | Fix to ISO 8601; `+1` prefix; remove empty fields; use `https://schema.org` | 1 hr |
| M5 | **Content depth below competitive range** — 420-870 words | Expand to 1,200+ words with H2/H3 sections, symptoms, FAQs | 6-10 hrs |
| M6 | **No CDN** — all assets from origin | Add Cloudflare free tier or QUIC.cloud | 1-2 hrs |
| M7 | **dns-prefetch instead of preconnect** for fonts.googleapis.com | Change to `<link rel="preconnect" ... crossorigin>` | 5 min |
| M8 | **og:image 250×250** — undersized for social sharing | Replace with 1200×630 image | 15 min |

### LOW — Hygiene

| # | Issue | Fix | Effort |
|---|---|---|---|
| L1 | H3→H5 heading jump (no H4) | Retag H5 as H4 | 5 min |
| L2 | Alt text is filename-based on 6 inceptionimages.com images | Rewrite alt text descriptively | 15 min |
| L3 | `.jpg.webp` double extension on SoftWave overlay image | Rename to `.webp` | 5 min |
| L4 | `shortlink` `<link>` present — duplicate content risk | Remove via Yoast settings | 2 min |
| L5 | xmlrpc.php exposed via RSD link | Remove link; disable XML-RPC | 5 min |
| L6 | Sporadic Twitter card data incomplete (OG fallback works — not a defect, but explicit tags better) | Configure Yoast Social → Twitter defaults | 15 min |
| L7 | BreadcrumbList missing `item` on last position | Add URL to last breadcrumb | 15 min |
| L8 | 5 Google Font families with unused weights | Reduce to 2 families; self-host via LSCache | 1 hr |
| L9 | No `google-site-verification` meta | Add GSC verification tag | 2 min |

---

## 5. Technical Stack Assessment

### Plugin Inventory & CVEs

| Plugin | Version | CVEs | Risk |
|---|---|---|---|
| **Beaver Builder** | 2.10.3 | CVE-2025-8897 (6.1), CVE-2025-12782 (4.3), CVE-2024-11832 | Verify patched in 2.10.3 |
| **PowerPack for BB** | 2.40.1.6 | CVE-2024-12239 (6.1, ≤1.3.0.5), CVE-2024-37409 (5.9) | Lite CVEs; full version likely clean |
| **Ultimate Addons for BB** | 2.10.3 | CVE-2024-43151 (6.4, ≤1.5.9), CVE-2019-25763 (9.8) | Lite CVEs; full version likely clean |
| **Beaver Themer** | 1.5.3.2 | CVE-2023-6694 (5.4, ≤1.4.9), CVE-2023-6695 (6.5) | Above affected range; likely patched |
| **Yoast SEO** | 28.1 | No current CVEs | Clean |
| **Swiper JS** | 8.4.7 | **CVE-2026-27212 (CVSS 9.5)** | **Critical — update to 12.1.2+** |
| **Fancybox** | 3.5.7 (JS) | CVE-2024-5020 (5.8, ≤3.5.7) | In affected range |
| **jQuery** | 3.7.1 | All historical CVEs patched | Clean |
| **ReviewWave** | External CDN | **CVE-2025-39442 (CVSS 7.1, unpatched)** | No patch available |
| **UserWay** | External CDN | No CVEs | Compliance/performance concern |
| **WordPress** | 7.0.2 | Verify against latest security advisories | Very new — monitor |

### Caching Maturity

| Layer | Current | Target |
|---|---|---|
| Page cache | None | LiteSpeed Cache (native, free) |
| Object cache | None | Redis via LSCache |
| Browser cache (static) | 30 days (good) | 30 days + ETag |
| Browser cache (HTML) | None | `max-age=86400` for returning visitors |
| CDN | None | Cloudflare free or QUIC.cloud |
| CSS/JS optimization | No minify, no combine, no defer | LSCache: minify + combine + defer |
| Image optimization | WebP format used | Add responsive srcset + AVIF fallback |

### Security Headers — All Missing

`Strict-Transport-Security`, `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` — none present. Severity: MEDIUM (marketing site, no PHI transmitted; CSP impractical on Beaver Builder).

---

## 6. Prioritized Work Roadmap

### Week 1 — Stop the Bleeding (Performance + Security)

| Task | Time | Verification |
|---|---|---|
| Install + configure LiteSpeed Cache plugin | 2 hrs | TTFB <600ms, `x-litespeed-cache: hit` |
| Enable Gzip/Brotli compression | 30 min | `Content-Encoding` present |
| Add async/defer to non-critical scripts | 1 hr | 0ms render-blocking savings |
| Compress/replace background video | 2 hrs | LCP <4s |
| Add `font-display: swap` | 15 min | Font audit passes |
| Add security headers (.htaccess) | 15 min | All 6 headers present |
| Update Swiper 8.4.7→12.1.2+ | 1 hr | CVE-2026-27212 resolved |
| Fix "Meet the Doctor" 404 | 1-3 hrs | `/us/` returns 200 or 301 |

**Success criteria:** Mobile ≥50. TTFB <800ms. Zero critical CVEs.

### Week 2-3 — SEO Foundation + Content

| Task | Time | Verification |
|---|---|---|
| Configure Yoast on all pages | 3 hrs | Meta desc + OG image on every page |
| Fix schema errors | 1 hr | Rich Results Test: 0 errors |
| Fix `/about/`→`/us/` redirect | 15 min | 301 redirect in place |
| Expand service pages to 1,200+ words | 6 hrs | Word count verified per page |
| Fix alt text on inceptionimages.com images | 15 min | WAVE tool: 0 warnings |
| Submit sitemap to GSC + Bing | 15 min | Sitemap submitted, no errors |
| Add FAQ schema to top 5 pages | 2 hrs | Rich Results Test: FAQ eligible |

**Success criteria:** All pages have complete metadata. Schema validates clean. Service pages ≥1,200 words.

### Month 2 — CDN + Optimization

| Task | Time | Verification |
|---|---|---|
| Add CDN (Cloudflare or QUIC.cloud) | 2 hrs | CDN headers present; TTFB <400ms |
| Lazy-load YouTube thumbnails | 2 hrs | Lighthouse "Defer offscreen images" passes |
| Reduce DOM elements | 3 hrs | DOM <1,500 |
| Reduce Google Fonts to 2 families | 1 hr | ≤2 font families |
| Disable XML-RPC, remove shortlink/RSD | 15 min | No xmlrpc.php/shortlink references |
| Defer ReviewWave script | 30 min | Not in critical path |

**Success criteria:** Mobile ≥70. Desktop ≥85. CDN active.

### Ongoing

| Task | Cadence | Verification |
|---|---|---|
| GSC monitoring | Weekly | Impressions/clicks trending up |
| Core Web Vitals (CrUX) | Monthly | LCP <2.5s, INP <200ms, CLS <0.1 |
| Plugin updates | Weekly | All within 1 version of latest |
| New condition + location pages | Monthly | 1 page/month, 1,500+ words |
| Review schema integration | Once | AggregateRating present |
| Replace UserWay with native a11y | When budget | Accessibility ≥95 without UserWay |

---

## 7. Quick Wins (Under 1 Hour Each)

| # | Fix | Time | Impact |
|---|---|---|---|
| 1 | Add `&display=swap` to Google Fonts URL | 2 min | CLS reduction, FOIT eliminated |
| 2 | Change `dns-prefetch`→`preconnect` for fonts.googleapis.com | 2 min | ~100ms saved |
| 3 | Add security headers to .htaccess | 10 min | Security baseline |
| 4 | Remove shortlink + xmlrpc.php RSD link | 5 min | Attack surface reduction |
| 5 | Fix `.jpg.webp`→`.webp` rename | 5 min | MIME correctness |
| 6 | Set explicit width/height on hero video container | 10 min | CLS 0.184→~0.05 |
| 7 | Add `loading="lazy"` to 6 images missing it | 10 min | 200+ KiB deferred |
| 8 | Update Swiper 8.4.7→12.1.2+ | 30 min | CVSS 9.5 resolved |
| 9 | Configure Yoast for neuropathy page | 10 min | SERP snippet control |
| 10 | Enable Gzip via LiteSpeed | 5 min | 70%+ HTML size reduction |

**Total: ~90 minutes. Estimated Lighthouse gain: 27→40-45 mobile, 47→55-60 desktop.**

---

## 8. CVE Reference Links

- [CVE-2026-27212 — Swiper 8.4.7 Prototype Pollution (CVSS 9.5)](https://security.snyk.io/package/npm/swiper/8.4.7)
- [CVE-2025-8897 — Beaver Builder Reflected XSS](https://research.cleantalk.org/reports/search/beaver-builder-lite-version/CVE-2025-11726)
- [CVE-2025-12782 — Beaver Builder Auth Bypass](https://www.wordfence.com/threat-intel/vulnerabilities/wordpress-plugins/beaver-builder-lite-version/beaver-builder-wordpress-page-builder-294-missing-authorization-to-authenticated-contributor-builder-status-tampering)
- [CVE-2024-12239 — PowerPack Reflected XSS](https://www.cve.org/CVERecord?id=CVE-2024-12239)
- [CVE-2024-43151 — Ultimate Addons Stored XSS](https://www.wordfence.com/threat-intel/vulnerabilities/wordpress-plugins/ultimate-addons-for-beaver-builder-lite/ultimate-addons-for-beaver-builder-lite-159-authenticated-contributor-stored-cross-site-scripting)
- [CVE-2024-5020 — Fancybox 3.5.x Stored XSS](https://vuldb.com/?id.286834)
- [CVE-2025-39442 — ReviewWave CSRF→Stored XSS (CVSS 7.1, unpatched)](https://patchstack.com/database/wordpress/plugin/review-wave-google-places-reviews/vulnerability/wordpress-review-wave-google-places-reviews-plugin-1-4-7-cross-site-request-forgery-csrf-vulnerability)
- [CVE-2023-6694/6695 — Beaver Themer XSS + Info Exposure](https://attackerkb.com/topics/8bSsPfgqCC/cve-2023-6694)
