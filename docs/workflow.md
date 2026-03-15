# Codex x Claude Code 双 Agent 协作流程

Claude Code 自编排的设计-实现-审查 pipeline。

---

## 流程图

```
                      ┌─────────────────────────────────┐
                      │     阶段一：设计辩论 (≤3 轮)      │
                      ├─────────────────────────────────┤
                      │                                 │
  需求描述 ──────────▶│  Claude Code 写 design.md        │
                      │       ↓                         │
                      │  用户确认方向                     │
                      │       ↓                         │
                      │  Codex 审查设计                   │
                      │       ↓                         │
                      │  有 P0/P1? ──no──▶ 通过          │
                      │       │yes                      │
                      │       ↓                         │
                      │  Claude Code 按分歧机制处理       │
                      │       ↓                         │
                      │  (回到 Codex 审查)               │
                      │                                 │
                      └───────────────┬─────────────────┘
                                      │ 设计通过
                                      ▼
                      ┌─────────────────────────────────┐
                      │     阶段二：Claude Code 实现      │
                      ├─────────────────────────────────┤
                      │  读取 design.md 最终版            │
                      │  实现代码 + 构建/测试              │
                      │  输出 changeset.md               │
                      └───────────────┬─────────────────┘
                                      │
                                      ▼
                      ┌─────────────────────────────────┐
                      │     阶段三：代码审查 (≤3 轮)      │
                      ├─────────────────────────────────┤
                      │                                 │
                      │  Codex 审查 git diff              │
                      │       ↓                         │
                      │  有 P0/P1? ──no──▶ 完成          │
                      │       │yes                      │
                      │       ↓                         │
                      │  Claude Code 修复代码             │
                      │       ↓                         │
                      │  (回到 Codex 审查)               │
                      │                                 │
                      └─────────────────────────────────┘
```

---

## 角色分工

| 角色 | 职责 | 权限 |
|------|------|------|
| **Claude Code** | 编排流程、编写设计、实现代码、修复问题 | 完全读写 |
| **Codex** | 审查设计文档、审查代码 diff | `--sandbox read-only`（只读） |
| **用户** | 确认设计方向、决定取舍类分歧 | 检查点介入 |

---

## 轮次规则

| 项目       | 设计辩论（阶段一）         | 代码审查（阶段三）         |
|-----------|--------------------------|--------------------------|
| 最大轮数   | 3（有 P0）/ 2（仅 P1）    | 3（有 P0）/ 2（仅 P1）    |
| 通过标准   | 无新 P0/P1 问题           | 无新 P0/P1 问题           |
| 审查方     | Codex                    | Codex                    |
| 修订方     | Claude Code              | Claude Code              |

### 问题分级

- **P0**: 必须修复——不改会导致运行错误、安全漏洞或数据丢失
- **P1**: 应当修复——性能隐患、可维护性问题
- **P2**: 建议改进，不阻塞流程

### 问题分类

- **[事实]**: 可通过跑代码、查文档客观验证（API 参数错误、语法错误等）
- **[取舍]**: 多种合理方案的选择，无客观对错（Redis vs 内存缓存等）
- **[质量]**: 代码风格和可维护性建议

---

## 上下文传递方式

通过 `codex-call --file` 传递文件路径，让 Codex 在只读沙箱中自行读取：

```bash
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/architect.md \
  --file CLAUDE.md \
  --file .design/design.md \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-design-1.md \
  - <<'PROMPT'
<REQUIREMENT>
用户原始需求
</REQUIREMENT>

审查 design.md。按照 architect.md 中的角色要求输出审查结论。
PROMPT
```

Claude Code **不需要读取文件内容再内联到 prompt**——只需确定哪些文件传给 Codex，通过 `--file` 标志传递路径即可。

---

## 产物目录

```
.design/
├── design.md                 # 设计文档（Claude Code 维护，逐轮更新）
├── design-debate.md          # 设计阶段辩论记录（每轮追加）
├── changeset.md              # 实现改动摘要（Claude Code 产出）
├── diff.txt                  # git diff 快照（供 Codex 审查）
├── implementation-debate.md  # 代码审查辩论记录（每轮追加）
├── codex-raw-design-*.md     # Codex 设计审查原始输出（可审计）
├── codex-raw-review-*.md     # Codex 代码审查原始输出（可审计）
└── .codex-session            # Codex 会话 ID（用于 session 复用）
```

---

## 分歧解决机制

| 类型 | 处理方式 |
|------|----------|
| `[事实]` | 必须验证（跑代码、查文档、检查现有用法），验证后 `fixed` 或 `rejected`（附验证过程） |
| `[取舍]` | 小取舍：Claude 选保守方案并说明理由。大取舍：标记 `deferred`，翻译成用户能理解的利弊，让用户决定 |
| `[质量]` | Claude 自行判断，接受或拒绝并给出理由 |

**验证者心态**：处理 Codex 反馈时默认假设 Codex 可能是对的。"我觉得不对"不是有效的拒绝理由——必须有具体依据。

---

## codex-call 参数

```bash
codex-call [--file PATH]... [--session-file PATH] [--resume SESSION_ID] [--save-output PATH] "prompt"
```

| 参数 | 说明 |
|------|------|
| `--file PATH` | 传递文件路径给 Codex（可重复多次），Codex 在只读沙箱中自行读取 |
| `--session-file PATH` | 启用 session 模式，将 session ID 保存到指定文件 |
| `--resume SESSION_ID` | 续接已有会话 |
| `--save-output PATH` | 保存 Codex 原始输出到文件 |

> **Codex 路径**: PATH 优先，fallback 到 `/Applications/Codex.app/Contents/Resources/codex`
> **超时**: 默认 600 秒，可通过 `CODEX_TIMEOUT` 环境变量覆盖
