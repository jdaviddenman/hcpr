# Coordinated disclosure to UserWay — unauthenticated `/debug` endpoint

**Prepared:** 2026-08-13 · **Reporter to supply own contact details before sending**
**Affected plugin:** Accessibility by UserWay (`userway-accessibility-widget`), WordPress
**Affected versions:** at least 2.4.8 through **2.6.6 (the current release)** — see below
**Type:** unauthenticated information disclosure (CWE-200 / CWE-306: missing authentication)

---

## Summary

The plugin registers a REST route, `/wp-json/userway/v1/debug`, with `permission_callback` hardcoded to
return `true`. Any unauthenticated visitor receives the site's PHP version, WordPress version, plugin
version, UserWay account ID and **database table prefix**. The route is present and unauthenticated in the
version WordPress.org distributes today.

## The proof it is plugin-specific, not a site misconfiguration

**This is the whole argument, and it needs no third-party sites: the vendor's own shipped code registers
the route this way.**

Downloaded `https://downloads.wordpress.org/plugin/userway-accessibility-widget.2.6.6.zip` on 2026-08-13
(2.6.6 is the current release, dated 2025-12-08). `includes/controller.php`, verbatim:

```php
public function register_routes()
{
    register_rest_route($this->namespace, '/save', [
        'methods'             => WP_REST_Server::CREATABLE,
        'callback'            => [$this, 'save'],
        'permission_callback' => [$this, 'permissions_check'],   // ← real capability check
    ]);

    register_rest_route($this->namespace, '/debug', [
        'methods'             => WP_REST_Server::READABLE,
        'callback'            => [$this, 'debug'],
        'permission_callback' => function () {
            return true;                                          // ← no check at all
        },
    ]);
}
```

Two routes registered eight lines apart. `/save` is protected; `/debug` is not. A site owner cannot cause
or prevent this — it is a fixed declaration in the plugin. Because it ships in the current release, **every
install of 2.6.6 is affected by design**, which is a stronger statement than any sample of live sites.

`namespace` is `userway/v1`, so the full path is `/wp-json/userway/v1/debug`. The route is wired up in the
same file:

```php
add_action('rest_api_init', 'usw_register_rest_routes');
```

## Reproduction

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
   "table":"wp_userway","tableExist":true}}
```

`"table":"wp_userway"` discloses the WordPress table prefix (`wp_`), which is a precondition for several
SQL-injection payloads that would otherwise be blind.

## History in the plugin's own repository

The public repository `UserWayOrg/wordpress-accessibility-plugin` shows issue **#2, "Fix debug endpoint
declaration"** (opened 2021-10-17, closed 2021-10-21), and commit `6b64f99` "fix debug endpoint
declaration" of the same date — where this route was last touched. No issue, pull request or advisory has
raised it as a **security** concern.

> **Note for anyone re-checking this:** the GitHub repository is not the code WordPress.org distributes.
> The repo was last pushed 2024-06-19, its `master` is 2.5.1, and that tree contains **no REST routes at
> all** — which can look as though the endpoint was removed. It was not. The distributed 2.6.6 `.zip`
> still contains it. Always verify against the `.zip`, not the repo.

## Suggested remediation (for the vendor)

Replace the `/debug` `permission_callback` with a capability check, matching `/save`:

```php
'permission_callback' => function () { return current_user_can('manage_options'); },
```

or remove the route entirely if it exists only for support tooling.

## Requested

A tracking ID or CVE assignment, and confirmation of a fixed version.

---

## Establishing prevalence across other sites (optional, corroborating)

The source proof above already establishes plugin-specificity. If UserWay's triage wants live
corroboration that the route is reachable in production across unrelated installs, it can be gathered
**without exploitation and without collecting third parties' data**, using `audit/data/userway-debug-probe.sh`.

**Finding candidate installs.** The plugin — as opposed to UserWay's hand-pasted JavaScript snippet, which
has no REST endpoint — emits a distinctive footer block. A source-code search engine (PublicWWW,
Nerdydata) finds it with:

```
"el.setAttribute('data-account'" "document.body.appendChild(el)" "cdn.userway.org/widget.js"
```

or, where a search index exposes REST namespaces, `"/wp-json/userway/v1"`.

**The probe.** `userway-debug-probe.sh` takes a list of candidate domains and makes **one read-only GET**
per site to the public endpoint. It records the HTTP status and the **field names** returned as proof of
what leaks, and **redacts the values** — account IDs and table prefixes are never stored. You are
demonstrating that the endpoint is open and what schema it exposes, not accumulating other organisations'
reconnaissance data.

```bash
printf '%s\n' site-a.com site-b.org … > domains.txt
bash audit/data/userway-debug-probe.sh domains.txt
```

**Boundaries observed:** one request per site; only the `/debug` route (never `/save`, the write route);
no authentication attempted; no input submitted; values redacted. This is the same request an
unauthenticated browser can make, gathered for the purpose of a coordinated fix.

> This repository did not mass-probe third-party sites to produce this report. The evidence that carries
> the disclosure is the vendor's own distributed source. The probe is provided so UserWay, or the reporter
> with a scope they are comfortable with, can add prevalence data if they choose.
