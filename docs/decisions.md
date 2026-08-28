# Decisions — Why Each Tweak Is Safe/Conditional/Rejected

Source of truth for claims. Every row has provenance, verified value on this machine 2026-08-28, and revert.

Backup before mutate: `C:\Users\LENOVO\.factory\live-state-20260828-161723` + `fortnite-outside-box` snapshot. No backup, no write.

## Tier1 SAFE — apply via `apply.ps1 -Tier Safe`

| # | Tweak | File/Reg | Expected gain | Verified now | Revert |
|---|-------|----------|---------------|--------------|--------|
| S1 | Performance Mode `PreferredFeatureLevel=es31`, `sg.*=0`, `bMotionBlur False`, `bUseVSync False`, `bUseNanite False` | `GameUserSettings.ini` in-game menu (cloud authoritative) | Baseline — biggest lever already | `es31` / `0` present, but `sg.ResolutionQuality=65` drifted, `bDisableMouseAcceleration=False` drifted — fix **in-game** not ini | Set in-game Video |
| S2 | Reflex `LowInputLatencyModeIsEnabled True` + NVCP Low Latency `Off` (Reflex rules) | `GameUserSettings.ini` + NV .nip `PrerenderLimit 0` | -1-2 frames queue | `LowInputLatencyModeIsEnabled=True` OK, NV `Fortnite` profile `PrerenderLimit 0` OK (`tweak.md:251`) | In-game Reflex On |
| S3 | Exclusive fullscreen `FSEBehaviorMode 2`, `AppCompatFlags DISABLEDXMAXIMIZEDWINDOWEDMODE`, `r.VSync 0 + t.MaxFPS 0 + rhi.SyncInterval 0` + `GameDVR_Enabled 0` + `Policies\GameDVR AllowGameDVR 0` | `GameConfigStore` + `Engine.ini` | 5-10ms DWM bypass | FSE 2 OK, DXMAXIMIZED already for 3 exes, `AllowGameDVR 0` via Batch6 (`tweaks.log:251`) | `reg import` backup |
| S4 | MPO off `OverlayTestMode 5` | `HKLM\SYSTEM\...\GraphicsDrivers` | Reduces DWM overlay stutter | Re-asserted Batch1 (`tweaks.log:31`) | delete value |
| S5 | USB selective suspend `EnhancedPowerManagementEnabled 0` for XHCI `06ED/15EC` + mouse per-device | `HKLM\SYSTEM\...\USB` | Stable 1000Hz poll | Batch5 `tweaks.log:181` done | set 1 |
| S6 | `SystemResponsiveness 0`, `NetworkThrottlingIndex 0xffffffff` (4294967295) | `HKLM\SOFTWARE\...\Multimedia\SystemProfile` | Disables MMCSS throttling | **DRIFTED:** `10` not `ffffffff` now — outside-box `tweaks.log:119` claimed ffffffff but ActiveStore volatile, Policies missing | `Set-ItemProperty 10` |
| S7 | `DirectXUserGlobalSettings VRROptimizeEnable=1;SwapEffectUpgradeEnable=1;` | `HKCU\...\DirectX\UserGpuPreferences` | Windowed flip model + VRR | Flagged by `fortnite-lab\baseline.json:mustContain` but drifted to `0` earlier (`tweak.md:392`) — guard fixed | `VRROptimizeEnable=0;` |
| S8 | Core parking `CPMINCORES 100 CPMAXCORES 100` on `8c5e7fda` High perf, `DISKIDLE 0` NVMe | `powercfg` | Keeps 6C ready for endgame burst, NVMe no PS3 sleep | Batch2 `tweaks.log:100` set, Batch6 `DISKIDLE 0` (`tweaks.log:249`) | `powercfg /setacvalueindex ... 0` |
| S9 | QoS DSCP 46 via `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite` (persistent) + `FortniteUDP-EF` ActiveStore | Registry Policies | Harmless if router ignores, ~2ms if honors | Outside-box used ActiveStore only (`tweaks.log:49` `Get-NetQosPolicy`) — **volatile**, now missing on reboot | `Remove-NetQosPolicy` + delete QoS key |
| S10 | I219-V `Flow Control Disabled`, `Interrupt Moderation Disabled`, `EEE Off`, `AllowComputerToTurnOffDevice Disabled` via WMI, `PMARP/PMNS Off`, `LsoV2IPv4 Off` | `Get-NetAdapterAdvancedProperty` | -0.5-2ms DPC | Verified still Disabled/Off (`tweak.md:347` + `tweaks.log:123`) | `Set-NetAdapterAdvancedProperty` revert |

