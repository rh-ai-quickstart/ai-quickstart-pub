# Automated Documentation Review System - Technical Specification

**Version:** 1.0  
**Date:** 2026-06-05  
**Status:** Draft  
**Author:** @keklundrh + AI-assisted design session

---

## 1. Overview

### 1.0 Executive Summary

**What:** Automated documentation review system that validates quickstart READMEs against Red Hat standards.

**How it runs:**
- **Identity:** GitHub App bot (`AI Quickstart Doc Reviewer`) - NOT your personal account
- **Trigger:** Automatically on every PR that modifies a submodule in `quickstart/`
- **Process:** Reviews README → Creates issues in source repos → Posts summary comment on PR
- **You review:** The bot's summary comment + linked issues (not the raw README)

**Setup required:**
1. Create GitHub App (one-time, org admin required) - **See §10.1**
2. Install app on repos (one-time) - **See §10.1**
3. Configure secrets (ANTHROPIC_API_KEY, app credentials) - **See §10.2**
4. Implement workflow (code in this PR branch) - **See §6**

**What you do:**
- Review the bot's PR comment summary
- Check linked issues in source repos
- Approve PR when satisfied with quality
- Bot handles all the tedious review work

### 1.1 Problem Statement

Currently, the `ai-quickstart-pub` repository accepts PRs with submodule links to standalone quickstart repositories. When merged to main, the README contents are published to a [Red Hat website](https://www.docs.redhat.com/learn/ai-quickstarts). The current review process relies on a manual checklist in the PR template, which:

- Is time-consuming and error-prone
- Lacks consistency across reviewers
- Cannot automatically track fixes across submodule updates
- Doesn't provide actionable feedback in the source repositories
- AI quickstart contributors are asking for a review time SLA which is unrealistic given quantity

### 1.2 Goals

**Primary Goals:**
- Automate documentation quality review against Red Hat standards
- Provide actionable feedback to source repository maintainers
- Track review findings across submodule updates
- Enable efficient review workflow for publication approvers

**Non-Goals:**
- Reviewing code quality in source repositories
- Automated merging or auto-fixing of issues
- Reviewing anything beyond README documentation (initially)

### 1.3 Success Criteria

- ✅ Reviews trigger automatically on PR open/update
- ✅ Findings are categorized by severity (blocker, major, minor, suggestion)
- ✅ Issues are created in source repos for each finding
- ✅ Issues are clearly linked together as part of the automated publication review
- ✅ PR comment provides at-a-glance review summary
- ✅ Re-reviews detect resolved issues and update accordingly
- ✅ Reviewer can approve PR based primarily on automated review feedback

---

## 2. Background & Context

### 2.1 Repository Structure

```
ai-quickstart-pub/          (this repo - publication mechanism)
├── quickstart/
│   ├── demo-app/           (git submodule → source repo with README for publication)
│   ├── rag-example/        (git submodule → source repo with README for publication)
└── ...

ai-quickstart-contrib/      (requirements & standards repo)
├── docs/
│   ├── CONTRIBUTING.md
│   ├── PUBLISHING.md
└── ...

source-repo-1/              (individual quickstart)
├── README.md               (reviewed content)
├── src/
└── ...
```

### 2.2 Current Workflow

1. Developer creates PR in `ai-quickstart-pub` with submodule update
2. Reviewer manually checks against PR template checklist
3. Feedback is given in PR comments (but changes must be made in source repo)
4. Developer updates source repo, updates submodule in PR
5. Reviewer re-checks manually
6. Repeat until approved
7. Merge publishes to Red Hat website

### 2.3 Constraints & Requirements

- **One submodule per PR** - Simplifies detection and review logic
- **Review scope** - README only (for now)
- **Requirements sources** - All in `ai-quickstart-contrib` repository
- **Write access** - System has permissions to create issues in source repos
- **Merge blocking** - PRs are always blocked until resolved (standard practice)
- **Cross-repo coordination** - Feedback must be actionable where changes happen

---

## 3. Architecture

### 3.1 High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                     PR Event (opened/sync)                   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              GitHub Actions Workflow                         │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ 1. Detect Changed Submodule                         │   │
│  │ 2. Extract README from Submodule                    │   │
│  │ 3. Fetch Requirements from ai-quickstart-contrib    │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                  Claude API Review                           │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Input: README + Requirements Docs                   │   │
│  │ Output: Structured Findings (JSON)                  │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              Issue Management (Source Repo)                  │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Create issues for new findings                    │   │
│  │ • Close issues for resolved findings                │   │
│  │ • Update issues for changed findings                │   │
│  │ • Track state via PR comment metadata               │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              PR Comment Dashboard Update                     │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ • Summary with severity counts                      │   │
│  │ • Links to all open issues                          │   │
│  │ • Track resolved items                              │   │
│  └─────────────────────────────────────────────────────┘   │
└───────────────────────┬─────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│             Human Review & Approval                          │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 Component Breakdown

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Trigger** | GitHub Actions (PR events) | Detect when review needed |
| **Submodule Detector** | Shell script / git commands | Identify which submodule changed |
| **Content Extractor** | git submodule commands | Get README content |
| **Requirements Fetcher** | GitHub API / git clone | Get latest requirements docs |
| **Review Engine** | Claude API (Sonnet 4.x) | Perform intelligent review |
| **Issue Manager** | GitHub API (Octokit) | Create/update/close issues |
| **State Tracker** | HTML comment in PR | Persist findings across runs |
| **Comment Generator** | Markdown template | Display review summary |

---

## 4. Detailed Design

### 4.1 GitHub Action Workflow

**File:** `.github/workflows/doc-review.yml`

**Trigger Configuration:**
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'quickstart/**'
```

**Job Steps:**
1. **Generate App Token** - Create installation token from GitHub App credentials
2. **Checkout** - Clone PR with submodules using app token
3. **Detect Submodule** - Identify changed submodule path and source repo URL
4. **Extract README** - Get README.md from submodule
5. **Fetch Requirements** - Clone/fetch docs from `ai-quickstart-contrib`
6. **Review** - Call Claude API with review prompt
7. **Manage Issues** - Create/update/close issues in source repo (using app token)
8. **Update PR Comment** - Post/update summary dashboard (as bot)
9. **Set Status** - Report check status (informational only, not blocking)

**Workflow Sketch:**
```yaml
name: Documentation Review
on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'quickstart/**'

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write  # For PR comments
      contents: read        # For checkout
    
    steps:
      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.DOC_REVIEW_APP_ID }}
          private-key: ${{ secrets.DOC_REVIEW_APP_PRIVATE_KEY }}
      
      - name: Checkout PR with submodules
        uses: actions/checkout@v4
        with:
          token: ${{ steps.app-token.outputs.token }}
          submodules: recursive
          fetch-depth: 0  # Need history to detect changes
      
      - name: Detect changed submodule
        id: detect
        run: |
          # Script to detect which submodule changed
          # Sets outputs: submodule_path, source_repo, source_org, source_name
      
      - name: Extract README from submodule
        id: readme
        run: |
          # Read README.md from submodule path
          # Set output: readme_content
      
      - name: Fetch requirements docs
        run: |
          # Clone ai-quickstart-contrib
          # Read CONTRIBUTING.md, PUBLISHING.md, etc.
      
      - name: Review with Claude API
        id: review
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          # Call Claude API with README + requirements
          # Parse JSON response
          # Set output: findings (JSON)
      
      - name: Manage issues in source repo
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Compare findings to previous state
          # Create/update/close issues in source repo
          # Track issue URLs
      
      - name: Update PR comment
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Generate markdown comment with dashboard
          # Create or update PR comment
          # Embed state in HTML comment
