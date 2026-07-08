# Allegro SKILL 本地函数库 (Local Knowledge Base)

这是本项目在实际 Vibe Coding 过程中沉淀的常用 SKILL API 函数库。在后续开发新功能时，请**优先查阅本文件**，以提升编码效率并减少踩坑。

## 数据库提取 (Database Access)

### `axlDBGetDesign`
- **功能**：获取当前打开的 Allegro 设计的顶层数据库对象（根对象）。
- **参数**：无。
- **返回值**：返回设计对象（如 `dbid:123456`），通过它可以访问所有的元件、网络、走线等。
- **示例**：
  ```skill
  design = axlDBGetDesign()
  symbols = design->symbols ; 获取设计中所有的元器件 (Symbols)
  nets = design->nets       ; 获取所有网络
  ```

## 符号与器件属性 (Symbols & Components)

### `symbol->refdes`
- **功能**：获取元器件的位号（Reference Designator）。如果是一个常规器件，它将有一个字符串（如 `"R1"`）。如果是机械定位孔或板框符号，这可能是 `nil`。

### `symbol->bBox`
- **功能**：获取元器件的边界框（Bounding Box）。
- **返回值**：一个包含两个坐标点的列表，表示左下角和右上角，如 `((x1 y1) (x2 y2))`。
- **示例**：
  ```skill
  box = sym->bBox
  width = car(cadr(box)) - car(car(box))   ; x2 - x1
  height = cadr(cadr(box)) - cadr(car(box)) ; y2 - y1
  ```

### `symbol->pins`
- **功能**：获取属于该元器件的所有引脚（Pins）对象的列表。可以通过遍历这个列表来检查每个引脚。

### `pin->definition`
- **功能**：获取引脚对应的焊盘栈定义对象（Padstack Definition）。这用于查询这个引脚物理上使用的孔径、焊盘大小等。

### `padstack->drillDiameter`
- **功能**：获取焊盘栈的钻孔直径（实数）。如果不是通孔（如表贴器件），通常返回 `0.0` 或 `nil`。

### `padstack->pads`
- **功能**：获取焊盘栈在不同层上的焊盘形状定义列表。
- **说明**：通过遍历 `padstack->pads`，可以过滤出特定类型的焊盘（例如 `pad->type == "REGULAR"`）。

## 文件与 I/O (File I/O)

### `outfile`
- **功能**：打开一个文件用于写入。如果文件不存在则创建，如果存在则覆盖。
- **参数**：文件名字符串（绝对路径或相对于 Allegro 当前工作目录的路径）。
- **返回值**：成功返回端口对象（Port），失败返回 `nil`。
- **注意**：绝对不要用 `axlLogOpen` 写常规文件数据，应该用标准 SKILL `outfile`。
- **示例**：
  ```skill
  outPort = outfile("report.log")
  ```

### `fprintf` / `sprintf`
- **功能**：格式化输出。`fprintf` 输出到指定的文件端口，`sprintf` 输出并返回一个字符串。
- **常用格式符**：
  - `%s`：字符串
  - `%d`：整数
  - `%.3f`：保留三位小数的浮点数
  - `%L`：打印任何 LISP 对象的字面量表示（非常适合打印列表 `nil`, `("A" "B")` 等）
- **示例**：
  ```skill
  fprintf(outPort "Name: %s | Size: %.2f\n" name size)
  str = sprintf(nil "%.3f x %.3f" w h) ; nil 表示返回字符串而不是打印到标准输出
  ```

## 字符串操作 (String Manipulation)

### `substring`
- **功能**：从字符串中提取子串。
- **参数**：
  1. 字符串
  2. 起始位置（1-based，即第一位是 1）
  3. 截取长度（可选）
- **返回值**：提取的字符串片段。
- **使用场景**：在遍历设计元器件时，通过检查首字母（如 `substring(refdes 1 1) == "U"`）来快速过滤提取芯片（IC），从而剔除 R（电阻）、C（电容）等离散器件。
- **示例**：
  ```skill
  if(substring(sym->refdes 1 1) == "U" then
      ; 处理芯片...
  )
  ```

### `close`
- **功能**：关闭一个打开的文件端口。
- **参数**：端口对象。
- **示例**：
  ```skill
  close(outPort)
  ```

## UI 与用户交互 (User Interface)

