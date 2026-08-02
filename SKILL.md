---
name: allegro-vibe
description: |
  Use this skill whenever the user wants to interact with Cadence Allegro PCB design through the Vibe Bridge — querying design data (stackup, constraints, components, nets), executing SKILL code in an open Allegro session, or debugging SKILL scripts. Triggers on: mentions of Allegro, SKILL, PCB, Cadence, constraint manager, stackup, layout queries, vibe bridge, or any request to "get/check/query/find" design parameters from a board file. Also triggers when the user references the allegro_vibe_bridge project or asks to "send code to Allegro".
---

# Allegro Vibe Bridge — AI Agent 工作流

> **目标读者：AI Agent（Claude Code、Antigravity 等）。** 人类用户请阅读 [`README.md`](./README.md)。

本工作流指导 AI Agent 通过 Vibe Bridge 与 Cadence Allegro PCB 系统交互，涵盖 **API 知识查询**、**代码下发与调试**及 **IPC 文件通信**。

---

## 工作流总览

交互过程分为四个阶段 (Phase 1 ➔ Phase 4)：

```
[ 用户需求 ]
     │
     ▼
Phase 1: 需求分析与知识查询 ──► 优先查本地库 skill_library.md ──► 未命中则调用 NotebookLM 查询
     │
     ▼
Phase 2: 编写与下发 SKILL 代码 ──► 通过 allegro_client.py 下发 ──► 触发 IPC 通信
     │
     ▼
Phase 3: 调试与迭代反馈 ───────► 轮询 vibe_out.log 获取返回 ──► 解析结果（报错则回 Phase 2 修改）
     │
     ▼
Phase 4: 验证与清理归档 ───────► 确认结果无误后归档至 archive/ ──► 清理 temp/ ──► 更新本地知识库
```

---

## 环境与目录规范

### 1. 核心项目文件
```
<YOUR_PROJECT_PATH>\
├── vibe_server.il              # Allegro 端轮询服务（在 Allegro 中 skill load 启动）
├── allegro_client.py           # 客户端代码下发工具（支持单行 REPL 和文件运行）
├── references/skill_library.md # 本地 SKILL 函数知识库（优先查询）
├── temp/                       # 临时脚本目录（任务完成后清理）
└── archive/                    # 验证通过的 SKILL 脚本归档库
```

### 2. 目录规范
**根目录仅保留核心桥接工具文件，禁止在根目录创建业务性 `.il` 文件。**
- **临时脚本**：所有 `.il` 测试脚本必须放入 `temp/` 目录。
- **命令行调用**：文件模式传入相对路径 `temp/<filename>.il`。
  ```bash
  mkdir -p temp
  python allegro_client.py -f temp/query_stackup.il
  ```

### 3. 前置检查
- Allegro 已打开目标板文件 (Design)。
- `vibe_server.il` 已在 Allegro 内加载（`load` 后自动监听）。
- **外部知识库检查**：如需复杂 API 探索，检查是否可用 [notebooklm-skill](https://github.com/PleasePrompto/notebooklm-skill)，且 NotebookLM 包含相关笔记本。
  - **笔记本内容要求**：包含 **SKILL 语法规范**与 **Allegro AXL 函数说明**（含参数解释与返回值约定）。
  - **缺失引导**：若缺少相关环境，主动询问用户是否需要协助配置。

---

## Phase 1: 需求分析与知识查询

**核心原则：切勿凭记忆猜测 SKILL 函数名与参数。** SKILL API 存在版本差异与命名细节，按以下顺序查询：

### 1A. 优先查阅本地知识库
- 编写代码前，首选查询 `references/skill_library.md` 获取已验证的 API 用法与范例代码。

### 1B. 调用 NotebookLM 查询（本地库未命中时）
若 `references/skill_library.md` 未命中：
- 调用 [notebooklm-skill](https://github.com/PleasePrompto/notebooklm-skill) 向外部知识库查询。
- 明确提供编程意图与待查询的函数/接口。
- 结合查询结果进入 Phase 2 编写代码。

---

## Phase 2: 编写与下发 SKILL 代码

### 1. Client 客户端执行模式

| 运行模式 | 命令示例 | 适用场景 |
| :--- | :--- | :--- |
| **单行内联 (REPL)**（推荐首选） | `python allegro_client.py "<code>"` | 单个函数测试、变量查询或简单断言 |
| **文件驱动模式** | `python allegro_client.py -f temp/<file>.il` | 循环、复杂逻辑或多行脚本 |
| **交互会话模式** | `python allegro_client.py` | 复杂问题排查时的持续交互调试 |

### 2. IPC 通信与执行流程
1. **代码下发**：`allegro_client.py` 将命令写入 `vibe_in.il`。
2. **服务端读取**：Allegro 后台 `vibe_server.il` 定时轮询并读取脚本。
3. **执行代码**：Allegro 运行时通过 `evalstring` 执行。
4. **日志捕获**：终端输出与表达式返回值写入 `vibe_out.log`。
5. **获取结果**：`allegro_client.py` 读取 `vibe_out.log` 变化并输出到 CLI。

---

## Phase 3: 调试与迭代反馈

### 1. 调试与纠偏流程
- **发生错误或异常**（报错、返回 `nil` 或格式不符）：分析根因（入参大小写、层名称错误、结构层级偏移等），修改后返回 **Phase 2** 重新测试。
- **验证通过**：输出完全符合需求后，进入 **Phase 4**。

### 2. 调试策略
- **分步验证**：复杂逻辑先用**单行内联模式**逐个验证单个 API，确认无误后再组装。
- **宽松查询**：无法确定筛选条件时，先传入宽松参数（如 `""` / `nil`）观察全量返回数据。
- **全量运行测试**：合并为完整 `.il` 文件后，必须执行一次 `python allegro_client.py -f temp/<file>.il` 进行完整测试。
  - 若脚本生成报表或导出日志，需检查输出内容的正确性。
  - 确保最终代码无报错且满足用户需求。

---

## Phase 4: 验证、归档与沉淀

任务完成后执行以下操作：

### 1. 结果验证
任务完成前，确保已在真实 Allegro PCB 环境中成功运行并获取预期结果。

### 2. 正式产物归档
将验证通过的代码从 `temp/` 移动至 **`archive/`** 目录（如 `archive/get_component_list.il`）。

### 3. 环境清理
清理 `temp/` 目录中的临时脚本和日志文件，仅保留空的 `temp/` 文件夹。

### 4. 知识沉淀
- **整理经验**：梳理调试中发现的关键点（生僻 API 参数规则、数据格式、转换细节等）。
- **更新知识库**：将整理后的 API 说明、参数解析与代码示例追加到 **`references/skill_library.md`**。
- **持续积累**：通过沉淀知识，提升后续 Phase 1A 检索本地库的命中率。
