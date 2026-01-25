# Security Advisory Response Runbook

## Overview

### Purpose
This runbook guides security teams through responding to security advisories affecting container images in the Laingville infrastructure. It covers the complete workflow from detection through remediation to verification.

### Scope
- **What**: Container image vulnerabilities detected via Dependabot alerts and SARIF scans
- **Where**: GitHub Security tab, Dependabot alerts, SARIF reports
- **When**: Continuous monitoring with automated triage and remediation

### Timeline Expectations
- **Priority 1 (CRITICAL + exploit)**: Immediate response (< 4 hours)
- **Priority 2 (CRITICAL)**: Urgent response (< 24 hours)
- **Priority 3 (HIGH + exploit)**: Soon (< 3 days)
- **Priority 4 (HIGH)**: Planned (< 1 week)
- **Priority 5 (MEDIUM/LOW)**: Backlog (next sprint)

---

## Detection

### How Alerts Are Discovered

Security vulnerabilities are detected through multiple channels:

1. **Dependabot Alerts** (Primary)
   - Automatic scanning of dependencies in `infra/flake.lock`
   - GitHub sends notifications for new CVEs
   - Alerts appear in repository Security tab

2. **SARIF Scans** (Secondary)
   - Container image scanning via Trivy/Grype
   - SARIF reports uploaded to GitHub Code Scanning
   - Provides detailed package-level vulnerability data

3. **Manual Checks**
   - Periodic review of Security tab
   - Upstream security mailing lists
   - CVE databases (NVD, GitHub Advisory Database)

### Where to Find Alerts

**GitHub UI:**
```
Repository → Security → Dependabot alerts
Repository → Security → Code scanning alerts
```

**CLI:**
```bash
# List Dependabot alerts
gh api repos/:owner/:repo/dependabot/alerts

# List code scanning alerts
gh api repos/:owner/:repo/code-scanning/alerts
```

### Alert Types & Severity

| Severity | Description | Example |
|----------|-------------|---------|
| **CRITICAL** | Remote code execution, privilege escalation, data breach | CVE-2024-1234 in openssl (RCE) |
| **HIGH** | Significant security impact, requires authentication | CVE-2024-5678 in curl (auth bypass) |
| **MEDIUM** | Moderate impact, limited scope | CVE-2024-9012 in libxml2 (DoS) |
| **LOW** | Minor impact, difficult to exploit | CVE-2024-3456 in zlib (info disclosure) |

---

## Triage & Prioritization

### Automated Triage

The `bin/security-triage` script automatically scores alerts on a 1-5 scale:

```bash
# Run triage (executed automatically by GitHub Actions)
bin/security-triage --sarif-file security-scan.sarif --output triage-report.json
```

### Priority Levels

**Priority 1: CRITICAL + Exploit Available**
- **Criteria**: CVSS ≥ 9.0 AND known exploit in the wild
- **Action**: Immediate remediation (< 4 hours)
- **Example**: CVE-2024-1234 in openssl with public PoC exploit
- **Response**: Auto-invoke `/security-fix`, emergency deployment

**Priority 2: CRITICAL**
- **Criteria**: CVSS ≥ 9.0 OR CRITICAL severity
- **Action**: Urgent remediation (< 24 hours)
- **Example**: CVE-2024-5678 in glibc (RCE, no public exploit yet)
- **Response**: Auto-invoke `/security-fix`, expedited deployment

**Priority 3: HIGH + Exploit Available**
- **Criteria**: CVSS 7.0-8.9 AND known exploit
- **Action**: Soon (< 3 days)
- **Example**: CVE-2024-9012 in curl with exploit code
- **Response**: Auto-invoke `/security-fix`, normal deployment

**Priority 4: HIGH**
- **Criteria**: CVSS 7.0-8.9 OR HIGH severity
- **Action**: Planned (< 1 week)
- **Example**: CVE-2024-3456 in libxml2 (auth bypass)
- **Response**: Auto-invoke `/security-fix`, scheduled deployment

**Priority 5: MEDIUM/LOW**
- **Criteria**: CVSS < 7.0 OR MEDIUM/LOW severity
- **Action**: Backlog (next sprint)
- **Example**: CVE-2024-7890 in zlib (DoS, local only)
- **Response**: Manual review, batch with other updates

### Identifying Affected Images