```

**Environment Variables Required:**
- `ANTHROPIC_API_KEY` - For Claude API access
- `GITHUB_TOKEN` - For GitHub API (issues, comments)

#### 4.1.1 Authentication & Execution Context

**Best Practice: GitHub App (Recommended)**

The workflow should run as a **GitHub App** rather than a personal account. Here's why:

**✅ GitHub App Benefits:**
- Dedicated bot identity (e.g., "doc-review-bot[bot]")
- Fine-grained permissions per repository
- Higher rate limits (5000 requests/hour per installation)
- No dependency on individual user accounts
- Audit trail shows bot actions, not personal actions
- Works even if user leaves organization
- Can be granted cross-repo write access cleanly

**❌ Personal Account Issues:**
- Actions appear as your commits/comments
- Requires personal access token (PAT) with broad permissions
- PAT expires and needs rotation
- If you leave org, bot breaks
- Harder to audit (mixed with your real activity)

**🟡 Default GITHUB_TOKEN (Not Sufficient):**
- Only has write access to the current repo
- Cannot create issues in source repos (different repositories)
- Read-only for other repos in the org

**Implementation Path:**

1. **Create GitHub App** (Organization-level)
   - Name: `AI Quickstart Doc Reviewer`
   - Permissions:
     - Repository permissions:
       - Issues: Read & Write (to create/close issues)
       - Pull Requests: Read & Write (to comment)
       - Contents: Read (to read submodules)
     - Organization permissions: None required
   
2. **Install App** on all relevant repositories:
   - `ai-quickstart-pub` (this repo)
   - `ai-quickstart-contrib` (requirements repo)
   - All source quickstart repos (for issue creation)

3. **Generate Installation Token** in workflow:
   ```yaml
   jobs:
     doc-review:
       runs-on: ubuntu-latest
       steps:
         - name: Generate GitHub App Token
           id: app-token
           uses: actions/create-github-app-token@v1
           with:
             app-id: ${{ secrets.APP_ID }}
             private-key: ${{ secrets.APP_PRIVATE_KEY }}
             repositories: |
               ai-quickstart-pub
               ai-quickstart-contrib
               # Will also work for any repo the app is installed on
         
         - name: Checkout with submodules
           uses: actions/checkout@v4
           with:
             token: ${{ steps.app-token.outputs.token }}
             submodules: recursive
         
         # Use this token for all GitHub API calls
         - name: Create issues
           env:
             GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
           run: |
             # Script to create issues in source repos
   ```

4. **Store Secrets**:
   - `APP_ID`: GitHub App ID (from app settings)
   - `APP_PRIVATE_KEY`: Private key generated for the app
   - `ANTHROPIC_API_KEY`: Claude API key

**Alternative: Fine-Grained PAT (Acceptable but less ideal)**

If GitHub App setup is blocked organizationally:

1. Create a machine/service user account (e.g., `rh-ai-doc-bot`)
2. Generate fine-grained PAT with:
   - Repositories: All quickstart repos + ai-quickstart-pub + ai-quickstart-contrib
   - Permissions: Issues (read/write), Pull Requests (read/write), Contents (read)
   - Expiration: 90 days (set reminder to rotate)
3. Store as `BOT_GITHUB_TOKEN` secret
4. Use in workflow: `token: ${{ secrets.BOT_GITHUB_TOKEN }}`

**Decision Matrix:**

| Approach | Setup Effort | Maintenance | Security | Auditability | Recommendation |
|----------|-------------|-------------|----------|--------------|----------------|
| GitHub App | Medium | Low | ✅ Best | ✅ Clear bot identity | **RECOMMENDED** |
| Machine User + PAT | Low | Medium | 🟡 Good | 🟡 Separate account | Acceptable |
| Personal PAT | Low | High | ❌ Risky | ❌ Mixed with personal | Avoid |
| Default GITHUB_TOKEN | None | None | ✅ Safe | ✅ Built-in | ❌ Insufficient permissions |

**Recommended Setup: GitHub App**

### 4.2 Submodule Detection Logic

```bash
# Detect changed submodules in PR
git diff --submodule=diff origin/$BASE_BRANCH...$HEAD_SHA -- quickstart/

