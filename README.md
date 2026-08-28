# Fortnite Rig v2 — ThinkPad P15 Gen1 (i7-10750H + Quadro T1000 4GB + 60Hz + I219-V)

**Better rig, not cheats.** Measurement-first, hardware-aware, fully reversible. Built on top of `fortnite-outside-box-20260828-123540` + `fortnite-lab` + `fortnite-latency-tweaks` but fixes their drift, placebo, and missing biggest levers.

> **Yo in hood:** we took that outside-the-box pack (44 tweaks deep) and rebuilt it so it *actually* hits. No more fake registry keys, no more appending to a file Fortnite deletes, no more `TdrLevel 0` bricking ya. Just what BENCH proves on THIS 6C/12T + 4GB + 60Hz laptop.

## What's here

- `docs/decisions.md` — every tweak: source, expected gain, risk, revert, measured delta or why rejected. The receipts.
- `docs/architecture.md` — how Fortnite UE5 actually runs on this rig (CPU-bound hitches, PSO storm 348→33, 60Hz ceiling, UDP 36ms floor)
- `configs/` — INI overlays + verified `.nip` (not regex appends)
- `scripts/apply.ps1` — idempotent, timestamped backups, hash-verify
- `scripts/verify.ps1` — reads live state like `fortnite-lab\baseline.json` guard
- `scripts/revert.ps1` — one-click restore from `backups/`
- `scripts/bench.ps1` — PresentMon-ready + `fortnite-report.ps1` + `latency-bench.ps1` merged (hitches vs 348 baseline, gateway/us-west2 p95, thermals)
- `measurements/` — CSVs per run, A/B/A protocol per `fortnite-fps-tracker\03-test-protocol.md`
- `backups/` — timestamped `.reg` + `.ini.bak` + `bcdedit.txt` before any mutate (Rule 1)

## Quick start

```powershell
# 1. Snapshot current state (auto on apply too)
.\scripts\verify.ps1          # see what's drifted

# 2. Apply SAFE tier only (Tier1) — reversible, measured
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1 -Tier Safe

# 3. Apply CONDITIONAL tier only if you bench first
powershell -ExecutionPolicy Bypass -File .\scripts\apply.ps1 -Tier Conditional
powershell -ExecutionPolicy Bypass -File .\scripts\bench.ps1 -Duration 60  # play 1 min in lobby, get hitch count

# 4. Revert everything
powershell -ExecutionPolicy Bypass -File .\scripts\revert.ps1
```

## Tiers

| Tier | Meaning | Example | Risk |
|------|---------|---------|------|
| **Tier1 SAFE** | Reversible, measured, low risk | Reflex verify, MPO off, USB suspend off, QoS via Policies (persistent), NV .nip | Low |
| **Tier2 CONDITIONAL** | Only if bench shows gain on *this* hardware | `0x555` affinity, HZB/VRS, PERFBOOST Aggressive, MemoryCompression off | Medium — needs A/B |
| **Tier3 REJECTED** | Documented why not — placebo/dangerous | `TdrLevel 0`, HPET disable on Win11, `LargeSystemCache`, IRQ `DevicePolicy 4`, TCP Nagle for UDP | N/A — don't apply |

## Hardware ceiling (read before chasing tweaks)

1. **60Hz panel** = 16.6ms floor, invisible frames above 60. External 144Hz+ is the biggest single upgrade (`missions\fortnite-tweak.md:27`).
2. **Thermals** 73°C idle, 50W cap single-fan — cooling pad/elevate/clean vents > any registry tweak for sustained FPS.
3. **4GB VRAM scarce** — `PoolSize 768` + close background GPU apps matters more than RAM tweaks.
4. **Network floor 36ms** to us-west-2 already hit (Ethernet). No proxy/DNS fixes that.

## Why this beats outside-box (audit summary)

See `docs/decisions.md` for line-by-line. TL;DR:
- Fixed `Engine.ini` wipe (Fortnite deletes appends) → atomic overlay + hash persist
- Fixed `NetworkThrottlingIndex` drift `10` vs `ffffffff` (ActiveStore volatile → Policies persistent)
- Replaced infinite 3s PowerShell watcher with native Lasso rule (less CPU)
- Replaced `TdrLevel 0` (BSOD risk) with `TdrLevel 3` + 8s delay
- Removed `LargeSystemCache`, HPET/bcdedit myth, IRQ manual affinity on laptop
- Added measurement harness — no claim without `measurements/*.csv`

## Safety

- No EAC/BattlEye touch, no memory injection, no input automation (all bannable, see `tweak.md:39` macro refusal)
- `StickyKeys`, `GameDVR`, `Secure Boot` handling per `fortnite-latency-tweaks` verified list
- Every mutate copies original to timestamped path first
- Never echo secrets — session files ignored

## Sources

- `missions\fortnite-tweak.md` (539L, 15 addenda, hitch 348→33 verified)
- `tools\fortnite-lab\baseline.json` (known-good state)
- `fortnite-latency-tweaks\README.md` (measured +26% FPS, spike 241→25ms)
- `fortnite-tweak-packs\AUDIT.md` (placebo/fake key catalog)
- NVIDIA `NvApiDriverSettings.h` + `nvidiaProfileInspector` 3.0.2.1
- FrameSync Labs / Hyecross / Epic competitive guide
