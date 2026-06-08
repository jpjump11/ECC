---
name: skill-create
description: Analyze local git history to extract coding patterns and generate SKILL.md files. Local version of the Skill Creator GitHub App.
allowed_tools: ["Bash", "Read", "Write", "Grep", "Glob"]
---

# /skill-create - Local Skill Generation

Analyze your repository's git history to extract coding patterns and generate SKILL.md files that teach Claude your team's practices.

## Usage

```bash
/skill-create                    # Analyze current repo
/skill-create --commits 100      # Analyze last 100 commits
/skill-create --output ./skills  # Custom output directory
/skill-create --instincts        # Also generate instincts for continuous-learning-v2
```

## What It Does

1. **Parses Git History** - Analyzes commits, file changes, and patterns
2. **Detects Patterns** - Identifies recurring workflows and conventions
3. **Generates SKILL.md** - Creates valid Claude Code skill files
4. **Optionally Creates Instincts** - For the continuous-learning-v2 system

## Pipeline Position

`/skill-create` is **Stage 2** of the skill lifecycle pipeline
(scout -> create -> validate). The canonical chain is documented once in
`docs/SKILL-DEVELOPMENT-GUIDE.md` (Skill Lifecycle Pipeline). Do not run this
command in isolation: search first (Stage 1) and validate after (Stage 3).

## Analysis Steps

### Step 0: Search First (skill-scout)

Before generating anything, confirm a suitable skill does not already exist.
Invoke `skill-scout` (or, at minimum, search local sources):

```bash
# Quick local check for an existing match (replace KEYWORD with the skill's domain)
find ~/.claude/skills -maxdepth 2 -name SKILL.md 2>/dev/null | grep -iE "KEYWORD"
grep -RilE "KEYWORD" ~/.claude/skills ~/.claude/plugins/marketplaces 2>/dev/null
```

- If a close match exists, recommend **use / fork / extend** instead of creating
  a duplicate, and stop here.
- Only proceed to Step 1 when no close match is found, or the user explicitly
  asks to create fresh.

### Step 1: Gather Git Data

```bash
# Get recent commits with file changes
git log --oneline -n ${COMMITS:-200} --name-only --pretty=format:"%H|%s|%ad" --date=short

# Get commit frequency by file
git log --oneline -n 200 --name-only | grep -v "^$" | grep -v "^[a-f0-9]" | sort | uniq -c | sort -rn | head -20

# Get commit message patterns
git log --oneline -n 200 | cut -d' ' -f2- | head -50
```

### Step 2: Detect Patterns

Look for these pattern types:

| Pattern | Detection Method |
|---------|-----------------|
| **Commit conventions** | Regex on commit messages (feat:, fix:, chore:) |
| **File co-changes** | Files that always change together |
| **Workflow sequences** | Repeated file change patterns |
| **Architecture** | Folder structure and naming conventions |
| **Testing patterns** | Test file locations, naming, coverage |

### Step 3: Generate SKILL.md

Output format:

```markdown
---
name: {repo-name}-patterns
description: Coding patterns extracted from {repo-name}
version: 1.0.0
source: local-git-analysis
analyzed_commits: {count}
---

# {Repo Name} Patterns

## Commit Conventions
{detected commit message patterns}

## Code Architecture
{detected folder structure and organization}

## Workflows
{detected repeating file change patterns}

## Testing Patterns
{detected test conventions}
```

### Step 4: Generate Instincts (if --instincts)

For continuous-learning-v2 integration:

```yaml
---
id: {repo}-commit-convention
trigger: "when writing a commit message"
confidence: 0.8
domain: git
source: local-repo-analysis
---

# Use Conventional Commits

## Action
Prefix commits with: feat:, fix:, chore:, docs:, test:, refactor:

## Evidence
- Analyzed {n} commits
- {percentage}% follow conventional commit format
```

### Step 5: Validate the Generated Skill (close the loop)

A generated `SKILL.md` is a draft until it passes Stage 3. Do not consider the
command complete after writing the file:

1. **Self-check against the quality bar** before handing off. The skill must be:
   - **Actionable** - concrete commands/steps, not vague advice.
   - **Scoped** - `name` + `description` + body aligned; not too broad/narrow.
   - **Unique** - not already covered by another skill, a rule, or CLAUDE.md
     (Step 0 should have caught duplicates; re-confirm now).
   - **Current** - referenced tools/flags/APIs work in today's environment.
2. **Audit with `skill-stocktake`** (quick scan) targeting the new skill. A
   freshly generated skill should earn a **Keep** verdict; an
   `Improve` / `Merge` / `Retire` verdict means iterate before shipping.
3. **Optionally measure with `skill-comply`** when the generated skill defines a
   behavioral sequence (a workflow), to confirm an agent follows it even when the
   prompt does not explicitly reinforce it. Skip for pure reference/pattern dumps.

See `docs/SKILL-DEVELOPMENT-GUIDE.md` (Skill Lifecycle Pipeline) for the full
chain.

## Example Output

Running `/skill-create` on a TypeScript project might produce:

```markdown
---
name: my-app-patterns
description: Coding patterns from my-app repository
version: 1.0.0
source: local-git-analysis
analyzed_commits: 150
---

# My App Patterns

## Commit Conventions

This project uses **conventional commits**:
- `feat:` - New features
- `fix:` - Bug fixes
- `chore:` - Maintenance tasks
- `docs:` - Documentation updates

## Code Architecture

```
src/
├── components/     # React components (PascalCase.tsx)
├── hooks/          # Custom hooks (use*.ts)
├── utils/          # Utility functions
├── types/          # TypeScript type definitions
└── services/       # API and external services
```

## Workflows

### Adding a New Component
1. Create `src/components/ComponentName.tsx`
2. Add tests in `src/components/__tests__/ComponentName.test.tsx`
3. Export from `src/components/index.ts`

### Database Migration
1. Modify `src/db/schema.ts`
2. Run `pnpm db:generate`
3. Run `pnpm db:migrate`

## Testing Patterns

- Test files: `__tests__/` directories or `.test.ts` suffix
- Coverage target: 80%+
- Framework: Vitest
```

## GitHub App Integration

For advanced features (10k+ commits, team sharing, auto-PRs), use the [Skill Creator GitHub App](https://github.com/apps/skill-creator):

- Install: [github.com/apps/skill-creator](https://github.com/apps/skill-creator)
- Comment `/skill-creator analyze` on any issue
- Receives PR with generated skills

## Related Commands

Skill lifecycle pipeline (scout -> create -> validate), documented in
`docs/SKILL-DEVELOPMENT-GUIDE.md`:

- `skill-scout` - Stage 1: search before creating (the Step 0 precondition).
- `skill-stocktake` - Stage 3: audit the generated skill for quality/duplicates.
- `skill-comply` - Stage 3 (optional): measure whether the new skill is followed.

continuous-learning-v2 integration (when run with `--instincts`):

- `/instinct-import` - Import generated instincts
- `/instinct-status` - View learned instincts
- `/evolve` - Cluster instincts into skills/agents

---

*Part of [Everything Claude Code](https://github.com/affaan-m/everything-claude-code)*
