# RTX 5070 Ti "GPU has fallen off the bus" (Xid 79 / BusReset TDR): a keep-alive that stopped it on one card

**Credit, please read this first.** This workaround was **found by an AI assistant**, and the keep-alive
program, the install scripts and this report were **written by that AI**. The owner of the card did not
find the fix and did not write any of the code. The owner provided the broken hardware and five months
of failed attempts, allowed the changes, clicked "Yes" on the Windows permission prompts, signed back
in after each restart, checked the results as they came in, and asked for all of this to be said
plainly. The assistant was ZCode, running the GLM 5.4 model from Z.ai. The owner has not yet played a
game or run their own AI programs with the fix in place (see [Limits](#limits-and-unknowns)).

If this helps you, an issue saying so (card model, driver version, what you were doing) would help the
next person. If it does not, say that too.

---

## TL;DR

- An RTX 5070 Ti dropped off the PCIe bus within 1–3 seconds every time a **large load hit it from
  fully idle**: loading an AI model, and by the owner's account also games, Strata, LM Studio and Ollama.
  It was not heat, power or load: the card died at 11–16 W and under 35 °C, before doing any real work.
- Replacing the card (three times), the mini PC and the dock did not help. Nor did four changes to
  Windows and the driver settings.
- What stopped it: **a tiny second program that keeps a CUDA context open on the card.** It holds
  256 MiB of the card's memory, does no computing, and starts at sign-in.
- Same load that crashed the card 3 times out of 3: **35 full model loads with the keep-alive running,
  none crashed**, plus 20 minutes of AI workload and two 3-minute heavy loads. It also passed checks
  after two cold restarts, at PCIe Gen3 and at Gen5, with the keep-alive starting by itself.
- Nobody knows why. This is a workaround for a card fault, not a repair. It has been tried on exactly
  one card.

## The machine

| Part | Details |
|---|---|
| Graphics card | MSI GeForce RTX 5070 Ti, 16 GB, VBIOS `98.03.58.00.9d` |
| Mini PC | Beelink GTi14 (Intel Core Ultra 9 185H), BIOS `GTi14T208` of 2026-07-09, 32 GB RAM |
| GPU dock | Beelink EX Pro (the PCIe 5.0 version), connected to the GTi14's bottom PCIe port |
| PCIe link | 8 lanes; set to Gen3 in the BIOS for most tests, Gen5 for the last ten (Gen1 at idle is normal) |
| Driver | NVIDIA 610.88, installed automatically by Windows Update |
| OS | Windows 11 Pro, 26H2 |
| Display | The monitor is on the mini PC's Intel graphics, so the 5070 Ti has no display attached |

An RTX 3060 had run in the same dock for months without a problem, and the owner reports the 5070 Ti
failed the same way in other PCs. So for this card the dock and the mini PC are not the cause.

## The fault

Each time, the sequence was the same:

1. The card sits idle (state P8, about 13 W, nothing using it).
2. A program starts a large load on it: in the tests, loading a 1.9 GB model through CUDA.
3. Within 1–3 seconds the card is gone. Windows logs this from the NVIDIA driver (`nvlddmkm`,
   Event ID 153):

   ```
   BusReset TDR occurred on GPUID:100
   ```

4. `nvidia-smi` answers `GPU is lost. Reboot the system to recover this GPU` from then on. Switching
   the dock's power off and on while the PC is running does **not** bring it back; a PC restart does.

No Windows hardware-error events (WHEA) were logged around any of the three crashes.

It was captured three times with the card's sensors recorded once per second
([evidence](evidence/README.md)). The last reading before each crash:

| Crash | Driver settings | Last reading before the card was lost |
|---|---|---|
| 1, at 18:11:14 | Default | P1, 16.25 W, 34 °C, memory clock 13,801 MHz, 1,760 MiB in use |
| 2, at 18:38:36 | Four changes applied (below) | P0, 15.41 W, 29 °C, memory clock 14,001 MHz, 194 MiB in use |
| 3, at 18:55:01 | Four changes applied (below) | Still at idle clocks (195 / 405 MHz), 11.56 W, 30 °C, 194 MiB in use |

Small CUDA loads were never a problem: a 25 MB model and a 1 MB model each loaded fine, including as
the very first thing the card did after a restart.

## What was tried and did not fix it

### Before this session: the owner's own attempts, over about five months

- The card was replaced three times. A fourth return was about to be sent.
- The mini PC was replaced once and the dock once.
- PCIe link speed set to Gen3, Gen4 and Gen5 in the BIOS.
- Power limiting and underclocking the card.
- Disabling the Intel graphics in Device Manager.
- The card in other PCs: same failure.

### During the session

All four changes below were in place for crashes 2 and 3. They did not stop the crash. They were all
put back afterwards, and the keep-alive then passed the same load five more times, so it does not
depend on any of them.

| Change | What came of it |
|---|---|
| Windows power plan: PCI Express → Link State Power Management → **Off** | Crash 2 and 3 still happened |
| Windows **Fast Startup** → off | Crash 2 and 3 still happened. When the card is lost, use Restart rather than Shut down |
| Driver setting **Power management mode** → "Prefer maximum performance" | Did not keep the card out of idle while nothing used it. Crash 3 started from the idle state with it on |
| Driver setting **CUDA – Force P2 State** → off | Did take effect: the card then ran at its full state (memory clock 14,001 MHz) instead of the lower CUDA state (13,801 MHz). It got further into the load and still died |

Two more things turned out not to be answers:

- **"Vulkan instead of CUDA" was never actually tested.** Two runs that were supposed to use Vulkan
  silently ran on the CPU because the device selection was wrong. The results were thrown away.
- **`GGML_CUDA_NO_VMM=1`** (a llama.cpp switch for how large buffers are allocated) had no effect:
  current llama.cpp no longer has that switch, and the log still showed `VMM: yes`.

Ruled out as the cause: heat, power draw and load. The card died at 11–16 W and under 35 °C with no
computation going on yet.

## What worked: a keep-alive

With **any other process holding a CUDA context on the card**, the same load passed every time.

The keep-alive in this repo is that process. It opens a CUDA context on the card, fills 256 MiB in it,
and then just sits there, checking once every 15 s that the card still answers.

It does **not** keep the card's clocks up. With it running, the card still idles at P8, 195 MHz and
about 12–13 W, exactly as before. The only measured difference is that something holds the card open.

### The numbers

Every load below is the same 1.9 GB model loaded through CUDA, starting from an idle card.

| Card state before the load | Result |
|---|---|
| Nothing holding it | **0 of 3 passed** (crashes 1, 2 and 3) |
| A keep-alive holding it | **35 of 35 passed** |

Of the 35, 34 started from the deepest idle state (P8, about 13 W) and 1 from a light-idle state
(P5, 21 W). Seven ran with an early stand-in helper (a small llama.cpp server holding a context),
twenty with the Python keep-alive in this repo, and eight with the `.exe`: three with the exact
build in this repo, five with a build that differed only in how it wrote its log file. The Python
file in the repo differs from the tested one only in its opening comment. The last ten runs were made
after the four settings above had been put back, with nothing changed on the PC except the
keep-alive: five at Gen3, and five at Gen5 after another cold restart. The sensor recordings are in
the [evidence](evidence/README.md) folder. All of this was measured on 2026-11-26.

With a keep-alive running, the card also got through:

- 20 minutes of AI workload with pauses between requests: 50 requests, none failed.
- 3 minutes of heavy load after a cold restart, twice: at Gen3 (peak 251 W, 67 °C) and at Gen5 (peak
  258 W, 66 °C), fans up to 55%, and no Windows hardware-error events.
- Two cold restarts (Gen3 and Gen5), with the keep-alive starting by itself at sign-in before anything
  else.

### What it costs

| | Python version | Standalone `.exe` |
|---|---|---|
| Memory on the card | 450 MiB (194 MiB for the context + 256 MiB held) | the same |
| System RAM in use | 131 MB | 132 MB |
| CPU | none (one small query every 15 s) | the same |
| Needs | Python 3 for Windows | nothing; it uses the driver's own `nvcuda.dll` |

### How to tell whether your card has this fault

- Windows Event Viewer → Windows Logs → System: errors from `nvlddmkm`, Event ID 153, with
  `BusReset TDR occurred on GPUID:100` in the data.
- `nvidia-smi` in a terminal says `GPU is lost. Reboot the system to recover this GPU`.
- It happens within seconds of starting something heavy on an idle card.
- A restart brings the card back until the next time.

If your card dies in the middle of sustained load instead, this may not help.

## Install the keep-alive

Windows 11 with an NVIDIA driver (it has only been tried on Windows 11). No administrator rights needed.

### Option A: the standalone program (no Python)

1. On this page: **Code → Download ZIP**, and unzip it.
2. Open the `GpuKeepAlive` folder and double-click **`install.cmd`**.

That puts "GPU keep-alive" in your Startup folder and starts it now.

The `.exe` is unsigned, so a browser, Windows or an antivirus program may warn about it. It is 116
lines of C# that do nothing but the driver calls listed below. To be sure of what you are running,
rebuild it yourself: **`build.cmd`** compiles `GpuKeepAlive.cs` with the C# compiler that is already
part of Windows.

### Option B: the Python script

This is the original, and the version running on the owner's PC. It needs Python 3 for Windows.

1. Install Python from python.org or the Microsoft Store if you do not have it.
2. In the `python` folder, run `install_keepalive.ps1` (right-click → Run with PowerShell), or from a
   terminal: `powershell -ExecutionPolicy Bypass -File install_keepalive.ps1`.

## Check that it is working

- Run **`status.cmd`** (in `GpuKeepAlive`). It should say the keep-alive is running and that the card
  lists it.
- Or open Task Manager → Details: `GpuKeepAlive.exe` (or `pythonw.exe`) should be there.
- Or run `nvidia-smi`: the keep-alive should be listed under Processes, and about 450 MiB in use.

**The keep-alive must be running before the card gets a heavy load.** It starts at sign-in within a
few seconds. Do not remove "GPU keep-alive" from your startup programs.

## Remove it

Run **`uninstall.cmd`**. It stops the program and deletes the Startup shortcut. The card is no longer
protected after that.

## Why it might work

This is a guess. The only thing measured is: a large load from fully idle kills this card within
seconds; the same load with a CUDA context already open on the card does not.

The keep-alive does not change the card's clocks, power or performance state, so it is not "keeping
the card awake" in the usual sense. A held context seems to keep some part of the card or driver in an
initialized state that a cold card is missing when a large load arrives.

## Limits and unknowns

1. **One card, one PC, one afternoon.** An MSI RTX 5070 Ti in a Beelink dock on a GTi14, driver 610.88.
2. **The owner's own programs have not been tried yet.** Games, Strata, LM Studio and Ollama come
   next. The tests here used a small public model through llama.cpp.
3. **No reverse test after the fix.** Once the keep-alive was found, it was never deliberately stopped
   to watch the crash return. The comparison is the three crashes without it.
4. **One dock, mini PC and driver.** The link was at Gen3 for most of the tests and at Gen5 for the
   last ten. No other card, dock, mini PC or driver version has been tried.
5. **The root cause is unknown**, and this does not fix it. The card is still faulty. Keep your logs
   and pursue a replacement or a refund.
6. **Windows and NVIDIA only.** The same idea should work on Linux (any small process holding a CUDA
   context), but that has not been tried.

## Mistakes made along the way

For anyone judging how much to trust the above, these happened and were corrected:

- Two "Vulkan" test steps silently ran on the CPU. It was caught by looking at the card's readings,
  and the results were discarded.
- The first recording script had two bugs and recorded nothing for its first few minutes.
- The first version of the Python keep-alive called old driver entry points and failed to allocate.
- The memory-allocation switch (`GGML_CUDA_NO_VMM`) was tried before checking that llama.cpp still
  supports it.
- One swap between helper versions left the card unprotected for about 35 seconds (nothing was
  loaded during that time).

## How the keep-alive works

It calls the CUDA driver interface in `nvcuda.dll`, which comes with every NVIDIA driver:

1. `cuInit`, `cuDeviceGet`, `cuDevicePrimaryCtxRetain`, `cuCtxSetCurrent`: open a context on the card.
2. `cuMemAlloc_v2` of 256 MiB, then `cuMemsetD8_v2` to fill it.
3. Every 15 s, `cuMemGetInfo_v2`. If the card stops answering, the log records the moment with
   `CARD STOPPED ANSWERING`.

One trap for anyone writing their own: on driver 610.88 the old, unsuffixed entry points
(`cuMemAlloc`, `cuMemGetInfo`) answer "invalid device context" even with a valid context set. The
`_v2` names work.

## Background reading

- [NVIDIA/open-gpu-kernel-modules issue #1151](https://github.com/NVIDIA/open-gpu-kernel-modules/issues/1151):
  a long public thread of RTX 50 owners (5060 Ti through 5090, Windows and Linux) reporting this class
  of failure. It was still open on 2026-11-26.
- [NVIDIA developer forum, Windows thread](https://forums.developer.nvidia.com/t/bug-report-rtx-5090-gpu-lost-0x116-tdr-and-failed-warm-reboot-after-pcie-sram-ecc-events-windows-11-610-62/378873):
  includes the same `BusReset TDR occurred on GPUID:100` line.
- [nvprofileinspector.com on power management settings](https://nvprofileinspector.com/power-management):
  where the "Power management mode" and "CUDA - Force P2 State" settings are described.

## Licence

MIT. Use it, change it, share it.
