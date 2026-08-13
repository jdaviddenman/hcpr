# Security findings — highcountrypainrelief.com

**13 August 2026.** Everything below came from ordinary `GET` requests to public endpoints, made while
measuring page speed. No credentials tried, no input submitted, no scanner run, nothing altered. None of
it required access the general public does not have — which is the point.

This is a register of things that surfaced incidentally, not a security audit. A real one needs
authenticated access, a CVE review, and permission to test. Nothing here is a live compromise: two items
are information disclosure that make a future attack cheaper, two are missing hardening.

| # | Finding | Severity | Status |
|---|---|---|---|
| S1 | UserWay plugin exposes an unauthenticated debug endpoint | **Medium** | Open |
| S2 | REST API allows user enumeration | **Medium** | Open |
| S3 | No HTTP security headers on any response | **Low–Medium** | Open |
| S4 | Liquid Web Harbor plugin still loaded on AWS | **Low** | Open |
| S5 | Plugin versions not checked against known vulnerabilities | **Unassessed** | Not done |
| — | `xmlrpc.php`, `readme.html` | — | **Closed** — both 403 |

---

## S1 — UserWay's unauthenticated debug endpoint · Medium

`/wp-json/userway/v1/debug` is readable by anyone and returns:

```json
{"php":"8.4.24","wordpress":"7.0.4",
 "userway":{"version":"2.4.8",
   "account":[{"preference_id":"1","account_id":"Vgm0gbMRdF","state":"1",
               "created_time":"2021-11-20 03:41:36","updated_time":"2021-11-20 03:41:36"}],
   "table":"wp_userway","tableExist":true}}
```

Exact PHP version, exact WordPress version, exact plugin version, the **database table prefix** (`wp_`,
from `wp_userway`), the account ID and setup date.

None of this is a vulnerability alone. Together it removes the reconnaissance step: an attacker no longer
guesses which PHP or plugin exploits apply, and the default `wp_` prefix is a precondition for several
SQL-injection payloads that would otherwise have to be blind.

**This is a vendor defect.** The endpoint ships with the plugin; anyone running UserWay 2.4.8 has it.

**Fix, in order of preference:**

1. Report it to UserWay and ask for a capability check on `/debug`.
2. Block it in the child theme:
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
3. Or block the path at the server or firewall.

**Verify:** the endpoint returns 401 or 403, not 200.

Fold this into Ticket 2 of `PRIORITY-FIXES.md`, which already touches this plugin.

## S2 — REST user enumeration · Medium

`/wp-json/wp/v2/users` returns 200 with two valid usernames:

```json
[{"id":1,"name":"inception","slug":"inception", …},
 {"id":8,"name":"Inception .","slug":"inception-2", …}]
```

WordPress exposes this by design for users who have authored published content. On a site with no posts
it is disclosure with no functional benefit. A password-guessing attack needs a username and a password;
this supplies half, and confirms the account is real.

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
business-continuity question worth raising.

## S3 — No HTTP security headers · Low–Medium

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
the reports for a fortnight. HSTS is effectively one-way — a served `max-age` is honoured until it
expires — so start at `max-age=300`.

**Safe starting set:**

```
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
X-Frame-Options: SAMEORIGIN
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

**Verify:** `curl -sD - -o /dev/null https://www.highcountrypainrelief.com/ | grep -iE 'x-content-type|referrer-policy|x-frame'`
returns three lines.

## S4 — Liquid Web Harbor still loaded · Low

`/wp-json/liquidweb/harbor/v1` returns 200. The site runs on AWS EC2 (`44.223.213.21`), not Liquid Web.
This is host-management software for a provider the site left.

Unused code executing on every request, from a vendor with no current relationship, that nobody monitors
for updates. Nothing here establishes it is vulnerable — the risk is that nobody owns it.

This is the second migration leftover found, which suggests the AWS migration had no cleanup pass. A
review of all 18 registered REST namespaces against what the site actually uses is a reasonable half-hour.

**Fix:** confirm nothing depends on it, then deactivate and delete. **Verify:** the route returns 404.

## S5 — Plugin versions not checked against known vulnerabilities · Unassessed

A gap in the work, not a finding. The stack is known — WordPress 7.0.4, PHP 8.4.24, Beaver Builder
2.10.3.1, Beaver Themer 1.5.3.2, BB Theme 1.7.19.2, PowerPack, Ultimate Addons, Yoast, UserWay 2.4.8,
10Web Booster, Solid Security, Featured Image From URL, and the Liquid Web leftover — but none of it was
checked against a vulnerability database. That needs WPScan or Patchstack and ideally authenticated
access.

Two reasons not to assume it is fine:

- **The core software is current; its bundled libraries are years old** — Bootstrap 3.4.1 (EOL July 2019),
  fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1, Swiper 8.4.7, plus two abandoned libraries. No
  plugin update reaches any of it (`audit/05` §2).
- **UserWay 2.4.8 is behind** — 2.5.1 is public. S1 is one endpoint in a version that is not current.

## Closed

`xmlrpc.php` and `readme.html` both return 403, verified 13 August. The 30 July original flagged both.
`xmlrpc.php` is the standard credential-stuffing and pingback-amplification target, so this one mattered.

---

## Order

1. **S1** — fold into Ticket 2. 10 min.
2. **S2** — one filter, or a Solid Security toggle. 10 min.
3. **S3, the safe four headers** — no CSP, no HSTS yet. 20 min.
4. **S4** — confirm and remove, plus a sweep for other leftovers. 30 min.
5. **S5** — commission a proper vulnerability review. Needs a person and a budget, not a ticket.

None is urgent. S1 and S2 are worth doing alongside the performance work because the files are already
open.

Confirming whether any of these is exploitable would need permission from the practice and a scope
agreement, and is different work.
