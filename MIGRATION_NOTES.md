# MIGRATION_NOTES.md

## Purpose

Audit of every fork-only commit in `WilldanGroup/claude-code-with-aws-bedrock`
relative to upstream `aws-solutions-library-samples/guidance-for-claude-code-with-amazon-bedrock`,
categorized so we can:

1. Drop changes that upstream has since superseded
2. Open upstream PRs for changes that aren't Willdan-specific
3. Keep on the fork only what's genuinely Willdan-only or still pending upstream review

This is a one-time snapshot. Re-audit after each upstream rebase.

## Snapshot

- Fork HEAD at audit time: `033be13` (`v2.2.0-158-g033be13`)
- Upstream HEAD: `53468ef` (post-v2.2.0; v2.3.0 is queued in upstream pyproject)
- Fork is at upstream `v2.2.0` + 158 upstream commits (merged 2026-04-28) + 4 Willdan-only commits

## The 4 Willdan-only commits

```
033be13  Alex Telford  2026-05-07  fix: changes to support side by side install
01b22df  Alex Telford  2026-04-28  fix: updates for email templates from cognito
ed9bad0  Alex Telford  2026-04-01  fix: mark test_silent_refresh.py fake credentials as non-secrets in baseline
e7f2e15  Alex Telford  2026-03-24  fix: updates to fix issues with cognito and sonnet 4.6
```

## Categorization

Each hunk is bucketed as:
- **(a) config-able** — could be moved to a CFN parameter or per-org config and dropped from source
- **(b) upstreamable** — generally useful; open PR upstream and drop locally once merged
- **(c) genuine Willdan** — keep on fork indefinitely (Willdan-tenant-only or org-internal tooling)
- **(d) stale / upstream-fixed** — upstream has landed the equivalent change; drop on next rebase

### `033be13` — fix: changes to support side by side install

| Hunk | Category | Action |
|---|---|---|
| `source/claude_code_with_bedrock/cli/commands/package.py` — adds `--side-by-side` and `--default-longcontext` flags to the generated `install.sh` template | **(b)** upstreamable | Open PR upstream. Useful for any org whose users have personal Claude subscriptions or want 1M context as default. Keep on fork until merged. |
| `deployment/infrastructure/otel-collector.yaml` — removes `HTTPSListener` from the OTEL ECS service `DependsOn` | **(b)** upstreamable, *or* **(a)** config-able | Investigate whether upstream's `HTTPSListener` resource is conditional on a TLS cert that Willdan doesn't provide. If unconditional and the dep is just wrong, PR upstream. If conditional, drop the patch — upstream's version handles the missing-cert case. |

### `01b22df` — fix: updates for email templates from cognito

| Hunk | Category | Action |
|---|---|---|
| `deployment/scripts/customization/apply-email-template.sh` (new) | **(c)** genuine Willdan | Keep. IT-internal tooling. |
| `deployment/scripts/customization/invitation-email.html` (new) | **(c)** genuine Willdan | Keep. Willdan-branded email body. |
| `deployment/scripts/customization/verification-email.html` (new) | **(c)** genuine Willdan | Keep. Willdan-branded email body. |
| `prep-scripts/UNINSTALL.md` (renamed from top-level `UNINSTALL.md`) | **(c)** genuine Willdan | Keep at `prep-scripts/`. |
| `prep-scripts/backup-settings.sh` (new) | **(c)** genuine Willdan | Keep. Willdan IT user-machine cleanup utility. |
| `prep-scripts/uninstall.sh` (new) | **(c)** genuine Willdan | Keep. Willdan IT user-machine cleanup utility. |

### `ed9bad0` — fix: mark test_silent_refresh.py fake credentials as non-secrets in baseline

| Hunk | Category | Action |
|---|---|---|
| `.secrets.baseline` — adds detect-secrets entries marking AWS-doc-example creds and JWT test-signing keys as false positives | **(c)** genuine Willdan | Keep. Baseline files are local CI state. Upstream has its own equivalent entries; we only need ours. |

### `e7f2e15` — fix: updates to fix issues with cognito and sonnet 4.6

