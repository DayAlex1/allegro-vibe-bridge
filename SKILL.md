---
name: allegro-vibe
description: |
  Use this skill whenever the user wants to interact with Cadence Allegro PCB design through the Vibe Bridge — querying design data (stackup, constraints, components, nets), executing SKILL code in an open Allegro session, or debugging SKILL scripts. Triggers on: mentions of Allegro, SKILL, PCB, Cadence, constraint manager, stackup, layout queries, vibe bridge, or any request to "get/check/query/find" design parameters from a board file. Also triggers when the user references the allegro_vibe_bridge project or asks to "send code to Allegro".
---

# Allegro Vibe Bridge — Vibe Coding 工作流

## 项目位置

```
<YOUR_PROJECT_PATH>\
```

关键文件：
- `vibe_server.il` — Allegro 端定时轮询服务（需先在 Allegro 中 load 并 start）
- `allegro_client.py` — IDE 端 Python 客户端
- `get_stackup.il` — 示例 SKILL 脚本
- `workspace/` — IPC 临时文件目录

### 目录规范

**主目录只保留以上 3 个核心文件，禁止在根目录创建任何 .il 文件！**

- 所有桥接过程中生成的临时 .il 脚本一律放入 `temp/` 子目录
- `temp/` 目录不存在时先创建再写入
- 用完的临时脚本在任务完成后应清理（但保留 `temp/` 目录本身）
- 文件模式下引用 .il 文件时使用相对路径 `temp/xxx.il`，如：
  ```bash
  python allegro_client.py -f temp/query_spacing.il
  ```

## 工作流概览

每个 Allegro 查询任务都遵循以下模式：

```
用户需求 → 查 NotebookLM 获取 API → 写代码 → 通过 Bridge 执行 → 调试迭代 → 呈现结果
```

## 前置条件

在执行任何代码之前，先确认：
- Allegro 已打开设计文件
- `vibe_server.il` 已 load 且 `vibeStartServer()` 已运行
- 用户的 NotebookLM 知识库中已有 "Allegro SKILL Programming Guide"（ID: `allegro-skill-programming-guide`）

## Phase 1: 查询 NotebookLM 获取 SKILL API 知识

**核心原则：永远不要凭记忆猜测 SKILL 函数名和参数。** SKILL API 有大量版本差异和命名陷阱，必须先查 NotebookLM。

### 步骤
1. 检查 auth：`python scripts/run.py auth_manager.py status`（在 `<NOTEBOOKLM_SKILL_PATH>` 下）
2. 查询 API：
   ```bash
   cd "<NOTEBOOKLM_SKILL_PATH>"
   python scripts/run.py ask_question.py --notebook-id allegro-skill-programming-guide \
     --question "你的问题（要具体，包含你想做什么、参数类型、返回值）"
   ```
3. **追问直到信息完整**：NotebookLM 每次回答后会问"Is that ALL you need?"，必须确认以下信息完整后再进入 Phase 2：
   - 函数名和完整签名
   - 每个参数的含义和可选值
   - 返回值类型和单位
   - 至少一个代码示例

### 查询技巧
- 第一次查询要具体但全面，一次性问清楚
- 追问时带上上下文（函数名、场景），因为每次都是新 session
- 典型追问：层名格式（"TOP" vs "ETCH/TOP"）、单位转换、错误处理

## Phase 2: 编写并执行 SKILL 代码

### Bridge 三种模式

| 模式 | 命令 | 适用场景 |
|------|------|----------|
| **REPL 单行**（推荐首选）| `python allegro_client.py "<code>"` | 单次函数调用、简单查询、调试 |
| **文件模式** | `python allegro_client.py -f <file.il>` | 多步逻辑、循环、条件判断 |
| **交互 REPL** | `python allegro_client.py` | 需要连续交互探索时 |

### ⚠️ 关键踩坑规则

#### 规则 0：临时 .il 文件必须放入 `temp/` 目录！

根目录只保留 `vibe_server.il`、`allegro_client.py`、`get_stackup.il` 三个核心文件。所有桥接过程中创建的 .il 脚本一律放入 `temp/` 子目录：

```bash
# 先确保 temp/ 存在
mkdir -p temp

# 文件写入 temp/ 目录
# Write: temp/query_spacing.il

# 执行时引用 temp/ 路径
python allegro_client.py -f temp/query_spacing.il
```

完成后清理：删除临时 .il 文件，保留 `temp/` 目录。

#### 规则 1：文件模式绝对不要用 `;` 注释！

Bridge 服务端用 `strcat` 拼接代码行，虽然 `gets` 保留了换行符，但 `;` 注释在某些情况下会导致代码被意外注释。**已实测验证：含 `;` 注释的 .il 文件返回 nil，去掉注释后正常。**

正确做法：
- 文件模式：零注释，纯代码
- 需要说明时用 REPL 单行模式逐条执行

```skill
; ❌ 错误 — 文件模式中分号注释会导致后续代码被吞
; 获取所有层
etch_layers = axlSubclassRoute()

; ✅ 正确 — 文件模式不用注释
etch_layers = axlSubclassRoute()
```

#### 规则 2：简单查询优先用 REPL 单行模式

```bash
# 一步搞定：查询 + 转换单位
python allegro_client.py "axlMKSConvert(axlCNSGetSpacing(\"\" \"TOP\" 'line_line) \"design\" \"MILS\")"
```

比写文件→执行→看结果快得多，适合快速探索。

#### 规则 3：返回值解析

Bridge 输出格式：
```
SUCCESS
<value>
```

