# codex-claude-pipeline

Fully automated dual-agent pipeline: **Codex** designs, **Claude Code** reviews and implements, then they debate until consensus.

## What It Does

```
You: dual-agent "add a favorites feature"

Phase 1: Design Debate (up to 3 rounds)
  Codex writes design doc  ->  Claude Code reviews  ->  iterate

Phase 2: Implementation
  Claude Code implements the approved design

Phase 3: Code Review Debate (up to 3 rounds)
  Codex reviews code  ->  Claude Code fixes  ->  iterate
```

Zero human intervention. The script orchestrates both agents, parses `VERDICT: PASS/REVISE`, and stops when they agree (or after 3 rounds).

## Install

```bash
# Copy to PATH
sudo cp dual-agent /usr/local/bin/dual-agent
sudo chmod +x /usr/local/bin/dual-agent

# Prerequisites
# - codex CLI (or Codex.app installed)
# - claude CLI (Claude Code)
```

## Usage

```bash
cd your-project        # must be a git repo
dual-agent "your feature requirement"

# Options
dual-agent --max-rounds 2 "fix login bug"    # fewer debate rounds
dual-agent --timeout 300 "small change"      # shorter timeout per call
dual-agent --yolo "quick fix"                # bypass Codex sandbox
```

## Artifacts

After running, check `.design/` in your project:

```
.design/
├── design.md                # Final design document
├── design-debate.md         # Phase 1 debate log
├── changeset.md             # Implementation summary
└── implementation-debate.md # Phase 3 debate log
```

## How It Works

The script (`dual-agent`) is a stateless orchestrator. It doesn't understand code. It just:

1. Calls `codex exec` or `codex review` via subprocess
2. Calls `claude -p` via subprocess
3. Parses output for `VERDICT: PASS` or `VERDICT: REVISE`
4. Loops or advances based on the verdict

Both agents read/write files in `.design/` to share context. No direct agent-to-agent communication.

## Requirements

- Python 3.8+
- macOS (Codex fallback path is macOS-specific)
- Git repository (Phase 3 uses `git diff`)
- `codex` CLI: in PATH or at `/Applications/Codex.app/Contents/Resources/codex`
- `claude` CLI: in PATH

## License

MIT
