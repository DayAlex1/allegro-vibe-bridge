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

## 状态与检查属性 (Status & Checks)

### `design->drcs`
- **功能**：获取设计中所有的 DRC（Design Rule Check）违规列表。
- **示例**：
  ```skill
  drc_count = length(axlDBGetDesign()->drcs)
  ```

### `net->unconnected`
- **功能**：获取指定网络中未连接（Unconnected / Ratsnest）的引脚数量。
- **示例**：
  ```skill
  total_unconnected = 0
  foreach(net design->nets
      if(net->unconnected then total_unconnected = total_unconnected + net->unconnected)
  )
  ```

### 孤立元素（Dangling/Island）检查
- **原理**：使用 `axlDBGetConnect(obj t)`。对于走线（`path`）和过孔（`via`），如果返回的连接数 `< 2`，通常意味着是一端悬空（Dangling）；对于铺铜（`shape`），如果连接数 `<= 1`，则通常意味着是一块不连任何其他元素的孤岛（Isolated shape）。

### Shape 状态判定
- **属性**：
  - `shape->dynamicGroup`：如果不为 `nil`，说明这是一个动态铜皮（Dynamic shape）；如果为 `nil`，说明它是静态铜皮。
  - `shape->fillOOD`：如果为 `t`，说明该动态铜皮处于 "Out of Date" 状态，需要更新（Update to Smooth）。

## 器件与摆放 (Placement)

### `design->components` 与 `comp->symbol`
- **功能**：获取设计中所有的逻辑器件。如果一个器件尚未摆放在版图上，它的 `symbol` 属性为 `nil`。
- **示例**：
  ```skill
  unplaced = 0
  foreach(comp design->components
      if(comp->symbol == nil then unplaced = unplaced + 1)
  )
  ```

## 形状与面积运算 (Shapes & Polygons)

### `axlPolyFromDB`
- **功能**：将数据库对象（如 shape, path）转化为多边形对象（Polygon），用于数学运算。
- **参数**：数据库对象 (shape)。
- **返回值**：多边形对象列表（通常取第一个元素 `car()`）。
- **示例**：
  ```skill
  poly = car(axlPolyFromDB(shape))
  ```

### `axlPolyArea`
- **功能**：计算多边形对象的面积。
- **参数**：多边形对象。
- **返回值**：面积数值（实数），单位取决于设计的当前单位设置。
- **使用场景**：S05 铜密度与残铜率检查，用于统计各层铺铜的精确面积。
- **示例**：
  ```skill
  area = axlPolyArea(poly)
  ```

## 几何计算与距离 (Geometry & Distance)

### `axlDistance`
- **功能**：计算两个对象或坐标点之间的最短距离。
- **参数**：对象A，对象B（可以是坐标点、线段、shape等）。
- **返回值**：距离数值（实数）。
- **使用场景**：S03 间距与边距检查，例如计算 Die 到 Package Edge 的距离。
- **示例**：
  ```skill
  dist = axlDistance(pin1 pin2)
  ```

## 封装与引脚信息 (Padstack & Pins)

### `pin->definition->name`
- **功能**：获取引脚或过孔对应的 Padstack 定义名称。
- **示例**：
  ```skill
  pad_name = via->definition->name
  ```

### `axlDBGetPad`
- **功能**：根据指定的 padstack、板层和类型，提取对应的焊盘对象。
- **参数**：
  1. padstack 定义对象或名称
  2. 层名（如 `"TOP"`）
  3. 焊盘类型（如 `"REGULAR"`, `"ANTI"` 等）
- **返回值**：焊盘对象，可以通过其获取 shape 或 bBox。
- **使用场景**：S01 提取过孔钻孔尺寸和 S10 获取 Anti-pad 尺寸。
- **示例**：
  ```skill
  pad = axlDBGetPad(via->definition "TOP" "ANTI")
  ```

## 层与叠层信息 (Layers & Stackup)

### `axlGetParam("paramLayerGroup:ETCH")->groupMembers`
- **功能**：获取设计中所有的电气层（Etch layers）的有序列表，从 Top 层到底部 Bottom 层。
- **返回值**：层名字符串组成的列表，例如 `("TOP" "L2_GND" "L3_IN" "BOTTOM")`。
- **使用场景**：S02 叠孔与过孔结构检查，需要判断两个 via 跨越的层数，或寻找相邻参考平面（S12）。
- **示例**：
  ```skill
  etch_layers = axlGetParam("paramLayerGroup:ETCH")->groupMembers
  ```

