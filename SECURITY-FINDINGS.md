# Security findings — highcountrypainrelief.com

**13 August 2026.** Everything below came from ordinary `GET` requests to public endpoints, made while
measuring page speed, plus public-source research. No credentials tried, no input submitted, no scanner
run, nothing altered. None of it required access the general public does not have.

This is a register of things that surfaced incidentally, not a security audit. A real one needs
authenticated access, a CVE review of the full stack, and permission to test.

## Severity

**Nothing here is a live compromise, and the site is not currently exposed to any known exploited
vulnerability.** WordPress is on 7.0.4, which is the current release, and `/wp-json/batch/v1` returns 403
— so the July core RCE chain (CVE-2026-63030 + CVE-2026-60137, both in CISA's Known Exploited
Vulnerabilities catalogue) does not apply here.

One finding is low-severity information disclosure, two are missing hardening, and one is an unchecked
gap. The argument for fixing them is cost and timing, not exposure — see "Why fix them" below.

| # | Finding | Severity | Cost to fix | Status |
|---|---|---|---|---|
| S1 | REST API allows user enumeration | **Low** | One filter | Open |
| S2 | No HTTP security headers | **Low–Medium** | 20 min | Open |
| S3 | Liquid Web Harbor still loaded on AWS | **Low** | 30 min | Open |
| S4 | Full stack not checked against a vulnerability database | **Unassessed** | Needs a tool and a licence | Open |
| — | `xmlrpc.php`, `readme.html` | — | — | **Closed** — both 403 |

---

## S1 — REST user enumeration · Low

`/wp-json/wp/v2/users` returns 200 with two valid usernames:

```json
[{"id":1,"name":"inception","slug":"inception", …},
 {"id":8,"name":"Inception .","slug":"inception-2", …}]
```

WordPress exposes this by design for users who have authored published content. On a site with no posts it
is disclosure with no functional benefit. A password-guessing attack needs a username and a password; this
supplies half, and confirms the account is real.

**Partly mitigated already:** `?author=1` returns a 301 to the homepage rather than an author archive, and
`wp-login.php` returns a 302 to `/not_found` — the login URL has been moved. Solid Security
(`ithemes-security/v1`) is installed and presumably does both. The REST endpoint is the hole left open.

**Fix** — in the child theme, or check Solid Security's settings for a toggle first:

```php
add_filter( 'rest_endpoints', function ( $endpoints ) {
    unset( $endpoints['/wp/v2/users'], $endpoints['/wp/v2/users/(?P<id>[\d]+)'] );
    return $endpoints;
} );
```

**Verify:** the endpoint returns 401 or 404, not 200.

Separately: both accounts are Inception's. If the practice has no WordPress login of its own, that is a
business-continuity question.

---

## S2 — No HTTP security headers · Low–Medium

Measured on the canonical homepage and on a static asset. All absent:

| Header | What it would prevent |
|---|---|
| `Strict-Transport-Security` | A first visit on `http://` being intercepted before the redirect |
| `Content-Security-Policy` | An injected script running with the page's full privileges |
| `X-Frame-Options` / `frame-ancestors` | The site being framed on another domain |
| `X-Content-Type-Options: nosniff` | A browser guessing a wrong content type and executing it |
| `Referrer-Policy` | Full URLs leaking to third parties in the `Referer` header |
| `Permissions-Policy` | Third-party scripts reaching camera, microphone or geolocation |

This matters more here than on a typical brochure site: the page loads and executes code from **five
external hosts** — `cdn.userway.org`, `cdn.reviewwave.com`, `rw-embed-data.s3.amazonaws.com`,
`googletagmanager.com`, `chiro.inceptionimages.com` — each with full access to the page.

**Do not deploy CSP casually.** A restrictive policy will break the review widget, the chat widget, the
accessibility toolbar and Google Analytics. Deploy `Content-Security-Policy-Report-Only` first and read
the reports for a fortnight. HSTS is effectively one-way — a served `max-age` is honoured until it expires
— so start at `max-age=300`.

**Safe starting set:**

