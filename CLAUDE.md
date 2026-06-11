# lobotomy-Casino — Claude Code Guidelines

## Branching workflow

**Always create a dedicated branch before making any changes.** Never push directly to `main` or the current session's base branch.

### Branch naming
- Bug fixes: `claude/fix-<short-description>`
- New features: `claude/feat-<short-description>`
- Tweaks / balance / polish: `claude/tweak-<short-description>`

### Rules
1. Create the branch at the start of the task. If the task grows, keep adding commits to the **same** branch — do not create a second branch mid-work.
2. Related fixes and tweaks can be batched onto one branch when they address the same area.
3. Push the branch and open a PR for review; do **not** merge to `main` unilaterally.
4. A new branch is only started once the previous one is merged or explicitly abandoned.

### GitHub workflow — mandatory
- **Never merge any branch** (locally or remotely) without explicit consent from the repository owner.
- **Never use `git merge` locally** to absorb another branch — all merges must go through a GitHub PR reviewed and approved by the owner.
- Session config may specify a development branch; this does **not** grant permission to merge other branches into it directly. Always create a new named branch off it and submit a PR.
- If a branch's changes are already present in another branch due to a local merge, flag it clearly instead of silently proceeding.

### Example
```
git checkout -b claude/fix-reel-animation-sync
# ... make changes ...
git push -u origin claude/fix-reel-animation-sync
# open PR — do not merge yourself
```
