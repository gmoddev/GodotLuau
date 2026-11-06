# Release retention checks

```text
python tests/release/ReleaseRetentionTests.py
```

Standard-library tests use actual read-only `git check-ref-format` and mocked
`gh api` responses. They never invoke a real API, release publisher, packager,
tag creation or deletion. They also inspect the workflow's retention wiring.

`tools/CheckReleaseIdentity.py` is the workflow's fail-closed read-only preflight,
using GITHUB_REPOSITORY, RELEASE_TAG and an authenticated GH_TOKEN/GITHUB_TOKEN.
Do not dispatch the publishing workflow to run these tests. See
[policy and limitations](../../newdocs/release-retention.md).
