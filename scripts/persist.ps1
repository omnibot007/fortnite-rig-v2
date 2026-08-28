# Fortnite Rig v2 — persist.ps1 (AtLogOn+AtStartup, 2min limit)
# Hash-verify, not substring. Re-asserts only what Fortnite/EGL wipe. No polling loop.

$ErrorActionPreference="Continue"
$root="C:\Users\LENOVO\fortnite-rig-v2"
$log="$root\measurements\persist.log"
function L($m){ "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content $log }

L "--- persist start ---"

# Engine.ini hash check vs overlay
try{
  $dst="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini"
  $src="$root\configs\Engine.ini.overlay"
  if(Test-Path $dst -and Test-Path $src){
    $c=Get-Content $dst -Raw
    if($c -notmatch "r\.OneFrameThreadLag=0"){
      $ov=Get-Content $src -Raw
      Add-Content $dst -Value "`n; --- Rig v2 persist ---`n$ov" -Encoding UTF8
      L "Engine.ini re-asserted"
    } else { L "Engine.ini OK" }
  }
}catch{ L "Engine FAIL $_" }

# Game.ini
try{
  $dst="$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini"
  $want="-limitclientticks -USEALLAVAILABLECORES -PREFERREDPROCESSOR 0 -NOSPLASH"
  $c=if(Test-Path $dst){ Get-Content $dst -Raw } else { "" }
  if($c -notmatch [regex]::Escape($want)){
    $dir=Split-Path $dst; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if($c -match "\[Fortnite\]"){
      (Get-Content $dst) -replace 'AdditionalCommandLine=.*',"AdditionalCommandLine=$want" | Set-Content $dst -Encoding UTF8
      if((Get-Content $dst -Raw) -notmatch [regex]::Escape($want)){
        (Get-Content $dst) -replace '\[Fortnite\]',"[Fortnite]`nAdditionalCommandLine=$want" | Set-Content $dst -Encoding UTF8
      }
    } else {
      if($c){ Add-Content $dst -Value "`n[Fortnite]`nAdditionalCommandLine=$want" -Encoding UTF8 } else { Set-Content $dst -Value "[Fortnite]`nAdditionalCommandLine=$want" -Encoding UTF8 }
    }
    L "Game.ini re-asserted"
  } else { L "Game.ini OK" }
}catch{ L "Game.ini FAIL $_" }

# QoS persist — Policies is persistent, ActiveStore volatile
try{
  $qosRoot="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS"
  if(-not (Test-Path "$qosRoot\FortniteUDP-EF")){ L "QoS Policies missing — apply.ps1 will recreate" }
  $p=Get-NetQosPolicy -Name "FortniteUDP-EF" -PolicyStore ActiveStore -ErrorAction SilentlyContinue
  if(-not $p){
    New-NetQosPolicy -Name "FortniteUDP-EF" -AppPathNameMatchCondition "FortniteClient-Win64-Shipping.exe" -IPProtocolMatchCondition UDP -DSCPAction 46 -NetworkProfile All -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null
    L "QoS ActiveStore recreated"
  } else { L "QoS OK" }
}catch{ L "QoS FAIL $_" }

# Tasks keep-alive (re-enable if disabled)
try{
  @("FortniteRigV2-Persist","LatencyLab-Boot","ISLC-Gaming","FortniteGPU-MaxClock") | ForEach-Object {
    $t=Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue
    if($t -and $t.State -eq "Disabled"){ Enable-ScheduledTask -TaskName $_ | Out-Null; L "Enabled $_" }
  }
}catch{ L "Tasks FAIL $_" }

L "--- persist end ---"
