# Working notes for this repo

## Writing

These are audit and client documents. Keep the prose plain and free of padding.

**No self-grading hedges.** Cut phrases that rate your own honesty, clarity, effort, or the value of what
you are saying rather than saying it: "stated honestly," "to be clear," "in plain terms," "the real X,"
"worth doing anyway," "worth noting," "which is the point," "let me be direct." They add nothing, and by
claiming a virtue they imply the surrounding text lacks it. Same for section headings built from them —
"Severity, stated honestly" is just "Severity."

**No revision narration in the documents.** The audits are evidence, not a diary of their own corrections.
Where an earlier reading was wrong, state the current fact and the trap that protects against repeating the
error — not "rev. 3 claimed X, which was wrong." History lives in the git log.

**Every figure carries its provenance.** Lighthouse numbers are labelled by date; July and August CPU
figures are not comparable (different test machines — see `audit/data/lighthouse-mobile-2026-08-13.md`).
Distinguish measured from inferred, and transfer size from file size.

## Verifying claims about the live site

Four traps make a correct fix look failed and an unshipped one look done — page cache with no WordPress
purge control, ETag as a cache-entry ID not a content fingerprint, `?ver=` frozen at the WP version, and
UA-gated mobile behaviour. Details and a runnable census in `VERIFYING-BACKEND-CLAIMS.md` and
`audit/data/verify-live.sh`.

## Git

Branch, commit, PR, merge — do not commit straight to `main`. `gh` is authenticated. Pushing needs
`git -c credential.helper='!gh auth git-credential' push` (the global `gh auth setup-git` is blocked).