## Tier2 CONDITIONAL — only if `bench.ps1` shows gain on *this* box (A/B/A per `fortnite-fps-tracker\03-test-protocol.md`)

| # | Tweak | Gain | Cost | Bench gate |
|---|-------|------|------|------------|
| C1 | `r.OneFrameThreadLag 0 / GTSyncType 1 / FinishCurrentFrame 0`, `r.Streaming.PoolSize 768 + LimitPoolSizeToVRAM 1 + UseFixedPoolSize 1`, `r.Nanite 0`, `t.MaxFPS 0` | -10ms input + less VRAM pressure | Engine.ini wiped every launch — needs overlay + hash persist | PresentMon 1% low +5% or input latency -5ms |
| C2 | `r.HZBOcclusion 1 + AllowOcclusionQueries 1 + DownsampledOcclusionQueries 1` | Cheaper occlusion for 100-player build | Turing specific, placebo if draw 69 not GPU | FPS +3% in builds |
| C3 | `r.VRS.Enable 1 + ContrastAdaptiveShading 1` (Turing Tier1) | Periphery shading save at 65% res | Visual quality tradeoff | FPS +2% no blur |
| C4 | Affinity `0x555` physical cores Forti+ EAC High, launchers/EAC `0xAAA` via Lasso `prolasso.ini` *not* PS watcher loop | Isolates DPC | Lasso license nag, scheduler already does most | 1% low +3% vs stock |
| C5 | `PERFBOOSTMODE 2 Aggressive` on `8c5e7fda` | Boost longer in endgame | +heat, can cage to 23W on laptop (`fortnite-latency-tweaks` measured) | Avg FPS +5% no thermal throttle |
| C6 | `Disable-MMAgent -MemoryCompression` (32GB, diag true) | -3-5% CPU (no compress) | If RAM pressure returns, page faults | CPU time -3% in `bench` |
| C7 | `Win32PrioritySeparation 38 (0x26)` vs 36 | FrameSync says 36 best 1% lows, outside-box used 38 (`tweaks.log:178`) | Sub-perceptual, Lasso may override | CapFrameX 1% low A/B |

## Tier3 REJECTED — documented with receipts

