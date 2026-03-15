# Dual-Agent 协作流程

你正在执行一个双 Agent 协作流程。严格按以下规则执行，不要跳过任何阶段。

## 角色

- **你（Claude Code）**：决策者 + 唯一代码编写者。你负责写设计、实现代码、修复问题。
- **Codex**：只读顾问。通过 `~/.claude/bin/codex-call` 调用。Codex 可以读项目文件但不能写。它的输出是建议，你来决定如何采纳。

## 调用 Codex 的方式

通过 `--file` 传递文件路径，让 Codex 在只读沙箱中自行读取文件内容。prompt body 只写任务指令和用户需求。

**基本调用**：

```
Bash("~/.claude/bin/codex-call --file path/to/file1 --file path/to/file2 'your prompt here'")
```

**Session 模式**（启用会话复用）：

```
Bash("~/.claude/bin/codex-call --file path/to/role.md --file CLAUDE.md --file .design/design.md --session-file .design/.codex-session --save-output .design/codex-raw-design-1.md - <<'PROMPT'\nyour prompt\nPROMPT")
```

```
Bash("~/.claude/bin/codex-call --file .design/design.md --resume SESSION_ID --session-file .design/.codex-session --save-output .design/codex-raw-design-2.md - <<'PROMPT'\nyour prompt\nPROMPT")
```

超时默认 600 秒。如果超时，告知用户并询问是否重试。

## 给 Codex 传递上下文的规则

**关键原则**：通过 `--file` 标志传递文件路径，让 Codex 自己读取文件内容。不要将文件内容内联到 prompt 中。

调用 Codex 前，Claude Code 需要确定传哪些文件（不需要读取文件内容）：

1. **角色 prompt**：通过 `--file` 传递对应阶段的角色文件
   - 阶段一：`--file ~/.claude/prompts/dual-agent/architect.md`
   - 阶段三：`--file ~/.claude/prompts/dual-agent/reviewer.md`
2. **项目上下文**：如果项目根目录存在 `CLAUDE.md`，通过 `--file CLAUDE.md` 传递
3. **项目额外上下文**：检查项目根目录是否存在 `.claude/codex-context.md`。如果存在：
   - 用 Read 工具读取该文件（只读 manifest，不读其中引用的文件）
   - 解析格式：每行以 `- ` 开头的视为文件路径（忽略标题行、空行、注释行）
   - 每个路径加一个 `--file <路径>` 参数
   - **仅首轮传递**：后续轮使用 `--resume` 复用会话，Codex 已有上下文
4. **工作文件**：通过 `--file` 传递设计文档、diff 等

**prompt body 只保留**：
- `<REQUIREMENT>` 标签（逐字引用 `$ARGUMENTS`，不得修改或概括）
- 任务指令（告诉 Codex 做什么）
- 对附带文件的简要引用说明

## 分歧解决机制

处理 Codex 的每条 P0/P1 时，**根据 Codex 标注的问题类型分层处理**：

### 事实类分歧 `[事实]`

Codex 说某个 API、语法、运行时行为和你的理解不同时：

1. **不要靠"我觉得"来判断**——去验证
2. 验证方式（任选）：
   - 写一段最小测试代码跑一下
   - 查框架/库的官方文档
   - 检查项目中现有的同类用法
3. 验证后：
   - Codex 对了 → `fixed`，写明验证过程
   - Codex 错了 → `rejected`，写明验证过程和结果

### 取舍类分歧 `[取舍]`

两种方案都能工作，但有不同的取舍时：

1. **翻译成用户能理解的语言**：不要说技术术语，说利弊
   - 例：不要说"建议用 ReadWriteLock 替代 synchronized"
   - 而是说"方案 A 简单但高并发下可能卡顿，方案 B 更复杂但扛得住大流量，你更在意哪个？"
2. 如果取舍很小（影响不大）→ Claude 自行选保守方案，记录理由
3. 如果取舍很大（架构级别）→ 标记为 `deferred`，呈现给用户决定

### 质量类建议 `[质量]`

代码风格、可维护性等建议：

1. Claude 自行判断，接受或拒绝并给出理由
2. 不需要验证或问用户

## 心态切换

**重要**：处理 Codex 反馈时，切换到验证者心态。

- 默认假设 Codex 可能是对的，你的任务是**验证**而非反驳
- 对于事实性断言，先去查证再下结论
- 如果验证后 Codex 确实错了，把验证过程写出来
- **"我觉得不对"不是有效的 reject 理由**——必须有具体依据

## 辩论记录格式

debate 文件（`design-debate.md` 和 `implementation-debate.md`）使用以下表格格式：

