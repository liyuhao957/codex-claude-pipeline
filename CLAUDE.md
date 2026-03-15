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
- **Raw output transparency**: `codex-call --save-output` 保存 Codex 原始输出到 `.design/codex-raw-*.md`，供用户审计
- **Severity levels**: P0 (must fix), P1 (should fix), P2 (nice to have, can skip)
- **Issue classification**: 每个问题必须标注类型 `[事实]`/`[取舍]`/`[质量]`，不同类型走不同解决路径
- **Dispute resolution**: 事实类→必须验证（跑代码/查文档），取舍类→翻译给用户或选保守方案，质量类→Claude 自行判断
- **Mindset switch**: 处理 Codex 反馈时默认假设 Codex 可能是对的，先验证再下结论
- **Requirement anchoring**: 每次 Codex prompt 包含 `<REQUIREMENT>` 标签锚定原始需求，防止需求漂移
- **User checkpoints**: 设计完成后先给用户确认方向，再发 Codex 审查
- **Adaptive rounds**: 无 P0/P1 时一轮即过；有 P0 最多 3 轮；只有 P1 最多 2 轮
- **Artifacts**: all design/review artifacts go in `.design/` directory
- **Project context**: if project has `.claude/codex-context.md`, listed files (lines starting with `- `) are inlined into first-round Codex prompts under `<CONTEXT>` tag; subsequent rounds rely on session resume
