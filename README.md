# Allegro Vibe Bridge（交互式沉浸编程工具）

这是一个专为 Cadence Allegro 和 AI agent（例如 Claude Code、Codex、Antigravity 等）打造的轻量级、无阻塞的 Vibe Coding 桥接系统。它让你可以在现代 IDE 中编写 SKILL 代码，并实时在 Allegro 中执行和查看结果。

> **💡 提示**：如果你是 AI agent（如 Claude Code），请阅读根目录下的 [`SKILL.md`](./SKILL.md)，那是你的工作流定义文件。本文档面向人类用户。

---

## 📁 目录结构

| 文件/目录 | 用途 |
|-----------|------|
| `vibe_server.il` | Allegro 端核心服务脚本，加载即启动后台轮询 |
| `allegro_client.py` | IDE 端 Python 客户端，负责发送代码和抓取结果 |
| `SKILL.md` | AI agent 的工作流定义文件（人类用户可忽略） |
| `references/` | AI agent 的 SKILL 函数知识库（由 AI 自动维护） |
| `workspace/` | 自动生成的 IPC 临时文件目录（`vibe_in.il` / `vibe_out.log`） |
| `temp/` | 存放桥接过程中生成的临时 `.il` 脚本，任务完成后清理 |
| `archive/` | 存放已验证通过的 `.il` 脚本归档 |

---

## 📚 创建 Allegro SKILL 知识库（可选但推荐）

AI agent 可以通过 [notebooklm-skill](https://github.com/PleasePrompto/notebooklm-skill) 查询 NotebookLM 知识库，获取准确的 SKILL API 函数签名、参数说明和代码示例，大幅提升编码准确率。

**如何创建**：自行获取 Cadence SKILL 相关文档（如 SKILL Language User Guide、SKILL Language Reference、Allegro SKILL API 参考等），上传到 [Google NotebookLM](https://notebooklm.google.com/) 创建笔记本，命名为 `allegro-skill-programming-guide` 即可。


---

## 🚀 快速开始

### 0. 前置要求

- **Python 3.7+**（客户端脚本不兼容 Python 2）
- **Cadence Allegro 17.4** 已安装并打开目标设计文件

### 1. 启动 Allegro 服务端

在 Allegro 的 Command 窗口中输入以下命令：

```skill
skill load("<YOUR_PROJECT_PATH>/vibe_server.il")
```

**加载即启动**，看到 `Vibe Polling Server started successfully.` 表示服务端已在后台静默轮询。

> 如需停止服务端，在 Allegro 中执行：`axlUIWTimerRemove(vibeTimerId)`

### 2. 在 IDE 终端中发送代码

进入本文件夹目录：
```bash
cd "<YOUR_PROJECT_PATH>"
```

#### 模式 A：交互式 REPL（适合测试单行命令）

```bash
python allegro_client.py
```
进入后输入 `result = 100 + 200`，按回车即可看到结果。输入 `exit` 退出。

#### 模式 B：单行指令（适合快速查询）

```bash
python allegro_client.py "axlVersion()"
```

⚠️ **Windows 用户注意**：单行模式中避免使用带双引号的复杂字符串，命令行解析可能破坏引号导致语法错误。复杂逻辑请使用模式 C。简单无引号参数无需引号包裹，例如 `python allegro_client.py 1+1` 也是合法的。

#### 模式 C：执行 SKILL 脚本文件（推荐，适合多步逻辑）

将代码写在独立的 `.il` 文件中，放入 `temp/` 目录，然后用 `-f` 参数执行：

```bash
python allegro_client.py -f temp/my_script.il
```

> **最佳实践**：在左侧窗口编辑 `temp/my_script.il`，保存后在终端按 ↑ + 回车，立刻在 Allegro 中看到执行结果。

---

## ⚠️ 踩坑规则 & 调试指南

### 规则 1：文件模式绝对不要用 `;` 注释！

Bridge 服务端用 `strcat` 拼接代码行，虽然 `gets` 保留了换行符，但 `;` 注释在某些情况下会导致后续代码被意外吞掉。**已实测验证：含 `;` 注释的 .il 文件返回 nil，去掉注释后正常。**

```skill
; ❌ 错误 — 文件模式中分号注释会导致后续代码被吞
; 获取所有层
etch_layers = axlSubclassRoute()

; ✅ 正确 — 文件模式不用注释
etch_layers = axlSubclassRoute()
```

### 规则 2：简单查询优先用 REPL 单行模式

```bash
# 一步搞定：查询 + 单位转换
python allegro_client.py "axlMKSConvert(axlCNSGetSpacing(\"\" \"TOP\" 'line_line) \"design\" \"MILS\")"
```

比写文件→执行→看结果快得多，适合快速探索。

### 规则 3：理解返回值

Bridge 输出格式：
```
SUCCESS
<value>
```

- `<value>` 用 SKILL `%L` 格式化，`nil` 显示为字面量 `nil`
- 如果返回 `t` 但期望数字，说明函数在该上下文中返回了布尔值（可能是约束存在性而非值），需换查询方式
- `printf` 输出进入 Allegro Command Window，**不回传给 Bridge**（只有最后表达式的值回传）

### 规则 4：单位转换

```skill
value_mils = axlMKSConvert(raw_value "design" "MILS")
value_mm   = axlMKSConvert(raw_value "design" "MILLIMETERS")
```

`axlCNSGetSpacing` 返回值是设计单位（DBU），具体单位取决于设计设置（常见为 μm）。

### 常见问题速查

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

---

## ⚠️ 注意事项

1. 所有 SKILL 代码如果想要将结果返回给 IDE，请确保在代码块的**最后一行**放置想要返回的变量或字符串（该变量的值将被回传给客户端）。
2. **强大的错误捕捉**：如果你书写的 SKILL 代码包含语法错误或运行时异常，`vibe_server` 会通过底层错误端口（`errport`）重定向，将原汁原味的报错信息（如 `*Error* eval: undefined function`）直接返回并在终端中用红色打印。你无需再频繁切换到 Allegro 窗口查看排错信息。*（注：部分非致命的 `*WARNING*` 仍会在 Allegro 的命令窗口中打印。）*
3. 如果你需要停止 Allegro 端的轮询，请在 Allegro 中执行：
   ```skill
   axlUIWTimerRemove(vibeTimerId)
   ```
