# Security findings — highcountrypainrelief.com

**13 August 2026.** Everything below came from ordinary `GET` requests to public endpoints, made while
measuring page speed, plus public-source research. No credentials tried, no input submitted, no scanner
run, nothing altered. None of it required access the general public does not have — which is the point.

This is a register of things that surfaced incidentally, not a security audit. A real one needs
authenticated access, a CVE review of the full stack, and permission to test.

## Severity, stated honestly

**Nothing here is a live compromise, and the site is not currently exposed to any known exploited
vulnerability.** WordPress is on 7.0.4, which is the current release, and `/wp-json/batch/v1` returns 403
— so the July core RCE chain (CVE-2026-63030 + CVE-2026-60137, both in CISA's Known Exploited
Vulnerabilities catalogue) does not apply here.

Two findings are information disclosure, low severity in isolation. Two are missing hardening. **The
argument for fixing them is cost and timing, not danger** — see "Why this is worth doing anyway" below.

| # | Finding | Severity | Cost to fix | Status |
|---|---|---|---|---|
| S1 | UserWay exposes an unauthenticated debug endpoint | **Low–Medium** | **One plugin update** | Open |
| S2 | REST API allows user enumeration | **Low** | One filter | Open |
| S3 | No HTTP security headers | **Low–Medium** | 20 min | Open |
| S4 | Liquid Web Harbor still loaded on AWS | **Low** | 30 min | Open |
| S5 | Full stack not checked against a vulnerability database | **Unassessed** | Needs a tool and a licence | **The real gap** |
| — | `xmlrpc.php`, `readme.html` | — | — | **Closed** — both 403 |

---

## S1 — UserWay's unauthenticated debug endpoint · Low–Medium

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

### The fix is a plugin update, not custom code

**UserWay removed the REST endpoints in version 2.5.1.** Verified against the official repository
(`UserWayOrg/wordpress-accessibility-plugin`) on 2026-08-13 — all five PHP files, `userway.php` and
`includes/{admin,controller,functions,notifications}.php`:

```
register_rest_route  occurrences:  0
"debug"              occurrences:  0
```

The only frontend hook in 2.5.1 is `add_action( 'wp_footer', 'usw_addplugin_footer_notice' )` at line 81
of `userway.php`. **The site runs 2.4.8.** So this is not a design decision to argue about or a plugin to
write a workaround for — it is an artefact of a version the vendor has already superseded.

1. **Update the plugin to 2.5.1.** That is the whole fix. No code, no regression surface.
2. Regression-test the toolbar afterwards, since 2.5.1 also changes how settings are stored.
3. Only if the update is blocked for some reason, block the route in the child theme:
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

**Verify:** the endpoint returns 404 (after update) or 401/403 (after the filter), not 200.

### This is not a known CVE, and that cuts both ways

WPScan records **zero** vulnerabilities for this plugin across **80,000 active installs**. So it cannot be
cited as known-exploited — but it also means nobody has reported it, and every site still on 2.4.8 has it.
**Report it to UserWay and request a tracking ID.** A vendor acknowledgement is the most credible thing to
put in front of a client, and at that install base it is a real contribution.

The class of finding is already accepted as a vulnerability. accessiBe — a competing accessibility overlay
— took **CVE-2025-10375** and **CVE-2025-13113** for exposing configuration data, including account IDs
and licence information, to unauthenticated users on public pages. Same shape.

Fold the update into Ticket 2 of `PRIORITY-FIXES.md`, which already touches this plugin.

---

## S2 — REST user enumeration · Low

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
business-continuity question worth raising.

---

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

## S4 — Liquid Web Harbor still loaded · Low

`/wp-json/liquidweb/harbor/v1` returns 200. The site runs on AWS EC2 (`44.223.213.21`), not Liquid Web.
This is host-management software for a provider the site left.

Unused code executing on every request, from a vendor with no current relationship, that nobody monitors
for updates. Nothing here establishes it is vulnerable — the risk is that nobody owns it.

This is the second migration leftover found, which suggests the AWS migration had no cleanup pass. A
review of all 18 registered REST namespaces against what the site actually uses is a reasonable half-hour.

**Fix:** confirm nothing depends on it, then deactivate and delete. **Verify:** the route returns 404.

---

## S5 — The full stack has not been checked against a vulnerability database · The real gap

