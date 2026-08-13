# Security findings — highcountrypainrelief.com

**Compiled:** 13 August 2026 · **Method:** passive, unauthenticated observation from outside
**Scope note:** every finding below came from ordinary `GET` requests to public endpoints, made while
measuring page speed. No credentials were tried, no input was submitted, no scanner was run, and nothing
here altered the site. None of it required access the general public does not have — which is the point.

**This is not a security audit.** A real one would need authenticated access, a plugin-version review
against CVE data, and permission to test. Treat this as a register of things that surfaced incidentally
and should be looked at by someone who owns security for this site.

**Severity is stated as impact, not as a score.** Nothing here is a live compromise. Two items are
information disclosure that make a future attack cheaper; two are missing hardening.

| # | Finding | Severity | Status 13 Aug |
|---|---|---|---|
| S1 | UserWay plugin exposes an unauthenticated debug endpoint | **Medium** | Open |
| S2 | WordPress REST API allows user enumeration | **Medium** | Open |
| S3 | No HTTP security headers on any response | **Low–Medium** | Open |
| S4 | Migration leftover: Liquid Web Harbor plugin still loaded on AWS | **Low** | Open |
| S5 | Plugin versions not checked against known vulnerabilities | **Unassessed** | Not done |
| — | `xmlrpc.php` and `readme.html` exposed | — | **Closed** — both return 403 |

---

## S1 — UserWay's plugin exposes an unauthenticated debug endpoint · Medium

`https://www.highcountrypainrelief.com/wp-json/userway/v1/debug` is readable by anyone, with no
authentication, and returns:

```json
{"php":"8.4.24","wordpress":"7.0.4",
 "userway":{"version":"2.4.8",
   "account":[{"preference_id":"1","account_id":"Vgm0gbMRdF","state":"1",
               "created_time":"2021-11-20 03:41:36","updated_time":"2021-11-20 03:41:36"}],
   "table":"wp_userway","tableExist":true}}
```

**What it gives away:**

- **Exact PHP version** — 8.4.24
- **Exact WordPress version** — 7.0.4 (also in the generator meta tag, so this one is not new)
- **Exact plugin version** — UserWay 2.4.8
- **The database table prefix** — `wp_`, inferable from `wp_userway`
- The UserWay account ID and the date the integration was set up

**Why it matters.** None of this is a vulnerability on its own. Together it removes the reconnaissance
step from any future attack: an attacker no longer has to guess the PHP or plugin version to know which
exploits apply, and the default `wp_` table prefix is a precondition for several SQL-injection payloads
that would otherwise have to be blind. Version disclosure at this precision is what turns "try
everything" into "try the one thing that works."

**It is also a vendor defect, not a site defect.** This endpoint ships with the plugin. Anyone running
UserWay 2.4.8 has it.

**Fix, in order of preference:**

1. **Report it to UserWay** and ask them to require a capability check on `/debug`. It is their bug.
2. **Block it at the site**, in the child theme:
   ```php
   add_filter( 'rest_authentication_errors', function ( $result ) {
       if ( ! empty( $result ) ) { return $result; }
       $route = $GLOBALS['wp']->query_vars['rest_route'] ?? '';
       if ( str_starts_with( ltrim( $route, '/' ), 'userway/v1/debug' ) && ! current_user_can( 'manage_options' ) ) {
           return new WP_Error( 'rest_forbidden', 'Forbidden', array( 'status' => 401 ) );
       }
       return $result;
   } );
   ```
3. Or block the path at the server / firewall level.

**Verify:** `curl -o /dev/null -w '%{http_code}\n' https://www.highcountrypainrelief.com/wp-json/userway/v1/debug`
returns **401** or **403**, not 200.

> **Cross-reference:** whoever picks up Ticket 2 in `PRIORITY-FIXES.md` is already working on UserWay.
> Fold this in there rather than scheduling it separately.

---

## S2 — The REST API allows user enumeration · Medium

`https://www.highcountrypainrelief.com/wp-json/wp/v2/users` returns **200** with:

```json
[{"id":1,"name":"inception","slug":"inception", …},
 {"id":8,"name":"Inception .","slug":"inception-2", …}]
```

**Two valid WordPress usernames, unauthenticated.** WordPress core exposes this by design — it lists
users who have authored published content — but on a site with no posts it is pure disclosure with no
functional benefit.

**Why it matters.** A password-guessing attack needs a username and a password. This supplies half of it,
for free, and confirms the account is real so an attacker knows not to waste attempts elsewhere.

**Partly mitigated already, and worth crediting:** `?author=1` returns a **301 to the homepage** rather
than an author archive, and `wp-login.php` returns a **302 to `/not_found`** — the login URL has been
moved. Solid Security (`ithemes-security/v1`) is installed and is presumably doing both. So the obvious
brute-force route is already blunted. The REST endpoint is the hole left open.

**Note for whoever owns the accounts:** both users are Inception's, not the practice's. If the practice
has no WordPress login of its own, that is worth a conversation separately from security — it is a
business-continuity question.

**Fix** — in the child theme:

```php
add_filter( 'rest_endpoints', function ( $endpoints ) {
    unset( $endpoints['/wp/v2/users'], $endpoints['/wp/v2/users/(?P<id>[\d]+)'] );
    return $endpoints;
} );
```

Solid Security may also have a toggle for this; check its settings first, as with UserWay.

**Verify:** `curl -o /dev/null -w '%{http_code}\n' https://www.highcountrypainrelief.com/wp-json/wp/v2/users`
returns **401** or **404**, not 200.

---

