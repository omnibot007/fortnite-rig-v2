#Requires -RunAsAdministrator
# Fortnite Rig v2 apply - Tier Safe fixes
param([ValidateSet("Safe","Conditional","All")] [string]$Tier="Safe", [switch]$Force)
$ErrorActionPreference="Continue"
$root="C:\Users\LENOVO\fortnite-rig-v2"
$ts=Get-Date -Format "yyyyMMdd-HHmmss"
$bak="$root\backups\$ts"
New-Item -ItemType Directory -Path $bak -Force | Out-Null
$log="$root\measurements\apply-$ts.log"
function L($m){ "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Tee-Object -FilePath $log -Append | Write-Host }
function HashFile($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash.Substring(0,12) } else { "MISSING" } }
L "=== APPLY Tier=$Tier ==="
L "Backup $bak Hash Engine $(HashFile "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini")"
# backup files
Copy-Item "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini" "$bak\Engine.ini.bak-$ts" -Force -ErrorAction SilentlyContinue; L "backup Engine"
Copy-Item "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\GameUserSettings.ini" "$bak\GameUserSettings.ini.bak-$ts" -Force -ErrorAction SilentlyContinue; L "backup GameUserSettings"
Copy-Item "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini" "$bak\Game.ini.bak-$ts" -Force -ErrorAction SilentlyContinue; L "backup Game.ini"
reg export "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "$bak\GraphicsDrivers.reg" /y 2>$null | Out-Null
reg export "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "$bak\Multimedia.reg" /y 2>$null | Out-Null
bcdedit /enum > "$bak\bcdedit-before.txt"
powercfg /getactivescheme > "$bak\power-before.txt"
# S6 fix NetworkThrottlingIndex drift 10 -> 4294967295
try{
  $mp="HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
  Set-ItemProperty $mp -Name SystemResponsiveness -Value 0 -Type DWord -Force
  $v=[uint32]4294967295; New-ItemProperty $mp -Name NetworkThrottlingIndex -Value $v -PropertyType DWord -Force | Out-Null
  $r=(Get-ItemProperty $mp).NetworkThrottlingIndex; L "S6 NetworkThrottlingIndex=$r SystemResponsiveness 0"
}catch{ L "S6 FAIL $_" }
# S7 DirectX
try{
  $p="HKCU:\Software\Microsoft\DirectX\UserGpuPreferences"
  $cur=(Get-ItemProperty $p -ErrorAction SilentlyContinue).DirectXUserGlobalSettings
  if($cur -notlike "*SwapEffectUpgradeEnable=1*"){
    Set-ItemProperty $p -Name DirectXUserGlobalSettings -Value "VRROptimizeEnable=1;SwapEffectUpgradeEnable=1;" -Type String -Force
    L "S7 DirectX -> VRROptimizeEnable=1;SwapEffectUpgradeEnable=1;"
  } else { L "S7 DirectX OK $cur" }
}catch{ L "S7 FAIL $_" }
# S8 core parking + disk idle
try{
  $plan="8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c"; $subCpu="54533251-82be-4824-96c1-47b60b740d00"
  powercfg /setacvalueindex $plan $subCpu 0cc5b647-c1df-4637-891a-dec35c318583 100 | Out-Null
  powercfg /setdcvalueindex $plan $subCpu 0cc5b647-c1df-4637-891a-dec35c318583 100 | Out-Null
  powercfg /setacvalueindex $plan $subCpu ea062031-0e34-4ff1-9b6d-eb1059334028 100 | Out-Null
  powercfg /setdcvalueindex $plan $subCpu ea062031-0e34-4ff1-9b6d-eb1059334028 100 | Out-Null
  powercfg /setacvalueindex $plan 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 | Out-Null
  powercfg /setdcvalueindex $plan 0012ee47-9041-4b5d-9b77-535fba8b1442 6738e2c4-e8a5-4a42-b16a-e040e769756e 0 | Out-Null
  powercfg /setactive $plan | Out-Null
  L "S8 Core parking 100 + DISKIDLE 0"
}catch{ L "S8 FAIL $_" }
# S9 QoS Policies persistent
try{
  $qosRoot="HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS"
  if(-not (Test-Path $qosRoot)){ New-Item $qosRoot -Force | Out-Null }
  $fort="$qosRoot\FortniteUDP-EF"; if(-not (Test-Path $fort)){ New-Item $fort -Force | Out-Null }
  Set-ItemProperty $fort -Name "Application Name" -Value "FortniteClient-Win64-Shipping.exe" -Force
  Set-ItemProperty $fort -Name "Protocol" -Value "UDP" -Force
  Set-ItemProperty $fort -Name "DSCP Value" -Value 46 -Force
  Set-ItemProperty $fort -Name "Version" -Value "1.0" -Force
  $a=Get-NetQosPolicy -Name "FortniteUDP-EF" -PolicyStore ActiveStore -ErrorAction SilentlyContinue
  if(-not $a){ New-NetQosPolicy -Name "FortniteUDP-EF" -AppPathNameMatchCondition "FortniteClient-Win64-Shipping.exe" -IPProtocolMatchCondition UDP -DSCPAction 46 -NetworkProfile All -PolicyStore ActiveStore -ErrorAction SilentlyContinue | Out-Null; L "S9 QoS ActiveStore created" } else { L "S9 QoS ActiveStore OK" }
  L "S9 QoS Policies DSCP 46"
}catch{ L "S9 FAIL $_" }
# S10 I219 offloads
try{
  $eth=Get-NetAdapter -Name "Ethernet" -ErrorAction SilentlyContinue
  if($eth){
    @(@{k="*PMARPOffload";v=0},@{k="*PMNSOffload";v=0},@{k="*LsoV2IPv4";v=0},@{k="*EEE";v=0}) | ForEach-Object {
      try{ Set-NetAdapterAdvancedProperty -Name "Ethernet" -RegistryKeyword $_.k -RegistryValue $_.v -NoRestart -ErrorAction SilentlyContinue | Out-Null }catch{}
    }
    L "S10 I219 offloads 0"
  }
}catch{ L "S10 FAIL $_" }
# GameDVR
try{
  Set-ItemProperty "HKCU:\System\GameConfigStore" -Name GameDVR_Enabled -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
  Set-ItemProperty "HKCU:\System\GameConfigStore" -Name GameDVR_FSEBehaviorMode -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
  $pol="HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; if(-not (Test-Path $pol)){ New-Item $pol -Force | Out-Null }
  Set-ItemProperty $pol -Name AllowGameDVR -Value 0 -Type DWord -Force
  L "S3 GameDVR/FSE2"
}catch{ L "S3 FAIL $_" }
# Fix TdrLevel 0 -> 3
try{
  $g="HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
  $lvl=(Get-ItemProperty $g -ErrorAction SilentlyContinue).TdrLevel
  if($lvl -eq 0){
    Set-ItemProperty $g -Name TdrLevel -Value 3 -Type DWord -Force
    Set-ItemProperty $g -Name TdrDelay -Value 8 -Type DWord -Force
    Set-ItemProperty $g -Name TdrDdiDelay -Value 8 -Type DWord -Force
    L "FIX TdrLevel 0 -> 3"
  } else { L "TdrLevel $lvl ok" }
}catch{ L "TDR FAIL $_" }
# bcdedit delete disabledynamictick
try{
  $b=bcdedit /enum | Out-String
  if($b -match "disabledynamictick\s+Yes"){
    bcdedit /deletevalue disabledynamictick 2>&1 | Out-Null
    L "FIX bcdedit disabledynamictick deleted"
  } else { L "bcdedit disabledynamictick absent ok" }
}catch{ L "bcdedit FAIL $_" }
# Engine overlay
if($Tier -in @("Safe","All")){
  try{
    $dst="$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\Engine.ini"
    $src="$root\configs\Engine.ini.overlay"
    $ov=Get-Content $src -Raw
    $cur=if(Test-Path $dst){ Get-Content $dst -Raw } else { "" }
    if($cur -notmatch "r.OneFrameThreadLag=0"){
      if($cur -notmatch "\[SystemSettings\]"){
        Add-Content $dst -Value "`n$ov" -Encoding UTF8
      } else {
        Add-Content $dst -Value "`n; Rig v2 overlay`n$ov" -Encoding UTF8
      }
      L "Engine overlay applied $(HashFile $dst)"
    } else { L "Engine overlay already present" }
  }catch{ L "Engine FAIL $_" }
  try{
    $dst="$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini"
    $want="-limitclientticks -USEALLAVAILABLECORES -PREFERREDPROCESSOR 0 -NOSPLASH"
    $dir=Split-Path $dst; if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $cur=if(Test-Path $dst){ Get-Content $dst -Raw } else { "" }
    if($cur -notmatch [regex]::Escape($want)){
      if($cur -match "\[Fortnite\]"){
        (Get-Content $dst) -replace 'AdditionalCommandLine=.*',"AdditionalCommandLine=$want" | Set-Content $dst -Encoding UTF8
        if((Get-Content $dst -Raw) -notmatch [regex]::Escape($want)){
          (Get-Content $dst) -replace '\[Fortnite\]',"[Fortnite]`nAdditionalCommandLine=$want" | Set-Content $dst -Encoding UTF8
        }
      } else {
        if($cur){ Add-Content $dst -Value "`n[Fortnite]`nAdditionalCommandLine=$want" -Encoding UTF8 } else { Set-Content $dst -Value "[Fortnite]`nAdditionalCommandLine=$want" -Encoding UTF8 }
      }
      L "Game.ini -> $want"
    } else { L "Game.ini OK" }
  }catch{ L "Game.ini FAIL $_" }
}
# Tier2
if($Tier -in @("Conditional","All")){
  L "--- Tier2 Conditional ---"
  try{
    $mc=(Get-MMAgent).MemoryCompression
    if($mc -eq $true){ Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue; L "C6 MemoryCompression disabled" } else { L "C6 MemoryCompression $mc" }
  }catch{ L "C6 FAIL $_" }
  L "C1 HZB/VRS in overlay commented - uncomment after bench"
  L "C4 Lasso at $root\configs\prolasso.ini"
}
# persist task
try{
  $taskName="FortniteRigV2-Persist"
  $exists=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  $action=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$root\scripts\persist.ps1`""
  $trig1=New-ScheduledTaskTrigger -AtLogOn
  $trig2=New-ScheduledTaskTrigger -AtStartup
  $prin=New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
  $set=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
  if($exists){ Set-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trig1,$trig2) -Principal $prin -Settings $set | Out-Null; L "Persist updated $taskName" }
  else { Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trig1,$trig2) -Principal $prin -Settings $set | Out-Null; L "Persist created $taskName" }
}catch{ L "Persist FAIL $_" }
L "=== APPLY DONE backup $bak ==="
