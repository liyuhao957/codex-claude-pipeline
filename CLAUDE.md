# codex-claude-pipeline

## Tech Stack

- Bash (`codex-call` wrapper)
- Markdown (`dual-agent.md` slash command template)

## Directory Structure

```
codex-call          # Shell wrapper: invokes Codex CLI in read-only sandbox
dual-agent.md       # Slash command template: defines 3-phase collaboration flow
install.sh          # Installs codex-call + dual-agent.md to ~/.claude/
docs/               # Planning docs and workflow notes
```

## Key Conventions

- **Codex is read-only**: always called with `--sandbox read-only`, never writes code
- **Claude Code is sole coder**: all file creation/modification happens through Claude Code
- **Severity levels**: P0 (must fix), P1 (should fix), P2 (nice to have, can skip)
- **Debate cap**: max 3 rounds per phase; stop and ask user if P0/P1 remain
- **Artifacts**: all design/review artifacts go in `.design/` directory
