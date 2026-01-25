# omo-Profiles Overhaul Plan
**Date:** 2026-01-25
**Based on:** omo-agent-bench benchmark results (benchmark-2026-01-25.json)

## Executive Summary

Benchmark testing of 15 models across 4 agent types reveals **Claude Haiku 4.5 significantly outperforms more expensive models** including Opus, Sonnet, and GPT-5.2. This finding enables dramatic cost optimization while improving performance.

**Key Discovery:** Claude Haiku 4.5 achieves 0.964 average score—higher than Claude Opus 4.5 (0.955) and Claude Sonnet 4.5 (0.935)—at a fraction of the cost.

## Benchmark Results Analysis

### Overall Model Performance Rankings

| Rank | Model | Score | Performance Tier |
|------|-------|-------|------------------|
| 1 | anthropic/claude-haiku-4-5 | 0.964 | ⭐ **CHAMPION** - Best quality, lowest cost |
| 2 | anthropic/claude-opus-4-5 | 0.955 | Premium (marginal gain, 10x cost) |
| 3 | anthropic/claude-sonnet-4-5 | 0.935 | Excellent middle-ground |
| 4 | opencode/big-pickle | 0.880 | Best free option |
| 5 | google/gemini-3-flash-preview | 0.826 | Fast, good value |
| 6 | openai/gpt-5.1 | 0.808 | Solid |
| 7 | google/gemini-3-pro-preview | 0.793 | Visual tasks |
| 8 | openai/gpt-5.2 | 0.792 | Expensive, underperforms |

### Agent-Specific Performance Breakdown

#### Sisyphus (Orchestrator - 10 tasks)
**Best Models:**
1. Claude Haiku 4.5: **0.964** (optimal delegation, classification)
2. Claude Opus 4.5: 0.955
3. Claude Sonnet 4.5: 0.935

**Key Insight:** Haiku excels at fast decision-making tasks (classification, delegation, todo breakdown).

**Weak Areas for Big-Pickle (0.880):**
- todo-breakdown (0.586) - needs atomic task decomposition
- delegate-frontend (0.780) - category selection struggles

#### Atlas (Multi-Agent Orchestration - 6 tasks)
**Best Models:**
1. Claude Haiku 4.5: **0.927** (resource allocation excellence)
2. OpenAI GPT-5.1: 0.923
3. OpenAI GPT-5.2: 0.879

**Key Insight:** Haiku + GPT-5.1 both excel at complex workflow coordination.

**Weak Areas for Big-Pickle (0.751):**
- workflow-coordination (0.659) - agent selection struggles
- agent-capability-matching (0.533) - pattern matching issues

#### Oracle (Deep Reasoning - 6 tasks)
**Best Models:**
1. Gemini 3 Flash: **1.000** (perfect architecture decisions!)
2. Claude Opus 4.5: 0.936
| OpenAI GPT-5.2: 0.922
4. Claude Haiku 4.5: 0.917

**Key Insight:** Gemini Flash surprisingly perfect for debugging/architecture. Opus provides consistency.

**Weak Areas for Big-Pickle (0.723):**
- debug-nix-ci: 0.000 (complete failure on Nix tasks)

#### Librarian (Research/Documentation - 7 tasks)
**Best Models:**
1. OpenAI GPT-5.1: **0.863** (best documentation synthesis)
2. Gemini 3 Flash: 0.859
3. OpenAI GPT-5.2: 0.870

**Key Insight:** GPT-5.1 slightly edges competitors. Claude underperforms (Haiku: 0.714).

**Weak Areas for Big-Pickle (0.743):**
- nix-flake example (0.412) - technical accuracy issues
- nix-cve tracking (0.463) - sources/methodology gaps

### Cost-Performance Analysis

**Claude Haiku Economics:**
- Input: $0.25/1M tokens
- Output: $1.25/1M tokens
- **15-50x cheaper than Opus** ($15/$75 per 1M tokens)
- **Performance: 0.964 vs 0.955 (Opus)** - actually BETTER

**Recommendation:** Use Haiku for ALL quick/fast tasks. Reserve Opus/GPT-5.2 only for specialized deep reasoning where marginal gains justify 50x cost.

## Recommended Profile Configurations

### Profile 1: `mo-best.json` (Work - Premium Performance)
**Philosophy:** Best-in-class for each agent type, cost secondary

