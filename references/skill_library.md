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


## MCM 与 SiP 基板设计特性 (MCM & Substrate Specifics - S02 实操沉淀)

在 Cadence SiP / APD / MCM 基板设计环境下，层级组织和元件表达跟普通传统 PCB (Etch/Top) 有很大的差异，在开发检查脚本（如间距与边距综合检查 S02）时，务必遵循以下结论：

### 1. 导电面层命名为 CONDUCTOR 非 ETCH
- **说明**：在基板（Substrate）和 MCM 中，常规线路主层组不再使用 `ETCH` 命名，而是归位于 `paramLayerGroup:CONDUCTOR` 下。
- **命名规范**：各导电层为 `"CONDUCTOR/CU-1"`, `"CONDUCTOR/CU-2"` 直至 `"CU-10"`（或设计定义的特定非导电及绝缘穿孔层名如 `"DRILL1-2"`、`"CORE5-6"`）。编写走线与敷铜判定时不能写死 `"ETCH/TOP"`，应遍历获取真实命名的导电平层。

### 2. 基板边远主框架层的真实隶属
- **说明**：在 SiP 和基板中，整体基准封装轮廓常存列于 `SUBSTRATE GEOMETRY/DESIGN_OUTLINE`（或者是 `DRAWING FORMAT/OUTLINE`），往往找不到传统 PCB 默认使用的 `BOARD GEOMETRY/OUTLINE` 或 `PACKAGE KEEP-IN`。
- **备选保障机制**：若通过层名获取轮廓失败或为空，最稳健的做法是捕获图面上具有“整个封载极坐标平台属性”的中央主体（例如位号前缀为 `BGA` 的根级载座元器件）自身的 `bBox` 极限空间坐标对，作为该块载体真正的核心边边界轴 `Package Edge`。

### 3. `axlDistance` 的入参类型与边切间距解算法则
- **报错提醒**：如果故意把两个复杂的顶层器件（如 `Symbol` 的 dbid 对象）直接传往 `axlDistance(s1 s2)`，将引爆：`*Error* axlDistance: argument #1 should be a list (type template = "ll")`，最终捕回 `nil` 奔溃。
- **官方解说**：`axlDistance` 要求的是对 `(List)`（比如实体的坐标点对 `'((x1 y1) (x2 y2))` 或者简单的两对离散 `pin->xy` 直拉线等），**绝不可传入器件或者大类对象本体 `dbid`**。
- **真正精准边向红斑求隙运算**：面对不规则阻性表片与异性主干时，要毫厘不争得追求【完全免误杀且决不崩溃的 Edge-to-Edge 最短距离数学计算式】，建议按坐标轴投打拆取极距平方和的几何归一写法：
  ```skill
  procedure( calc_edge_to_edge_dist(box1 box2)
      let((dx dy x1_min x1_max y1_min y1_max x2_min x2_max)
          x1_min = caar(box1)  y1_min = cadar(box1)
          x1_max = caadr(box1) y1_max = cadadr(box1)
          x2_min = caar(box2)  y2_min = cadar(box2)
          x2_max = caadr(box2) y2_max = cadadr(box2)
          
          dx = 0.0
          if(x2_min > x1_max then dx = x2_min - x1_max)
          if(x1_min > x2_max then dx = x1_min - x2_max)
          
          dy = 0.0
          if(y2_min > y1_max then dy = y2_min - y1_max)
          if(y1_min > y2_max then dy = y1_min - y2_max)
          
          sqrt(dx*dx + dy*dy)
      )
  )
  ```

### 4. 稳妥高速的字符串与类型筛选匹配 (strncmp)
- **踩坑实证**：直接尝试在一对普通属性中调用 `rexMatchp("^(C|R|L|SRO)" s->refdes)` 时会出现交集表达式解析短折或语法失效而使目标抓回为 `nil`/空阵。
- **标准方案**：为了彻底兼顾无状态开销与全平台 100% 正解通性，过滤特定位号（如阻容或者特定定位器名片时），尽量拥戴原生高效纯对比子函数 `strncmp` 匹配：
  ```skill
  ; 精确找齐各被动电阻与大电容载格
  rlc_list = setof(s symbols s->refdes && (
      strncmp(s->refdes "C" 1) == 0 || 
      strncmp(s->refdes "R" 1) == 0 || 
      strncmp(s->refdes "L" 1) == 0 || 
      strncmp(s->refdes "SRO" 3) == 0))
  ```

