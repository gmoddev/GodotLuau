# GL-012 nondestructive release retention

Date: 2026-10-27. Base/main: `34edaa2adfe698d6527e5c5b9bc0159428b5db64`.
Branch: `maintenance/gl-012-release-retention`, independently based on verified
main, not the unmerged GL-016 updater branch.

## Investigation and policy

The inherited workflow dispatches manually or on selected main-path pushes. It
builds Linux Debug/Release, extracts Windows libraries from the inherited ZIP,
derives a tag from `Version`, packages archives, commits the combined ZIP/hash,
and publishes platform assets through `softprops/action-gh-release@v2`. Its final
step enumerated 100 releases and deleted every older release with `--cleanup-tag`.
Nothing in the inspected build/package/publish steps depends on that deletion.
`tools/release.ps1` compiles/packages/commits/pushes; `generar_release.py` creates
local archives/hashes. Neither is a historical release/tag deletion mechanism.
They were inspected, not executed, and remain unchanged.

Retention now preserves every historical published release, its assets and tag.
The deletion loop is removed. A read-only preflight runs after version selection
and before packaging, archive commit or publication. It verifies repository
readability and requires both the exact release-by-tag and exact Git tag reference
to be absent. Existing identities, unreadable repositories, authentication/rate/
server errors, transport failure, timeout or unrecognized API status block the
operation. Repeated versions require a new `Version`; no bypass/overwrite mode
is added. Tag syntax is checked using read-only `git check-ref-format` and URL
path data is encoded. Tokens and API response bodies are not logged.
If a failed publication leaves a tag or release, that identity is preserved too;
investigate it manually and choose a fresh Version rather than auto-cleaning or
overwriting it on retry.

The preflight uses existing runner `gh` and Python standard libraries, and issues
only three bounded GETs for an admitted new identity. Publishing runs from this
workflow are serialized without canceling an active run. The existing publisher
explicitly receives `overwrite_files: false`, supported by its
[declared input contract](https://raw.githubusercontent.com/softprops/action-gh-release/v2/action.yml).
The read endpoints follow GitHub's
[release-by-tag](https://docs.github.com/en/rest/releases/releases#get-a-release-by-tag-name)
and [exact reference](https://docs.github.com/en/rest/git/refs#get-a-reference)
contracts. No remote retention pruning or forced tag movement is introduced.

## Verification

```text
python tests/release/ReleaseRetentionTests.py
```

All **12 tests** pass using mocked `gh api` responses and actual read-only Git tag
syntax validation. Cases cover new identity with exactly three GETs, existing
release, existing tag without a release, missing repository, auth/permission/rate/
server errors, network failure, timeouts, malformed/inconsistent responses,
invalid input and encoded nested tags. Workflow assertions check guard ordering
before package/commit/publish, no historical delete/force-tag commands,
non-canceling serialization and disabled asset overwrite. Existing triggers and
inherited Windows ZIP reuse remain explicit. PyYAML BaseLoader additionally
parses the workflow and confirms these structural settings without interpreting
GitHub `on` as a YAML 1.1 boolean. PyYAML was already available; no dependency was
installed or added to the production script.

A direct CLI probe with both token environment entries removed returns the
expected exit 1 and bounded authentication-required message before any API call.
The first unit run identified acceptance of `../repo` by an overly permissive
repository-name pattern; owner validation and explicit dot-segment rejection
correct it. The final run passes without network or remote mutations.
The [manifest](evidence/gl012-release-retention-2026-10-27.json) records commands,
test output and source hashes.

No publishing workflow was dispatched, release created/deleted, existing tag
changed, archive generated or binary published. This is static/mocked
qualification of the workflow policy, not a live publishing trial. Concurrency
applies to this workflow; repository-wide immutable-release enforcement and races
with independent external publishers/administrators are not qualified or changed.
The third-party action remains at its inherited `@v2` reference. GL-010's Windows
artifact provenance and GL-011's release-gate automation remain open; this change
does not redesign or qualify the rest of the publishing pipeline.

Disposition: **IMPLEMENTED AND VALIDATED ON DEDICATED BRANCH — NOT MERGED.**
Canonical main retains the inherited retention behavior until a separately
authorized integration. Historical issue evidence remains in the ledger.

## Continuation assessment

The smallest useful next non-adversarial task is **GL-011: add a separate,
non-publishing CI gate for the existing 39-case core suite on Windows and Linux**.
Use pinned dependencies, read-only workflow permissions, bounded build parallelism
and retained failure logs. This supplies an automated regression signal without
coupling checks to the inherited release job or reopening completed GL-019/VM
work. Native fixture/release gates and same-source artifact provenance can follow
as explicit scopes; GL-010 is not solved by a core-only gate.

GL-013 header extraction has no newly demonstrated performance/ownership need and
would be a larger change. GL-015 still needs asset-specific provenance evidence;
GL-009 needs an accepted transactional persistence decision; GL-005 needs a
lifecycle/cancellation design for nonblocking HTTP. These remain independent
future tasks. Further implementation, merging GL-016/012, enabling production
updates, publishing releases, and GL-020's deferred adversarial qualification
require separate authorization; none is undertaken in this continuation assessment.
