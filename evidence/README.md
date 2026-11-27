# Evidence: sensor recordings from the card

Readings taken directly from the card with NVIDIA's own tools while the tests ran. Nothing here
is synthetic: every file is copied from a recording made on 2026-11-26 and cut to the relevant
minutes. The files contain only timestamps and numbers.

## The three crashes (no keep-alive running)

Windows logged the same line each time, from the NVIDIA driver (`nvlddmkm`, Event ID 153, Error):

```
BusReset TDR occurred on GPUID:100
```

and `nvidia-smi` answered `GPU is lost. Reboot the system to recover this GPU` from then on.
Only a restart of the PC brought the card back. No Windows hardware-error (WHEA) events were
logged around any of the three.

| File | Last reading before the card was lost | Event logged |
|---|---|---|
| `crash-1_18-11-14_no-helper_default-driver-settings.csv` | 18:11:13.495: P1, 16.25 W, 34 °C, memory clock 13,801 MHz, 1,760 MiB in use | 18:11:14.214 |
| `crash-2_18-38-36_no-helper_four-settings.csv` | 18:38:33.576: P0, 15.41 W, 29 °C, memory clock 14,001 MHz, 194 MiB in use | 18:38:36.461 |
| `crash-3_18-55-01_no-helper_four-settings.csv` | 18:55:00.325: still at idle clocks (195 / 405 MHz), 11.56 W, 30 °C, 194 MiB in use | 18:55:01.470 |

In each case a 1.9 GB model was being loaded onto the card: the first real work for the card
after that boot. The readings stop at the last successful sample; there is no next sample.

"Four settings" means crash 2 and 3 happened with all four changes from the main report in place
(PCIe link power saving off, Fast Startup off, "Prefer maximum performance", "CUDA - Force P2
State" off). They did not prevent the crash.

## The same load with the keep-alive running

| File | What it shows |
|---|---|
| `ok_19-01-12_full-load-with-keepalive_20-readings-per-second.csv` | 34 seconds at 20 readings per second: a tiny warm-up load, the start of the keep-alive, then the same 1.9 GB model load and benchmark that crashed the card three times. About 0.5 s of readings are missing at 19:01:35 while the upload happened; the card then stepped up its clocks and ran the benchmark. |
| `ok_19-34-26_cold-restart_with-keepalive_5-loads-and-3-min-heavy.csv` | The whole check after a cold restart with the keep-alive starting by itself: five full model loads from idle, then three minutes of heavy load (peak 251 W, 67 °C, fans up to 55%). |

## Columns

`crash-*.csv` and `ok_19-34-26_*.csv` (one reading per second):

| Column | Meaning |
|---|---|
| `time` | Local time |
| `pstate` | NVIDIA performance state (P0 = active, P8 = idle) |
| `temp_c` | GPU temperature |
| `power_w` | Power draw |
| `clk_gfx_mhz`, `clk_mem_mhz` | Graphics and memory clock |
| `util_gpu_pct`, `util_mem_pct` | GPU and memory utilisation |
| `mem_used_mib` | Memory in use on the card |
| `pcie_gen`, `pcie_width` | PCIe link speed and width |
| `fan_pct` | Fan speed |
| `throttle` | Clock-throttle flags. Zero in all three crash files and everywhere else, except two readings during the heavy load in the cold-restart file (`0x4`, the card's software power cap, at about 249 W) |

`ok_19-01-12_*.csv` (20 readings per second): `time, power_mw, util_gpu, util_mem, clk_gfx_mhz,
clk_mem_mhz, temp_c`. Power is in milliwatts there.

## Not included

Raw Windows event dumps and driver logs are left out on purpose: they contain computer names
and account identifiers.
