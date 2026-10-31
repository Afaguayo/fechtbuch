# Builds dist\BattleEyeInstaller.exe and dist\BattleEye-mod.zip.
#   powershell -ExecutionPolicy Bypass -File installer\build.ps1 [-UE4SSZip path\to\UE4SS_v*.zip]
# Without -UE4SSZip the latest UE4SS experimental build is downloaded from GitHub.
param([string]$UE4SSZip)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root  = Split-Path $PSScriptRoot -Parent
$dist  = Join-Path $root 'dist'
$work  = Join-Path $dist 'work'
New-Item -ItemType Directory -Force $work | Out-Null

# Mod zip (contains the BattleEye folder; never your settings/stats files)
$modZip = Join-Path $work 'BattleEye.zip'
if (Test-Path $modZip) { Remove-Item $modZip }
$stage = Join-Path $work 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $stage 'BattleEye\Scripts') | Out-Null
Copy-Item (Join-Path $root 'BattleEye\Scripts\main.lua') (Join-Path $stage 'BattleEye\Scripts')
Copy-Item (Join-Path $root 'BattleEye\overlay.ps1'), (Join-Path $root 'BattleEye\enabled.txt') (Join-Path $stage 'BattleEye')
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $modZip)

# UE4SS zip
$ue4ss = Join-Path $work 'ue4ss.zip'
if ($UE4SSZip) { Copy-Item $UE4SSZip $ue4ss -Force }
else {
    $rel = Invoke-RestMethod 'https://api.github.com/repos/UE4SS-RE/RE-UE4SS/releases/tags/experimental-latest'
    $asset = $rel.assets | Where-Object { $_.name -match '^UE4SS_v.*\.zip$' } | Select-Object -First 1
    Write-Host "Downloading $($asset.name)"
    Invoke-WebRequest $asset.browser_download_url -OutFile $ue4ss
}

# Compile
$fw  = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
$exe = Join-Path $dist 'BattleEyeInstaller.exe'
& "$fw\csc.exe" /nologo /target:exe /optimize /out:$exe `
    /r:"$fw\System.IO.Compression.dll" /r:"$fw\System.IO.Compression.FileSystem.dll" `
    /resource:"$modZip,BattleEye.zip" /resource:"$ue4ss,ue4ss.zip" `
    (Join-Path $PSScriptRoot 'Installer.cs')
if ($LASTEXITCODE -ne 0) { throw "csc failed" }

Copy-Item $modZip (Join-Path $dist 'BattleEye-mod.zip') -Force
Remove-Item $work -Recurse -Force
Write-Host "Built $exe"
