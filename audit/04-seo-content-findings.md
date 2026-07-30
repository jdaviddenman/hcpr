# On-Page SEO & Content Audit: highcountrypainrelief.com

**Date:** 2026-07-28

**Note:** This document contains findings that were identified during the site crawl but are **outside the scope of page speed performance.** Page speed findings are in `audit/01-page-speed-performance-audit.md`.

---

## Summary

Yoast SEO v28.1 is installed and functional on most pages. Homepage has complete metadata. Several service pages have configuration gaps — missing meta descriptions, missing OG images, inconsistent title/H1 alignment. The "Meet the Doctor" page at `/us/` returns 404. Schema markup exists but has format errors (openingHours, telephone format). No blog content exists.

---

## Findings

### CRITICAL — Missing or Broken Pages

**C1: "Meet the Doctor" page returns 404 (`/us/`)**

- **Evidence:** `/us/` returns HTTP 404. This is the main nav "About" dropdown's primary link. No practitioner schema (Physician, MedicalOrganization) exists on any page. For a healthcare provider, a missing practitioner bio page is a significant E-E-A-T gap.
- **Fix:** Determine correct slug (possible: `/meet-the-doctor/`, `/about/`, `/dr-denman/`). If page exists at different URL: fix nav link + add 301 redirect from `/us/`. If deleted: rebuild. Add Physician schema with credentials, NPI number, photo, clinic affiliation.
- **Verification:** `/us/` returns 200 or 301. Structured Data Testing Tool shows valid Physician schema.

### HIGH — Page-Level Metadata Gaps

**H1: `/neuropathy-center-lp/` — zero SEO metadata**

- **Evidence:** No meta description, no OG tags, no Twitter cards, no JSON-LD schema, no canonical URL. Title "Neuropathy Relief in Boone NC" does not match H1 "Neuropathy in Boone NC." This page is linked from the main nav but has no SERP snippet control.
- **Fix:** Configure Yoast for this page. Write unique meta description (150-160 chars). Set focus keyphrase. Verify Yoast auto-generates OG/schema/canonical. Align title and H1.
- **Verification:** View-source shows meta description, OG tags, canonical, JSON-LD.

**H2: `/shockwave-therapy/` — missing og:image**

- **Evidence:** Full metadata present except `og:image` is absent. `twitter:card` is `summary_large_image` but no image is provided. Social shares will render without a preview image. Also: `itemprop="description"` says "Softwave Therapy" but page is titled "Shockwave Therapy" — naming inconsistency.
- **Fix:** Set social image in Yoast (1200×630px recommended). Fix itemprop description to match page topic.
- **Verification:** View-source shows `og:image` with valid URL.

**H3: Contact page — wrong `og:type`, thin content**

- **Evidence:** `og:type` is `article` — should be `website` for a contact page. Meta description is adequate but body text is ~222 words (very thin). Form is JS-only via inceptionchiro.com embed — no `<form>` fallback in source.
- **Fix:** Override Yoast `og:type` to `website` for this page. Expand body text with location info, hours, map embed. Add `<noscript>` fallback for form.
- **Verification:** `og:type` = `website`. Body text ≥300 words.

### MEDIUM — Schema & Technical SEO

**M1: Schema format errors (site-wide)**

- **Evidence:**
  - `openingHours`: `We 0800-1200` instead of ISO 8601 `We 08:00-12:00`
  - `telephone`: `18283861888` (missing `+` prefix) — should be `+18283861888`
  - `@type`: `LocalBusiness` — should be `MedicalBusiness` or `MedicalClinic` for a healthcare practice
  - `email`, `currenciesAccepted`, `sameAs`: set to empty strings — remove or populate
  - Block 2 uses `http://schema.org` context — should be `https://schema.org`
- **Fix:** Edit LocalBusiness JSON-LD (appears to be custom, not Yoast-generated). Fix all format issues. Change `@type` to `MedicalBusiness`. Fix telephone to `+18283861888`. Fix openingHours to ISO 8601. Remove empty fields. Change schema.org context to `https`.
- **Verification:** Google Rich Results Test — 0 errors, 0 warnings.