**From Triage Report:**
```json
{
  "alert_id": "GHSA-xxxx-yyyy-zzzz",
  "priority": 1,
  "affected_images": [
    "ghcr.io/laingville/web-app:latest",
    "ghcr.io/laingville/api-server:v1.2.3"
  ],
  "vulnerable_package": "openssl",
  "current_version": "3.0.0",
  "fixed_version": "3.0.13"
}
```

**Manual Verification:**
```bash
# Check which images contain vulnerable package
for image in $(docker images --format "{{.Repository}}:{{.Tag}}"); do
  echo "Checking $image..."
  docker run --rm $image dpkg -l | grep openssl
done
```

---

## Remediation Workflow

### Automatic Remediation (Priority 1-4)

For Priority 1-4 alerts, the system automatically invokes Claude `/security-fix`:

**Workflow:**
1. **Trigger**: GitHub Actions detects Priority 1-4 alert
2. **Invocation**: Claude `/security-fix` called with alert details
3. **Execution**: Claude performs remediation steps (see below)
4. **PR Creation**: Automated PR with fix and evidence
5. **Review**: Security team reviews and approves
6. **Deployment**: Merge triggers image rebuild and deployment

**What Claude Does:**
- Updates `infra/flake.lock` (nixpkgs bump to include fix)
- OR adds CVE patch overlay in `infra/overlays/cve-patches.nix`
- Rebuilds affected container images
- Generates new SBOMs
- Runs `bin/sbom-diff` to verify fix
- Creates PR with before/after evidence

### Manual Remediation (Priority 5 or Complex Cases)

**When to Use Manual Remediation:**
- Priority 5 alerts (can batch with other updates)
- Multiple interdependent vulnerabilities
- Upstream fix not available (requires custom patch)
- Breaking changes in fixed version

**Manual Steps:**

#### Step 1: Update Dependencies

**Option A: Nixpkgs Bump (Preferred)**
```bash
# Update flake.lock to latest nixpkgs (includes security fixes)
cd infra/
nix flake update nixpkgs

# Verify the fix is included
nix-shell -p nix-info --run "nix-info -m"
```

**Option B: CVE Patch Overlay (When Upstream Fix Not Available)**
```nix
# infra/overlays/cve-patches.nix
final: prev: {
  openssl = prev.openssl.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      (prev.fetchpatch {
        name = "CVE-2024-1234.patch";
        url = "https://github.com/openssl/openssl/commit/abc123.patch";
        sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
      })
    ];
  });
}
```

#### Step 2: Rebuild Container Images

```bash
# Rebuild affected images
cd infra/
nix build .#container-images.web-app
nix build .#container-images.api-server

# Load into Docker for testing
docker load < result
```

#### Step 3: Generate New SBOMs

```bash
# Generate SBOMs for rebuilt images
bin/generate-sbom --image ghcr.io/laingville/web-app:latest \
  --output sboms/web-app-latest.json

bin/generate-sbom --image ghcr.io/laingville/api-server:v1.2.3 \
  --output sboms/api-server-v1.2.3.json
```

#### Step 4: Verify Fix

```bash
# Compare before/after SBOMs
bin/sbom-diff \
  --before sboms/web-app-latest-old.json \
  --after sboms/web-app-latest.json \
  --cve CVE-2024-1234

# Expected output:
# ✓ CVE-2024-1234 RESOLVED
#   - openssl 3.0.0 (vulnerable) → 3.0.13 (fixed)
```

#### Step 5: Create PR

```bash
# Commit changes
git add infra/flake.lock sboms/
git commit -m "fix(security): resolve CVE-2024-1234 in openssl

- Update nixpkgs to include openssl 3.0.13
- Rebuild web-app and api-server images
- Verified fix via SBOM diff

Resolves: GHSA-xxxx-yyyy-zzzz
Priority: 2 (CRITICAL)"

# Push and create PR
git push origin fix/cve-2024-1234
gh pr create --title "Security: Fix CVE-2024-1234 (openssl RCE)" \
  --body "$(cat PR_TEMPLATE.md)"
```

---

## Verification & Evidence

### Before/After SBOM Comparison

**Purpose**: Prove the vulnerability was remediated

**Command:**
```bash
bin/sbom-diff \
  --before sboms/web-app-latest-before.json \
  --after sboms/web-app-latest-after.json \
  --cve CVE-2024-1234 \
  --output evidence/cve-2024-1234-fix.json
```

