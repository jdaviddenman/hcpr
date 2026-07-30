# HCPR — High Country Pain Relief

Page speed performance audit, caching analysis, and remediation roadmap for [highcountrypainrelief.com](https://www.highcountrypainrelief.com).

## Documents

| # | Document | Scope |
|---|----------|-------|
| 1 | [Page Speed Performance Audit](audit/01-page-speed-performance-audit.md) | Lighthouse 27/100 mobile, 47/100 desktop. 14 findings (Critical→Low). LCP breakdown. Resource waterfall. Performance budget. Implementation sequence. |
| 2 | [Spelling & Grammar Audit](audit/02-spelling-grammar-audit.md) | 40 errors across 44 pages. Technician-ready columnar table. Site-wide + per-page. Branding inconsistencies. |
| 3 | [Page Load & Caching Deep-Dive](audit/03-page-load-caching-deep-dive.md) | CDN cache policy table (10 domains, verified TTLs). LCP 15.9s waterfall. YouTube facade implementation (lite-youtube-embed). BB + LSCache integration. Third-party deferral strategy. Cache hierarchy. |
| 4 | [On-Page SEO & Content Findings](audit/04-seo-content-findings.md) | SEO issues found during crawl. Metadata gaps. Schema errors. 404 page. Content depth. CVE register. Excluded from page speed scope. |

## Quick Summary

| Metric | Current | Target |
|--------|---------|--------|
| PageSpeed Mobile | 27/100 | 50-65 (config + facade) |
| PageSpeed Desktop | 47/100 | 75-85 (config + facade) |
| LCP | 15.9s | <2.5s |
| TTFB | 2,540ms | <500ms |
| TBT | 18,520ms | <5,000ms (achievable via deferral) |
| CLS | 0.184 | <0.1 |
| YouTube thumbnails | 35 loaded eagerly, ~2hr cache | 0 until click (facade) |
| Page weight | 16,558 KB | <1,000 KB |
| Spelling/Grammar Errors | 40 found | 0 |
| CVEs (active) | 4 | 0 |

**Estimated time-to-green:** ~10-14 hours (config + video replacement + facade + CDN + hygiene).
