# codex-claude-pipeline

## Tech Stack

- Bash (`codex-call` wrapper，支持 session 复用)
- Markdown (slash command 模板 + 角色 prompt)

## Directory Structure

```
codex-call          # Shell wrapper: invokes Codex CLI in read-only sandbox
dual-agent.md       # 完整三阶段流程（设计→实现→审查）
dual-design.md      # 只做设计辩论
dual-review.md      # 只做代码审查
prompts/            # Codex 角色 prompt
  architect.md      #   设计审查专家（阶段一）
  reviewer.md       #   代码审查专家（阶段三）
install.sh          # 安装到 ~/.claude/
docs/               # 规划文档和工作流笔记
```

## Key Conventions

- **Codex is read-only**: always called with `--sandbox read-only`, never writes code
- **Claude Code is sole coder**: all file creation/modification happens through Claude Code
- **Role prompts**: 阶段一加载 `architect.md`，阶段三加载 `reviewer.md`
- **Session reuse**: `codex-call --session-file` 保存会话 ID，`--resume` 复用上下文
- **Severity levels**: P0 (must fix), P1 (should fix), P2 (nice to have, can skip)
- **Debate cap**: max 3 rounds per phase; stop and ask user if P0/P1 remain
- **Artifacts**: all design/review artifacts go in `.design/` directory
- **Project context**: if project has `.claude/codex-context.md`, listed files (lines starting with `- `) are inlined into first-round Codex prompts under `<CONTEXT>` tag; subsequent rounds rely on session resume
