# Fortnite Rig v2 — bench.ps1
# Dry-run network + system bench without disturbing game. For in-match hitch count, use fortnite-lab\fortnite-report.ps1 after a session.
# Usage: .\bench.ps1 -Duration 30

param([int]$Duration=30)

$root="C:\Users\LENOVO\fortnite-rig-v2"
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
$out="$root\measurements\bench-$ts.md"
New-Item -ItemType Directory -Path "$root\measurements" -Force | Out-Null

function W($m){ $m | Tee-Object -FilePath $out -Append | Write-Host }

W "# Bench $ts — dry run (no game load, $Duration s)"
W ""
W "## Machine"
W "- Plan: $(powercfg /getactivescheme | Out-String)".Trim()
W "- PERFBOOST: $((powercfg /query 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 | Select-String 'Current AC').ToString().Trim())"
W "- HPET: $((Get-PnpDevice -FriendlyName '*High Precision*' | Select -First 1).Status)"
W "- GPU: $((nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu --format=csv,noheader 2>$null | Out-String).Trim())"
W "- RAM: $((Get-CimInstance Win32_OperatingSystem | Select TotalVisibleMemorySize,FreePhysicalMemory | Out-String).Trim())"
W ""

W "## Network ($Duration pings)"
# gateway
$gw=(Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select -First 1).NextHop
if(-not $gw){ $gw="10.0.0.1" }
W "Gateway $gw"
try{
  $pings=Test-Connection -ComputerName $gw -Count $Duration -ErrorAction SilentlyContinue | Measure-Object -Property Latency -Minimum -Maximum -Average
  W "- gateway avg $([math]::Round($pings.Average,1)) min $($pings.Minimum) max $($pings.Maximum) ms (spread $($pings.Maximum - $pings.Minimum))"
}catch{ W "- gateway FAIL $_" }
try{
  $pings=Test-Connection -ComputerName "1.1.1.1" -Count $Duration -ErrorAction SilentlyContinue | Measure-Object -Property Latency -Minimum -Maximum -Average
  W "- 1.1.1.1 avg $([math]::Round($pings.Average,1)) min $($pings.Minimum) max $($pings.Maximum) ms"
}catch{ W "- 1.1.1.1 FAIL $_" }

# us-west-2 TCP handshake rough via Test-NetConnection
W ""
W "## us-west-2 TCP handshake (10 samples, ~46ms floor = good)"
try{
  $times=@()
  1..10 | ForEach-Object {
    $t=Measure-Command { Test-NetConnection -ComputerName "ping-na-west-2.epicgames.com" -Port 443 -WarningAction SilentlyContinue | Out-Null }
    $times+=[int]$t.TotalMilliseconds; Start-Sleep -Milliseconds 300
  }
  $avg=($times | Measure-Object -Average).Average; $min=($times | Measure-Object -Minimum).Minimum; $max=($times | Measure-Object -Maximum).Maximum; $p95=($times | Sort)[[math]::Floor($times.Count*0.95)]
  W "- min $min avg $([math]::Round($avg,1)) p95 $p95 max $max ms (tail 80+ = endpoint variance, not bloat — see tweak.md:521)"
}catch{ W "- us-west-2 FAIL $_" }

W ""
W "## Hitch baseline to beat"
W "- Pre-fix: 348 hitches / 88 storm / 2384 stall lines (`fortnite-lab\baseline.json` + `tweak.md:283`)"
W "- Post-fix: 33 hitches / 32 in first 60s then clean (`tweak.md:415`)"
W "- Run `tools\fortnite-lab\fortnite-report.ps1` after a real session for hitch count"

W ""
W "## Next"
W "- Play 1 lobby 2-3 min before queueing (warmup, PSO precache — tweak.md:298 warmup habit)"
W "- After session: `powershell -File C:\Users\LENOVO\tools\fortnite-lab\fortnite-report.ps1` then append to measurements\"
W "- Full A/B: `fortnite-fps-tracker\measure.ps1` + PresentMon per `03-test-protocol.md`"

Write-Host "`nWrote $out" -ForegroundColor Cyan
Get-Content $out | Out-String -Width 600 | Write-Host
