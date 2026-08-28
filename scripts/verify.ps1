# Fortnite Rig v2 - verify (ASCII only, no unicode)
$root="C:\Users\LENOVO\fortnite-rig-v2"
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
Write-Host "=== Fortnite Rig v2 Verify $ts ===" -ForegroundColor Cyan

function OK($m){ Write-Host "  [OK] $m" -ForegroundColor Green }
function ShowDiff($m){ Write-Host "  [DIFF] $m" -ForegroundColor Yellow }
function MISS($m){ Write-Host "  [MISS] $m" -ForegroundColor Red }

$e="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini"
Write-Host "`n--- Engine.ini ---" -ForegroundColor Yellow
if(Test-Path $e){
  $c=Get-Content $e -Raw
  foreach($k in @("r.OneFrameThreadLag=0","r.GTSyncType=1","r.Streaming.PoolSize=768","t.MaxFPS=0")){
    if($c -match [regex]::Escape($k)){ OK $k } else { ShowDiff "missing $k" }
  }
  if($c -match "r.HZBOcclusion=1"){ OK "r.HZBOcclusion=1 (Conditional)" } else { Write-Host "  [..] r.HZBOcclusion absent (ok if not benched)" -ForegroundColor DarkGray }
  Write-Host "  hash $((Get-FileHash $e -Algorithm SHA256).Hash.Substring(0,12)) bytes $((Get-Item $e).Length)"
} else { MISS "Engine.ini not found" }

$g="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini"
Write-Host "`n--- GameUserSettings.ini (cloud authoritative) ---" -ForegroundColor Yellow
if(Test-Path $g){
  $checks=@(
    @{k="bDisableMouseAcceleration";want="True"},
    @{k="bUseVSync";want="False"},
    @{k="PreferredFullscreenMode";want="0"},
    @{k="LowInputLatencyModeIsEnabled";want="True"}
  )
  foreach($kv in $checks){
    $m=Select-String -Path $g -Pattern ("^"+[regex]::Escape($kv.k)+"=") | Select -First 1
    if($m){
      $v=$m.Line.Split("=")[1]
      if($v -eq $kv.want){ OK "$($kv.k)=$v" } else { ShowDiff "$($kv.k)=$v want $($kv.want) fix IN-GAME" }
    } else { MISS "$($kv.k) absent" }
  }
  $sg=Select-String -Path $g -Pattern "^sg.ResolutionQuality=" | Select -First 1
  if($sg){ Write-Host "  [..] $($sg.Line) (cloud, set in-game)" -ForegroundColor DarkGray }
  $fr=Select-String -Path $g -Pattern "^FrameRateLimit=" | Select -First 1
  if($fr){ Write-Host "  [..] $($fr.Line) (cloud, set in-game)" -ForegroundColor DarkGray }
} else { MISS "GameUserSettings.ini not found" }

$gi="$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini"
Write-Host "`n--- Game.ini ---" -ForegroundColor Yellow
if(Test-Path $gi){
  $c=Get-Content $gi -Raw
  if($c -match "AdditionalCommandLine"){ OK ((Select-String -Path $gi -Pattern AdditionalCommandLine).Line.Trim()) } else { ShowDiff "AdditionalCommandLine missing" }
} else { MISS "Game.ini missing" }