- `<value>` 用 SKILL `%L` 格式化，`nil` 显示为字面量 `nil`，数字直接显示
- 如果返回 `t` 但期望数字，说明函数在该上下文中返回了布尔值（可能是约束存在性而非值），需换查询方式
- `printf` 输出进入 Allegro Command Window，不回传给 Bridge（只有最后表达式的值回传）

#### 规则 4：单位转换公式

```skill
value_mils = axlMKSConvert(raw_value "design" "MILS")
value_mm   = axlMKSConvert(raw_value "design" "MILLIMETERS")
```

`axlCNSGetSpacing` 返回值是设计单位（DBU），具体单位取决于设计设置（常见为 μm）。

## Phase 3: 调试迭代

常见问题速查：

| 症状 | 原因 | 解决 |
|------|------|------|
| 文件模式返回 `nil` | 文件含 `;` 注释 | 去掉所有注释 |
| 返回 `t` 但期望数值 | 约束返回布尔值 | 用 `nil` 参数查所有约束看结构 |
| `printf` 的调试信息看不到 | `printf` 输出到 Allegro 窗口 | 正常现象，把关键数据放在最后一行返回 |
| REPL 模式字符串含引号报错 | Windows 命令行引号解析 | 用文件模式或转义 `\"` |
| 返回 `75.0` 不知单位 | 设计单位未确认 | 用 `axlMKSConvert` 转换后同时输出 mils 和 mm |

### 调试策略
1. **先用 REPL 验证单个函数** — 确认函数存在且参数正确
2. **用 `nil` 参数展开全部数据** — 如 `axlCNSGetSpacing("" "TOP" nil)` 不加约束筛选
3. **逐步增加复杂度** — 验证通过后再写到 .il 文件

## Phase 4: 呈现结果

- 同时展示设计单位和常用单位（mils / mm）
- 标注查询参数（层名、约束集名称）
- 简要说明使用的函数，方便用户复现

## Phase 5: 清理、自我验证归档与知识沉淀

每次完成脚本开发后，必须执行以下规范的收尾工作：

### 1. 自我验证与自动归档
- **自我验证**：在宣称任务完成前，必须自己运行脚本，并真实读取输出内容（桥接返回或日志文件），确保得到的数据完全符合用户预期。
- **自动归档**：待用户确认功能无误后，将完成的 `.il` 脚本整理后移动/保存到项目根目录的 `archive/` 文件夹中（不存在则创建），并给予规范命名（如 `get_component_info.il`）。

### 2. 清理临时文件夹 (Auto-cleanup)
- 归档完成后，主动删除 `temp/` 目录下本次任务产生的所有残留临时 `.il` 测试脚本、错误日志等中间文件。
- 坚决杜绝把 `temp/` 文件夹搞得乱糟糟。

### 3. 沉淀至全局函数库
- 脚本归档后，梳理本次用到的新 Allegro SKILL 函数。
- 自动将这些函数的使用方法、参数解析和示例代码，汇总并追加到本 Agent 的全局知识库文件 `references/skill_library.md` 中（位于 `<GLOBAL_SKILL_LIBRARY_PATH>`）。
- **效率提升原则**：在后续所有的 coding 过程中，**必须优先使用 `view_file` 查阅全局的 `skill_library.md` 中寻找答案**。只有全局库没有时，再去查阅 NotebookLM。这将极大增加效率，让本 Skill 越用越聪明。

---

## 常用 SKILL 函数速查

以下从 NotebookLM 知识库提取，作为快速参考（执行前仍建议查 NotebookLM 确认）：

### 约束查询
```skill
; 获取间距约束
axlCNSGetSpacing(cset layer constraint)  
; cset: "" = DEFAULT,  "约束集名" = 特定csetset
; layer: "TOP", "ETCH/TOP", 或 nil = 所有层
; constraint: 'line_line, 'shape_shape, nil = 所有

; 获取物理约束
axlCNSGetPhysical(cset layer constraint)
; constraint: 'width_min, 'width_max, etc.
```

### 层操作
```skill
axlSubclassRoute()          ; 列出所有 ETCH 层
axlGetParam("paramLayerGroup:ETCH")  ; 获取层组对象
```

### 单位转换
```skill
axlMKSConvert(value "design" "MILS")
axlMKSConvert(value "design" "MILLIMETERS")
axlMKSConvert(value "design" "MICROMETERS")
```

---

## 示例：完整的查询任务

用户问："查一下 TOP 层 line to line 间距"

### 执行过程：

**Step 1** — 查 NotebookLM：
```bash
python scripts/run.py ask_question.py --notebook-id allegro-skill-programming-guide \
  --question "How to get line-to-line spacing constraint for TOP layer? Need function name, parameters, return value, and unit conversion."
```

**Step 2** — 确认后用 REPL 单行执行：
```bash
python allegro_client.py "axlCNSGetSpacing(\"\" \"TOP\" 'line_line)"
```
→ 得到 `75.0`

**Step 3** — 转换单位确认：
```bash
python allegro_client.py "axlMKSConvert(75.0 \"design\" \"MILS\")"
```
→ 得到 `2.952756` mils

**Step 4** — 呈现结果："TOP 层 line-to-line 间距为 75 μm (0.075 mm / ~2.95 mils)"

---

## 边界情况处理

- **设计未打开**：提示用户在 Allegro 中打开设计
- **Server 未启动**：提示用户执行 `skill load("vibe_server.il")` 和 `skill vibeStartServer()`
- **Bridge 超时**：检查 Allegro 是否响应、workspace 目录权限
- **NotebookLM 查询限额**：免费账号每天 50 次查询，注意节约使用
- **约束集非 DEFAULT**：如果 `""` 返回 nil，需要先获取可用约束集列表
- **层名不匹配**：先用 `axlSubclassRoute()` 获取实际层名