### `axlUIViewFileCreate`
- **功能**：在 Allegro 软件的内置文本查看器中自动弹出一个文件，供用户阅读。
- **参数**：
  1. 文件路径（相对于当前工作目录）
  2. 窗口标题字符串
  3. `nil`（保留参数）
- **示例**：
  ```skill
  axlUIViewFileCreate("component_report.log" "Component Report" nil)
  ```

### `axlMsgPut`
- **功能**：在 Allegro 软件底部的 Command 命令行窗口输出提示信息。
- **参数**：字符串（支持简单的 printf 格式化）。
- **示例**：
  ```skill
  axlMsgPut("Report generated successfully.")
  ```

## 泪滴与连接检查 (Teardrops & Connectivity)

### `axlDBGetConnect`
- **功能**：获取连接到指定对象的所有元素。
- **参数**：
  1. `dbid`：对象（如 pin, via, cline 等）
  2. `t_full` (可选)：传 `t` 返回完整的连接对象，包括 cline, shape, pin, via 等。
- **返回值**：与传入对象相连的所有对象的列表。
- **示例**：
  ```skill
  connected = axlDBGetConnect(pin t)
  clines = setof(x connected x->objType == "path") ; 筛选出走线
  ```

### 泪滴判断 (Teardrop Detection)
- **原理**：在 Allegro 中，泪滴实际上是一种形状（shape），其 `fillet` 属性被设置为 `t`。
- **检测方法**：要检测某个 pin 或 via 上是否连接有泪滴，可以通过 `axlDBGetConnect` 提取所有连接对象，筛选出 `shape`，并检查其 `fillet` 属性。
- **示例**：
  ```skill
  connected = axlDBGetConnect(pin t)
  shapes = setof(x connected x->objType == "shape")
  has_teardrop = nil
  foreach(s shapes
      if(s->fillet then has_teardrop = t)
  )
  ```

## UI 与命令注册扩展 (UI & Command Registration)

### `axlEnterString`
- **功能**：弹出一个带文本框的对话框，请求用户输入字符串。这是一个阻塞型交互函数。
- **参数**：可以使用命名的参数如 `?prompts`，接收一个字符串列表。
- **返回值**：用户输入的字符串；如果用户点击 Cancel，则返回 `nil`。
- **示例**：
  ```skill
  user_input = axlEnterString(
      ?prompts list("Enter nets to ignore (e.g. GND, VCC)")
  )
  ```

### `axlCmdRegister` (Interactive Mode)
- **功能**：注册 SKILL 函数为 Allegro 内置命令。
- **陷阱与最佳实践**：如果脚本中使用了交互式 UI（如 `axlEnterString`）或需要改变/查询复杂的连接性，**建议**加上 `?cmdType "interactive"`。这会在执行前安全地 "done" 掉其他正在活动的交互命令，防止数据库查询（如 `axlDBGetConnect`）受到活动命令状态的干扰而失效。同时建议在一切 UI 阻塞操作**之后**再调用 `axlDBGetDesign()` 重新获取最新的设计句柄。
- **示例**：
  ```skill
  axlCmdRegister("my_cmd" 'myFunc ?cmdType "interactive")
  ```

## 字符串匹配 (Regex & Pattern Matching)

### `pcreMatchp`
- **功能**：执行无副作用的 Perl 兼容正则表达式匹配（推荐方案）。
- **陷阱与最佳实践**：尽量**不要**使用老旧的 `rexCompile` + `rexExecute`。`rexCompile` 会修改 SKILL 全局的正则表达式缓存区。一旦你在自定义脚本中污染了全局的 `rex` 状态，将会导致那些依赖全局状态的系统内置函数（如 `axlDBGetConnect`）在后续执行时遇到不可预知的查询失败 Bug。应该统一使用无状态的 `pcreMatchp` 来做匹配。
- **示例**：
  ```skill
  ; 通配符转换逻辑
  if(pcreMatchp("^VCC.*" netName) then
      ; 匹配成功
  )
  ```

## 网络与过孔 (Nets & Vias)
- **陷阱与最佳实践**：不要直接读取 `design->vias`，因为很多情况下通过该属性拿不到任何过孔对象。要在设计中遍历所有存在物理连接的过孔，标准的做法是按层级深度遍历：`nets` -> `branches` -> `children`。
- **示例**：
  ```skill
  foreach(net design->nets
      foreach(branch net->branches
          foreach(via setof(child branch->children child->objType == "via")
              ; 处理 via
          )
      )
  )
  ```