Write-Host "`n--- Registry ---" -ForegroundColor Yellow
$mp=Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" -ErrorAction SilentlyContinue
if($mp.SystemResponsiveness -eq 0){ OK "SystemResponsiveness 0" } else { ShowDiff "SystemResponsiveness=$($mp.SystemResponsiveness) want 0" }
if($mp.NetworkThrottlingIndex -eq 4294967295 -or $mp.NetworkThrottlingIndex -eq -1){ OK "NetworkThrottlingIndex ffffffff" } else { ShowDiff "NetworkThrottlingIndex=$($mp.NetworkThrottlingIndex) want 4294967295" }
$dx=(Get-ItemProperty "HKCU:\Software\Microsoft\DirectX\UserGpuPreferences" -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
if($dx -like "*SwapEffectUpgradeEnable=1*"){ OK "DirectXUserGlobalSettings $dx" } else { ShowDiff "DirectXUserGlobalSettings $dx" }
$pr=(Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -ErrorAction SilentlyContinue).Win32PrioritySeparation
if($pr -eq 36){ OK "Win32PrioritySeparation 36" } elseif($pr -eq 38){ OK "Win32PrioritySeparation 38" } else { ShowDiff "Win32PrioritySeparation $pr" }
$gd=Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -ErrorAction SilentlyContinue
if($gd.TdrLevel -eq 3){ OK "TdrLevel 3 safe" } elseif($gd.TdrLevel -eq 0){ ShowDiff "TdrLevel 0 DANGEROUS run apply -Tier Safe to fix to 3" } else { ShowDiff "TdrLevel $($gd.TdrLevel)" }
if($gd.TdrDelay -eq 8){ OK "TdrDelay 8" } else { ShowDiff "TdrDelay $($gd.TdrDelay) want 8" }

Write-Host "`n--- bcdedit ---" -ForegroundColor Yellow
$b=bcdedit /enum | Out-String
if($b -match "disabledynamictick\s+Yes"){ ShowDiff "disabledynamictick Yes present harmful Win11" } else { OK "disabledynamictick absent correct" }
$tsc=bcdedit | Select-String tscsync
if($tsc){ OK $tsc.ToString().Trim() }

Write-Host "`n--- HPET ---" -ForegroundColor Yellow
$h=Get-PnpDevice -FriendlyName "*High Precision*" -ErrorAction SilentlyContinue
if($h.Status -eq "Error"){ OK "HPET Error (outside-box disabled)" } else { OK "HPET $($h.Status) stock" }

Write-Host "`n--- Power ---" -ForegroundColor Yellow
$plan=powercfg /getactivescheme
Write-Host "  $plan"
if($plan -match "8c5e7fda"){ OK "High performance 8c5e7fda" } elseif($plan -match "5a756bc4"){ OK "Ultimate Performance" } else { ShowDiff "Power not High/Ultimate" }
$pb=powercfg /query 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 54533251-82be-4824-96c1-47b60b740d00 be337238-0d82-4146-a960-4f3749d470c7 | Select-String "Current AC"
if($pb -match "0x00000002"){ OK "PERFBOOSTMODE 2 Aggressive" } else { ShowDiff "PERFBOOSTMODE $pb want 0x2" }

Write-Host "`n--- Adapters ---" -ForegroundColor Yellow
$eth=Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue
if($eth){
  $props=Get-NetAdapterAdvancedProperty -Name "Ethernet" -ErrorAction SilentlyContinue
  foreach($n in @("Flow Control","Interrupt Moderation","Energy Efficient Ethernet")){
    $p=$props | Where-Object DisplayName -eq $n | Select -First 1
    if($p){
      if($p.DisplayValue -eq "Disabled" -or $p.DisplayValue -eq "Off"){ OK "$n $($p.DisplayValue)" } else { ShowDiff "$n $($p.DisplayValue) want Disabled/Off" }
    } else { MISS $n }
  }
}

Write-Host "`n--- QoS ---" -ForegroundColor Yellow
$qA=Get-NetQosPolicy -Name "FortniteUDP-EF" -PolicyStore ActiveStore -ErrorAction SilentlyContinue
$qP=Test-Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\FortniteUDP-EF"
if($qA){ OK "ActiveStore FortniteUDP-EF DSCP $($qA.DSCPAction)" } else { ShowDiff "ActiveStore missing volatile" }
if($qP){ OK "Policies QoS present persistent" } else { ShowDiff "Policies QoS missing apply will create" }

Write-Host "`n--- Tasks ---" -ForegroundColor Yellow
foreach($tn in @("FortniteAffinityWatcher","FortniteOutsideBox-Persist","FortniteRigV2-Persist","LatencyLab-Boot","ISLC-Gaming","FortniteGPU-MaxClock")){
  $t=Get-ScheduledTask -TaskName $tn -ErrorAction SilentlyContinue
  if($t){ OK "$tn $($t.State)" } else { Write-Host "  [..] $tn absent" -ForegroundColor DarkGray }
}

Write-Host "`n=== Verify done ===" -ForegroundColor Cyan