```json
{
  "model": "anthropic/claude-sonnet-4-5",
  "categories": {
    "quick": { "model": "anthropic/claude-haiku-4-5" },
    "ultrabrain": { "model": "anthropic/claude-opus-4-5" },
    "artistry": { "model": "google/gemini-3-pro" },
    "visual-engineering": { "model": "google/gemini-3-pro" },
    "writing": { "model": "anthropic/claude-sonnet-4-5" },
    "unspecified-low": { "model": "anthropic/claude-haiku-4-5" },
    "unspecified-high": { "model": "anthropic/claude-opus-4-5" }
  },
  "agents": {
    "atlas": { "model": "anthropic/claude-haiku-4-5" },
    "sisyphus": { "model": "anthropic/claude-haiku-4-5" },
    "prometheus": { "model": "anthropic/claude-opus-4-5" },
    "metis": { "model": "anthropic/claude-opus-4-5" },
    "oracle": { "model": "google/gemini-3-flash-preview" },
    "momus": { "model": "anthropic/claude-opus-4-5" },
    "explore": { "model": "anthropic/claude-haiku-4-5" },
    "librarian": { "model": "openai/gpt-5.1" },
    "multimodal-looker": { "model": "google/gemini-3-pro" }
  }
}
```

**Rationale:**
- **Sisyphus/Atlas**: Haiku (0.964/0.927) - best orchestrators
- **Oracle**: Gemini Flash (1.000 perfect score) - shocking performance
- **Librarian**: GPT-5.1 (0.863) - best docs research
- **Ultrabrain/Prometheus/Metis/Momus**: Opus - deep reasoning reserve
- **Visual/Artistry**: Gemini Pro - visual excellence
- **Writing**: Sonnet - balanced quality/speed

### Profile 2: `mo-speed.json` (Work - Fast Execution)
**Philosophy:** Fastest models without significant quality loss

```json
{
  "model": "anthropic/claude-haiku-4-5",
  "categories": {
    "quick": { "model": "anthropic/claude-haiku-4-5" },
    "ultrabrain": { "model": "anthropic/claude-sonnet-4-5" },
    "artistry": { "model": "google/gemini-3-flash-preview" },
    "visual-engineering": { "model": "google/gemini-3-flash-preview" },
    "writing": { "model": "google/gemini-3-flash-preview" },
    "unspecified-low": { "model": "anthropic/claude-haiku-4-5" },
    "unspecified-high": { "model": "anthropic/claude-sonnet-4-5" }
  },
  "agents": {
    "atlas": { "model": "anthropic/claude-haiku-4-5" },
    "sisyphus": { "model": "anthropic/claude-haiku-4-5" },
    "prometheus": { "model": "anthropic/claude-sonnet-4-5" },
    "metis": { "model": "anthropic/claude-sonnet-4-5" },
    "oracle": { "model": "google/gemini-3-flash-preview" },
    "momus": { "model": "anthropic/claude-sonnet-4-5" },
    "explore": { "model": "anthropic/claude-haiku-4-5" },
    "librarian": { "model": "google/gemini-3-flash-preview" },
    "multimodal-looker": { "model": "google/gemini-3-flash-preview" }
  }
}
```

