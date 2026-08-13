# Coordinated disclosure to UserWay — unauthenticated `/debug` endpoint

**Prepared:** 2026-08-13 · reporter to supply own contact details before sending
**Plugin:** Accessibility by UserWay (`userway-accessibility-widget`), WordPress
**Affected versions:** at least 2.4.8 through **2.6.6 (the current release)**
**Type:** unauthenticated information disclosure — CWE-200 / CWE-306
**Proposed severity:** CVSS 3.1 `AV:N/AC:L/PR:N/UI:N/S:U/C:L/I:N/A:N` = **5.3 (Medium)**

Send privately to UserWay's security contact (`security@userway.org` or the channel in their security.txt /
HackerOne). Do not open a public GitHub issue — it tips off attackers and forces a rushed close.

---

## Report body (paste into the email)

### Summary

The plugin registers `GET /wp-json/userway/v1/debug` with `permission_callback` hardcoded to return
`true`. Any unauthenticated visitor receives the site's PHP version, the live database table prefix, the
plugin version, the WordPress version, and the UserWay account row. The sibling `/save` route, registered
eight lines away in the same file, has a real capability check. The route is present and unauthenticated in
the version shipping today (2.6.6).

### What actually leaks, and why it matters

Two fields are not otherwise available to an unauthenticated visitor:

- **`php` → `phpversion()`** — the exact PHP patch version (e.g. `8.4.24`). WordPress does not expose this
  to unauthenticated clients, and the `X-Powered-By` header is commonly stripped. It lets an attacker
  match PHP-level CVEs to the host.
- **`table` → `$wpdb->prefix . 'userway'`** — the live database table prefix. On a site that has changed
  its prefix to a random value for hardening (a control WordPress security guides and plugins recommend to
  frustrate blind SQL-injection payloads), this endpoint discloses it — e.g. `xk3f_userway` — undoing that
  control. Confirmed from source: the value is `$wpdb->prefix`, not a constant.

Three fields are redundant with data already public on the site, and are noted here for completeness, not
as the basis of the report:

- `account` (the account ID) — already emitted in the widget snippet's `data-account` on every page.
- `wordpress` — already in the `<meta name="generator">` tag.
- account timestamps — install metadata.

The `catch` block returns `$e->getTraceAsString()`, so a thrown exception would additionally disclose
absolute server file paths. This does not fire on a healthy site, but it is a second disclosure path.

### Impact, stated at its real level

This is unauthenticated information disclosure. It is **not** RCE, not SQL-injectable (the query uses a
fixed prefix; no request input reaches SQL), not a write, and not a denial of service. It lowers the cost
of reconnaissance for a later attack and defeats prefix-randomisation hardening. 5.3 Medium.

### Precedent

The same class of issue in a competing accessibility widget was assigned CVEs: **accessiBe** took
**CVE-2025-10375** and **CVE-2025-13113** for exposing configuration data to unauthenticated users on
public pages.

### Reproduction

On any site running the plugin with a configured account:

```
GET /wp-json/userway/v1/debug
```

Returns HTTP 200 and:

```json
{"php":"8.4.24","wordpress":"7.0.4",
 "userway":{"version":"2.4.8",
   "account":[{"preference_id":"1","account_id":"<ACCOUNT_ID>","state":"1",
               "created_time":"…","updated_time":"…"}],
   "table":"<PREFIX>userway","tableExist":true}}
```

### Proposed fix

Give `/debug` the same check as `/save`:

```php
register_rest_route($this->namespace, '/debug', [
    'methods'             => WP_REST_Server::READABLE,
    'callback'            => [$this, 'debug'],
    'permission_callback' => function () { return current_user_can('manage_options'); },
]);
```

or remove the route if it exists only for internal support tooling.

### Requested

A tracking ID or CVE assignment, and confirmation of a fixed version.

---

## Evidence appendix (for the reporter, not the email)

### It is the plugin, not a site misconfiguration

Downloaded `https://downloads.wordpress.org/plugin/userway-accessibility-widget.2.6.6.zip` on 2026-08-13
(2.6.6 is the current release, dated 2025-12-08). `includes/controller.php`, verbatim:

```php
public function register_routes()
{
    register_rest_route($this->namespace, '/save', [
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => [$this, 'save'],
        'permission_callback' => [$this, 'permissions_check'],   // capability check
    ]);

    register_rest_route($this->namespace, '/debug', [
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => [$this, 'debug'],
        'permission_callback' => function () {
            return true;                                          // no check
        },
    ]);
}
```

`$this->tableName = $wpdb->prefix . 'userway'` (line 33), and `debug()` returns
`'table' => $this->tableName` and `'php' => phpversion()`. A site owner cannot cause or prevent any of
this. Because it ships in the current release, every install of 2.6.6 is affected.

### There is no vendor version that fixes it

Updating the plugin does not close this. The site-side mitigation is the child-theme filter in
`SECURITY-FINDINGS.md` S1.

> **Do not trust the GitHub repository for this plugin.** `UserWayOrg/wordpress-accessibility-plugin` was
> last pushed 2024-06-19, its `master` is 2.5.1, and that tree registers no REST routes at all — which can
> look as though the endpoint was removed. It was not. Verify against the distributed `.zip`.

### No prior public report

Checked 2026-08-13, nothing found: GitHub code and issue search (`userway/v1/debug`, schema strings), the
GitHub Advisory database, WPScan (0 vulnerabilities across ~80,000 installs), the vendor repo's own tracker
(only issue #2 "Fix debug endpoint declaration", 2021, which introduced this form — not a security
report), HackerNews (Algolia), and the plugin's WordPress.org support forum. Reddit and StackOverflow could
not be crawled directly and were not exhaustively checked. The endpoint is unreported as well as unfixed.

### What would get this dismissed, and the pre-empt

- *"Only exposes public data."* → The report leads with PHP version and table prefix, and concedes the
  redundant fields up front.
- *"Prefix is `wp_` anyway."* → Source shows it returns `$wpdb->prefix`, so it leaks a custom prefix too.
- *"The endpoint is intentional."* → `/save` has a capability check; `/debug` eight lines later does not.
- *"Info disclosure isn't a vulnerability."* → The accessiBe CVEs, same class, same product category.
- Report hygiene: private channel, exact versions, request/response, a patch, and an honest 5.3 — not
  "critical."

### Establishing prevalence (optional, corroborating)

The source proof already establishes plugin-specificity. If UserWay wants live corroboration, gather it
without exploitation and without collecting third-party data, using `audit/data/userway-debug-probe.sh`:
one read-only GET per supplied domain, only `/debug` (never `/save`), recording the HTTP status and the
field names while redacting the values. Find candidate installs with a source-code search
(PublicWWW / Nerdydata): `"el.setAttribute('data-account'" "cdn.userway.org/widget.js"`, or `"/wp-json/userway/v1"`.
