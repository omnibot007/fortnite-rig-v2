#Requires -RunAsAdministrator
# Fortnite Rig v2 — revert.ps1
# Restores last backup or specified timestamp. No secrets echoed.
param([string]$BackupDir)

$root="C:\Users\LENOVO\fortnite-rig-v2"
if(-not $BackupDir){
  $BackupDir=Get-ChildItem "$root\backups" -Directory | Sort LastWriteTime -Descending | Select -First 1 -ExpandProperty FullName
  if(-not $BackupDir){ Write-Host "No backups found"; exit 1 }
}
Write-Host "Revert from $BackupDir" -ForegroundColor Cyan

# Files
@("Engine.ini","GameUserSettings.ini") | ForEach-Object {
  $b=Get-ChildItem "$BackupDir" -Filter "$_.bak-*" | Select -First 1
  if($b){ Copy-Item $b.FullName "$env:LOCALAPPDATA\FortniteGame\Saved\Config\WindowsClient\$_" -Force; Write-Host "Restored $_" -ForegroundColor Green }
}
$giBak=Get-ChildItem "$BackupDir" -Filter "Game.ini.bak-*" | Select -First 1
if($giBak){ Copy-Item $giBak.FullName "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini" -Force; Write-Host "Restored Game.ini" -ForegroundColor Green }
else { Remove-Item "$env:LOCALAPPDATA\EpicGamesLauncher\Saved\Config\Windows\Game.ini" -Force -ErrorAction SilentlyContinue; Write-Host "Removed Game.ini (no backup)" }

# Registry via .reg imports
Get-ChildItem "$BackupDir" -Filter "*.reg" | ForEach-Object { reg import $_.FullName 2>&1 | Out-Null; Write-Host "Imported $($_.Name)" }

# bcdedit + power
if(Test-Path "$BackupDir\bcdedit-before.txt"){ Write-Host "bcdedit backup at $BackupDir\bcdedit-before.txt — manual compare, no auto import (requires reboot)" -ForegroundColor Yellow }
if(Test-Path "$BackupDir\power-before.txt"){ $g=(Get-Content "$BackupDir\power-before.txt" | Select-String "([a-f0-9-]{36})").Matches[0].Value; if($g){ powercfg /setactive $g; Write-Host "Power restored $g" } }

# QoS + Tasks
Remove-NetQosPolicy -Name "FortniteUDP-EF" -PolicyStore ActiveStore -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item "HKLM:\SOFTWARE\Policies\Microsoft\Windows\QoS\FortniteUDP-EF" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Removed QoS FortniteUDP-EF (both stores)"

Unregister-ScheduledTask -TaskName "FortniteRigV2-Persist" -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "Removed FortniteRigV2-Persist"
Write-Host "Note: Outside-box tasks FortniteAffinityWatcher/FortniteOutsideBox-Persist still exist — remove manually if unwanted: Unregister-ScheduledTask FortniteAffinityWatcher" -ForegroundColor Yellow

Write-Host "Revert done — reboot recommended" -ForegroundColor Cyan