### 5. 顶底层被动组件跨面避让与散空误筛防爆法则 (LSC Top/Bottom Separation Check - S02 实证)
- **隐瞒陷阱**：如果不论板层直发拿顶层的阻容去测寻底背 Solder Ball 球缝（或采用平视二微距计差法 2D Euclidean DBU calculation），极有可能因为板面俯瞰垂影相冲直接将垂直间隙报零（`0.00 mm`），激发不必要的工艺冲突红信。
- **最佳规范**：于任何牵连 BGA 球间切隙及贴配层检查前，先读取阻容元器件自身镜像驻性属性 `sym->isMirrored` 作分断解算：
  - `nil` 代表处于非转反上盖 (Die Side / Top Placement)，对其索查底球交并距离应直接舍记为 `N/A (Top Side)`，切禁测投点 0 距。
  - `t` 表征背层座居 (Land Side Capacitor / LSC Placement)，仅在该真确平层时起运各导接实地 BBox / xy 切边净缝的测定。

### 6. 板边切割保留防区全导平层排布统计 API
- **实做验证**：通过迭代拉取 `paramLayerGroup:CONDUCTOR` 下归档名表，并利用构造合并全名符串（如 `"CONDUCTOR/CU-1"`）去筛选圈查该阶上的全部 `shape` 及 `path(clines)` 铜箔实体边界，与中心封框的极短缝隔（Singulation Sawing Clearance Check），是 S02/S07 系列排布核算的王牌推荐架构。

### 7. 单极化原生主单位动态捕获与格式化输出标准 (Design Units Standardization)
- **工程最佳实践**：不要在核对结果报告中繁琐地大量并列堆叠双边及混搭的重叠换算值 (如 `xxx mils / xxx mm`)。直接从设计本身抽提原生绘图单位进行归一化呈现，能够还原研发端最直观合理的工整设定间隙真值（例如准确的 `300.00 um` 或 `450.00 um` 避退安全切层距离）。
- **标准语法实现**：
  ```skill
  /* 读取当前 CAD 文档自身基准量程字典单位 */
  design_param = axlGetParam("paramDesign")
  unit_raw = if(design_param && design_param->units then design_param->units else "mils")
  unit_abbr = cond(
      ((unit_raw == "microns" || unit_raw == "um") "um")
      ((unit_raw == "millimeters" || unit_raw == "mm") "mm")
      ((unit_raw == "mils" || unit_raw == "milli-inches") "mils")
      ((unit_raw == "inches") "in")
      (t unit_raw)
  )
  /* 使用 %9.2f %s 格式向外化单一主单位投掷出值 */
  ```

### 8. 四维全域渐进式组件类别与属性联合鉴别法则 (Robust Symbol Classification - 摒弃脆弱的关键词)
- **致命痛点**：长期以来初级开发极度依赖位号前缀匹配（如 `strncmp(refdes "DIE" 3)` 或 `rexMatchp`），这在遇到用户自定义芯片名称（`CPU/SOC/DSP/ASIC` 或特殊料号命名）时脆弱无比，极易产生大面积漏识或错识。
- **底层原理（Cadence DBID Dump 深度解构证据）**：
  1. **芯片 (ACTIVE DIE)**：属于集成电路主件，在底层元数据中的组件大类必定归宗为 **`comp->class == "IC"`**；同时 SiP 工具链会在载体上挂载专属物理参数字典，如 **`assoc('ICPKG_DIE_THICKNESS sym_props)`** 与 **`assoc('COMP_SUBTYPE comp_props) -> "DIE"`**。
  2. **被动阻容元件 (PASSIVE)**：组件大类恒守 **`comp->class == "DISCRETE"`**；子属性呈现 `"RESISTOR"/"CAPACITOR"/"DISCRETE"`。
  3. **底层引出阵列 (BGA/IO)**：组件大类为 **`comp->class == "IO"`**；装配归属于 `"BGA"`。