## 走线与线段分析 (Clines & Segments)

### `path->segments`
- **功能**：走线（Cline / Path）由多个线段（segments）组成，通过该属性可以遍历所有的单段走线。
- **相关属性**：
  - `segment->width`：获取当前线段的线宽。
  - `segment->startEnd`：获取线段的起点和终点坐标 `((x1 y1) (x2 y2))`。
  - `segment->layer`：所在层。
- **使用场景**：S06 走线质量与几何检查，逐段检查走线线宽是否满足规则，以及相邻线段是否存在锐角。
- **示例**：
  ```skill
  foreach(seg path->segments
      if(seg->width < min_width then
          printf("Violating segment found at %L\n" seg->startEnd)
      )
  )
  ```

## 对象修改与删除 (Modification & Deletion)

### `axlDeleteObject`
- **功能**：从数据库中删除一个或多个对象。
- **参数**：单个 dbid 或 dbid 列表。
- **返回值**：成功返回 `t`，失败返回 `nil`。
- **使用场景**：S04 清理与完整性检查，当检测到 dangling line 或孤立过孔时，可用此命令直接清除残留。
- **示例**：
  ```skill
  axlDeleteObject(dangling_via)
  ```

## 规则与高速信号 (Constraints & High-speed)

### `axlCNSGetPhysical` 与 `axlCNSGetSpacing`
- **功能**：查询 Constraint Manager 中的物理规则（线宽、颈状线）和间距规则。
- **使用场景**：S09 信号质量与阻抗走线检查。结合 `axlMKSConvert` 转换单位，用于自动化提取设计要求，避免硬编码规则数值。


## 中文乱码与编码问题 (Chinese Encoding Issues)

在中文 Windows 环境下开发包含中文字符串的 SKILL 脚本（尤其是用于弹窗或 `axlUIViewFileCreate` 显示的文本），必须处理好文件编码问题，否则会出现乱码。

### 核心问题
1. **Allegro 原生机制**：Allegro（Windows 版）的内置文本查看器和 UI 组件默认使用系统 ANSI 编码（中文系统即 **GBK/GB2312**）来解析文本文件和字符串。
2. **现代编辑器冲突**：现代 IDE（如 VS Code）默认使用 **UTF-8**。如果用 UTF-8 保存了含有中文字符的 `.il` 文件，Allegro 运行时将其作为 GBK 读取，就会导致弹窗和 UI 显示乱码（如出现“甯姪”等乱码字符）。
3. **Agent 工具冲突**：AI Agent 的常规文件修改工具大多基于 UTF-8。如果直接用工具修改 GBK 编码的 `.il` 文件，极易导致文件编码被破坏或混合。

### 解决方案与最佳实践
1. **全链路使用 GBK**：必须确保包含中文字符的 `.il` 脚本在保存到硬盘时是纯粹的 GBK 编码。
2. **配置 IDE 自动识别**：为了让开发者能够在 IDE 中正常阅读和编辑 GBK 文件而不出现乱码，可以在项目根目录的 `.vscode/settings.json` 中强制关联：
   ```json
   {
       "files.associations": {
           "*.il": "skill",
           "*.ils": "skill"
       },
       "[skill]": {
           "files.encoding": "gbk"
       }
   }
   ```
3. **AI Agent 操作规范**：
   - AI Agent 在创建或修改包含中文的 `.il` 脚本时，强烈建议：先将完整代码以 UTF-8 写入文件，然后立即**通过 Python 脚本显式转换为 GBK 编码**。
   - **转换命令参考**：
     ```bash
     python -c "import codecs; data = codecs.open('script.il', 'r', 'utf-8').read(); codecs.open('script.il', 'w', 'gbk').write(data)"
     ```
   - 尽量避免使用局部替换工具（如 `multi_replace_file_content`）去修改已存在的含有中文的 GBK 文件，因为框架的默认行为可能会强制写入 UTF-8，导致文件编码被破坏混合。遇到大修情况，建议采用全量写入后整体转换的方法。