| Hunk | Category | Action |
|---|---|---|
| `source/claude_code_with_bedrock/cli/commands/deploy.py` — Cognito User Pool issuer URL uses `cognito-idp.{region}.amazonaws.com/{pool_id}` instead of hosted-UI domain | **(d)** stale / upstream-fixed | **Drop on next rebase.** Upstream merge `e6a4577` (2026-05-05) lands the same fix. Resolve any rebase conflict by taking upstream. |
| `source/claude_code_with_bedrock/models.py` — adds `sonnet-4-6` entry to the `CLAUDE_MODELS` dict | **(d)** stale / upstream-fixed; **CURRENTLY CAUSING A BUG** | **Drop on next rebase.** Upstream's centralized model catalog (`4244f07`) added `sonnet-4-6` at line 105. Alex's add at line 572 collided after the merge: the dict now has duplicate `sonnet-4-6` keys (lines 105 and 572). Python last-wins so Alex's version silently overrides upstream's, which masks any later upstream changes to that model entry. Dropping the Willdan version restores upstream-tracking. |
| `deployment/infrastructure/bedrock-auth-cognito-pool.yaml` — `AllowedPattern` loosened from `^[a-z0-9]{26}$` to `^[a-z0-9]{10,128}$` | **(b)** upstreamable | PR upstream. Cognito User Pool Client IDs can vary in length depending on configuration; the strict 26-char pattern is too narrow. Keep locally until merged. |
| `deployment/infrastructure/cognito-user-pool-setup.yaml` — `IdTokenValidity: 60` → `480` (minutes; 1h → 8h) | **(a)** config-able / **(b)** upstreamable | PR upstream to make `IdTokenValidity` a CFN parameter (default to upstream's 60). Then set Willdan's parameter to 480. The 8-hour session is a Willdan UX preference, not a security best practice for everyone. |

## Recommended actions, in order

1. **Now**: Drop the duplicate `sonnet-4-6` entry in `models.py` (line 572 onward). It's actively masking upstream model-catalog updates. This is a one-line cleanup that doesn't depend on anything else.
2. **Now**: Drop the `deploy.py` Cognito issuer fix in this fork — upstream has it.
3. **Open upstream PRs** for:
   - Side-by-side install + 1M context flags (`033be13` package.py portion)
   - `AllowedPattern` loosening on `CognitoUserPoolClientId`
   - `IdTokenValidity` parameterization
   - `HTTPSListener` dependency on otel-collector ECS service (after investigating its current upstream form)
4. **Establish rebase discipline**: when upstream cuts a tag, rebase the fork onto that tag rather than merging upstream/main. Future audits become diffs against the upstream tag, which is much easier to reason about than merge-commit soup.
5. **Move all new Willdan-specific files into a `willdan/` subtree** as future commits land, except `prep-scripts/` (which has a known top-level path users invoke from). This minimizes rebase conflict surface.

## What stays on the fork after action 1-4 are complete

- `prep-scripts/` (uninstall + backup utilities)
- `deployment/scripts/customization/` (Cognito email templates) — could move to `willdan/cognito-email-templates/`
- `.secrets.baseline` (Willdan CI state)
- `source/claude_code_with_bedrock/cli/commands/package.py` patch (until upstream PR merges)
- `deployment/infrastructure/otel-collector.yaml` patch (if still needed after investigation)
- `deployment/infrastructure/bedrock-auth-cognito-pool.yaml` AllowedPattern (until upstream PR merges)
- `deployment/infrastructure/cognito-user-pool-setup.yaml` IdToken validity (until parameterization PR merges; then becomes a profile config)

That's a much smaller surface than today.

## Open questions

1. **HTTPSListener investigation** — does upstream's current `otel-collector.yaml` make HTTPSListener conditional on a TLS cert parameter? Worth checking before opening a PR for the dependency removal.
2. **Side-by-side install flag naming** — upstream may already be tracking a similar feature. Search upstream issues/PRs for "side-by-side" or "claude-bedrock alias" before opening the PR.
3. **Quota fields in `~/claude-code-with-bedrock/config.json`** — earlier in this session we noted Willdan's templated config.json includes `quota_api_endpoint`, `quota_fail_mode`, `quota_check_interval`. Those are in deployment/templates, not commits. Verify those still match upstream's quota system expectations after the rebase; the v2.1 quota refactor may have moved or renamed them.
