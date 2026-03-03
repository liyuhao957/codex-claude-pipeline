# codex-claude-pipeline

[中文版](./README.zh-CN.md)

Claude Code + Codex dual-agent collaboration via slash command. Claude Code acts as orchestrator and sole coder; Codex serves as read-only consultant for design review and code review.

## What It Does

```
You (in Claude Code): /dual-agent add a favorites feature

Phase 1 — Design Debate (up to 3 rounds)
  Claude Code writes design doc  →  Codex reviews  →  iterate until no P0/P1

Phase 2 — Implementation
  Claude Code implements the approved design, runs tests

Phase 3 — Code Review (up to 3 rounds)
  Codex reviews git diff  →  Claude Code fixes  →  iterate until no P0/P1
```

No external orchestrator needed. Claude Code drives the entire flow from inside its own session using a slash command template.

## Install

```bash
git clone https://github.com/liyuhao957/codex-claude-pipeline.git
cd codex-claude-pipeline
./install.sh
```

This copies two files into your home directory:
- `~/.claude/bin/codex-call` — shell wrapper that invokes Codex in read-only sandbox
- `~/.claude/commands/dual-agent.md` — slash command template defining the 3-phase flow

## Usage

Inside any Claude Code session (must be in a git repo):

```
/dual-agent your requirement here
```

Claude Code will follow the template automatically: analyze the project, write a design, call Codex for review, implement, and get a code review from Codex.

## Key Features

- **Context-aware debate**: From round 2 onward, the full debate history is included in the Codex prompt with explicit instructions not to repeat rejected issues — eliminates wasted rounds.
- **Auto-convergence**: Reviews pass automatically when Codex reports no new P0/P1, or only repeats previously rejected issues without new technical arguments.
- **Clean workspace**: `.design/` is wiped at the start of each run to prevent stale artifacts from interfering.
- **Commit prompt**: After completion, you're asked whether to commit — no manual step needed.
- **Severity triage**: P0 (must fix), P1 (should fix), P2 (nice to have, can skip). Only P0/P1 drive iteration.

## Artifacts

All intermediate work products are saved to `.design/` in your project:

```
.design/
├── design.md                # Design document (Phase 1 output)
├── design-debate.md         # Design debate log (Phase 1)
├── changeset.md             # Implementation summary (Phase 2 output)
├── diff.txt                 # git diff snapshot (Phase 3 input)
└── implementation-debate.md # Code review debate log (Phase 3)
```

| File | Description |
|------|-------------|
| `design.md` | The design document written by Claude Code, revised through Codex review rounds. The final version reflects all accepted feedback. |
| `design-debate.md` | Full record of the design debate: what issues Codex raised each round, and whether Claude Code accepted (with fix) or rejected (with rationale). |
| `changeset.md` | Summary written after implementation: which files were changed, what was done in each, risk points, and items needing manual confirmation. |
| `diff.txt` | Raw `git diff` output, exported as a file for Codex to review during the code review phase. |
| `implementation-debate.md` | Same format as `design-debate.md`, but for the code review phase: Codex's findings on the actual code and Claude Code's responses. |

## How It Works

The slash command template (`dual-agent.md`) instructs Claude Code to follow a strict 3-phase protocol:

1. **Design debate** — Claude Code writes `.design/design.md`, then calls Codex via `codex-call` to review it. P0/P1 issues must be addressed or rebutted; P2 is optional. Up to 3 rounds.
2. **Implementation** — Claude Code implements the approved design and writes `.design/changeset.md`.
3. **Code review** — Claude Code generates a diff and calls Codex to review the actual code changes. Same P0/P1/P2 rules apply. Up to 3 rounds.

`codex-call` is a thin Bash wrapper that resolves the Codex binary, enforces a timeout (default 600s, configurable via `CODEX_TIMEOUT`), and always runs Codex with `--sandbox read-only`.

## Requirements

- macOS
- Git repository (the slash command checks for this)
- `codex` CLI in PATH (or Codex.app installed)
- `claude` CLI (Claude Code)
- Optional: `timeout` or `gtimeout` (from coreutils) for Codex call timeouts

## License

MIT
