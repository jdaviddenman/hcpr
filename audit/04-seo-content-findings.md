# On-Page SEO & Content Findings: highcountrypainrelief.com

**Date:** 2026-07-28 | **Re-verified against the live site:** 2026-07-30

**Scope note:** these findings were identified during the site crawl and are **outside page speed scope**. Page speed lives in `audit/01-page-speed-performance-audit.md`.

> **Re-verification, 2026-07-30.** Every finding below was re-checked against live page source. Two were substantially wrong and have been rewritten: the "Meet the Doctor 404" (the page returns 200 with full content) and the "neuropathy page has zero metadata" claim (it has a meta description, OG tags, and a canonical). Corrections are marked inline.

---

## Summary

Yoast SEO v28.1 is installed and configured on most pages. Homepage metadata is complete. The real gaps are narrower than first reported: one page missing `og:image`, one page missing JSON-LD, a `LocalBusiness` schema block with several format errors, an undersized social image, and no practitioner schema anywhere on a healthcare site.

---

## Findings

### HIGH

**H1: No practitioner or medical-organization schema anywhere**

- **Evidence:** `/us/` returns **HTTP 200**, titled "About Us - High Country Pain Relief", with substantial body content and an `<h1>`. It is present in `page-sitemap.xml`. Searching that page for `Physician`, `MedicalBusiness`, or `MedicalClinic` returns **zero matches**. Site-wide the only business schema is `"@type": "LocalBusiness"`.
- **Correction:** the original finding stated `/us/` returns 404 and called it a CRITICAL broken-nav issue. That is false — the page is live and populated. What survives is the schema gap, which is a real E-E-A-T weakness for a healthcare provider but is a markup task, not a broken page.
- **Fix:** Add `Physician` schema to `/us/` with credentials, NPI, photo, and clinic affiliation. Change the site-wide `LocalBusiness` block to `MedicalBusiness` or `MedicalClinic` (see M1).
- **Verification:** Google Rich Results Test shows valid `Physician` markup on `/us/`.

**H2: `/shockwave-therapy/` — no `og:image`**

- **Evidence:** Confirmed 2026-07-30. `og:image` count on the page: **0**. `<meta name="twitter:card" content="summary_large_image">` is present, so the page declares a large-image card and supplies no image. Social shares render blank.
- **Fix:** Set the social image in Yoast (1200×630).
- **Verification:** `og:image` present with a valid absolute URL.

**H3: `/neuropathy-center-lp/` — no JSON-LD**

- **Evidence:** Confirmed 2026-07-30: `application/ld+json` count is **0** on this page.
- **Correction:** the original finding claimed this page had "no meta description, no OG tags, no Twitter cards, no JSON-LD, no canonical." Live source shows `name="description"` ×1, `property="og:*"` ×10, and `rel="canonical"` ×1 — all present. **Only JSON-LD is genuinely missing.** The title is "Neuropathy Relief in Boone NC - High Country Pain Relief"; whether it matches the H1 was not re-verified because the heading spans multiple source lines and a single-line pattern cannot read it reliably.
- **Fix:** Determine why Yoast is not emitting schema on this template — landing-page templates sometimes suppress it. Re-check the title/H1 alignment by rendering the page rather than by grep.
- **Verification:** View-source shows a JSON-LD block.

### MEDIUM

**M1: `LocalBusiness` schema format errors**

- **Evidence:** Confirmed 2026-07-30 against homepage source:

  | Field | Current | Should be |
  |---|---|---|
  | `openingHours` | `We 0800-1200 We 1400-1800 Fr 0800-1200 Fr 1400-1800 Sa 0800-1200` | `We 08:00-12:00` etc. — ISO 8601 times |
  | `@type` | `LocalBusiness` | `MedicalBusiness` or `MedicalClinic` |
  | `@context` | **both** `http://schema.org` and `https://schema.org` appear in different blocks | `https://schema.org` throughout |
  | `email` | `""` | populate or remove |
  | `currenciesAccepted` | `""` | populate or remove |
  | `telephone` | **both** `+18283861888` and `18283861888` appear | `+18283861888` throughout |

  The `telephone` field is partially corrected already — one block has the `+` prefix and another does not. The original audit reported only the unprefixed form.
- **Fix:** Edit the JSON-LD block. It is hand-authored, not Yoast-generated.
- **Verification:** Rich Results Test — 0 errors.

**M2: Homepage `og:image` is 250×250**

- **Evidence:** Confirmed 2026-07-30. `og:image:width` = 250, `og:image:height` = 250 — a square team thumbnail. Facebook and LinkedIn recommend 1200×630.
- **Fix:** Create a 1200×630 image; set it as the Yoast default social image.
- **Verification:** `og:image:width` = 1200, `og:image:height` = 630.

**M3: `og:type` is `article` on the contact page**

- **Evidence:** Confirmed 2026-07-30. `<meta property="og:type" content="article">` on `/contact-us/`. A contact page is not an article.
- **Fix:** Override to `website` in Yoast for this page.
- **Verification:** `og:type` = `website`.
- **Note on the thin-content claim:** the original audit reported "~222 words" of body text here. That figure could not be reproduced and is **not carried forward** — tag-stripping word counts are unreliable on this site because inline scripts inflate them. If content depth matters, measure it with a rendering tool, not a regex.

