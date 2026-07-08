/* vibe_server.il
 * Allegro Vibe Bridge Server
 * Uses native axlUIWTimerAdd to create a non-blocking background poller.
 */

(defvar vibeTimerId nil)

(defun vibeProcessHandler (window timerId elapsedTime)
    (let (workspaceDir inFile outFile inPort outPort code line result)
        
        workspaceDir = "<YOUR_PROJECT_PATH>/workspace/"
        inFile = strcat(workspaceDir "vibe_in.il")
        outFile = strcat(workspaceDir "vibe_out.log")
        
        (when (isFile inFile)
            (setq inPort (infile inFile))
            (setq code "")
            (while (gets line inPort)
                (setq code (strcat code line))
            )
            (close inPort)
            
            (when (neq code "")
                (printf "[Vibe] Received code, executing...\n")
                
                ; Redirect errport to file to capture errors securely
                (let (errLog oldErrPort errMsg)
                    errLog = strcat(workspaceDir "vibe_err.log")
                    oldErrPort = errport
                    errport = (outfile errLog)
                    
                    ; Execute code safely by wrapping it in a let block to evaluate all top-level expressions sequentially
                    result = errset(
                        evalstring(strcat("let((vibeLastRes)\n" code "\n)"))
                        t
                    )
                    
                    (close errport)
                    errport = oldErrPort
                    
                    ; Read captured error
                    errMsg = ""
                    (when (isFile errLog)
                        (let (errIn line)
                            errIn = (infile errLog)
                            (while (gets line errIn)
                                errMsg = (strcat errMsg line)
                            )
                            (close errIn)
                        )
                        (deleteFile errLog)
                    )
                    
                    ; Write result
                    (setq outPort (outfile outFile))
                    (if result
                        (fprintf outPort "SUCCESS\n%L\n" (car result))
                        (if (neq errMsg "")
                            (fprintf outPort "ERROR\n%s" errMsg)
                            (fprintf outPort "ERROR\nExecution failed. See Allegro command window for details.\n")
                        )
                    )
                    (close outPort)
                )
                
                ; Clean up
                (deleteFile inFile)
            )
        )
    )
)

(defun vibeStartServer ()
    (printf "Starting Vibe Polling Server using pure SKILL timer...\n")
    (when vibeTimerId
        (axlUIWTimerRemove vibeTimerId)
    )
    
    ; axlUIWTimerAdd( o_window x_timeout g_oneshot u_callback )
    ; Using nil for main window, 500ms timeout, nil for continuous loop
    vibeTimerId = (axlUIWTimerAdd nil 500 nil 'vibeProcessHandler)
    
    (if vibeTimerId
        (printf "Vibe Polling Server started successfully. Timer ID: %L\n" vibeTimerId)
        (printf "ERROR: Failed to start Vibe Polling Server.\n")
    )
)
vibeStartServer()