---
name: git-guardrails-claude-code
description: One-time setup — install a Claude Code PreToolUse hook that blocks destructive git commands (push, reset --hard, clean -f, branch -D, checkout ., restore .) before they execute. Run once per project or globally. Especially important for interactive Claude Code sessions on the host machine — the Docker sandbox used by ralph-implement and auto-review already has no push credentials, but this hook protects you when working interactively outside Docker. Adapted from mattpocock/skills.
---

# Git Guardrails for Claude Code

One-time setup. Not a per-session skill.

## What gets blocked

The hook intercepts the `Bash` tool before execution and blocks:

- `git push` — all variants including `--force`, `--force-with-lease`
- `git reset --hard`
- `git clean -f`, `git clean -fd`, `git clean -fdx`
- `git branch -D`
- `git checkout .`
- `git restore .`

When blocked, Claude sees a clear BLOCKED message and cannot proceed with the command. It must propose an alternative or ask Minh to run the command manually.

## Why this matters for this pipeline

- **ralph-implement and auto-review** run inside Docker with no remote credentials — they are already safe from accidental pushes.
- **Interactive Claude Code sessions on the host** are not sandboxed. Without this hook, an interactive session could accidentally push to a remote, reset work, or wipe untracked files.
- The hook is the last line of defence against "I'll just run this one cleanup command" decisions.

## Steps

### 1. Decide scope

Ask Minh: install for this project only (`.claude/settings.json`) or globally for all projects (`~/.claude/settings.json`)?

Recommendation: **global** — the hook has no downsides and protects all projects equally.

### 2. Copy the hook script

The hook script is at `.claude/skills/git-guardrails-claude-code/block-dangerous-git.sh` in this plugin.

Copy it to the target location:

```bash
# Project-scoped
cp .claude/skills/git-guardrails-claude-code/block-dangerous-git.sh \
   .claude/hooks/block-dangerous-git.sh
chmod +x .claude/hooks/block-dangerous-git.sh

# Global
mkdir -p ~/.claude/hooks
cp .claude/skills/git-guardrails-claude-code/block-dangerous-git.sh \
   ~/.claude/hooks/block-dangerous-git.sh
chmod +x ~/.claude/hooks/block-dangerous-git.sh
```

### 3. Register the hook in settings

**Project scope** — add to `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

**Global scope** — add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/block-dangerous-git.sh"
          }
        ]
      }
    ]
  }
}
```

If the settings file already exists, **merge** the hook into the existing `hooks.PreToolUse` array — do not overwrite other settings.

### 4. Customise (optional)

Ask Minh if there are patterns to add or remove. Edit the copied script accordingly.

Common additions for this pipeline:
- Block `git rebase --onto` (destructive history rewrite)
- Block `git tag -d` (delete tags) — rarely needed interactively

### 5. Verify

Test that the hook works:

```bash
echo '{"tool_input":{"command":"git push origin main"}}' \
  | .claude/hooks/block-dangerous-git.sh
# Should exit 2 and print a BLOCKED message to stderr
```

Test that safe commands still pass:

```bash
echo '{"tool_input":{"command":"git status"}}' \
  | .claude/hooks/block-dangerous-git.sh
# Should exit 0 silently
```

## Notes

- The hook does **not** block `git commit`, `git add`, `git stash`, `git log`, `git diff`, `git merge` — only explicitly destructive operations.
- If Minh genuinely needs to run a blocked command, they run it manually in their own terminal. This is intentional — the point is that Claude cannot do it, not that the command is impossible.
- The Docker sandbox used by `ralph-implement/ralph.sh` and `auto-review/review-loop.sh` does NOT need this hook — it has no remote credentials and refuses to run on host without `RALPH_FORCE_HOST=1`.
