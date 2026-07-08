/*
 * Name: check_teardrops.il
 * Description: Check for missing teardrops on pins and vias connected to clines.
 *              Generates a report with missing layer info and displays it in Allegro.
 *              Supports wildcard (* and ?) in ignore_nets.
 *              Interactive popup for ignore_nets input.
 * Usage: load("check_teardrops.il")
 *        check_teardrops
 */

; 辅助函数：判断网络名是否匹配忽略列表（支持 * 和 ? 通配符）
defun( isNetIgnored (netName ignore_nets)
    let((ignored regex_pattern pcre_obj)
        ignored = nil
        if(ignore_nets then
            foreach(pattern ignore_nets
                ; 手动构建正则表达式以避免 rexCompile 的全局状态污染
                regex_pattern = ""
                for(i 0 strlen(pattern)-1
                    let((ch)
                        ch = substring(pattern i+1 1)
                        if(ch == "*" then regex_pattern = strcat(regex_pattern ".*")
                        else if(ch == "?" then regex_pattern = strcat(regex_pattern ".")
                        else regex_pattern = strcat(regex_pattern ch)))
                    )
                )
                regex_pattern = strcat("^" regex_pattern "$")
                
                if(pcreMatchp(regex_pattern netName) then ignored = t)
            )
        )
        ignored
    )
)