**Expected Output:**
```json
{
  "cve": "CVE-2024-1234",
  "status": "RESOLVED",
  "changes": [
    {
      "package": "openssl",
      "before": "3.0.0",
      "after": "3.0.13",
      "vulnerable": false
    }
  ],
  "verification_timestamp": "2024-01-15T10:30:00Z"
}
```

### Verify Vulnerable Package Removed/Updated

**Check Package Version:**
```bash
# In running container
docker run --rm ghcr.io/laingville/web-app:latest dpkg -l | grep openssl
# Expected: openssl 3.0.13 (not 3.0.0)

# In SBOM
jq '.components[] | select(.name == "openssl") | .version' sboms/web-app-latest.json
# Expected: "3.0.13"
```

**Rescan with Trivy:**
```bash
# Scan new image
trivy image --severity CRITICAL,HIGH ghcr.io/laingville/web-app:latest

# Expected: CVE-2024-1234 should NOT appear
```

### Cosign Attestation Verification

**Purpose**: Cryptographically prove the fix was applied

**Generate Attestation:**
```bash
# Sign SBOM with cosign
cosign attest --predicate sboms/web-app-latest.json \
  --type cyclonedx \
  ghcr.io/laingville/web-app:latest

# Verify attestation
cosign verify-attestation \
  --type cyclonedx \
  ghcr.io/laingville/web-app:latest
```

**Attestation Includes:**
- SBOM with fixed package versions
- Timestamp of fix
- Signature from CI/CD system
- Immutable proof for audits

### Dependabot Alert Closure

**Automatic Closure:**
- Dependabot detects fixed version in `flake.lock`
- Alert automatically marked as "Fixed"

**Manual Closure (if needed):**
```bash
# Close alert via GitHub API
gh api -X PATCH repos/:owner/:repo/dependabot/alerts/:alert_number \
  -f state=dismissed \
  -f dismissed_reason=fix_started \
  -f dismissed_comment="Fixed in PR #123"
```

**Verify Closure:**
```
Repository → Security → Dependabot alerts → Closed
```

---

## Example Scenarios

### Scenario 1: Critical CVE in openssl (Common Case)

**Alert:**
- **CVE**: CVE-2024-1234
- **Severity**: CRITICAL (CVSS 9.8)
- **Package**: openssl 3.0.0
- **Exploit**: Public PoC available
- **Priority**: 1 (Immediate)

**Response:**

1. **Detection** (T+0 min):
   - Dependabot alert received
   - `bin/security-triage` scores as Priority 1
   - Affected images: `web-app`, `api-server`

2. **Automatic Remediation** (T+5 min):
   - Claude `/security-fix` auto-invoked
   - Updates `infra/flake.lock` (nixpkgs bump)
   - Rebuilds images with openssl 3.0.13
   - Generates new SBOMs

3. **Verification** (T+10 min):
   - `bin/sbom-diff` confirms openssl 3.0.0 → 3.0.13
   - Trivy rescan shows CVE-2024-1234 resolved
   - cosign attestation generated

4. **PR Review** (T+30 min):
   - Security team reviews automated PR
   - Verifies evidence (SBOM diff, Trivy scan)
   - Approves PR

5. **Deployment** (T+60 min):
   - PR merged
   - CI/CD rebuilds and deploys images
   - Dependabot alert auto-closes

**Total Time**: < 2 hours (within 4-hour SLA)

### Scenario 2: Multiple Packages Affected

**Alert:**
- **CVEs**: CVE-2024-5678 (curl), CVE-2024-9012 (libxml2)
- **Severity**: HIGH (CVSS 7.5 each)
- **Priority**: 4 (Planned)

**Response:**

1. **Detection**:
   - Two separate Dependabot alerts
   - `bin/security-triage` scores both as Priority 4
   - Affected images: `web-app`, `api-server`, `worker`

2. **Batch Remediation**:
   - Single nixpkgs bump fixes both CVEs
   - Claude `/security-fix` handles both in one PR
   - Rebuilds all three images

3. **Verification**:
   - `bin/sbom-diff` shows both packages updated:
     - curl 7.88.0 → 8.0.1
     - libxml2 2.10.0 → 2.11.5
   - Both CVEs resolved in single deployment

**Lesson**: Batch related fixes when priority allows (Priority 4-5)

### Scenario 3: Upstream Fix Not Available (Overlay Needed)