| Tweak | Where it came from | Why rejected | Source |
|-------|-------------------|--------------|--------|
| `TdrDelay 8 TdrDdiDelay 8 TdrLevel 0` | outside-box Batch2 `tweaks.log:94` | `TdrLevel 0` = **disable recovery** → freeze/BSOD on PSO compile >2s on 4GB. Set `3` if you want longer timeout, never 0. | `fortnite-tweak-packs\AUDIT.md` + Guru3D |
| `HPET Error (Disable-PnpDevice) + bcdedit disabledynamictick Yes / tscsyncpolicy Enhanced` | outside-box `tweaks.log:82` | Win11 invariant TSC + auto timer boost for games; disabling HPET risks clock skew, EAC/BattlEye. Mission **removed** both flags as harmful `tweak.md:306`. | FrameSync 2026 consensus + `tweak.md` addendum 8 |
| `LargeSystemCache 1` | outside-box `tweaks.log:104` | Server SKU file cache, not gaming; can evict Fortnite working set. `EnablePrefetcher 0` already in verify list, not this. | `fortnite-tweak-packs` myths catalog |
| `IRQ affinity DevicePolicy 4 AssignmentSetOverride 0x800/0x200` | outside-box `tweaks.log:137` | Untested on laptop single-queue RSS (`tweak.md:350` RSS 1 queue normal), can increase DPC if core wrong. Keep default. | `tweak.md` local repo scan |
| `ShaderCacheSize 10` via `GraphicsDrivers` | outside-box `tweaks.log:141` | Legacy key pre-2015; modern cache is NVCP `Shader Cache Unlimited` via `.nip` (`tweak.md:251` verified). | NVIDIA `NvApiDriverSettings.h` |
| `LsoV2IPv4/PMARP/PMNS` already covered, but `TcpAckFrequency/TCPNoDelay` per-interface | outside-box `tweaks.log:114` verified all 8 interfaces `1` | Fortnite UDP, not TCP — Nagle only TCP. Placebo. | `tweak.md:54` skipped Nagle (UDP) |
| `VxD\BIOS CPUPriority/FastDRAM/PCIConcur` | `fortnite-tweak-packs\Peterbot\Delay18.reg` | **FAKE** Win9x path, does nothing on Win11. | `AUDIT.md:Delay18` |
| `Win32PrioritySeparation 0xfff55555` | `ReduceInputDelay\delayy.reg` | **INVALID** DWORD — undefined scheduler. | `AUDIT.md:delayy.reg` |
| `MSMQ\Parameters\TCPNoDelay` | `shakey_best_input.reg` | Wrong hive — TCP tuning is `Tcpip\Interfaces\<NIC>`, MSMQ is message queuing. | `AUDIT.md:shakey` |
| `GameFluidity / FpsAll` | `Peterbot\Delay19.reg` | Placebo, no documented OS behavior. | `AUDIT.md:Delay19` |

## Outside-Box Audit — what drifted vs what held (2026-08-28 live snapshot)

| Check | Outside-box claimed | Live now | Verdict |
|-------|---------------------|----------|---------|
| `Engine.ini OneFrame/GTSync/PoolSize` | `tweaks.log:13` present | **Absent** — 69919 byte default | **Wiped** by Fortnite rewrite — persist append logic fails |
| `GameUserSettings bDisableMouseAcceleration` | `tweaks.log:11` True | **False** | Cloud overwrite |
| `sg.ResolutionQuality` | 100 (`tweak.md:105`) | **65** | Cloud overwrite |
| `FrameRateLimit` | 240 (`tweak.md:116`) | **360** | Cloud overwrite |
| `FullscreenMode` | 0 exclusive | **1** borderless | Cloud overwrite |
| `NetworkThrottlingIndex` | `4294967295` (`tweaks.log:119`) | **10** | Drifted — Policies key never created |
| `Win32PrioritySeparation` | 38 (`tweaks.log:178`) | **36** | Guard removed WPS from baseline, ping-pong |
| `TdrLevel` | 0 | **0** | Held but dangerous |
| `HPET` | Error | **Error** | Held |
| `Game.ini AdditionalCommandLine` | `-limitclientticks -USEALL...` (`tweaks.log:90`) | **Held** | OK |
| `QoS FortniteUDP-EF` | DSCP 46 ActiveStore | **Missing** ActiveStore, no Policies key | Volatile |

## How v2 beats outside-box

1. **Atomic overlay, not append:** `configs\Engine.ini.overlay` + `scripts\apply.ps1` writes `[SystemSettings]` section atomically, hash `SHA256` verify, `persist.ps1` watches hash not substring.
2. **Policies QoS:** `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\Fortnite` persistent, `Apply` also seeds `ActiveStore` for immediate.
3. **Lasso native:** `configs\prolasso.ini` + `Import-ProLasso` vs `while($true) Start-Sleep 3` loop (`fortnite-affinity-watcher.ps1:3`).
4. **No `TdrLevel 0`:** v2 sets `TdrDelay 8 TdrDdiDelay 8 TdrLevel 3` or leaves default.
5. **Measurement gate:** every Conditional tweak requires `measurements\bench-*.csv` with hitch count vs 348 baseline + p95 before claim.