; 注册为 interactive 命令，这样它会在执行前安全地结束其它正在运行的命令，防止数据库被锁定
axlCmdRegister("check_teardrops" 'checkMissingTeardrops ?cmdType "interactive")

defun( checkMissingTeardrops ()
    let((design missing_list checked_pins checked_vias connected clines has_teardrop shapes outPort logFile ignore_nets layers_with_clines user_input ratio_input ratio_threshold ignore_due_to_ratio c_width_at_pin closest_dist d1 d2 min_d dx dy pad_size clines_on_layer)
        missing_list = nil
        checked_pins = 0
        checked_vias = 0
        logFile = "missing_teardrops.log"
        
        ; 弹出交互式输入框，让用户输入要忽略的网络
        user_input = axlEnterString(
            ?prompts list("Enter nets to ignore (wildcards * and ? supported, separated by comma/space)\nExample: GND, VCC, N*")
        )
        
        ; 弹出交互式输入框，输入线宽与Pad的比值阈值，用于自动忽略较宽的线
        ratio_input = axlEnterString(
            ?prompts list("Enter max trace/pad width ratio to require teardrop (e.g. 0.5 to ignore if trace is >= 50% of pad). Leave blank to check all:")
        )
        
        ; 必须在所有的 UI 挂起（例如弹窗）操作结束后，再获取最新的 design 指针，防止句柄失效
        design = axlDBGetDesign()
        if(!design then
            axlMsgPut("Error: Cannot access design database.")
            return(nil)
        )
        
        ; 如果用户输入了内容，按逗号或空格解析成列表；如果点取消，则列表为空
        if(user_input && user_input != "" then
            ignore_nets = parseString(user_input ", ")
        else
            ignore_nets = nil
        )
        
        if(ratio_input && ratio_input != "" then
            ratio_threshold = atof(ratio_input)
            if(!ratio_threshold || ratio_threshold <= 0.0 then ratio_threshold = nil)
        else
            ratio_threshold = nil
        )
        
        axlMsgPut("Ignore nets set to: %L" ignore_nets)
        if(ratio_threshold then
            axlMsgPut("Ignore teardrops if trace/pad ratio >= %.2f" ratio_threshold)
        )
        axlMsgPut("Checking design for missing teardrops...")
        
        ; 1. 检查所有 Pin (Pins)
        foreach(sym design->symbols
            foreach(pin sym->pins
                if(pin->net && pin->net->name != "" && !isNetIgnored(pin->net->name ignore_nets) then
                    connected = axlDBGetConnect(pin t)
                    clines = setof(x connected x->objType == "path")
                    if(clines then
                        checked_pins = checked_pins + 1
                        shapes = setof(x connected x->objType == "shape")
                        
                        layers_with_clines = nil
                        foreach(cline clines
                            if(!member(cline->layer layers_with_clines) then
                                layers_with_clines = cons(cline->layer layers_with_clines)
                            )
                        )
                        
                        foreach(layer layers_with_clines
                            has_teardrop = nil
                            ignore_due_to_ratio = nil
                            
                            foreach(s shapes
                                if(s->fillet && s->layer == layer then has_teardrop = t)
                            )
                            
                            if(ratio_threshold && !has_teardrop then
                                c_width_at_pin = 0.0
                                closest_dist = 1000000.0
                                clines_on_layer = setof(c clines c->layer == layer)
                                foreach(c clines_on_layer
                                    foreach(seg c->segments
                                        if(seg->startEnd && seg->width then
                                            d1 = axlDistance(pin->xy car(seg->startEnd))
                                            d2 = axlDistance(pin->xy cadr(seg->startEnd))
                                            min_d = min(d1 d2)
                                            if(min_d < closest_dist then
                                                closest_dist = min_d
                                                c_width_at_pin = seg->width
                                            )
                                        )
                                    )
                                )
                                dx = caadr(pin->bBox) - caar(pin->bBox)
                                dy = cadadr(pin->bBox) - cadar(pin->bBox)
                                pad_size = min(dx dy)
                                if(pad_size > 0.0 && c_width_at_pin > 0.0 then
                                    if((c_width_at_pin / pad_size) >= ratio_threshold then
                                        ignore_due_to_ratio = t
                                    )
                                )
                            )
                            
                            if(!has_teardrop && !ignore_due_to_ratio then
                                missing_list = cons(list("PIN" pin->xy pin->net->name sym->refdes pin->number layer) missing_list)
                            )
                        )
                    )
                )
            )
        )
        
        ; 2. 检查所有 Via (Vias)
        foreach(net design->nets
            if(net->name != "" && !isNetIgnored(net->name ignore_nets) then
                foreach(branch net->branches
                    foreach(via setof(child branch->children child->objType == "via")
                        connected = axlDBGetConnect(via t)
                        clines = setof(x connected x->objType == "path")
                        if(clines then
                            checked_vias = checked_vias + 1
                            shapes = setof(x connected x->objType == "shape")
                            
                            layers_with_clines = nil
                            foreach(cline clines
                                if(!member(cline->layer layers_with_clines) then
                                    layers_with_clines = cons(cline->layer layers_with_clines)
                                )
                            )
                            
                            foreach(layer layers_with_clines
                                has_teardrop = nil
                                ignore_due_to_ratio = nil
                                
                                foreach(s shapes
                                    if(s->fillet && s->layer == layer then has_teardrop = t)
                                )
                                
                                if(ratio_threshold && !has_teardrop then
                                    c_width_at_pin = 0.0
                                    closest_dist = 1000000.0
                                    clines_on_layer = setof(c clines c->layer == layer)
                                    foreach(c clines_on_layer
                                        foreach(seg c->segments
                                            if(seg->startEnd && seg->width then
                                                d1 = axlDistance(via->xy car(seg->startEnd))
                                                d2 = axlDistance(via->xy cadr(seg->startEnd))
                                                min_d = min(d1 d2)
                                                if(min_d < closest_dist then
                                                    closest_dist = min_d
                                                    c_width_at_pin = seg->width
                                                )
                                            )
                                        )
                                    )
                                    dx = caadr(via->bBox) - caar(via->bBox)
                                    dy = cadadr(via->bBox) - cadar(via->bBox)
                                    pad_size = min(dx dy)
                                    if(pad_size > 0.0 && c_width_at_pin > 0.0 then
                                        if((c_width_at_pin / pad_size) >= ratio_threshold then
                                            ignore_due_to_ratio = t
                                        )
                                    )
                                )
                                
                                if(!has_teardrop && !ignore_due_to_ratio then
                                    missing_list = cons(list("VIA" via->xy net->name layer) missing_list)
                                )
                            )
                        )
                    )
                )
            )
        )
        
        axlMsgPut("Checked %d pins and %d vias with connected clines." checked_pins checked_vias)
        axlMsgPut("Found %d locations missing teardrops." length(missing_list))
        
        ; 3. 生成报告并显示
        if(length(missing_list) > 0 then
            outPort = outfile(logFile)
            if(outPort then
                fprintf(outPort "========================================================================\n")
                fprintf(outPort "                       Missing Teardrops Report\n")
                fprintf(outPort "========================================================================\n")
                fprintf(outPort "Checked Pins: %d\n" checked_pins)
                fprintf(outPort "Checked Vias: %d\n" checked_vias)
                fprintf(outPort "Ignored Nets: %L\n" ignore_nets)
                fprintf(outPort "Total Missing: %d\n\n" length(missing_list))
                fprintf(outPort "Type\tRefDes/Pin\tLayer\t\tNet Name\tLocation (x, y)\n")
                fprintf(outPort "------------------------------------------------------------------------\n")
                
                foreach(item reverse(missing_list)
                    let((type xy netName refdes pinNum layer layer_parts layer_short)
                        type = nth(0 item)
                        xy = nth(1 item)
                        netName = nth(2 item)
                        
                        if(type == "PIN" then
                            refdes = nth(3 item)
                            pinNum = nth(4 item)
                            layer = nth(5 item)
                        else
                            layer = nth(3 item)
                        )
                        
                        ; 格式化层名，提取 / 后面的部分（如 ETCH/TOP -> TOP）
                        layer_parts = parseString(layer "/")
                        layer_short = if(length(layer_parts) > 1 then cadr(layer_parts) else car(layer_parts))
                        
                        if(type == "PIN" then
                            fprintf(outPort "PIN\t%s.%s\t\t%s\t\t%s\t\t(%.2f, %.2f)\n" refdes pinNum layer_short netName car(xy) cadr(xy))
                        else
                            fprintf(outPort "VIA\tN/A\t\t%s\t\t%s\t\t(%.2f, %.2f)\n" layer_short netName car(xy) cadr(xy))
                        )
                    )
                )
                close(outPort)
                axlMsgPut("Report generated: %s" logFile)
                axlUIViewFileCreate(logFile "Missing Teardrops Report" nil)
            else
                axlMsgPut("Error: Could not open file %s for writing." logFile)
            )
        else
            axlMsgPut("All traces have teardrops. No missing teardrops found.")
        )
        t
    )
)