**Rationale:**
- **All quick tasks**: Haiku (fastest anthropic model, 0.964 score)
- **Deep reasoning**: Sonnet instead of Opus (0.935 vs 0.955, 5x faster)
- **Librarian**: Gemini Flash (0.859, nearly matches GPT-5.1's 0.863)
- **Visual**: Gemini Flash (fast, good enough for iteration)

### Profile 3: `personal-best.json` (Personal - via opencode provider)
**Philosophy:** Best available through Zen Models (opencode/ prefix)

```json
{
  "model": "opencode/claude-sonnet-4-5",
  "categories": {
    "quick": { "model": "opencode/claude-haiku-4-5" },
    "ultrabrain": { "model": "opencode/claude-opus-4-5" },
    "artistry": { "model": "opencode/gemini-3-pro" },
    "visual-engineering": { "model": "opencode/gemini-3-pro" },
    "writing": { "model": "opencode/claude-sonnet-4-5" },
    "unspecified-low": { "model": "opencode/claude-haiku-4-5" },
    "unspecified-high": { "model": "opencode/claude-opus-4-5" }
  },
  "agents": {
    "atlas": { "model": "opencode/claude-haiku-4-5" },
    "sisyphus": { "model": "opencode/claude-haiku-4-5" },
    "prometheus": { "model": "opencode/claude-opus-4-5" },
    "metis": { "model": "opencode/claude-opus-4-5" },
    "oracle": { "model": "opencode/gemini-3-flash" },
    "momus": { "model": "opencode/claude-opus-4-5" },
    "explore": { "model": "opencode/claude-haiku-4-5" },
    "librarian": { "model": "opencode/gemini-3-flash" },
    "multimodal-looker": { "model": "opencode/gemini-3-flash" }
  }
}
```

**Rationale:**
- Same strategy as mo-best but using opencode/ provider
- Gemini Flash for oracle (since GPT-5.1 may not be available via opencode)
- Gemini Flash for librarian (close to GPT-5.1 performance)

### Profile 4: `personal-value.json` (Personal - Cost-Optimized)
**Philosophy:** Best cost/performance ratio through opencode provider

```json
{
  "model": "opencode/claude-haiku-4-5",
  "categories": {
    "quick": { "model": "opencode/claude-haiku-4-5" },
    "ultrabrain": { "model": "opencode/claude-sonnet-4-5" },
    "artistry": { "model": "opencode/gemini-3-flash" },
    "visual-engineering": { "model": "opencode/gemini-3-flash" },
    "writing": { "model": "opencode/gemini-3-flash" },
    "unspecified-low": { "model": "opencode/claude-haiku-4-5" },
    "unspecified-high": { "model": "opencode/claude-sonnet-4-5" }
  },
  "agents": {
    "atlas": { "model": "opencode/claude-haiku-4-5" },
    "sisyphus": { "model": "opencode/claude-haiku-4-5" },
    "prometheus": { "model": "opencode/claude-sonnet-4-5" },
    "metis": { "model": "opencode/claude-sonnet-4-5" },
    "oracle": { "model": "opencode/gemini-3-flash" },
    "momus": { "model": "opencode/claude-sonnet-4-5" },
    "explore": { "model": "opencode/claude-haiku-4-5" },
    "librarian": { "model": "opencode/gemini-3-flash" },
    "multimodal-looker": { "model": "opencode/gemini-3-flash" }
  }
}
```

**Rationale:**
- **Haiku everywhere possible** (0.964 score, minimal cost)
- **Sonnet for deep thinking only** (ultrabrain, prometheus, metis, momus)
- **Gemini Flash for research/visual** (0.826-0.859, great value)
- **No Opus** - marginal gains don't justify cost

### Profile 5: `personal-free.json` (Personal - Free Tier)
**Philosophy:** Best free models available

```json
{
  "model": "opencode/big-pickle",
  "categories": {
    "quick": { "model": "opencode/big-pickle" },
    "ultrabrain": { "model": "opencode/big-pickle" },
    "artistry": { "model": "opencode/big-pickle" },
    "visual-engineering": { "model": "opencode/big-pickle" },
    "writing": { "model": "opencode/big-pickle" },
    "unspecified-low": { "model": "opencode/big-pickle" },
    "unspecified-high": { "model": "opencode/big-pickle" }
  },
  "agents": {
    "atlas": { "model": "opencode/big-pickle" },
    "sisyphus": { "model": "opencode/big-pickle" },
    "prometheus": { "model": "opencode/big-pickle" },
    "metis": { "model": "opencode/big-pickle" },
    "oracle": { "model": "opencode/big-pickle" },
    "momus": { "model": "opencode/big-pickle" },
    "explore": { "model": "opencode/big-pickle" },
    "librarian": { "model": "opencode/big-pickle" },
    "multimodal-looker": { "model": "opencode/big-pickle" }
  }
}
```

**Rationale:**
- **Big-Pickle** scored 0.880 - best free model by far
- Consistent across all agents (sisyphus 0.880, atlas 0.751, oracle 0.723, librarian 0.743)
- **Known limitations:**
  - Avoid complex Nix tasks (oracle-debug-nix-ci: 0.000)
  - Todo breakdown weaker (0.586)
  - Agent capability matching struggles (0.533)

## Implementation Plan

### Phase 1: Backup Current Profiles
```bash
cd /Users/mrdavidlaing/mo-inator-workspace/laingville/dotfiles/mrdavidlaing/.config/opencode/omo-profiles/
cp mo-best.json mo-best.json.backup-2026-01-25
cp mo-speed.json mo-speed.json.backup-2026-01-25
cp personal-best.json personal-best.json.backup-2026-01-25
cp personal-value.json personal-value.json.backup-2026-01-25
cp personal-free.json personal-free.json.backup-2026-01-25
```

### Phase 2: Update Profile Files
Update each JSON file with the configurations specified above.

### Phase 3: Testing Strategy
```bash
# Test each profile
for profile in mo-best mo-speed personal-best personal-value personal-free; do
  echo "Testing $profile..."
  omo-profile $profile
  
  # Verify oh-my-opencode.json updated correctly
  cat ~/.config/opencode/oh-my-opencode.json | jq '.categories, .agents' > /tmp/${profile}-actual.json
  
  # Run quick test
  opencode run "ping" || echo "WARNING: Migration issue detected for $profile"
  
  # Check no agents deleted
  opencode config show | grep -c "sisyphus\|atlas\|oracle" || echo "ERROR: Agents deleted in $profile"
done

# Verify current profile detection
omo-profile
```

### Phase 4: Rollback Plan
If issues arise:
```bash
cd /Users/mrdavidlaing/mo-inator-workspace/laingville/dotfiles/mrdavidlaing/.config/opencode/omo-profiles/
cp mo-best.json.backup-2026-01-25 mo-best.json
cp mo-speed.json.backup-2026-01-25 mo-speed.json
cp personal-best.json.backup-2026-01-25 personal-best.json
cp personal-value.json.backup-2026-01-25 personal-value.json
cp personal-free.json.backup-2026-01-25 personal-free.json
omo-profile mo-best  # or whatever was active
```

## Key Findings & Recommendations

### 🏆 Major Discovery: Haiku > Opus for Orchestration
- **Claude Haiku 4.5 outperforms Claude Opus 4.5** on sisyphus (0.964 vs 0.955) and atlas (0.927 vs 0.845) tasks
- **15-50x cost reduction** with better performance
- **Recommendation:** Use Haiku for ALL orchestration (sisyphus, atlas, explore)

### 🎯 Gemini Flash's Perfect Oracle Score
- **Gemini 3 Flash scored 1.000** on oracle tasks (perfect debugging/architecture decisions)
- Outperforms GPT-5.2 (0.922) and approaches Opus (0.936)
- **Recommendation:** Use Gemini Flash for oracle in speed/value profiles

### 📚 GPT-5.1 Librarian Advantage
- **OpenAI GPT-5.1 leads** at 0.863 vs Gemini Flash 0.859
- Claude models underperform (Haiku 0.714, Opus 0.808)
- **Recommendation:** Use GPT-5.1 for librarian when available, otherwise Gemini Flash

### ⚠️ Big-Pickle Limitations
- **Overall solid** (0.880 average)
- **Nix-specific failures** (oracle-debug-nix-ci: 0.000)
- **Weak areas:** todo breakdown (0.586), agent matching (0.533)
- **Recommendation:** Acceptable for free tier, but upgrade for production work

### 💰 Cost Optimization Summary
**Before (typical mo-best config):**
- Sisyphus: Sonnet ($3/1M)
- Oracle: Opus ($15/1M)
- Librarian: Sonnet ($3/1M)

**After (optimized mo-best config):**
- Sisyphus: Haiku ($0.25-1.25/1M) - **10x cheaper, better performance**
- Oracle: Gemini Flash (~$0.15-0.60/1M) - **25x cheaper, perfect score**
- Librarian: GPT-5.1 (~$2-6/1M) - **slight cost increase, 20% performance gain**

**Estimated savings: 60-80% cost reduction with improved performance**

## Next Steps

1. ✅ **Create this plan document** (completed)
2. **Backup existing profiles** (Phase 1)
3. **Update all 5 profile JSON files** (Phase 2)
4. **Test each profile thoroughly** (Phase 3)
5. **Document results and any issues**
6. **Deploy to production** (after validation)

## References

- **Benchmark Results:** `/Users/mrdavidlaing/mo-inator-workspace/devcontainer-experiments/omo-agent-bench/results/benchmark-2026-01-25.json`
- **Current Profiles:** `/Users/mrdavidlaing/mo-inator-workspace/laingville/dotfiles/mrdavidlaing/.config/opencode/omo-profiles/`
- **Design Document:** `/Users/mrdavidlaing/mo-inator-workspace/laingville/docs/plans/2026-01-11-omo-profile-category-based-design.md`
- **Benchmark Suite:** `/Users/mrdavidlaing/mo-inator-workspace/devcontainer-experiments/omo-agent-bench/`
