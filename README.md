# HCPR — High Country Pain Relief

Page speed performance audit, caching analysis, and remediation roadmap for [highcountrypainrelief.com](https://www.highcountrypainrelief.com).

## Documents

| # | Document | Scope |
|---|----------|-------|
| 1 | [Page Speed Performance Audit](audit/01-page-speed-performance-audit.md) | Lighthouse 21/100 mobile. LCP breakdown, main-thread analysis, 15 findings, payload budget, ordered implementation sequence. **Start here.** |
| 2 | [Spelling & Grammar Audit](audit/02-spelling-grammar-audit.md) | 35 confirmed errors, 4 style preferences, 1 unverified. Site-wide chrome plus 4 content pages. |
| 3 | [Page Load & Caching Deep-Dive](audit/03-page-load-caching-deep-dive.md) | Cache policy across 11 domains, cold-cache analysis, YouTube facade, Beaver Builder cache behaviour, third-party load table. |
| 4 | [On-Page SEO & Content Findings](audit/04-seo-content-findings.md) | Metadata gaps, schema format errors, unverified security register. Outside page speed scope. |
| — | [Measured evidence](audit/data/) | Raw Lighthouse extract, 44-URL header sweep TSV, reproducer script. |

## Current State

Measured 2026-07-30. Sources: `audit/data/lighthouse-mobile-2026-07-30.md`, `audit/data/header-sweep-2026-07-30.tsv`.

| Metric | Current | Threshold | Notes |
|--------|---------|-----------|-------|
| Performance (mobile) | **21/100** | 90+ | 27 on a 2026-07-28 run of the same unchanged site |
| LCP | **18.9 s** | <2.5 s | 83% is Load Delay on the hero video |
| TBT | **14,710 ms** | <200 ms | main-thread work totals 36.9 s |
| CLS | **0.184** | <0.1 | 100% from one element — the hero video has no explicit size |
| FCP | **3.0 s** | <1.8 s | 11 render-blocking resources |
| Speed Index | **14.1 s** | <3.4 s | |
| TTFB (Lighthouse) | **700 ms** | <800 ms | **passes** |
| TTFB (cold cache) | **0.4-2.7 s** | — | 44/44 pages were cold; warm is 52-73 ms |
| Network payload | **5,123 KiB** | — | 62% is the hero video |
| DOM elements | **3,197** | <1,500 | |

## The Short Version

**One element causes the two worst metrics.** The hero background video is the LCP element at 18.9 s — 83% of which is the browser waiting to discover it — and it is the sole contributor to CLS 0.184 because it has no explicit dimensions. Its `poster` attribute is a 1×1 transparent GIF, so nothing paints early.

**The first two hours of work need no design approval and no plugin installs.** Explicit dimensions on the video container, a real poster frame (one already exists on the origin), reordering `<source>` to serve the 5.8 MB WebM ahead of the 15.3 MB MP4, `loading="lazy"` on five offscreen images, `&display=swap` on the fonts URL, and `defer` on three ReviewWave scripts. That addresses all of CLS and the most tractable part of LCP. See §7 of audit 1.

**There is no configuration path to a green score.** The ceiling is set by 3,197 DOM elements, a 10,883 ms Beaver Builder layout bundle, and 3,820 ms of third-party main-thread blocking. Config work is worth doing and will not reach 90.

## Measurement Caveat

Two Lighthouse runs of the identical, unmodified site produced a **6-point score spread, 3.0 s of LCP, 3,810 ms of TBT, and a 3.2× swing in reported payload**. Single-run figures from this site carry at least that much uncertainty. Take the median of 3+ runs before declaring any fix successful.

## Revision History

The 2026-07-28 deliverables contained errors that this revision corrects. The largest:

| Claim | Correction |
|---|---|
| "HTML served uncompressed, 216 KB raw" — CRITICAL | Wrong. 44/44 URLs serve Brotli, 81% saved. The original was verified with `curl -sI` (HEAD); this server omits `content-encoding` from HEAD responses. Finding deleted. |
| "No page caching, TTFB 2,540 ms on every load" — CRITICAL | Partly wrong. Server-level cache is active; warm TTFB is 52-73 ms. 2,540 ms is the cold-cache path, which real visitors do hit. Reframed as a pre-warming problem. |
| "33 render-blocking resources" | Wrong. Lighthouse flags 11. The figure 33 came from a different audit — "Avoid chaining critical requests: 33 chains". |
| "GTM — 4 KB, minimal, already async, OK" | Wrong. 275 KiB and 1,165 ms of blocking — the second-largest third-party cost. Now a HIGH finding. |
| "`/us/` returns 404" — CRITICAL | Wrong. Returns 200 with full content and is in the sitemap. The practitioner-schema gap survives; the broken-page claim does not. |
| "`/neuropathy-center-lp/` has zero metadata" | Mostly wrong. Meta description, OG tags, and canonical are all present. Only JSON-LD is missing. |
| "Page weight 16,558 KB, 90% one file" | Conflated file size with transfer size. The video is 15.3 MB on disk; 3,112 KiB actually transfers. Payload is 5,123 KiB. |
| "Estimated time-to-green: ~10-14 hours" | No projection in the repository reached green. Removed. |
| Duplicate `01-seo-performance-audit.md` | Deleted. It was unlinked from this README and still contained findings corrected in later commits. |

Roughly two dozen internal contradictions — conflicting effort totals, per-step times that did not sum to their stated totals, three different LCP targets, deferral tables whose rows contradicted their own totals — were resolved by consolidating each topic into one document. Full method notes are in [audit/data/README.md](audit/data/README.md).
