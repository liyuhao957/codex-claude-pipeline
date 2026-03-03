# Dual-Agent 自编排改造设计

## 背景

现有 `dual-agent` 是一个外部 Python 脚本，用 subprocess 调 Claude Code 和 Codex。存在两个结构性问题：

1. Phase 3 因 `codex review --uncommitted` 不能带 prompt 而失败
2. Claude Code 在脚本外部运行时不受控，会自行调查修复而非等待流程

根因：用"笨"脚本指挥"聪明" agent，控制器比被控制者蠢。

## 方案

改为 Claude Code 自编排：Claude Code 本身作为编排器，按 slash command 模板走流程，通过 shell wrapper 调 Codex 当只读顾问。

### 组件

| 文件 | 职责 |
|------|------|
| `~/.claude/commands/dual-agent.md` | 编排模板，定义三阶段流程和规则 |
| `~/.claude/bin/codex-call` | Shell wrapper，解析 Codex 路径 + 超时控制 + 调用 `codex exec --sandbox read-only` |

### 角色分工

- **Claude Code**：决策者 + 唯一代码编写者。负责写设计、实现代码、修复问题
- **Codex**：只读顾问（`--sandbox read-only`）。只出分析和建议，零文件写权限

### 三阶段流程

**阶段一：设计辩论（≤3 轮）**

1. Claude Code 分析项目 + 需求，写 `.design/design.md`
2. 调 `codex-call` 让 Codex 审查设计
3. P0/P1 问题必须处理（修复或反驳），更新设计，再审查
4. 无 P0/P1 则通过；满 3 轮未通过则停止

**阶段二：实现**

1. Claude Code 读 design.md 实现代码
2. 跑构建/测试
3. 写 `.design/changeset.md`

**阶段三：代码审查（≤3 轮）**

1. 调 `codex-call` 让 Codex 读项目代码 + git diff 审查
2. P0/P1 问题必须修复，再审查
3. 无 P0/P1 则通过；满 3 轮未通过则停止

### 辩论规则

- **P0/P1**：必须逐条处理（修复或给出技术理由），不能跳过
- **P2**：可酌情忽略
- 每轮处理结果记录到 `.design/` 对应 debate 文件

### codex-call wrapper

约 30 行 shell 脚本，做三件事：

1. 解析 Codex 路径（PATH 优先，fallback `/Applications/Codex.app/Contents/Resources/codex`）
2. 超时控制（默认 600s，`CODEX_TIMEOUT` 环境变量可调）
3. 执行 `codex exec --sandbox read-only "$prompt"` 并返回 stdout

不做：VERDICT 解析、JSON stream、Session 管理。

### 产物目录

```
.design/
├── design.md                # 设计文档
├── design-debate.md         # 阶段一辩论记录
├── changeset.md             # 改动摘要
└── implementation-debate.md # 阶段三辩论记录
```

### 触发方式

```
/dual-agent 添加收藏功能
/dual-agent 修复搜索异常
```

### 与现有方案的区别

| 项目 | 旧（Python 脚本） | 新（自编排） |
|------|-------------------|-------------|
| 编排器 | 外部 Python 脚本 | Claude Code 自身 |
| Codex 权限 | 阶段一可写文件 | 全程只读 |
| VERDICT 解析 | 正则提取 | Claude Code 直接理解 |
| 上下文 | 每次 subprocess 丢失 | 一个连续对话 |
| 触发方式 | 终端 `dual-agent "xxx"` | Claude Code 内 `/dual-agent xxx` |