### LOW

**L1: No Google Search Console verification tag**

- **Evidence:** Confirmed 2026-07-30 with two patterns. `google-site-verification` count: **0**. `<meta name="msvalidate.01" …>` (Bing) is present.
- **Fix:** Add the GSC verification meta tag, or verify by DNS.

**L2: `shortlink` link tag present**

- **Evidence:** Confirmed 2026-07-30: `<link rel='shortlink' href='https://www.highcountrypainrelief.com/' />`. The original audit reported the href as `?p=2`; the live value is the canonical homepage URL, which makes the duplicate-content risk lower than described — it is a redundant tag rather than a competing URL.
- **Fix:** Remove via Yoast if you want the cleaner `<head>`. Low value.

**L3: Alt text is filename-based on CDN images**

- **Evidence:** Six images from `chiro.inceptionimages.com` carry alt text identical to the filename, e.g. `Chiropractic-Senior-Couple-Stretching-Out-640x640-HP-Moto.webp`. Lighthouse independently flags `Chiropractic-Boone-NC-ASMST-Logo.webp` as an image whose alt is its filename.
- **Fix:** Rewrite descriptively. This is an accessibility fix as much as an SEO one.
- **Verification:** WAVE reports no alt-text warnings.

**L4: Heading level skip on the homepage**

- **Evidence:** "Conditions We Help" is an `<h5>` with no `<h4>` on the page.
- **Fix:** Retag as `<h4>`.

**L5: Phone number formatting is inconsistent**

- **Evidence:** Contact page meta description uses `(828) 386-1888`; JSON-LD uses `18283861888` in one block and `+18283861888` in another.
- **Fix:** Standardise on `+1 (828) 386-1888` for display and `+18283861888` in structured data.
- **Verification:** One display format and one structured-data format site-wide.

**L6: BreadcrumbList omits `item` on the final position**

- **Evidence:** Yoast-generated `BreadcrumbList` JSON-LD has no `item` URL on the last entry.
- **Correction:** the original audit graded this MEDIUM and stated it "fails strict Schema.org validation." Google's documented guidance is that the final breadcrumb does not require a URL, and `ListItem` is satisfied by `name` alone. This is **not a defect** and is retained only as a completeness note. No action needed.

---

## Security Findings — Unverified

These were collected during the crawl and are recorded for follow-up. **None have been independently verified**, and at least one citation does not match its CVE ID. Treat this as a research starting point, not a finding list.

| Item | Status |
|---|---|
| No HTTP security headers | Not re-checked. `Strict-Transport-Security`, `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`, `Permissions-Policy` were reported absent. Severity for a marketing site with no PHI transmission is low-to-moderate. |
| `xmlrpc.php` exposed via RSD link | Not re-checked. |
| CVE-2026-27212 — Swiper 8.4.7, claimed CVSS 9.5 | **Citation does not resolve to a CVE record** — the supplied link is a generic Snyk package page. Swiper 8.4.7 is confirmed loaded on the homepage (`swiper.min.js?ver=8.4.7`, 1,497 ms CPU). Verify the CVE against NVD before acting. |
| CVE-2025-8897 — Beaver Builder, claimed Reflected XSS | **Citation mismatch:** the supplied URL ends in `CVE-2025-11726`, a different identifier. One of the two is wrong. |
| CVE-2025-39442 — ReviewWave CSRF→Stored XSS, claimed unpatched | Not verified. If genuinely unpatched, "zero CVEs" is unreachable while ReviewWave remains installed. |
| CVE-2024-5020 — Fancybox 3.5.x Stored XSS | Not verified. |
| Plugin versions | The original inventory listed Ultimate Addons for Beaver Builder at version 2.10.3 — identical to Beaver Builder's version, while its own CVE rows reference a `≤1.5.9` affected range. The version is probably a copy-paste error. Re-inventory before assessing. |

**On remediation effort:** the original audit listed "Update Swiper 8.4.7 → 12.1.2+ | 30 min" as a quick win. Swiper is a JavaScript library bundled inside a Beaver Builder addon, not an independently updatable WordPress plugin. It cannot be upgraded without updating its parent plugin, and 8 → 12 crosses four major versions with breaking API changes. The same applies to Fancybox 3.5.7. Neither is a 30-minute task.

**Recommended next step:** run WPScan or Patchstack against the live site for an authoritative plugin-and-version vulnerability report, rather than reconciling this table by hand.

---

## Content Depth

The original audit reported `/knee-pain/` at ~420 words, `/shockwave-therapy/` at ~655, and `/neuropathy-center-lp/` at ~850, against a 1,200-2,000 word competitive benchmark.

**These figures are not carried forward.** The measurement method could not be reproduced, and no competitor pages were measured, so the benchmark has no stated source. Expanding service-page content is a defensible content-marketing decision on its own merits; it is not supported by evidence in this repository. If you want it evidenced, measure rendered word counts on both these pages and a named competitor set first.
