# Allegro Vibe Bridge (交互式沉浸编程工具)

这是一个专为 Cadence Allegro 和 AI agent（例如claude code/codex/antigravity等） 打造的轻量级、无阻塞的 Vibe Coding 桥接系统。它让你可以在现代 IDE 中编写 SKILL 代码，并实时在 Allegro 中执行和查看结果。

## 📁 目录结构

- `vibe_server.il`: 运行在 Allegro 中的核心服务端脚本。它使用原生 `axlUIWTimerAdd` 定时器监控代码输入，保证了界面绝对不卡顿。
- `allegro_client.py`: 运行在 AI agent 终端的 Python 交互客户端。负责将代码发送给服务端，并抓取执行结果打印。
- `get_stackup.il`: 示例 SKILL 脚本。展示了如何安全地获取 Allegro 的叠层数据并组装成字符串返回。
- `workspace/`: (自动生成) 存放用于进程间通信的临时文件 `vibe_in.il` 和 `vibe_out.log`。

---

## 🚀 快速开始

### 1. 启动 Allegro 服务端
在您打开的 Allegro 的 Command 窗口中输入以下命令：

```skill
skill load("<YOUR_PROJECT_PATH>/vibe_server.il")
skill vibeStartServer()
```
*提示：看到 `Vibe Polling Server started successfully.` 表示服务端已启动并在后台静默轮询。*

### 2. 在 AI agent 中发送代码

打开 AI agent 的终端，进入本文件夹目录：
```bash
cd "<YOUR_PROJECT_PATH>"
```

#### 模式 A：交互式模式 (REPL)
直接运行 Python 脚本进入交互界面，这非常适合测试单行命令：
```bash
python allegro_client.py
```
进入后输入 `result = 100 + 200`，按回车即可看到秒回结果。输入 `exit` 退出。

#### 模式 B：发送单行指令
如果您只是想临时查一个变量或者执行一个短命令：
```bash
python allegro_client.py "axlVersion()"
```
*(注意：请避免在单行指令中使用带双引号的复杂字符串，Windows 终端解析可能会破坏引号导致语法错误。对于复杂逻辑，请使用模式 C。)*

#### 模式 C：执行外部 SKILL 脚本文件 (推荐)
如果您正在编写大段的逻辑（如获取叠层、遍历所有器件等），请将代码写在独立的 `.il` 文件中（比如本项目自带的 `get_stackup.il`），然后使用 `-f` 参数一键发送整个文件：
```bash
python allegro_client.py -f get_stackup.il
```
这是 Vibe Coding 的最佳实践：在左侧窗口编辑 `get_stackup.il`，保存后在终端按上箭头+回车，立刻就能在 Allegro 中看到该脚本的执行全貌！

---

## ⚠️ 注意事项

1. 所有的 SKILL 代码如果想要将结果返回给 AI agent，请确保在代码块的**最后一行**放置想要返回的变量或字符串。例如 `get_stackup.il` 最后一行为 `msg`。
2. **强大的错误捕捉**：如果您书写的 SKILL 代码包含语法错误或运行时异常，`vibe_server` 会通过底层错误端口（`errport`）重定向，将原汁原味的报错信息（如 `*Error* eval: undefined function`）直接返回并在终端中用红色打印！您无需再频繁切换到 Allegro 窗口查看排错信息。
   *(注：部分非致命的 `*WARNING*` 仍会在 Allegro 的命令窗口中打印，供您辅助诊断。)*
3. 如果您需要停止 Allegro 端的轮询，请在 Allegro 中执行：
   ```skill
   axlUIWTimerRemove(vibeTimerId)
   ```