**Alert:**
- **CVE**: CVE-2024-3456
- **Severity**: HIGH (CVSS 8.1)
- **Package**: custom-lib 1.2.3
- **Issue**: Nixpkgs doesn't have fix yet, but upstream has patch

**Response:**

1. **Detection**:
   - Dependabot alert received
   - Priority 3 (HIGH + exploit available)

2. **Manual Remediation** (Overlay):
   ```nix
   # infra/overlays/cve-patches.nix
   final: prev: {
     custom-lib = prev.custom-lib.overrideAttrs (oldAttrs: {
       patches = (oldAttrs.patches or []) ++ [
         (prev.fetchpatch {
           name = "CVE-2024-3456.patch";
           url = "https://github.com/custom-lib/custom-lib/commit/abc123.patch";
           sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
         })
       ];
     });
   }
   ```

3. **Verification**:
   - Build image with overlay
   - Test patch doesn't break functionality
   - Generate SBOM (shows patched version)
   - Document patch in PR

4. **Follow-up**:
   - Monitor nixpkgs for official fix
   - Remove overlay once nixpkgs updated
   - Update documentation

**Lesson**: Overlays are temporary bridges until upstream fixes arrive

---

## Decision Tree

### When to Auto-Fix vs Manual Review

```
┌─────────────────────────────────────┐
│ New Security Alert Detected         │
└─────────────┬───────────────────────┘
              │
              ▼
      ┌───────────────┐
      │ Priority 1-4? │
      └───┬───────┬───┘
          │       │
        YES       NO (Priority 5)
          │       │
          ▼       ▼
    ┌─────────┐ ┌──────────────┐
    │ Auto-   │ │ Manual       │
    │ invoke  │ │ Review       │
    │ /fix    │ │ (Backlog)    │
    └────┬────┘ └──────────────┘
         │
         ▼
    ┌─────────────────┐
    │ Fix Available   │
    │ in Nixpkgs?     │
    └────┬────────┬───┘
         │        │
       YES        NO
         │        │
         ▼        ▼
    ┌────────┐ ┌──────────┐
    │ Flake  │ │ Overlay  │
    │ Update │ │ Patch    │
    └────┬───┘ └────┬─────┘
         │          │
         └────┬─────┘
              │
              ▼
       ┌──────────────┐
       │ Rebuild      │
       │ & Verify     │
       └──────┬───────┘
              │
              ▼
       ┌──────────────┐
       │ Create PR    │
       │ with Evidence│
       └──────────────┘
```

### When to Escalate

**Escalate to Security Lead when:**
- Priority 1 alert cannot be fixed within 4 hours
- Fix requires breaking changes to production
- Multiple interdependent CVEs with complex remediation
- Upstream fix not available and patch is complex
- Alert affects critical production systems

**Escalation Process:**
1. Document current status and blockers
2. Notify security lead via Slack/PagerDuty
3. Provide triage report and affected systems
4. Propose mitigation options (patch, workaround, accept risk)

### When to Document as Accepted Risk

**Criteria for Accepting Risk:**
- Priority 5 (MEDIUM/LOW) with minimal impact
- Exploit requires local access (not exposed)
- Fix introduces breaking changes > risk
- Compensating controls in place (WAF, network isolation)
- Scheduled for next major version upgrade

**Documentation Required:**
```markdown
# Accepted Risk: CVE-2024-7890

**Decision Date**: 2024-01-15
**Decision Maker**: Security Lead (Jane Doe)
**Review Date**: 2024-04-15 (quarterly)

**Vulnerability**:
- CVE: CVE-2024-7890
- Package: zlib 1.2.11
- Severity: MEDIUM (CVSS 5.3)
- Impact: Local DoS only

**Rationale**:
- Requires local shell access (not exposed)
- WAF blocks malicious payloads
- Fix scheduled for Q2 nixpkgs upgrade

**Compensating Controls**:
- Network isolation (no direct internet access)
- Rate limiting on affected endpoints
- Monitoring for exploitation attempts

**Acceptance**: Approved by Security Lead
```

---

## Tools & Commands

### Key Commands for Each Step

**Detection:**
```bash
# List Dependabot alerts
gh api repos/:owner/:repo/dependabot/alerts

# List code scanning alerts
gh api repos/:owner/:repo/code-scanning/alerts

# Download SARIF report
gh api repos/:owner/:repo/code-scanning/sarifs/:sarif_id > scan.sarif
```

