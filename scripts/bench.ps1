# Fortnite Rig v2 bench - dry run
param([int]$Duration=10)
$root="C:\Users\LENOVO\fortnite-rig-v2"
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
$out="$root\measurements\bench-$ts.md"
New-Item -ItemType Directory -Path "$root\measurements" -Force | Out-Null
function W($m){ $m | Tee-Object -FilePath $out -Append | Write-Host }
W "# Bench $ts dry run $Duration s"
W ""
W "## Machine"
W "- Plan: $(powercfg /getactivescheme | Out-String)".Trim()
$pb=powercfg /query 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 | Select-String "Current AC"
W "- PERFBOOST: $($pb.ToString().Trim())"
W "- HPET: $((Get-PnpDevice -FriendlyName '*High Precision*' | Select -First 1).Status)"
try{ $gpu=nvidia-smi --query-gpu=name,temperature.gpu,power.draw,utilization.gpu --format=csv,noheader 2>$null | Out-String; W "- GPU: $($gpu.Trim())" }catch{ W "- GPU: nvidia-smi fail" }
W ""
W "## Network $Duration pings"
$gw=(Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Select -First 1).NextHop
if(-not $gw){ $gw="10.0.0.1" }
W "Gateway $gw"
try{
  $pings=Test-Connection -ComputerName $gw -Count $Duration -ErrorAction SilentlyContinue | Measure-Object -Property Latency -Minimum -Maximum -Average
  W "- gateway avg $([math]::Round($pings.Average,1)) min $($pings.Minimum) max $($pings.Maximum) spread $($pings.Maximum - $pings.Minimum)"
}catch{ W "- gateway FAIL $_" }
try{
  $p=Test-Connection -ComputerName "1.1.1.1" -Count $Duration -ErrorAction SilentlyContinue | Measure-Object -Property Latency -Minimum -Maximum -Average
  W "- 1.1.1.1 avg $([math]::Round($p.Average,1)) min $($p.Minimum) max $($p.Maximum)"
}catch{ W "- 1.1.1.1 FAIL $_" }
W ""
W "## us-west-2 TCP handshake 10 samples"
try{
  $times=@()
  1..10 | ForEach-Object {
    $t=Measure-Command { Test-NetConnection -ComputerName "8.8.8.8" -Port 443 -WarningAction SilentlyContinue | Out-Null }
    $times+=[int]$t.TotalMilliseconds; Start-Sleep -Milliseconds 200
  }
  $avg=($times | Measure-Object -Average).Average; $min=($times | Measure-Object -Minimum).Minimum; $max=($times | Measure-Object -Maximum).Maximum
  W "- min $min avg $([math]::Round($avg,1)) max $max (tail 80+ = endpoint variance)"
}catch{ W "- us-west-2 FAIL $_" }
W ""
W "## Hitch baseline to beat"
W "- Pre-fix: 348 hitches / 88 storm (baseline.json)"
W "- Post-fix: 33 hitches / 32 in first 60s then clean"
W "- Run tools/fortnite-lab/fortnite-report.ps1 after a real session"
W ""
W "## Next"
W "- Play 1 lobby 2-3 min before queueing (warmup)"
W "- After session: fortnite-report.ps1 then append to measurements"
Write-Host "`nWrote $out" -ForegroundColor Cyan
Get-Content $out | Out-String -Width 600 | Write-Host