- **标准极简四维判据引擎范例**：
  ```skill
  procedure( classify_symbol_robust(sym)
      let((comp comp_props sym_props subtype c_class res)
          res = nil
          if(sym then
              comp = sym->component
              sym_props = axlDBGetProperties(sym)
              comp_props = if(comp then axlDBGetProperties(comp) else nil)
              
              /* 维度 1：优先探取 SiP 封装芯片专属私有属性厚度及凸点参数字典 */
              if(!res && sym_props && (assoc('ICPKG_DIE_THICKNESS sym_props) || assoc('ICPKG_DIE_BUMP_DATA sym_props) || assoc('DIE_TYPE sym_props)) then
                  res = "DIE"
              )
              /* 维度 2：研讨正统组件 COMP_SUBTYPE 子类别定义 */
              if(!res && comp_props && assoc('COMP_SUBTYPE comp_props) then
                  subtype = upperCase(cadr(assoc('COMP_SUBTYPE comp_props)))
                  cond(
                      ((subtype == "DIE" || subtype == "FLIPCHIP" || subtype == "IC") res = "DIE")
                      ((subtype == "BGA" || subtype == "SUBSTRATE") res = "BGA")
                      ((subtype == "RESISTOR" || subtype == "CAPACITOR" || subtype == "INDUCTOR" || subtype == "DISCRETE") res = "PASSIVE")
                  )
              )
              /* 维度 3：检索系统母卡大类 (class) 属性 (IC / DISCRETE / IO / MECH) */
              if(!res && comp && comp->class then
                  c_class = upperCase(comp->class)
                  cond(
                      ((c_class == "IC" || c_class == "MEMS" || c_class == "OPTICAL") res = "DIE")
                      ((c_class == "DISCRETE" || c_class == "PASSIVE") res = "PASSIVE")
                      ((c_class == "IO" || c_class == "CONNECTOR") res = "BGA")
                  )
              )
              /* 维度 4：仅针对无任何属性绑定的上古遗留黑盒图元，启用容错备选字符串猜测 */
              if(!res && sym->refdes then
                  /* 此处备用抓取 SOC/CPU/FPGA/DIE/U/C/R/BGA 等通用首段字母 */
                  nil
              )
          )
          res
      )
  )
  ```
  **严格法则**：往后制作全量核查逻辑均当挂载此类属性透听函数，彻底斩除“唯位号论”的隐患！

### 9. 封装基板与 MCM 光学定点标识的“纯图形成型”本质与捕获算法 (Shape-Based Optical Fiducial Recognition)
- **行业真相**：在常规低速 PCB 设计中，Fiducial 通常被构架为一个含有正当 `RefDes`（如 `FID1`、`MK1`）的完整系统 `Symbol`；然而在高端 **IC 基板 (Substrate) 与 MCM / SiP 封装工程中，Fiducial 几乎绝大多数属于顶底层纯导电层（Top/Bot Conductor）上直接通过人工绘制出无相连属性的纯净铜泊多边形几何实体（Shape/Figure）**（多见于三角形、等宽正方形、圆标）。
- **致命失误防范**：单纯依赖 `axlDBGetDesign()->symbols` 下找寻 `Class == FIDUCIAL`，会直接致使复杂的高级衬底中光学标识识别数量爆 `0`。
- **三重物理捕获判据 (3-Factor Recognition Protocol)**：
  1. **实体归类层级**：对象属于 `CONDUCTOR/<First_Layer>` / `CONDUCTOR/<Last_Layer>` 或对应开窗平层。
  2. **电气隔离天性**：处于 `NO_NET`（网络属性为空、未设或名标为 `DUMMY`/`NC`）。
  3. **尺度特征与工艺印记**：在坐标系里其边界盒（`bBox`）横向及纵向极限定尺应在典型打架取景刻尺 **`100.0 um` 至 `3000.0 um`** (或重叠换为 4~120 mils) 区间，且时常具备**“不可凿击灌装释气小面空心洞” (`(DEGAS_NO_VOID t)`)** 和 **空间锚性锁定 (`(FIXED t)`)** 内部绑定。