# Extract:
# - Submodule path (e.g., quickstart/demo-app)
# - Source repo URL (from .gitmodules)
# - Current commit SHA
# - Source repo org/name (for issue creation)
```

**Validation:**
- Exactly one submodule changed (fail if multiple)
- Submodule contains README.md (fail if missing)

### 4.3 Claude API Integration

#### 4.3.1 Review Prompt Structure

**System Prompt:**
```
You are a technical documentation reviewer for Red Hat AI quickstart guides.
Your job is to review README documentation against Red Hat standards and best practices.

You will be provided:
1. The README content to review
2. Quickstart requirements documentation
3. README template/structure requirements
4. Red Hat writing style guide

Analyze the README and identify any issues, categorized by severity:
- BLOCKER: Must fix before publication (missing required sections, incorrect trademarks)
- MAJOR: Should fix (structural issues, significant style violations)
- MINOR: Nice to have (minor formatting, consistency)
- SUGGESTION: Optional improvements (enhancements, recommendations)

Provide specific, actionable feedback with references to which requirement was violated.
```

**User Prompt Template:**
```
# README to Review

{README_CONTENT}

# Requirements Documents

## Quickstart Requirements
{QUICKSTART_REQUIREMENTS}

## README Template
{README_TEMPLATE}

## Red Hat Writing Guide
{REDHAT_WRITING_GUIDE}

# Task

Review the README and output findings in the following JSON structure:
{JSON_SCHEMA}
```

#### 4.3.2 Response Schema

```json
{
  "summary": {
    "total_findings": 8,
    "blockers": 2,
    "major": 3,
    "minor": 2,
    "suggestions": 1
  },
  "findings": [
    {
      "id": "hash-of-finding",
      "severity": "blocker",
      "category": "structure",
      "title": "Missing Prerequisites section",
      "description": "The README must include a Prerequisites section per quickstart-requirements.md §3.2. This section should list all required software, versions, and access requirements.",
      "location": "Top-level sections",
      "requirement_ref": "quickstart-requirements.md §3.2",
      "suggested_fix": "Add a ## Prerequisites section before Installation"
    },
    {
      "id": "hash-of-finding",
      "severity": "major",
      "category": "style",
      "title": "Inconsistent heading hierarchy",
      "description": "Heading levels skip from H2 to H4 without an H3 in between. Per README template, maintain consistent heading hierarchy.",
      "location": "Installation section, line 45",
      "requirement_ref": "readme-template.md - Heading Structure",
      "suggested_fix": "Change '#### Configure Settings' to '### Configure Settings'"
    }
  ]
}
```

**Finding ID Generation:**
```javascript
// Stable hash for tracking findings across reviews
const findingId = hash(
  category + title + location + requirement_ref
);
```

### 4.4 Issue Management Logic

#### 4.4.1 State Tracking

**Storage:** Embedded in PR comment as HTML comment (invisible to users)

```html
<!-- doc-review-state
{
  "review_run_id": "abc123-20260605143045",
  "submodule_sha": "def456",
  "findings": {
    "finding-hash-1": {
      "issue_url": "https://github.com/org/repo/issues/123",
      "issue_number": 123,
      "status": "open",
      "created_at": "2026-06-05T14:30:45Z"
    },
    "finding-hash-2": {
      "issue_url": "https://github.com/org/repo/issues/124",
      "issue_number": 124,
      "status": "open",
      "created_at": "2026-06-05T14:30:45Z"
    }
  }
}
-->
```

#### 4.4.2 Issue Lifecycle

**On Each Review Run:**

```javascript
previous_findings = extract_state_from_pr_comment()
current_findings = claude_review_results

