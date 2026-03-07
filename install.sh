#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install codex-call wrapper
mkdir -p ~/.claude/bin
cp "$SCRIPT_DIR/codex-call" ~/.claude/bin/codex-call
chmod +x ~/.claude/bin/codex-call
echo "Installed: ~/.claude/bin/codex-call"

# Install slash command templates
mkdir -p ~/.claude/commands
cp "$SCRIPT_DIR/dual-agent.md" ~/.claude/commands/dual-agent.md
cp "$SCRIPT_DIR/dual-design.md" ~/.claude/commands/dual-design.md
cp "$SCRIPT_DIR/dual-review.md" ~/.claude/commands/dual-review.md
echo "Installed: ~/.claude/commands/dual-agent.md"
echo "Installed: ~/.claude/commands/dual-design.md"
echo "Installed: ~/.claude/commands/dual-review.md"

# Install role prompts
mkdir -p ~/.claude/prompts/dual-agent
cp "$SCRIPT_DIR/prompts/architect.md" ~/.claude/prompts/dual-agent/architect.md
cp "$SCRIPT_DIR/prompts/reviewer.md" ~/.claude/prompts/dual-agent/reviewer.md
echo "Installed: ~/.claude/prompts/dual-agent/architect.md"
echo "Installed: ~/.claude/prompts/dual-agent/reviewer.md"

echo ""
echo "Done. Available commands:"
echo "  /dual-agent  <需求>  — 完整三阶段流程（设计→实现→审查）"
echo "  /dual-design <需求>  — 只做设计辩论"
echo "  /dual-review [范围]  — 只做代码审查"
