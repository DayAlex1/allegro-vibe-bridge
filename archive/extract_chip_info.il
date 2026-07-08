defun( extractComponentData ()
    let((symbols refdes box width height padSizeList drillSizeList pDef drill padBox pWidth pHeight outPort sizeStr)
        outPort = outfile("chip_report.log")
        fprintf(outPort "=================================================================\n")
        fprintf(outPort "Chip Component Report - RefDes, Size, Pad Sizes, Drill Sizes\n")
        fprintf(outPort "=================================================================\n")
        
        symbols = axlDBGetDesign()->symbols
        foreach(sym symbols
            if(sym->refdes && (substring(sym->refdes 1 1) == "U") then
                refdes = sym->refdes
                if(sym->bBox then
                    box = sym->bBox
                    width = car(cadr(box)) - car(car(box))
                    height = cadr(cadr(box)) - cadr(car(box))
                else
                    width = 0.0
                    height = 0.0
                )
                
                padSizeList = nil
                drillSizeList = nil
                
                foreach(pin sym->pins
                    if(pin->definition then
                        pDef = pin->definition
                        drill = pDef->drillDiameter
                        if(drill && drill > 0.0 && !member(drill drillSizeList) then
                            drillSizeList = cons(drill drillSizeList)
                        )
                        
                        foreach(pad pDef->pads
                            if(pad->type == "REGULAR" && pad->bBox then
                                padBox = pad->bBox
                                pWidth = car(cadr(padBox)) - car(car(padBox))
                                pHeight = cadr(cadr(padBox)) - cadr(car(padBox))
                                sizeStr = sprintf(nil "%.3f x %.3f" pWidth pHeight)
                                if(!member(sizeStr padSizeList) then
                                    padSizeList = cons(sizeStr padSizeList)
                                )
                            )
                        )
                    )
                )
                fprintf(outPort "RefDes: %-10s | Size: %.3f x %.3f | Pads: %L | Drills: %L\n" 
                    refdes width height padSizeList drillSizeList)
            )
        )
        close(outPort)
        axlUIViewFileCreate("chip_report.log" "Chip Report" nil)
        axlMsgPut("Report generated: chip_report.log")
        t
    )
)
extractComponentData()
