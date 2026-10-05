# CPUSTARV user guide

CPUSTARV is a small 4680/4690 BASIC program for observing controller scheduling
under CPU contention, originally used alongside RIOTTQCL. It repeatedly alternates
a tight CPU loop with a loop that yields through `WAIT`.

The default cycle is 20 seconds of tight looping followed by 20 seconds of a
lighter workload with a 1,000 millisecond wait per lap. The program runs until
you stop it; the phase durations are not a total runtime limit.

## Requirements

- A compatible 4680/4690 controller environment with the BASIC runtime and
  `ADXSERVE` service used by this program.
- Access to the controller's application launch and background-task controls.
- RIOTTQCL, if you want to observe its behavior under the generated load.
  CPUSTARV does not invoke RIOTTQCL or require its source files.
- To rebuild: the compatible BASIC compiler, linker, postlink utility, and
  `adxacrcl.l86` runtime library. These tools and the standalone runtime library
  are not included here.

This is a controller application, not a native Linux or Windows executable.
Use a test controller: creating CPU contention is its intended behavior and can
delay other applications.

## Quick start

1. Copy `cpustarv.286` to your controller's application location using your normal
   deployment procedure. The executable is the supplied legacy build; it was
   not rebuilt or run on a controller during this repository import.
2. Start one instance through the controller's background-application facility.
   Use the program name/path for `cpustarv.286` and this parameter string:

   ```text
   BURN=20 EASY=20 GAP=1000
   ```

3. For the original priority-5 contention scenario, configure priority 5 in the
   launcher. Priority is a controller launch setting, not a CPUSTARV parameter.
4. Watch the background status panel and the application you are investigating.
   CPUSTARV should alternate between `TIGHT` and `EASY` status messages.
5. Stop the instance through the controller's background-task controls when the
   observation is complete. Stop each copy if you launched several.

The background launcher is expected to supply `BACKGRND` in the command string.
That marker selects background-panel reporting. Without it, CPUSTARV prints
status to its foreground console. Adding the marker by hand does not itself
launch a background task. Exact launch and stop controls depend on the
controller setup.

## Parameters

Use space-separated `NAME=value` arguments with no spaces around `=`. Uppercase
names are recommended. The code also explicitly recognizes all-lowercase names;
mixed case is not explicitly handled.

| Parameter | Default | Meaning |
| --- | --- | --- |
| `BURN` | `20` | Tight-phase duration in whole seconds. `0` skips this phase. |
| `EASY` | `20` | Waiting-phase duration in whole seconds. `0` skips this phase. |
| `GAP` | `1000` | Milliseconds passed to `WAIT` on each easy lap. `0` disables that wait. A negative value resets to `1000`. |
| `BACKGRND` | Set by launcher | Send status through `ADXSERVE` function 26 instead of printing. |

Supply each numeric parameter once, using nonnegative whole decimal integers.
Keep `BURN` and `EASY` below `86400` seconds and use modest `GAP` values supported
by the controller runtime. Parameter parsing uses substring searches and passes
up to eight characters after `=` to `VAL`; it does not strictly validate complete
tokens, ranges, or malformed numeric values. Unknown parameters are ignored.

Examples (parameter strings for the controller launcher):

| Scenario | Parameters | Behavior |
| --- | --- | --- |
| Default alternating load | `BURN=20 EASY=20 GAP=1000` | Alternate tight and yielding phases. |
| Short load bursts | `BURN=5 EASY=30 GAP=1000` | Five-second tight phase, then a 30-second yielding phase. |
| Waiting loop only | `BURN=0 EASY=20 GAP=1000` | Repeated easy phases, approximately one wait per second. |
| Continuous tight load | `BURN=20 EASY=0` | Repeated tight phases with no scheduled rest between them. |
| Easy loop without yielding | `BURN=0 EASY=20 GAP=0` | Repeated easy-loop arithmetic with no explicit wait. This still creates CPU load. |
| Neither phase enabled | `BURN=0 EASY=0` | Display a reminder and wait 10 seconds repeatedly. The program stays running. |

Do not use negative `BURN` or `EASY` values. If neither phase is positive and at
least one is negative, the current code skips both phases and the zero/zero
fallback wait, creating an unintended busy loop.

## Reading status

Startup reports the selected values, for example:

```text
CPUSTARV B= 20 E= 20 G= 1000
```

Phase status resembles:

```text
TIGHT 12s n= 123000
EASY 8s n= 8 g= 1000
```