**Triage:**
```bash
# Run security triage
bin/security-triage --sarif-file security-scan.sarif --output triage-report.json

# View triage report
jq '.alerts[] | select(.priority <= 2)' triage-report.json
```

**Remediation:**
```bash
# Update nixpkgs
cd infra/ && nix flake update nixpkgs

# Rebuild image
nix build .#container-images.web-app

# Generate SBOM
bin/generate-sbom --image ghcr.io/laingville/web-app:latest --output sboms/web-app.json
```

**Verification:**
```bash
# Compare SBOMs
bin/sbom-diff --before sboms/old.json --after sboms/new.json --cve CVE-2024-1234

# Rescan with Trivy
trivy image --severity CRITICAL,HIGH ghcr.io/laingville/web-app:latest

# Verify attestation
cosign verify-attestation --type cyclonedx ghcr.io/laingville/web-app:latest
```

### Running Security Triage Locally

**Prerequisites:**
```bash
# Install dependencies
pip install -r requirements.txt

# Ensure SARIF file available
trivy image --format sarif --output scan.sarif ghcr.io/laingville/web-app:latest
```

**Run Triage:**
```bash
# Basic triage
bin/security-triage --sarif-file scan.sarif

# With custom priority thresholds
bin/security-triage --sarif-file scan.sarif \
  --critical-threshold 9.0 \
  --high-threshold 7.0

# Output to JSON for automation
bin/security-triage --sarif-file scan.sarif --output triage.json

# Filter by priority
jq '.alerts[] | select(.priority == 1)' triage.json
```

### Verifying Fixes

**SBOM Verification:**
```bash
# Generate before SBOM (from old image)
docker pull ghcr.io/laingville/web-app:v1.0.0
bin/generate-sbom --image ghcr.io/laingville/web-app:v1.0.0 --output before.json

# Generate after SBOM (from new image)
docker pull ghcr.io/laingville/web-app:v1.0.1
bin/generate-sbom --image ghcr.io/laingville/web-app:v1.0.1 --output after.json

# Compare
bin/sbom-diff --before before.json --after after.json --cve CVE-2024-1234
```

**Package Version Verification:**
```bash
# Check package in running container
docker run --rm ghcr.io/laingville/web-app:latest dpkg -l | grep openssl

# Check package in SBOM
jq '.components[] | select(.name == "openssl")' sboms/web-app.json
```

**Vulnerability Rescan:**
```bash
# Scan with Trivy
trivy image --severity CRITICAL,HIGH ghcr.io/laingville/web-app:latest

# Scan with Grype
grype ghcr.io/laingville/web-app:latest --only-fixed

# Compare scan results
diff <(trivy image old-image) <(trivy image new-image)
```

---

## Appendix: Quick Reference

### Priority Matrix

| Priority | Severity | Exploit | Timeline | Action |
|----------|----------|---------|----------|--------|
| 1 | CRITICAL | YES | < 4 hours | Auto-fix + Emergency deploy |
| 2 | CRITICAL | NO | < 24 hours | Auto-fix + Expedited deploy |
| 3 | HIGH | YES | < 3 days | Auto-fix + Normal deploy |
| 4 | HIGH | NO | < 1 week | Auto-fix + Scheduled deploy |
| 5 | MEDIUM/LOW | ANY | Next sprint | Manual review + Batch deploy |

### Common CVE Patterns

| Package | Common CVEs | Fix Strategy |
|---------|-------------|--------------|
| openssl | RCE, crypto flaws | Nixpkgs bump (frequent updates) |
| glibc | RCE, privilege escalation | Nixpkgs bump (critical path) |
| curl | SSRF, auth bypass | Nixpkgs bump (frequent updates) |
| libxml2 | XXE, DoS | Nixpkgs bump or overlay |
| zlib | DoS, buffer overflow | Nixpkgs bump (stable) |

### Useful Links

- **Dependabot Alerts**: `https://github.com/:owner/:repo/security/dependabot`
- **Code Scanning**: `https://github.com/:owner/:repo/security/code-scanning`
- **NVD Database**: `https://nvd.nist.gov/vuln/search`
- **GitHub Advisory DB**: `https://github.com/advisories`
- **Nixpkgs Security**: `https://github.com/NixOS/nixpkgs/issues?q=is%3Aissue+label%3A"1.severity%3A+security"`

---

## Changelog

- **2024-01-15**: Initial runbook created
- Document version: 1.0.0