## S3 — No HTTP security headers on any response · Low–Medium

Measured on the canonical homepage and on a static asset. **Every one of these is absent:**

| Header | Absent | What it would prevent |
|---|---|---|
| `Strict-Transport-Security` | ✗ | A first visit on `http://` being intercepted before the redirect to HTTPS |
| `Content-Security-Policy` | ✗ | An injected script running with the page's full privileges |
| `X-Frame-Options` / `frame-ancestors` | ✗ | The site being framed on another domain (clickjacking) |
| `X-Content-Type-Options: nosniff` | ✗ | A browser guessing a wrong content type and executing it |
| `Referrer-Policy` | ✗ | Full URLs leaking to third parties in the `Referer` header |
| `Permissions-Policy` | ✗ | Third-party scripts reaching camera, microphone or geolocation |

**Why it matters more here than on a typical brochure site.** This page loads and executes code from
**five external hosts** — `cdn.userway.org`, `cdn.reviewwave.com`, `rw-embed-data.s3.amazonaws.com`,
`googletagmanager.com`, and `chiro.inceptionimages.com`. Each has full access to the page. `Referrer-Policy`
and `Permissions-Policy` are the cheap, low-risk ones and are worth doing regardless.

**Do not deploy CSP casually.** A restrictive policy will break the review widget, the chat widget, the
accessibility toolbar and Google Analytics. If CSP is wanted, deploy it in `Content-Security-Policy-Report-Only`
first and read the reports for a fortnight. HSTS is also effectively one-way — a `max-age` that has been
served is honoured by browsers until it expires, so start small (`max-age=300`) and increase only once
HTTPS is confirmed working everywhere.

**Cheapest safe starting set,** server-level or via a WordPress filter:

```
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
X-Frame-Options: SAMEORIGIN
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

**Verify:** `curl -sD - -o /dev/null https://www.highcountrypainrelief.com/ | grep -iE 'x-content-type|referrer-policy|x-frame'`
returns three lines rather than nothing.

---

## S4 — Migration leftover: Liquid Web Harbor still loaded · Low

`/wp-json/liquidweb/harbor/v1` returns **200**. The site runs on **AWS EC2** (`44.223.213.21`), not Liquid
Web. This is host-management software for a hosting provider the site left.

**Why it matters.** It is unused code executing on every request, from a vendor with no current
relationship to the site, that nobody is monitoring for updates. Unmaintained plugin code is a standard
route in. The risk is not that Harbor is known-vulnerable — nothing here establishes that — it is that
nobody owns it.

Also worth knowing: this is the second migration leftover found (`audit/05` A1 recorded it first, in
July). It suggests the AWS migration was not followed by a cleanup pass, so **other leftovers may exist**.
A review of all 18 registered REST namespaces against "what does this site actually use" is a reasonable
half-hour.

**Fix:** confirm with Inception that nothing depends on it, then deactivate and delete the plugin.
**Verify:** the route returns 404.

---

## S5 — Plugin versions have not been checked against known vulnerabilities · Unassessed

**This is a gap in the work, not a finding.** The site's exact stack is now known — WordPress 7.0.4, PHP
8.4.24, Beaver Builder 2.10.3.1, Beaver Themer 1.5.3.2, BB Theme 1.7.19.2, PowerPack, Ultimate Addons,
Yoast, UserWay 2.4.8, 10Web Booster, Solid Security, Featured Image From URL, and the Liquid Web leftover
— but **none of it was checked against a vulnerability database.** That needs a source such as WPScan or
Patchstack and, ideally, authenticated access to enumerate exact versions of everything rather than the
subset that leaks.

Two things make this worth doing rather than assuming:

- **The core software is current, but its bundled libraries are years old** — Bootstrap 3.4.1 (end of life
  July 2019), fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1, Swiper 8.4.7, plus two abandoned
  libraries. No plugin update reaches any of it (`audit/05` §2). Old bundled JavaScript is not
  automatically a vulnerability, but it is where they accumulate.
- **UserWay 2.4.8 is behind** — 2.5.1 is public. S1 is one endpoint in a version that is not current.

---

## Closed since the July audit

**`xmlrpc.php` and `readme.html`.** The 30 July original flagged both as exposed. Both return **403**
today, verified 13 August. `xmlrpc.php` is the standard credential-stuffing and pingback-amplification
target, so this one mattered. No action needed.

---

## Recommended order

1. **S1** — fold into Ticket 2, since that work already touches UserWay. Ten minutes.
2. **S2** — one filter, or a Solid Security toggle. Ten minutes.
3. **S3, the safe four headers** — no CSP, no HSTS yet. Twenty minutes.
4. **S4** — confirm and remove. Thirty minutes, plus a sweep for other migration leftovers.
5. **S5** — commission a proper vulnerability review. This is the one that needs a person and a budget,
   not a ticket.

**None of these is urgent in the sense of "drop everything."** S1 and S2 are worth doing in the same
session as the performance work because the files are already open.

---

## What was deliberately not done

No authentication was attempted. No input was submitted to any form, endpoint or parameter. No scanner,
fuzzer or exploit was run. No plugin was probed for vulnerable behaviour. Nothing was tested that could
have affected the site's availability or data. Every observation came from a normal page request that any
visitor makes.

Confirming whether any of these findings is exploitable would require permission from the practice and a
scope agreement, and would be a different piece of work.

---

*Companion documents:* `PRIORITY-FIXES.md` (performance work),
`VERIFYING-BACKEND-CLAIMS.md` (how to confirm a fix is live),
`audit/05-architecture-and-code-quality.md` (§A1–A3, the original security register).