// New findings
new_findings = current_findings - previous_findings
for (finding in new_findings) {
  issue = create_issue(finding)
  track_issue(finding.id, issue.url)
}

// Resolved findings
resolved = previous_findings - current_findings
for (finding_id in resolved) {
  issue = get_tracked_issue(finding_id)
  close_issue(issue, "Fixed in submodule commit {SHA}")
}

// Changed findings (same ID, different description)
for (finding in current_findings) {
  if (finding.id in previous_findings 
      && finding.description != previous[finding.id].description) {
    issue = get_tracked_issue(finding.id)
    update_issue(issue, finding.description)
  }
}

// Unchanged findings - no action needed
```

#### 4.4.3 Issue Template

**Title:** `[Doc Review] {finding.title}`

**Body:**
```markdown
## Automated Documentation Review Finding

**Severity:** {severity_emoji} {SEVERITY}
**Category:** {category}

### Description
{finding.description}

### Location
{finding.location}

### Requirement Reference
{finding.requirement_ref}

### Suggested Fix
{finding.suggested_fix}

---

**Context:**
- Publication PR: {pr_url}
- Submodule commit: {sha}
- Reviewed: {timestamp}

**Labels:** `documentation`, `auto-review`, `{severity}`

*This issue was automatically created by the documentation review system.*
```

### 4.5 PR Comment Format

**Comment ID:** Uses GitHub comment ID for updates (find by search pattern)

**Template:**
```markdown
## 📋 Automated Documentation Review

**Submodule:** `{submodule_path}`  
**Source Repo:** [{org}/{repo}]({repo_url})  
**Commit:** `{sha_short}` ([full]({commit_url}))  
**Last Reviewed:** {timestamp} UTC

---

### 📊 Summary

| Severity | Count | Status |
|----------|-------|--------|
| 🚫 Blockers | {count} | {status_badge} |
| ⚠️ Major | {count} | {status_badge} |
| ℹ️ Minor | {count} | {status_badge} |
| 💡 Suggestions | {count} | {status_badge} |
| **Total** | **{total}** | |

---

### 🚫 Blockers