- **示范代码范型**：
  ```skill
  /* 捕捉基板铜面积纯图型式光显识别锚记 (Shape Fiducials) */
  foreach(s shapes
      if(s->layer == top_lyr || s->layer == bot_lyr then
          net_name = if(s->net && s->net->name then s->net->name else "")
          is_no_net = (net_name == "" || net_name == "NO_NET" || strncmp(upperCase(net_name) "DUMMY" 5)==0)
          box = s->bBox
          if(box && is_no_net then
              w = caadr(box) - caar(box)  h = cadadr(box) - cadar(box)
              if(w >= 100.0 && w <= 3000.0 && h >= 100.0 && h <= 3000.0 then
                  /* 已确认：斩获无符号物理光定位形斑，存录定位数组中 */
                  fid_list = cons(list("Shape_Fid" box s->layer) fid_list)
              )
          )
      )
  )
  ```
  **设计总结**：对于任何具有 IC Substrate 及高级模组属性的设计核实体系，此套纯实体级捕搜与类 Symbol 巡视合围的双路扫描引擎，必须保持绝对标准同序实装！

### 10. EDA 视图可视性 (Layer Visibility) 对 `axlAddSelectAll` 的屏蔽盲点与“层显自启强开打通法”
- **隐瞒极深的业界老怪 (Hidden Pitfall)**：在 Cadence SKILL 开发的常规理解下，往往以为在 `axlSetFindFilter` 设定好需要的图件类名（如 `shapes`、`clines`）即可抓获全球图素。然而，**绝大多数 `axlAddSelectAll()` 都是绝对“视界敏性 (Viewport-Sensitive)”的——凡被用户在画布中临时灭屏关闭（Invisible / Turn Off Layer）的平层与组建，系统在下令捞提时将无情且盲化地将其从结果阵中予以抛却**（不仅连定位标、更有甚至于把除主层外所有内部 `CU-2~N` 层等尽散如空）。
- **解禁戒律 (Mandatory Visibility Unlocking Protocol)**：
  为了实现跨设计态任意工况下的“抗视觉盲死强韧化”扫描，任何需要在 SKILL 系统作大空间、深通量全要素检选的规例程序段（尤其是定位斑抓检与跨导引面唱距排算时）：**必定于召唤 `axlAddSelectAll` 执行之夕，执行强开目标相关物理图形界域可视化的大解咒指令组合！**
- **典型样版与实弹落地**：
  ```skill
  /* 强制点亮全部待测图层不受界面封打困阻 (Layer Unlocking) */
  conductor_param = axlGetParam("paramLayerGroup:CONDUCTOR")
  if(conductor_param && conductor_param->groupMembers then
      foreach(lyr conductor_param->groupMembers
          axlVisibleLayer(strcat("CONDUCTOR/" lyr) t)
      )
  )
  axlVisibleLayer("SUBSTRATE GEOMETRY/DESIGN_OUTLINE" t)
  axlVisibleLayer("DRAWING FORMAT/OUTLINE" t)
  axlVisibleUpdate(t)
  
  /* 此刻下达抓捞才是真·一物无缺 */
  axlClearSelSet()
  axlSetFindFilter(?enabled list("noall" "shapes" "clines") ?onButtons list("noall" "shapes" "clines"))
  axlAddSelectAll()
  all_shapes = axlGetSelSet()
  axlClearSelSet()
  ```
  **严格操法**：今后编写后续各个复杂规则章节时，但凡涉及到“面向无选定区域、漫及多图幅界网的大型综合遍历”，一经使用 `axlAddSelectAll()`，本条“前置激活层级开扬照入”原则**不可剥离、缺一不可**！