**M2: Homepage OG image is 250×250**

- **Evidence:** `og:image` = a 250×250 Meet The Team thumbnail. Facebook recommends 1200×630 minimum for link share previews.
- **Fix:** Create 1200×630 OG image. Set as default social image in Yoast → Social → Facebook.
- **Verification:** `og:image:width` = 1200, `og:image:height` = 630.

**M3: Content depth below competitive range**

- **Evidence:** `/knee-pain/` body: ~420 words. `/shockwave-therapy/`: ~655 words. `/neuropathy-center-lp/`: ~850 words. Competitive local medical service pages typically target 1,200-2,000 words with structured H2/H3 sections.
- **Fix:** Expand each service page with: condition overview, symptoms checklist, treatment options, FAQ section, expected outcomes, internal links to related therapies.
- **Verification:** Each service page ≥1,200 words with H2/H3 structure.

**M4: BreadcrumbList missing `item` on last position (all pages)**

- **Evidence:** All Yoast-generated BreadcrumbList JSON-LD omits `"item"` URL on position 2 (current page). Valid per Google (they tolerate it) but fails strict Schema.org validation.
- **Fix:** Add last breadcrumb URL via Yoast filter or template override.
- **Verification:** Schema.org validator — BreadcrumbList passes without warnings.

### LOW — Hygiene

**L1: H3→H5 heading jump on homepage**

- **Evidence:** "Conditions We Help" is an H5. No H4 exists on the page. Heading hierarchy skips a level.
- **Fix:** Retag H5 as H4.
- **Verification:** WAVE tool — no heading level skips.

**L2: Alt text is filename-based on 6 CDN images**

- **Evidence:** 6 images from `chiro.inceptionimages.com` have alt text matching the filename (e.g., "Chiropractic-Senior-Couple-Stretching-Out-640x640-HP-Moto.webp").
- **Fix:** Rewrite alt text descriptively for each image.
- **Verification:** WAVE tool — no alt text warnings.

**L3: `shortlink` `<link>` present — duplicate content risk**

- **Evidence:** `<link rel='shortlink' href='https://www.highcountrypainrelief.com/?p=2'>` — WordPress default shortlink. If indexed, creates duplicate content.
- **Fix:** Yoast → Search Appearance → Advanced → "Remove shortlink" setting.
- **Verification:** View-source — no `<link rel='shortlink'>`.

**L4: NAP telephone inconsistency**

- **Evidence:** Contact page meta description: `(828) 386-1888`. JSON-LD telephone: `18283861888`. Header CTA: varies. Three different formats for the same phone number.
- **Fix:** Standardize on `+1 (828) 386-1888` across all phone references.
- **Verification:** Grep source for all phone number instances — single format.

**L5: No `google-site-verification` meta tag**

- **Evidence:** Microsoft verification present (`msvalidate.01`). Google verification absent.
- **Fix:** Add Google Search Console verification meta tag.
- **Verification:** View-source — `google-site-verification` meta present.

---

## CVE Reference

The following plugin vulnerabilities were identified but are **security findings, not page speed or SEO findings:**

- [CVE-2026-27212](https://security.snyk.io/package/npm/swiper/8.4.7) — Swiper 8.4.7 Prototype Pollution (CVSS 9.5)
- [CVE-2025-39442](https://patchstack.com/database/wordpress/plugin/review-wave-google-places-reviews/vulnerability/wordpress-review-wave-google-places-reviews-plugin-1-4-7-cross-site-request-forgery-csrf-vulnerability) — ReviewWave CSRF→Stored XSS (CVSS 7.1, unpatched)
- [CVE-2024-5020](https://vuldb.com/?id.286834) — Fancybox 3.5.x Stored XSS via data-caption
- [CVE-2025-8897](https://research.cleantalk.org/reports/search/beaver-builder-lite-version/CVE-2025-11726) — Beaver Builder Reflected XSS