Spacing depends on the BASIC runtime's `STR$` formatting. Messages are truncated
to 46 characters. Each phase starts at zero and resets its counters.

- `TIGHT`: `n` counts inner arithmetic iterations, updated in batches of 1,000.
  There is no explicit `WAIT`. Time is checked after each batch.
- `EASY`: `n` counts completed laps. Each lap performs 50 arithmetic iterations,
  then waits for `GAP` milliseconds when positive, then checks elapsed time.
- Elapsed time is wall-clock time in whole seconds, not measured CPU time.
  Status is refreshed when the observed second changes; delayed scheduling or
  a large `GAP` can make updates less frequent.

Compare `TIGHT n` at the same elapsed time across comparable runs on the same
controller. A smaller count suggests that the process made less progress, which
can be consistent with receiving less CPU time. It is not a CPU utilization
percentage, and `TIGHT n` and `EASY n` count different things.

To increase contention, add instances gradually while monitoring the affected
application. The original source suggests multiple priority-5 instances and
notes that priority 4 crowds harder. Choose priorities deliberately through the
controller launcher and retain access to its stop controls.

## Building from source

`CPUSTARV.BAS` is the source and `cpustarv.inp` is the linker input. Preserve the
legacy filenames and use a compatible toolchain environment. The compiler
invocation recorded in the source is:

```text
basic CPUSTARV[fum(b)
```

This is legacy compiler syntax, not a Bash command. Use the same compiler setup
and flags as your working RIOTTQCL build. After successful compilation:

1. Link the resulting `cpustarv.obj` with `adxacrcl.l86`, using your linker's
   input-file mechanism to read `cpustarv.inp`. Its contents are:

   ```text
   cpustarv.286 =
      cpustarv.obj,
      adxacrcl.l86[s,map[a],dbi,data[max[1000]],stack[max[fff]]]
   ```

2. Run the compatible postlink utility on the linked image:

   ```text
   postlink cpustarv.286
   ```

3. Check compiler, linker, and postlink diagnostics before copying the image to
   a test controller. Validate foreground and background status, phase changes,
   and stopping the task before using the build for a contention experiment.

The repository does not supply a build wrapper or automated controller tests.
The compiler line comes from this source; the exact linker invocation and tool
search paths must come from your installed toolchain. On case-sensitive build
hosts, account for the uppercase source/object filename and lowercase reference
in the linker input.

## Review findings and troubleshooting

The import review covered command parsing, loop behavior, timing, and status
reporting. The supplied source was preserved unchanged. Its 184 lines match the
existing local compiler listing. This is a source/listing consistency check,
not proof of executable reproducibility or controller compatibility.

- **Phase never ends:** elapsed time uses `TIME$` and handles one midnight
  crossing, but cannot measure a full 24-hour interval. Do not request phase
  durations of 86,400 seconds or more. Clock adjustments can also distort timing.
- **Easy phase ends late:** elapsed time is checked after `WAIT`; a large `GAP`
  can overrun the requested phase duration. Scheduling delays affect both phases.
- **Unexpected CPU load:** check for `EASY=0`, `GAP=0`, negative durations, or
  additional running copies. There is no fixed total runtime or automatic stop.
- **Missing background status:** verify that the launcher supplied `BACKGRND`
  and that the controller supports the service. The code ignores the return
  value from `ADXSERVE`, so status-service failures are not reported.
- **Unexpected exit:** the global error handler resumes at `STOP` without
  printing the error. Diagnosis requires controller/runtime debugging facilities.
- **Very long runs:** `laps` is a signed four-byte counter reset per phase.
  Sufficient iterations in one phase can exceed its range; behavior then depends
  on the BASIC runtime. Prefer short, repeatable test phases.

The Linux import environment did not provide a configured runnable legacy
toolchain/controller, so no fresh compilation or execution test was performed.

## Repository contents

| File | Purpose |
| --- | --- |
| `CPUSTARV.BAS` | Original BASIC source. |
| `cpustarv.inp` | Linker input and runtime-library settings. |
| `cpustarv.286` | Supplied legacy controller executable, preserved unchanged. |
| `.gitattributes` | Preserve legacy source line endings and executable bytes. |
| `.gitignore` | Exclude intermediate build products and local settings. |

Object, listing, map, symbol, and debug files are local build artifacts and are
not tracked. Rebuild and update the executable whenever you change the source.
The imported executable's SHA-256 is:

```text
24f1b985f4d2a3f96c935c09929624181834b09a18d77f08d5d8d86151502336
```