### 11. 元器件焊盘（Component Padstack）尺寸解析陷阱与分层双解耦机制 (S01 深度实操沉淀)
- **核心问题一：导电平层查询的单一依赖陷阱 (`ETCH` vs `CONDUCTOR`)**
  - **现象与实测**：部分逻辑若仅依赖 `paramLayerGroup:ETCH` 或单抓 `axlSubclassRoute()`，在复杂 SiP/MCM 或特定封装架构下会因 `ETCH` 未完成主层投映出现导电层抓空。
  - **规范解法**：建立优先轮询 `paramLayerGroup:CONDUCTOR` 再轮询 `paramLayerGroup:ETCH` 的双层兼容判定逻辑。
- **核心问题二：导电焊盘面积抓空（仅回传阻焊尺寸）的物理根因与对冲方案**
  - **根因分析**：
    1. **层名与层级位置冲突**：元器件建库常使用抽象层名（`BEGIN LAYER` / `END LAYER` / `DEFAULT INTERNAL`）；此外部分阻容件、内部转接贴片布装在导电内层（如 `CU-2~N`），若代码中强制绑定 `top_etch`/`bot_etch` 必然触发漏测漏抓。
    2. **SMD 阻焊定义与全空接触面**：BGA、Bump 等阻焊定义型组件的主布线连接通常全靠大面积动态辅铜直接联浸，造成电气引脚自身其 `figureName == "NULL" / "NONE"`。若遍历算法遇空直接输出 `"-"` 占位并锁止，将直接淹没掩去真正有效互连层数据，最终表现为“导电层为空白，但能抓至常态独立留置的阻焊面”的视觉异乱。
  - **改进范式 (4-Column Separation Protocol)**：
    - 将笼统合流的组件单列呈现模式升级解耦为专门指代顶面或底面的 **4 列独立输出结构：`Pad Top`、`Pad Bot`、`Soldermask Top`、`Soldermask Bot`**，以实现在大货报件里直接精判组件具体附置平面（表层、底面或特殊内件）。
    - 读取 `pdef->pads` 列表且进行判断时，严守“遇空项（`NULL`/`NONE` / `"-"`）不作终锁覆盖”的不顶替机制；针对不落在主表下缘及建库预期的夹内异品，自动采用前挂实归位标签的形式（如 `[CONDUCTOR/CU-3] 尺寸`）向下穿透回标。
- **核心问题三：不规则异形（Shape / Flash）在主图形对象尺寸失稳后的兼容降级运算**
  - **机理**：遇到多形铜膜及封装异面铺盖件时，调用接口直接按基本边界 `p->bBox` 常取到空值 `nil`；对于过缝开槽用的 `FLASH` 类形亦常显退化空指针。
  - **极差算距逻辑**：遭遇即显边界遗亡但保留几何图表信息的对象，自动激活对顶角散点列表 `p->corners` 的联合极值巡查：依托搜索最极端的绝对顶距与极差，算导反推有效长宽物理限界比（`w = max_x - min_x`, `h = max_y - min_y`）；对所寻归集入眼的闪切项 `FLASH`，透达抓绑引录名指代参数 `p->flash` 名字原码。

## 绘图与走线生成 (Drawing & Line Creation)

### `axlDBCreateLine`
- **功能**：根据多点坐标列表生成走线（Cline / Path）实体。支持连续多段折线绘制。
- **参数**：
  1. `point_list`：坐标点列表（使用 SKILL C 风格如 `list(-7000.0:6000.0, -6500.0:7000.0, -6000.0:6000.0)` 或 `-7000.0:6000.0` 格式）
  2. `width`：线宽（实数，基于当前设计单位，如 `100.0` microns）
  3. `layer`：目标物理图层（如 `"CONDUCTOR/CU-1"` 或 `"ETCH/TOP"`）
  4. `net_name` (可选)：网络名称字符串，缺省为无网络
- **返回值**：成功返回创建的 path 对象的 `(dbid)` 列表，失败返回 `nil`。
- **最佳实践**：在复杂图形绘制（如图案、矢量线条）中，将图形拆解为多组路径列表，循环调用 `axlDBCreateLine` 创建。
- **示例**：
  ```skill
  pts = list(-7100.0:7500.0, -7700.0:8300.0, -6800.0:7700.0)
  res = axlDBCreateLine(pts, 100.0, "CONDUCTOR/CU-1")
  ```