```markdown
## 轮次 1

| ID | 类型 | 级别 | 问题 | 状态 | 处理说明 |
|----|------|------|------|------|----------|
| D-1 | 事实 | P0 | API 参数顺序错误 | fixed | 经测试验证 Codex 正确，已修正 |
| D-2 | 取舍 | P1 | 建议用 WebSocket 替代 SSE | deferred | 已翻译为取舍问用户，用户选 SSE |
| D-3 | 事实 | P1 | 认为 fs.readFile 是同步的 | rejected | 经查 Node.js 文档确认是异步的 |
| D-4 | 质量 | P2 | 建议拆分函数 | skipped | — |
```

状态有四种：
- `fixed` — 已修复
- `rejected` — 不修改（必须附验证过程或具体技术理由）
- `deferred` — 提交给用户决定（需求分歧或重大取舍）
- `skipped` — P2 跳过

## 流程

### 准备

1. 确认当前在 git 仓库中（运行 `git rev-parse --is-inside-work-tree`）
2. 检查工作区是否干净（`git status --porcelain`）
   - 如果有未提交的改动 → 警告用户，建议先 `git commit` 或 `git stash` 再继续
   - 用户确认继续后才往下走
3. 创建 feature 分支：`git checkout -b feat/<需求简述>`
   - 分支名从需求中提取关键词，用英文小写 + 短横线，如 `feat/add-login-page`
   - 记录基准分支名到变量 `BASE_BRANCH`（即创建分支前所在的分支），后续 diff 使用
4. 清理并创建 `.design/` 目录（`rm -rf .design && mkdir -p .design`）
5. 告知用户："开始三阶段双 Agent 协作流程（分支：feat/xxx，基准：BASE_BRANCH）"

### 阶段一：设计辩论

1. 分析当前项目结构和代码，理解需求上下文
2. 按以下固定模板写设计文档到 `.design/design.md`：

```markdown
# 设计文档：<需求简述>

## 原始需求
> <逐字引用 $ARGUMENTS>

## 目标
- <要达成什么>

## 非目标
- <明确不做什么>

## 方案概述
<用 1-3 段话描述核心方案>

## 文件清单
| 文件 | 操作 | 说明 |
|------|------|------|
| path/to/file | 新建/修改/删除 | 一句话说明改什么 |

## 接口变更
<如果有 API/函数签名/配置格式变更，写新旧对比；如无则写"无">

## 边界情况与风险
| 场景 | 处理方式 |
|------|----------|
| <异常/边界场景> | <如何处理> |
```

3. **需求自检**：逐条对照原始需求（`$ARGUMENTS`）检查设计文档：
   - 需求中的每个要点是否都在设计中有对应？
   - 设计中是否有超出需求范围的内容？如果有，标注为"额外改动"并说明理由
4. **用户检查点**：向用户展示设计文档摘要（目标、方案概述、文件清单），询问："方向对吗？确认后我发给 Codex 审查。"等待用户确认后再继续。
5. **确定 Codex 文件列表**：确认以下文件是否存在（不需要读取内容）：
   - `~/.claude/prompts/dual-agent/architect.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在）
   - `.claude/codex-context.md`（如果存在，用 Read 读取 manifest，解析出文件路径列表）
   - `.design/design.md`（设计文档）
6. 调用 Codex 审查设计（首次调用启用 session + 保存原始输出），通过 `--file` 传递文件：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/architect.md \
  --file CLAUDE.md \
  --file .design/design.md \
  <如果有 codex-context.md 中的文件，每个加 --file> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-design-1.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

审查 design.md 中的设计方案。按照 architect.md 中定义的角色要求和检查清单输出审查结论。
PROMPT
```

7. 处理 Codex 的反馈（**注意心态切换**——默认假设 Codex 可能是对的）：
   - 按"分歧解决机制"分类处理每条 P0/P1
   - 如果 Codex 的建议会改变需求范围 → 标记 `deferred`，翻译后呈现给用户决定
   - 更新 `.design/design.md`
   - 按结构化表格格式将本轮结果追加到 `.design/design-debate.md`
   - 告知用户 Codex 原始输出已保存到 `.design/codex-raw-design-N.md`
8. 第 2 轮及之后：读取 `.design/.codex-session` 获取 session ID，使用 `--resume` 复用会话：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/architect.md \
  --file .design/design.md \
  --file .design/design-debate.md \
  --resume <SESSION_ID> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-design-N.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

以上是之前轮次的处理记录（见 design-debate.md）。状态为 fixed 的问题已修复，状态为 rejected 的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证 fixed 问题是否真正解决，2）发现新的问题。