{if blockers}
- [#{issue_num} {title}]({issue_url}) - {one_line_description}
{else}
✅ No blockers

---

### ⚠️ Major Issues

{if major}
- [#{issue_num} {title}]({issue_url}) - {one_line_description}
{else}
✅ No major issues

---

### ℹ️ Minor Issues

{if minor}
<details>
<summary>View {count} minor issues</summary>

- [#{issue_num} {title}]({issue_url})
- ...

</details>
{else}
✅ No minor issues

---

### 💡 Suggestions

{if suggestions}
<details>
<summary>View {count} suggestions</summary>

- [#{issue_num} {title}]({issue_url})
- ...

</details>
{else}
No suggestions

---

### ✅ Resolved ({count})

{if resolved}
- ~~[#{issue_num} {title}]({issue_url})~~ - Fixed in `{sha_short}`
{else}
No resolved issues yet

---

### 📚 Review Standards

This review checks against:
- [Quickstart Requirements](https://github.com/rh-ai-quickstart/ai-quickstart-contrib/blob/main/docs/quickstart-requirements.md)
- [README Template](https://github.com/rh-ai-quickstart/ai-quickstart-contrib/blob/main/docs/readme-template.md)
- [Red Hat Writing Guide](https://github.com/rh-ai-quickstart/ai-quickstart-contrib/blob/main/docs/redhat-writing-guide.md)

---

*🤖 Automated review powered by Claude • Last updated: {timestamp}*

<!-- doc-review-state
{state_json}
-->
```

---

## 5. API Contracts

### 5.1 Claude API Request

**Endpoint:** `https://api.anthropic.com/v1/messages`

**Request:**
```json
{
  "model": "claude-sonnet-4-5-20250929",
  "max_tokens": 8000,
  "temperature": 0,
  "system": "{SYSTEM_PROMPT}",
  "messages": [
    {
      "role": "user",
      "content": "{USER_PROMPT_WITH_README_AND_REQUIREMENTS}"
    }
  ]
}
```

**Expected Response:**
```json
{
  "content": [
    {
      "type": "text",
      "text": "{JSON_FINDINGS_STRUCTURE}"
    }
  ],
  "stop_reason": "end_turn",
  "usage": {
    "input_tokens": 15000,
    "output_tokens": 2500
  }
}
```

### 5.2 GitHub API Calls

#### Create Issue
```
POST /repos/{owner}/{repo}/issues
{
  "title": "[Doc Review] {title}",
  "body": "{formatted_body}",
  "labels": ["documentation", "auto-review", "{severity}"]
}
```

#### Close Issue
```
PATCH /repos/{owner}/{repo}/issues/{issue_number}
{
  "state": "closed"
}

POST /repos/{owner}/{repo}/issues/{issue_number}/comments
{
  "body": "Fixed in submodule commit {sha}"
}
```

#### Update Issue
```
PATCH /repos/{owner}/{repo}/issues/{issue_number}
{
  "body": "{updated_body}"
}

POST /repos/{owner}/{repo}/issues/{issue_number}/comments
{
  "body": "Finding details updated based on re-review"
}
```

#### Create/Update PR Comment
```
# First time: Create comment
POST /repos/{owner}/{repo}/issues/{pr_number}/comments
{
  "body": "{formatted_comment_with_state}"
}

# Subsequent runs: Update existing comment
PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}
{
  "body": "{updated_formatted_comment_with_state}"
}
```

---

## 6. Implementation Plan

### Phase 1: Foundation (Week 1)
**Deliverables:**
- [ ] GitHub Action workflow file (`.github/workflows/doc-review.yml`)
- [ ] Submodule detection script
- [ ] Requirements fetcher (clone ai-quickstart-contrib)
- [ ] Claude API integration with review prompt
- [ ] JSON schema for findings
- [ ] Basic PR comment posting (no issue management yet)

**Testing:**
- Manual trigger on test PR
- Validate findings quality
- Verify requirements are fetched correctly

### Phase 2: Issue Automation (Week 2)
**Deliverables:**
- [ ] Issue creation logic in source repos
- [ ] State tracking implementation (HTML comment parser)
- [ ] Issue lifecycle management (create/update/close)
- [ ] Finding ID hashing for stability
- [ ] Issue template formatting

**Testing:**
- Test with dummy findings
- Verify state persists across runs
- Test resolved finding detection
- Validate issue closure logic

### Phase 3: Full Integration (Week 3)
**Deliverables:**
- [ ] Complete PR comment dashboard
- [ ] Severity-based grouping and badges
- [ ] Resolved items tracking
- [ ] Links to requirements docs
- [ ] Error handling and edge cases
- [ ] Logging and observability

**Testing:**
- End-to-end test on real PR
- Test submodule update flow
- Verify re-review logic
- Test error scenarios (missing README, API failures)

### Phase 4: Polish & Documentation (Week 4)
**Deliverables:**
- [ ] Dry-run mode flag (review only, no issue creation)
- [ ] README for the system
- [ ] Troubleshooting guide
- [ ] Cost estimation and monitoring
- [ ] Performance optimization (caching requirements docs)

**Testing:**
- User acceptance testing
- Performance benchmarks
- Cost analysis

---

## 7. Design Decisions

### 7.1 Why Issues Over PRs?

**Decision:** Create issues in source repos rather than automated PRs.

**Rationale:**
- **Ownership:** Source repo maintainers know their codebase best
- **Flexibility:** Multiple valid ways to fix style issues; maintainer chooses
- **Batching:** One PR can close multiple issues
- **Overhead:** Managing cross-repo PRs requires auth, conflict resolution, review cycles
- **Discussion:** Issues allow conversation; PRs assume the fix is correct

**Alternatives Considered:**
- ❌ Automated PRs: Too prescriptive, creates review burden
- ❌ Just PR comments: Not actionable in source repo, no tracking
- ✅ Issues: Right balance of actionability and flexibility

### 7.2 Why Embedded State Over External Database?

**Decision:** Store finding state in HTML comments within PR comments.

**Rationale:**
- **Simplicity:** No external infrastructure needed
- **Auditability:** State visible in PR history
- **Self-contained:** Everything lives in GitHub
- **Lifecycle:** State only needed while PR is open
- **Recovery:** State survives workflow reruns

**Alternatives Considered:**
- ❌ External DB: Adds complexity, hosting, credentials
- ❌ GitHub repo file: Creates noise in git history
- ❌ GitHub Actions cache: Not durable across reruns
- ✅ HTML comment: Invisible to users, persists naturally

### 7.3 Why Claude API Over GitHub Copilot/Other?

**Decision:** Use Claude API (Anthropic) for review.

**Rationale:**
- **Context window:** Claude Sonnet 4.x handles large requirements docs + README
- **Structured output:** Reliable JSON generation with schema validation
- **Quality:** Strong performance on nuanced style/writing tasks
- **API simplicity:** Straightforward REST API
- **Cost:** Predictable token-based pricing

**Alternatives Considered:**
- ❌ GitHub Copilot: Limited API access, less suited for review tasks
- ❌ OpenAI GPT-4: Similar capability, but already using Claude in organization
- ❌ Open-source LLMs: Quality/consistency concerns for production use
- ✅ Claude: Best fit for task requirements

### 7.4 Why One Submodule Per PR?

**Decision:** Enforce one submodule change per PR (validation check).

**Rationale:**
- **Clarity:** Each PR represents one quickstart publication
- **Review focus:** Easier to review one guide thoroughly
- **Issue tracking:** Clean 1:1 mapping of PR to source repo
- **Rollback:** Simpler to revert if needed

**Future Consideration:**
- Could support multiple submodules if use case emerges
- Would require per-submodule comment sections

---

## 8. Open Questions & Future Work

### 8.1 Future Enhancements

**Potential additions (out of scope for v1):**
- Review additional documentation files (CONTRIBUTING.md, etc.)
- Support for reviewing code examples in README
- Automated fix suggestions with diff patches
- Integration with Red Hat's official style checker (if available)
- Review quality metrics and tracking over time
- Support for reviewing diagrams/images in docs
- Multi-language documentation support

### 8.2 Known Limitations

**v1 Scope:**
- Only reviews README.md (not other docs)
- Assumes one submodule per PR
- Requires manual merge approval (no auto-merge)
- English language only
- No offline mode (requires API access)

### 8.3 Monitoring & Observability

**Metrics to track:**
- Review execution time
- Claude API token usage and cost
- Finding distribution (severity, category)
- Issue resolution time
- False positive rate (issues closed without action)

**Alerts:**
- API failures or timeouts
- Unexpected finding count spikes
- Cost threshold exceeded

---

## 9. Appendices

### 9.1 Identity & Authentication Flow

**Visual representation of how the bot authenticates and acts:**

```
┌─────────────────────────────────────────────────────────┐
│ GitHub Actions Workflow Starts                          │
│ (Triggered by PR event in ai-quickstart-pub)            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ Step: Generate App Token                                │
│  Input: APP_ID + APP_PRIVATE_KEY (from secrets)         │
│  Output: Short-lived installation token (~1hr)          │
│  Identity: "AI Quickstart Doc Reviewer[bot]"            │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│ All GitHub API Calls Use This Token                     │
│                                                          │
│  ✓ Read submodule content (as bot)                      │
│  ✓ Create issues in source repos (as bot)               │
│  ✓ Post/update PR comments (as bot)                     │
│  ✓ Close resolved issues (as bot)                       │
│                                                          │
│  WHO SEES THIS:                                         │
│  - PR comments show: "AI Quickstart Doc Reviewer[bot]"  │
│  - Issues created by: "AI Quickstart Doc Reviewer[bot]" │
│  - NOT: Your personal GitHub username                   │
└─────────────────────────────────────────────────────────┘
```

**Example PR Comment Attribution:**

```markdown
AI Quickstart Doc Reviewer[bot] commented 2 minutes ago

## 📋 Automated Documentation Review
...
```

**Example Issue Attribution:**

```
Issue #123 opened by AI Quickstart Doc Reviewer[bot]

[Doc Review] Missing Prerequisites section

This issue was automatically created by the documentation review system.
Publication PR: #456
```

**Key Point:** All automated actions are clearly attributed to the bot, not to you personally.

### 9.2 Example Review Flow

**Scenario:** Developer submits PR adding new quickstart

1. **PR Created**
   - Title: "Add GenAI chatbot quickstart"
   - Changed files: `quickstart/genai-chatbot` (submodule)

2. **Workflow Triggers**
   - Detects submodule: `quickstart/genai-chatbot`
   - Source repo: `github.com/rh-ai-quickstart/genai-chatbot`
   - Fetches README from submodule

3. **Claude Reviews**
   - Finds 5 issues:
     - 1 blocker (missing prerequisites)
     - 2 major (inconsistent headings, missing trademark)
     - 1 minor (formatting)
     - 1 suggestion (add troubleshooting section)

4. **Issues Created** (in `genai-chatbot` repo)
   - Issue #45: [Doc Review] Missing Prerequisites section (blocker)
   - Issue #46: [Doc Review] Inconsistent heading hierarchy (major)
   - Issue #47: [Doc Review] Red Hat trademark missing (major)
   - Issue #48: [Doc Review] Code block formatting (minor)
   - Issue #49: [Doc Review] Add troubleshooting section (suggestion)

5. **PR Comment Posted**
   - Dashboard shows 5 findings
   - Links to all 5 issues
   - Summary table with counts

6. **Developer Fixes Issues**
   - Updates README in `genai-chatbot` repo
   - Updates submodule commit in PR

7. **Workflow Re-runs**
   - Detects 3 issues fixed (blocker + 2 major)
   - Closes issues #45, #46, #47 with "Fixed in abc123"
   - Issues #48, #49 still open (minor + suggestion)
   - Updates PR comment showing 3 resolved, 2 open

8. **Reviewer Approves**
   - Reviews PR comment dashboard
   - Sees blocker resolved
   - Approves PR (minor/suggestion acceptable)

9. **PR Merged**
   - README published to Red Hat site
   - Workflow stops running

### 9.2 Requirements Document References

**Location:** `https://github.com/rh-ai-quickstart/ai-quickstart-contrib`

**Expected documents:**
- `/docs/quickstart-requirements.md`
- `/docs/readme-template.md`
- `/docs/redhat-writing-guide.md`

**Access pattern:**
```bash
# Clone requirements repo (cached per workflow run)
git clone --depth=1 https://github.com/rh-ai-quickstart/ai-quickstart-contrib /tmp/requirements

# Read documents
cat /tmp/requirements/docs/quickstart-requirements.md
cat /tmp/requirements/docs/readme-template.md
cat /tmp/requirements/docs/redhat-writing-guide.md
```

### 9.3 Cost Estimation

**Per Review:**
- Average README: ~2,000 tokens
- Requirements docs: ~10,000 tokens (cached after first request)
- Claude Sonnet 4.x pricing:
  - Input: ~$3 per million tokens
  - Output: ~$15 per million tokens
- Estimated per review: ~$0.05-0.15

**Monthly estimate (assuming 20 PRs, 3 reviews per PR):**
- 60 reviews/month × $0.10 avg = **~$6/month**

**GitHub Actions:**
- Compute: Free tier likely sufficient (<2000 min/month)

**Total estimated cost: <$10/month**

### 9.4 Security Considerations

**Secrets Management:**
- `ANTHROPIC_API_KEY` - Stored as GitHub repository secret (organization or repository level)
- `DOC_REVIEW_APP_ID` - GitHub App ID (not sensitive, can be repository variable)
- `DOC_REVIEW_APP_PRIVATE_KEY` - GitHub App private key (encrypted secret, organization level recommended)

**GitHub App Permissions:**

The GitHub App should be configured with **minimal required permissions**:

*Repository Permissions:*
- **Issues**: Read & Write (to create/update/close issues in source repos)
- **Pull Requests**: Read & Write (to comment on PRs in ai-quickstart-pub)
- **Contents**: Read only (to read README files, no write access)
- **Metadata**: Read only (automatic, for repo info)

*Organization Permissions:*
- None required

*Account Permissions:*
- None required

**Installation Scope:**
- Install on organization (`rh-ai-quickstart`) with access to:
  - `ai-quickstart-pub` (this repo)
  - `ai-quickstart-contrib` (requirements repo)
  - All quickstart source repositories (for issue creation)
- Alternatively: Install with "All repositories" access if new quickstarts are added frequently

**Access Control:**
- Only repository/organization admins can modify app settings
- App credentials stored as encrypted secrets
- Workflow runs are auditable via GitHub Actions logs
- Bot actions clearly attributed to app (shows as `doc-review-bot[bot]`)

**Data Handling:**
- README content sent to Claude API (external service)
- No PII or sensitive data expected in READMEs
- Consider: Scanning for accidentally committed secrets before review

**Rate Limiting:**
- Claude API: 50 requests/minute (unlikely to hit)
- GitHub API: 5000 requests/hour (more than sufficient)

---

## 10. Setup Guide

### 10.1 GitHub App Creation (One-Time Setup)

**Prerequisites:**
- Organization owner or admin access to `rh-ai-quickstart`

**Steps:**

1. **Create the GitHub App**
   - Navigate to: `https://github.com/organizations/rh-ai-quickstart/settings/apps`
   - Click "New GitHub App"
   - Configure:
     - **Name**: `AI Quickstart Doc Reviewer` (or `rh-ai-doc-review-bot`)
     - **Homepage URL**: `https://github.com/rh-ai-quickstart/ai-quickstart-pub`
     - **Webhook**: Uncheck "Active" (we don't need webhooks)
     - **Permissions**:
       - Repository permissions:
         - Contents: Read-only
         - Issues: Read and write
         - Pull requests: Read and write
     - **Where can this GitHub App be installed?**: "Only on this account"
   - Click "Create GitHub App"

2. **Generate Private Key**
   - On the app settings page, scroll to "Private keys"
   - Click "Generate a private key"
   - Download the `.pem` file (keep this secure!)

3. **Note the App ID**
   - On the app settings page, note the "App ID" (numeric value)

4. **Install the App**
   - On the app settings page, click "Install App" in the left sidebar
   - Click "Install" next to your organization
   - Choose:
     - **All repositories** (if new quickstarts added frequently), OR
     - **Only select repositories**: Choose ai-quickstart-pub, ai-quickstart-contrib, and all quickstart repos
   - Click "Install"

### 10.2 Repository Secrets Configuration

**In `rh-ai-quickstart/ai-quickstart-pub` repository:**

1. Navigate to: `Settings` > `Secrets and variables` > `Actions`

2. Add **Repository secrets**:
   - `DOC_REVIEW_APP_ID`
     - Value: The App ID from step 3 above (e.g., `123456`)
   - `DOC_REVIEW_APP_PRIVATE_KEY`
     - Value: Contents of the `.pem` file (entire file, including `-----BEGIN RSA PRIVATE KEY-----` headers)
   - `ANTHROPIC_API_KEY`
     - Value: Your Anthropic API key (from https://console.anthropic.com/)

**Alternative (Organization-level secrets):**
- For better maintainability, set these as organization secrets instead
- Navigate to: `https://github.com/organizations/rh-ai-quickstart/settings/secrets/actions`
- Add the same secrets with repository access set to "Selected repositories" (at minimum: ai-quickstart-pub)

### 10.3 Verification

**Test the GitHub App token generation:**

Create a test workflow in `.github/workflows/test-app-token.yml`:
```yaml
name: Test App Token
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Generate token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.DOC_REVIEW_APP_ID }}
          private-key: ${{ secrets.DOC_REVIEW_APP_PRIVATE_KEY }}
      
      - name: Verify token
        env:
          GITHUB_TOKEN: ${{ steps.app-token.outputs.token }}
        run: |
          # Test reading a repo
          curl -H "Authorization: token $GITHUB_TOKEN" \
               https://api.github.com/repos/rh-ai-quickstart/ai-quickstart-pub
          
          # Test that we can create an issue (dry run)
          echo "Token is valid and has correct permissions"
```

Run this manually to verify secrets are configured correctly. Delete the file after verification.

### 10.4 Anthropic API Key

**Obtain API Key:**
1. Sign up or log in to: https://console.anthropic.com/
2. Navigate to "API Keys"
3. Create a new key (name it "AI Quickstart Doc Review")
4. Copy the key (starts with `sk-ant-...`)
5. Store as `ANTHROPIC_API_KEY` secret

**Cost Management:**
- Set usage limits in Anthropic console (recommended: $50/month cap)
- Monitor usage dashboard
- Expected cost: ~$6-10/month (see §9.3)

---

## 11. Frequently Asked Questions

### Q: Does the workflow run as me or as a bot?
**A:** As a **bot** (GitHub App). All comments, issues, and actions are attributed to "AI Quickstart Doc Reviewer[bot]", not your personal account.

### Q: Do I need to do anything special to trigger reviews?
**A:** No. Reviews run automatically when any PR modifies files in `quickstart/`. You don't need to comment or trigger manually.

### Q: Can I test the review without creating issues?
**A:** Yes. Phase 1 implementation includes a dry-run mode that posts findings in the PR comment only, without creating issues in source repos.

### Q: What if the bot creates a wrong/false-positive issue?
**A:** Source repo maintainers can close the issue with a comment explaining why it's not applicable. We track this as feedback to improve the review prompts.

### Q: Will this block PR merges?
**A:** No. The check is informational only. You review the bot's findings and approve/reject the PR manually. The bot doesn't auto-block or auto-merge.

### Q: What happens if a source repo doesn't exist anymore?
**A:** The workflow will fail gracefully and post an error in the PR comment. You'll need to investigate and update/remove the submodule.

### Q: Can I manually re-run the review?
**A:** Yes. Update the submodule commit (even to the same SHA) or use "Re-run jobs" in the GitHub Actions UI to trigger a fresh review.

### Q: What if ai-quickstart-contrib requirements change?
**A:** The workflow fetches the latest requirements on every run. Updated requirements automatically apply to the next review.

### Q: How much does this cost?
**A:** Estimated ~$6-10/month for Claude API usage (see §9.3). GitHub Actions compute is free tier. Anthropic console allows setting spend limits.

### Q: What if I need to review multiple submodules in one PR?
**A:** Current design supports one submodule per PR (validation check will fail). This keeps reviews focused. Create separate PRs for multiple quickstarts.

### Q: Who can modify the GitHub App settings?
**A:** Only organization owners/admins. Repository maintainers cannot change app permissions or access.

### Q: Where do I go if something breaks?
**A:** Check GitHub Actions logs in the PR "Checks" tab. Logs show each step (detect submodule, call API, create issues, etc.) with error details.

---

## 12. Approval & Sign-off

**Stakeholders:**
- [ ] Repository maintainer
- [ ] Red Hat documentation team
- [ ] Security review (if required)

**Next Steps:**
1. Review and approve this specification
2. Begin Phase 1 implementation
3. Test on staging/dev PR
4. Iterate based on feedback
5. Roll out to production

---

**Document History:**
- v1.0 (2026-06-05): Initial specification created
