! CPUSTARV.BAS
! Background app that alternates a tight CPU loop with a loop that waits.
! Use it to crowd the priority-5 ready queue and watch RIOTTQCL.
!
! Parameters, all optional. Capitals. Example: BURN=20 EASY=20 GAP=1000
!   BURN=  seconds of tight loop. Default 20. 0 skips this phase.
!   EASY=  seconds of the waiting loop. Default 20. 0 skips this phase.
!   GAP=   milliseconds WAIT each easy lap. Default 1000. 0 does not wait.
! The system passes BACKGRND when this is started as a background app.
! Status on the background panel is limited to 46 characters.
!   TIGHT 12s n=123456   elapsed seconds and loop laps in the tight phase
!   EASY  8s n=8 g=1000  elapsed seconds and laps in the waiting phase
! A smaller TIGHT n for the same elapsed seconds means this process got
! less CPU. Start several copies at priority 5. Priority 4 crowds harder.
! Compile with the same basic.exe flags as RIOTTQCL: basic CPUSTARV[fum(b)
! Then link and postlink it with the 4680 BASIC runtime.


INTEGER*4 GLOBAL burn.secs
INTEGER*4 GLOBAL easy.secs
INTEGER*4 GLOBAL gap.ms
INTEGER*4 GLOBAL laps
INTEGER*1 GLOBAL is.background

sub adxserve (ret,func,parm1,parm2) external 
   integer*4 ret 
   integer*2 func,parm1 
   string parm2 
end sub

! Seconds since midnight. Whole seconds.
FUNCTION seconds.now
    INTEGER*4 seconds.now
    STRING    t$

    t$ = TIME$
    seconds.now = (VAL(LEFT$(t$, 2)) * 3600) + \
                  (VAL(MID$(t$, 3, 2)) * 60) + \
                  VAL(RIGHT$(t$, 2))
END FUNCTION

! Elapsed whole seconds since t0. Crosses midnight.
FUNCTION seconds.since(t0)
    INTEGER*4 seconds.since
    INTEGER*4 t0
    INTEGER*4 t1

    t1 = seconds.now
    IF (t1 < t0) THEN t1 = t1 + 86400
    seconds.since = t1 - t0
END FUNCTION

! Number after key$ in COMMAND$. key$ includes the equals sign.
FUNCTION get.value(key$, default)
    INTEGER*4 get.value
    INTEGER*4 default
    INTEGER*4 p
    INTEGER*4 key.len
    STRING    key$

    key.len = LEN(key$)
    p = MATCH(key$, COMMAND$, 1)
    IF (p = 0) AND (key$ = "BURN=") THEN p = MATCH("burn=", COMMAND$, 1)
    IF (p = 0) AND (key$ = "EASY=") THEN p = MATCH("easy=", COMMAND$, 1)
    IF (p = 0) AND (key$ = "GAP=") THEN p = MATCH("gap=", COMMAND$, 1)
    IF (p = 0) THEN BEGIN
        get.value = default
    ENDIF ELSE BEGIN
        get.value = VAL(MID$(COMMAND$, p + key.len, 8))
    ENDIF
END FUNCTION

SUB show.status(msg$)
    STRING    msg$
    INTEGER*4 ret

    IF (LEN(msg$) > 46) THEN msg$ = LEFT$(msg$, 46)
    IF (is.background = 1) THEN BEGIN
        CALL adxserve(ret, 26, 0, msg$)
    ENDIF ELSE BEGIN
        PRINT msg$
    ENDIF
END SUB


! Tight phase. No WAIT. Stays on the ready queue.
! TIME$ is read once per 1000 laps, not once per add.
SUB run.tight
    INTEGER*4 t0
    INTEGER*4 elapsed
    INTEGER*4 shown
    INTEGER*4 k
    INTEGER*4 x

    t0 = seconds.now
    elapsed = 0
    shown = -1
    laps = 0
    x = 1
    CALL show.status("TIGHT 0s n=0")
    WHILE (elapsed < burn.secs)
        k = 0
        WHILE (k < 1000)
            x = x + k
            IF (x > 1000000) THEN x = 1
            k = k + 1
        WEND
        laps = laps + 1000
        elapsed = seconds.since(t0)
        IF (elapsed <> shown) THEN BEGIN
            shown = elapsed
            CALL show.status("TIGHT" + STR$(elapsed) + "s n=" + STR$(laps))
        ENDIF
    WEND
END SUB

! Less tight phase. A short burst, then WAIT, until EASY seconds.
! WAIT takes this process off the ready queue.
SUB run.easy
    INTEGER*4 t0
    INTEGER*4 elapsed
    INTEGER*4 shown
    INTEGER*4 k
    INTEGER*4 x

    t0 = seconds.now
    elapsed = 0
    shown = -1
    laps = 0
    x = 1
    CALL show.status("EASY 0s n=0")
    WHILE (elapsed < easy.secs)
        k = 0
        WHILE (k < 50)
            x = x + k
            IF (x > 1000000) THEN x = 1
            k = k + 1
        WEND
        laps = laps + 1
        IF (gap.ms > 0) THEN WAIT ; gap.ms
        elapsed = seconds.since(t0)
        IF (elapsed <> shown) THEN BEGIN
            shown = elapsed
            CALL show.status("EASY" + STR$(elapsed) + "s n=" + \
                             STR$(laps) + " g=" + STR$(gap.ms))
        ENDIF
    WEND
END SUB

!*****************************MAIN CODE STARTS HERE**************************/

!*****************************MAIN CODE STARTS HERE**************************/
   On Error goto err.routine


is.background = 0
IF (MATCH("BACKGRND", COMMAND$, 1) > 0) OR \
   (MATCH("backgrnd", COMMAND$, 1) > 0) THEN is.background = 1

burn.secs = get.value("BURN=", 20)
easy.secs = get.value("EASY=", 20)
gap.ms    = get.value("GAP=", 1000)
IF (gap.ms < 0) THEN gap.ms = 1000

CALL show.status("CPUSTARV B=" + STR$(burn.secs) + \
                 " E=" + STR$(easy.secs) + \
                 " G=" + STR$(gap.ms))

WHILE (1 = 1)
    IF (burn.secs > 0) THEN CALL run.tight
    IF (easy.secs > 0) THEN CALL run.easy
    IF (burn.secs = 0) AND (easy.secs = 0) THEN BEGIN
        CALL show.status("Set BURN= or EASY= above 0")
        WAIT ; 10000
    ENDIF
WEND

exit.program:
   Stop
   
err.routine:
   
   Resume exit.program
   !#12Ae