审查更新后的 design.md。按照角色要求输出审查结论。
PROMPT
```

9. **自适应轮次与收敛判断**：
   - Codex 返回无新 P0/P1 → 直接通过，进入阶段二
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 视为无新问题，直接通过
   - 有新 P0 → 继续下一轮（最多 3 轮）
   - 只有新 P1（无 P0）→ 继续下一轮（最多 2 轮）
   - 剩余问题全是取舍类且已 deferred → 直接通过
   - 达到轮次上限仍有未解决的 P0/P1 → 停止，告知用户未解决的问题，询问是否继续

### 阶段二：实现

1. 读取 `.design/design.md` 中的最终设计
2. 实现所有代码改动
3. 运行项目的构建/测试命令
4. 写改动摘要到 `.design/changeset.md`，包含：
   - 修改/新建的文件清单（必须与实际改动的文件一一对应，不多不少）
   - 风险点
   - 需要人工确认的事项
   - 注意：实现全部完成后，用 `git diff --name-only $BASE_BRANCH...HEAD` 交叉验证文件清单的准确性（如果尚未 commit，用 `git diff --name-only --cached` 替代）。验证时忽略 `.design/` 目录和构建系统自动生成的文件（如 `.xcodeproj`、`package-lock.json`），只核对源码文件

### 阶段三：代码审查

1. 获取精确范围的 diff 并保存到文件：
   - 优先：`git diff $BASE_BRANCH...HEAD > .design/diff.txt`（只含本分支改动）
   - 备选（尚未 commit）：`git diff --cached -- file1 file2 ... > .design/diff.txt`
   - 备选（用户跳过了建分支）：只 diff design.md 中列出的文件 → `git diff -- file1 file2 ... > .design/diff.txt`
   - 同时获取 diff 行数：`wc -l < .design/diff.txt`，记录到变量 `DIFF_LINES`
2. 从 `.design/design.md` 提取要修改的文件清单，作为审查范围
3. **确定 Codex 文件列表**：确认以下文件是否存在（不需要读取内容）：
   - `~/.claude/prompts/dual-agent/reviewer.md`（角色 prompt）
   - 项目根目录的 `CLAUDE.md`（如果存在）
   - `.claude/codex-context.md`（如果存在，用 Read 读取 manifest，解析出文件路径列表）
   - `.design/design.md`（设计文档）
   - `.design/changeset.md`（改动摘要）
   - `.design/diff.txt`（代码 diff）
4. **尝试复用 session**：检查 `.design/.codex-session` 是否存在，如果存在则读取其中的 session ID
5. 调用 Codex 审查代码，通过 `--file` 传递所有文件：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/reviewer.md \
  --file CLAUDE.md \
  --file .design/design.md \
  --file .design/changeset.md \
  --file .design/diff.txt \
  <如果有 codex-context.md 中的文件，每个加 --file> \
  --resume <SESSION_ID> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-review-1.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

审查范围仅限以下文件：
<此处列出文件清单>

按照 reviewer.md 中定义的角色要求输出审查结论。
PROMPT
```

6. 处理 Codex 的反馈（**注意心态切换**）：
   - 按"分歧解决机制"分类处理每条 P0/P1
   - 按结构化表格格式将本轮结果追加到 `.design/implementation-debate.md`
   - 告知用户 Codex 原始输出已保存到 `.design/codex-raw-review-N.md`
7. **刷新 diff**：修复代码后重新生成 diff（`git diff $BASE_BRANCH...HEAD > .design/diff.txt`），确保下一轮 Codex 审查的是最新代码
8. 第 2 轮及之后：继续使用 `--resume` 复用会话：

```
~/.claude/bin/codex-call \
  --file ~/.claude/prompts/dual-agent/reviewer.md \
  --file .design/diff.txt \
  --file .design/implementation-debate.md \
  --resume <SESSION_ID> \
  --session-file .design/.codex-session \
  --save-output .design/codex-raw-review-N.md \
  - <<'PROMPT'
<REQUIREMENT>
此处逐字引用用户原始需求
</REQUIREMENT>

以上是之前轮次的处理记录（见 implementation-debate.md）。状态为 fixed 的问题已修复，状态为 rejected 的问题不要重复提出，除非你认为拒绝理由有具体的技术错误并能给出反驳。只关注：1）验证 fixed 问题是否真正解决，2）发现新的问题。

按照角色要求输出审查结论。
PROMPT
```

9. **自适应轮次与收敛判断**：
   - Codex 返回无新 P0/P1 → 直接通过
   - Codex 只重复了已 rejected 的问题且无新的技术反驳 → 视为无新问题，直接通过
   - 有新 P0 → 继续下一轮（最多 3 轮）
   - 只有新 P1（无 P0）→ 继续下一轮（最多 2 轮）
   - 剩余问题全是取舍类且已 deferred → 直接通过
   - 达到轮次上限仍有未解决的 P0/P1 → 停止，告知用户未解决的问题

### 完成

1. 如果阶段三有 P0/P1 修复导致接口或架构变更，回溯更新 `.design/design.md`，使其与最终实现一致。
2. 告知用户流程结果，列出 `.design/` 目录下的产物，特别提示：
   - `codex-raw-*.md` 文件包含 Codex 的原始输出，可随时审计
   - 标注为 `deferred` 的问题（如果有）需要用户后续关注
3. 询问用户是否要提交代码（git commit）。如果用户确认，执行 commit。

## 需求

$ARGUMENTS