```
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
X-Frame-Options: SAMEORIGIN
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

**Verify:** `curl -sD - -o /dev/null https://www.highcountrypainrelief.com/ | grep -iE 'x-content-type|referrer-policy|x-frame'`
returns three lines.

---

## S3 — Liquid Web Harbor still loaded · Low

`/wp-json/liquidweb/harbor/v1` returns 200. The site runs on AWS EC2 (`44.223.213.21`), not Liquid Web.
This is host-management software for a provider the site left.

Unused code executing on every request, from a vendor with no current relationship, that nobody monitors
for updates. Nothing here establishes it is vulnerable — the risk is that nobody owns it.

This is a migration leftover, which suggests the AWS migration had no cleanup pass. A review of all 18
registered REST namespaces against what the site actually uses is a reasonable half-hour.

**Fix:** confirm nothing depends on it, then deactivate and delete. **Verify:** the route returns 404.

---

## S4 — The full stack has not been checked against a vulnerability database · Unassessed

Everything above is low severity. This one is not rated because it has not been checked.

The stack is known — WordPress 7.0.4, PHP 8.4.24, Beaver Builder 2.10.3.1, Beaver Themer 1.5.3.2, BB Theme
1.7.19.2, PowerPack 2.40.1.6, Ultimate Addons (version undetermined), Yoast, UserWay, 10Web Booster,
Solid Security, Featured Image From URL, and the Liquid Web leftover. None of it has been run against
WPScan or Patchstack, which needs a tool, a licence, and ideally authenticated access to enumerate exact
versions.

Reason not to assume it is fine: **the core software is current, but its bundled libraries are years old**
— Bootstrap 3.4.1 (EOL July 2019), fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1, Swiper 8.4.7,
plus two abandoned libraries. No plugin update reaches any of it (`audit/05` §2).

---

## Why fix them

[Patchstack's *State of WordPress Security in 2026*](https://patchstack.com/whitepaper/state-of-wordpress-security-in-2026/)
recorded **11,334 new WordPress vulnerabilities in 2025**, up 42% year on year, with **91% of them in
plugins** and only 6 in core. When one is disclosed:

| Time from disclosure | Share exploited |
|---|---|
| 6 hours | 20% |
| 24 hours | 45% |
| 7 days | 70% |

**46% had no patch available at the moment of disclosure.**

The exposure that matters is not any single item today — it is the next disclosed plugin vulnerability, and
the base rate is high. The defence is keeping the stack current and closing the cheap gaps now, so a
future disclosure meets a hardened, monitored site rather than a stale one.

The business consequence: the website is the booking channel. A compromise takes it offline or injects
spam content, and a Google Safe Browsing listing removes the search traffic the rest of this project
exists to protect. Cyber insurance questionnaires generally ask whether software is kept current.

---

## Strengthening the case further

**No authorization needed — worth doing now:**

1. **Close S4.** Run the full inventory through WPScan or Patchstack. This is the finding that could
   actually matter.
2. **Baseline Google Safe Browsing and Search Console → Security Issues** now, so a change is detectable.

**Needs written authorization from the practice:** an authenticated vulnerability scan. Get a scope
agreement first — the blast radius is a medical practice's booking channel.

**Do not** attempt exploitation against the live site.

## One question for the practice

The ReviewWave chat widget runs on a medical practice's site. **If it collects patient-identifying details,
the compliance picture is different from a brochure site's**, and S2's missing headers stop being hygiene.

---

## Closed

`xmlrpc.php` and `readme.html` both return 403, verified 13 August. `xmlrpc.php` is the standard
credential-stuffing and pingback-amplification target, so this one mattered.

## Order

1. **S1** — one filter, or a Solid Security toggle. 10 min.
2. **S2, the safe four headers** — no CSP, no HSTS yet. 20 min.
3. **S3** — confirm and remove, plus a sweep for other leftovers. 30 min.
4. **S4** — commission a proper vulnerability review. This one needs a person and a budget.

S1 is worth doing alongside the performance work because the child-theme file is already open.

Confirming whether any of these is exploitable would need permission from the practice and a scope
agreement, and is different work.
