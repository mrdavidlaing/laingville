# /security-fix
#
# Goal
# - Find the most impactful (highest severity + broadest blast radius) GitHub Security Code Scanning alerts
# - Fix them in our Nix-based infra/devcontainer by:
#   1) First trying an upstream update (nixpkgs pin bump)
#   2) Then, if needed, adding a targeted Nix overlay/patch
# - Open a PR with the minimal change set that closes the alerts
#
# Important repo rules
# - Use `bd` (beads) for tracking work. Prefer `bd ready --json`, `bd create ... --json`, `bd update ... --json`.
# - Keep PRs tight: infra changes in `infra/` and scanner/workflow changes in `.github/workflows/`.
#
# ---
#
# Step 0: Snapshot current alerts
# 1) Pull open alerts (dedupe by rule + package path):
#
#    gh api -H 'Accept: application/vnd.github+json' \
#      /repos/mrdavidlaing/laingville/code-scanning/alerts?state=open\&per_page=100 --paginate \
#    | jq -r '.[] | [.rule.security_severity_level, .tool.name, (.rule.id // .rule.name // ""), (.most_recent_instance.location.path // ""), (.html_url // "")] | @tsv' \
#    | sort -u
#
# 2) Group by issue family (examples):
# - Same CVE across multiple images => likely a base/system package in devcontainer contents
# - Many CVEs under one store path => one dependency (e.g. `pyright`, `nodejs`, `perl`)
#
# 3) Choose the “most impactful” target:
# - Prefer CRITICAL/HIGH first
# - Prefer issues present in multiple images (devcontainer + examples + runtime)
# - Prefer issues in *tools everyone uses* (node/npm, python/pip, git, nix, openssl, glibc, etc.)
#
# Create/claim a bd issue (optional but recommended):
# - bd create "Fix <CVE/GHSA> in devcontainers" -t chore -p 0 --json
#
# ---
#
# Step 1: Confirm where it comes from (closure + version)
# On macOS, evaluating Linux images requires `--system x86_64-linux`.
#
# - Inspect closure membership:
#   nix path-info -r --system x86_64-linux ./infra#laingville-devcontainer | rg '<package-name>|/perl-|/nodejs-|/pyright-|/pip-' | head
#
# - If you need to identify which top-level package pulls it in:
#   - Start from `infra/flake.nix` packageSets
#   - Remove/swap obvious candidates (e.g. `git` -> `gitMinimal`) to shrink closure
#
# ---
#
# Step 2: First attempt: update from upstream (nixpkgs bump)
# 1) Update infra nixpkgs pin:
#   cd infra
#   nix flake lock --update-input nixpkgs
#
# 2) Commit only infra lock changes (and any needed follow-up fixes).
#
# 3) Let CI build/publish images and rerun security scans:
# - `Build Containers` publishes `:latest`
# - `Security Scan` scans `:latest` on main/schedule
#
# If alerts close: stop here and open PR.
#
# ---
#
# Step 3: If still open: add a targeted overlay
# Add/adjust overlays in:
# - `infra/overlays/cve-patches.nix`
# - supporting package definitions under `infra/overlays/*-patched/`
#
# Common patterns:
# - **Bump package version** (preferred): overrideAttrs with newer `src` + hash
# - **Apply patch**: add to `patches = (old.patches or []) ++ [ ./fix.patch ];`
# - **Swap to minimal package**: e.g. `git -> gitMinimal` to drop Perl closure
#
# Keep overlays “temporary”:
# - Comment with CVE/GHSA, severity, and a removal condition (“remove once nixpkgs >= …”)
# - Link upstream release/PR if possible
#
# ---
#
# Step 4: Validate locally (lightweight)
# Prefer *evaluation* over *building* locally (builds can be expensive).
#
# - Confirm the vulnerable package is gone or version changed:
#   nix path-info -r --system x86_64-linux ./infra#laingville-devcontainer | rg '/perl-|/nodejs-|/pyright-|/pip-' | head -50
#
# If you do build, scope to one image:
# - nix build ./infra#laingville-devcontainer
#
# ---
#
# Step 5: Open PR
# 1) Branch name examples:
# - `chore/security-fix-<cve>`
# - `chore/security-bump-nixpkgs-<date>`
#
# 2) Commit changes (include `.beads/issues.jsonl` if you used bd).
#
# 3) Create PR with a clear “before/after” statement:
# - Which alerts are expected to close
# - Which images are affected
# - Whether this is an upstream bump vs a temporary overlay
#
# 4) After merge, verify:
# - `Security Scan` workflow run on main
# - Open alerts list decreases as expected
#