Everything above is low severity. **This is the one that could be serious, and it is unassessed.**

The stack is known — WordPress 7.0.4, PHP 8.4.24, Beaver Builder 2.10.3.1, Beaver Themer 1.5.3.2, BB Theme
1.7.19.2, PowerPack 2.40.1.6, Ultimate Addons (version undetermined), Yoast, UserWay 2.4.8, 10Web Booster,
Solid Security, Featured Image From URL, and the Liquid Web leftover. None of it has been run against
WPScan or Patchstack, which needs a tool, a licence, and ideally authenticated access to enumerate exact
versions rather than the subset that leaks.

Two reasons not to assume it is fine:

- **The core software is current; its bundled libraries are years old** — Bootstrap 3.4.1 (EOL July 2019),
  fancyBox 3.5.7, Font Awesome 5.15.4, Animate.css 3.5.1, Swiper 8.4.7, plus two abandoned libraries. No
  plugin update reaches any of it (`audit/05` §2).
- **UserWay 2.4.8 is behind, and that is the component already leaking.** If one plugin is two versions
  stale, the others are worth checking.

---

## Why this is worth doing anyway

Severity is the wrong frame for these findings. Cost and timing are the right one.

[Patchstack's *State of WordPress Security in 2026*](https://patchstack.com/whitepaper/state-of-wordpress-security-in-2026/)
recorded **11,334 new WordPress vulnerabilities in 2025**, up 42% year on year, with **91% of them in
plugins** and only 6 in core. When one is disclosed:

| Time from disclosure | Share exploited |
|---|---|
| 6 hours | 20% |
| 24 hours | 45% |
| 7 days | 70% |

**46% had no patch available at the moment of disclosure.**

Against that, the exposure is not today's endpoint. It is the next disclosure. Version and table-prefix
disclosure is what moves a site from *found by a blind scan* to *found by a scan targeting exactly this
stack* — and the SQL-injection half of the July core chain is precisely where a known table prefix
matters. The window between disclosure and exploitation is measured in hours; the site is two versions
behind on the one component doing the leaking.

The business consequence for a practice, in plain terms: the website is the booking channel. A compromise
takes it offline or injects spam content, and a Google Safe Browsing listing removes the search traffic the
rest of this project exists to protect. Cyber insurance questionnaires generally ask whether software is
kept current; "two versions behind on a plugin whose newer release removed the leaking endpoint" is a poor
answer to give after an incident.

---

## Strengthening the case further

**No authorization needed — worth doing now:**

1. **Report S1 to UserWay** and request a tracking ID or CVE. Vendor acknowledgement is the most credible
   escalation available.
2. **Check whether Inception's other client sites run UserWay 2.4.8.** If the plugin is deployed as agency
   standard, one update becomes an agency-wide fix — an easier sell than a single site's ticket.
3. **Close S5.** Run the full inventory through WPScan or Patchstack. This is the finding that could
   actually matter.
4. **Baseline Google Safe Browsing and Search Console → Security Issues** now, so a change is detectable.

**Needs written authorization from the practice:** an authenticated vulnerability scan, and any
verification that the disclosed prefix and versions enable something concrete. Get a scope agreement
first — the blast radius is a medical practice's booking channel.

**Do not** attempt exploitation against the live site. It is not needed: the argument for fixing S1 rests
on the version gap alone, which is a matter of public record.

## One question for the practice

The ReviewWave chat widget runs on a medical practice's site. **If it collects patient-identifying details,
the compliance picture is different from a brochure site's**, and S3's missing headers stop being hygiene.
Worth asking rather than assuming.

---

## Closed

`xmlrpc.php` and `readme.html` both return 403, verified 13 August. `xmlrpc.php` is the standard
credential-stuffing and pingback-amplification target, so this one mattered.

## Order

1. **S1 — update the UserWay plugin.** One click, and it is the finding with a vendor fix already shipped.
2. **S2** — one filter, or a Solid Security toggle. 10 min.
3. **S3, the safe four headers** — no CSP, no HSTS yet. 20 min.
4. **S4** — confirm and remove, plus a sweep for other leftovers. 30 min.
5. **S5** — commission a proper vulnerability review. This one needs a person and a budget.

S1 and S2 are worth doing alongside the performance work because the files are already open.

Confirming whether any of these is exploitable would need permission from the practice and a scope
agreement, and is different work.
