$ErrorActionPreference='Stop'
$workspace=Split-Path $PSScriptRoot -Parent
if (Test-Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{1A783A09-88B4-4D6F-B97F-584EA5A6E2E9}_is1') { throw 'Run installer fixture tests in a disposable Windows environment without this installer registered.' }
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$test=Join-Path $env:TEMP "SignalRGBProxy-installer-test-$stamp"
$root="$test\Signal-$([char]0x6d4b)$([char]0x8bd5)"
$app="$root\app-test\Signal-x64"
$package="$test\package"
New-Item -ItemType Directory -Force $app | Out-Null
Set-Content "$root\SignalRgbLauncher.exe" 'fixture'
Set-Content "$app\SignalRgb.exe" 'fixture'
Set-Content "$app\DWrite.dll" 'original fixture DLL'
$original=(Get-FileHash "$app\DWrite.dll").Hash
$installer="$workspace\release\SignalRGBProxyInstaller-v0.1.1-win-x64.exe"
$arguments=@('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=`"$package`"","/SIGNALROOT=`"$root`"",'/PROXYADDRESS=127.0.0.1','/PROXYPORT=17897',"/LOG=`"$test\install.log`"")
$p=Start-Process $installer -ArgumentList $arguments -Wait -PassThru
if ($p.ExitCode) { throw "Installer failed: $($p.ExitCode), log: $test\install.log" }
if ((Get-FileHash "$app\force-proxy.dll").Hash -ne (Get-FileHash "$workspace\payload\force-proxy.dll").Hash) { throw 'Payload hash mismatch.' }
if ((Get-Content "$package\signal-installation.txt" -Raw).Trim() -ne $root) { throw 'Unicode installation path was not preserved.' }
if (!(Select-String -Path "$app\proxy.txt" -Pattern '^SOCKS5_PROXY_PORT=17897$' -Quiet)) { throw 'Selected proxy port not installed.' }
if (!(Test-Path "$package\task-action.txt")) { throw 'Exact task action missing.' }
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$package\SignalRGBProxy.ps1" -Action Start -WaitSeconds 1
if ($LASTEXITCODE -ne 2) { throw 'Unavailable SOCKS proxy did not prevent launch.' }
$p=Start-Process "$package\unins000.exe" -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
if ($p.ExitCode) { throw "Uninstaller failed: $($p.ExitCode)" }
if ((Get-FileHash "$app\DWrite.dll").Hash -ne $original) { throw 'Original DLL not restored.' }
if ((Test-Path "$app\force-proxy.dll") -or (Test-Path "$app\proxy.txt")) { throw 'Added patch files not removed.' }
$p=Start-Process $installer -ArgumentList $arguments -Wait -PassThru
if ($p.ExitCode) { throw 'Reinstallation failed.' }
$p=Start-Process "$package\unins000.exe" -ArgumentList '/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART' -Wait -PassThru
if ($p.ExitCode) { throw 'Second uninstall failed.' }
Write-Output 'PASS: exe installs matching payload, preserves Unicode/custom path, applies selected port, stops unavailable-proxy launch, restores original files, and reinstalls.'
