# Architecture — How Fortnite Runs On This Rig

**Machine:** ThinkPad P15 Gen1, i7-10750H 6C/12T 2.6GHz Comet Lake-H, Quadro T1000 4GB 50W single-fan, 32GB DDR4-2933 dual, 1080p 60Hz, I219-V 1Gbps, Win11 Pro. Verified `missions\fortnite-tweak.md:6`.

## Engine

- Fortnite Ch6 UE5.4+ alpha. `PreferredFeatureLevel=es31` in `GameUserSettings.ini` = **Performance Mode** — disables Nanite/Lumen, forward shading, shadows/post. Single biggest FPS lever, already on.
- DX12 only (DX11 removed Ch6). `Engine.ini` Paths = 500+ `FortniteGame\Plugins` content mounts + `[SystemSettings]` CVars. Game **rewrites** `Engine.ini` to 70KB default on launch — appends get wiped (`tweaks.log:236`). `GameUserSettings.ini` is **cloud authoritative** — Epic overwrites local on launch (`tweak.md:434`), so in-game menu is source of truth for `bDisableMouseAcceleration`, `sg.ResolutionQuality`, `FullscreenMode`, `ViewDistance`, `FrameRateLimit`.
- Shipped `StagedBuild` configs expose no extra perf CVars (tweak.md addendum 7). `Engine.ini` `[SystemSettings]` overrides largely ignored.

## Bottleneck Profile (measured)

- **CPU-bound:** CPU frame 11.5ms vs GPU 3.9ms (`fortnite-latency-tweaks`), GPU 22-37% at 78°C lobby (`tweak.md:168`). 4GB VRAM scarce, ~1GB taken by desktop/browser before game (`05-hardware.md`).
- **Hitch storm:** 348 hitches / 88 in first 7 min, 69 draw calls worst frames = CPU stalls, PSO precache + asset IO + `HttpManagerThread` (`tweak.md:283`). Post-reboot 33 hitches total, 32 in first 60s then clean (`tweak.md:415`) — storm DEAD after BCD/worker thread fixes. 1% lows > avg FPS matters.
- **Power/thermal ceiling:** 73°C GPU at 30% idle (`05-hardware.md`), 50W cap single-fan. Sustained clocks decided by cooling long before settings. Power plan: High `8c5e7fda` vs Ultimate `5a756bc4` — A/B +26% on desktop but caged to 23W on this laptop (`fortnite-latency-tweaks\README.md`).

## Input Latency Pipeline (8 stages, hood: every ms counts)

1. **Mouse USB poll** 250Hz stock → 1000Hz via hidusbf (`tweak.md:422`, DualSense VID_054C). ~3ms win, hardware tuning not bannable.
2. **Windows queue** `Win32PrioritySeparation` 36 vs 38, `SystemResponsiveness 0`, `LargeSystemCache` placebo.
3. **Game tick** `-limitclientticks` + `r.OneFrameThreadLag 0` / `r.GTSyncType 1` / `r.FinishCurrentFrame 0` — cuts 1 frame queue (~10ms) if PresentMon proves.
4. **Render queue** Reflex `On` vs `On+Boost` — Boost adds 5°C single-fan (`fortnite-latency-tweaks`), in-game Reflex supersedes NVCP Low Latency `Off` (`tweak.md:204` Reflex On+Boost supersedes NVCP).
5. **GPU queue** `ShaderCache Unlimited` via NV .nip (10GB legacy `ShaderCacheSize` placebo) reduces PSO hitch.
6. **Display scanout** 60Hz = 16.6ms floor. 120FPS on 60Hz renders 2x invisible frames = heat for no gain (`tweak.md:176`). 144Hz external = 6.9ms floor, biggest lever.
7. **Network** UDP 30Hz server tick, min 36ms to us-west-2 (`latency-bench.ps1` bench-20260821: `tweak.md:508`). TCP Nagle/DNS irrelevant.
8. **Peripheral** core isolation `0x555` (physical 0,2,4,6,8,10) leaves HT siblings `0xAAA` for launchers/EAC, reduces DPC migration — but native scheduler already does most.

## What "Better Rig" Means Legit

Not cheats. Tighter pipeline + stable 1% lows. Priority order for *this* box:
1. External 144Hz+ (visible latency 16→7ms)
2. Thermals (cooling pad, elevate, clean vents, 1530MHz lock `fortnite-perf\unlock-gpu-power.ps1`)
3. Poll 1000Hz + `bDisableMouseAcceleration True` **in-game** (cloud sync) + Reflex `On+Boost` verify
4. Exclusive fullscreen `FSEBehaviorMode 2` + `DISABLEDXMAXIMIZEDWINDOWEDMODE` (already set) + `r.VSync 0` / `t.MaxFPS 0` uncapped
5. Measured tick tweaks (`OneFrameThreadLag` etc.) only if bench shows gain

## Config Surfaces (where tweaks live)

- **Fortnite INI:** `%LOCALAPPDATA%\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini` + `Engine.ini` + `%LOCALAPPDATA%\EpicGamesLauncher\Saved\Config\Windows\Game.ini` (`AdditionalCommandLine`)
- **NV profile:** `nvidiaProfileInspector` `.nip` (IDs from `NvApiDriverSettings.h`, `tweak.md:245` verified) — `nvdrsdb0.bin` binary store, not `nvapps.xml`
- **Windows:** `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`, `PriorityControl`, `Multimedia\SystemProfile`, `Session Manager\Executive` (worker threads 16), `Power\PowerThrottling`, `GameConfigStore`, `DirectX\UserGpuPreferences` (`SwapEffectUpgradeEnable=1` + `VRROptimizeEnable=1`)
- **Network:** `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS` (persistent DSCP 46) vs volatile `Get-NetQosPolicy ActiveStore`; I219-V `Get-NetAdapterAdvancedProperty` (`InterruptModeration Disabled`, `Flow Control Disabled`, `EEE Off` — verified `tweak.md:347` still holds)
- **Boot:** `bcdedit` — modern Win11 invariant TSC, `useplatformclock/tick/dynamictick` now obsolete/harmful (`tweak.md:306` removed)
