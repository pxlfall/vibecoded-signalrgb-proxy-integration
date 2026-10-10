param(
    [ValidateSet('Start','Install','Uninstall')][string]$Action = 'Start',
    [string]$SignalRoot = "$env:LOCALAPPDATA\VortxEngine",
    [ValidateRange(1,600)][int]$WaitSeconds = 90
)
$ErrorActionPreference = 'Stop'
if (!$PSBoundParameters.ContainsKey('SignalRoot') -and (Test-Path "$PSScriptRoot\signal-installation.txt")) {
    $SignalRoot = (Get-Content "$PSScriptRoot\signal-installation.txt" -Raw).Trim()
}
$state = "$env:LOCALAPPDATA\SignalRGBProxy"
New-Item -ItemType Directory -Force $state | Out-Null
function Log([string]$message) {
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $message"
    Add-Content "$state\launcher.log" $line
    Write-Output $line
}
function Stop-Signal {
    $processes = @(Get-Process SignalRgb,SignalRgbLauncher,SignalRgbSplash,QtWebEngineProcess -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$SignalRoot\*" })
    foreach ($process in $processes) {
        Stop-Process -Id $process.Id -Force
        $null = $process.WaitForExit(5000)
    }
}
function Hash([string]$path) { (Get-FileHash $path -Algorithm SHA256).Hash }
function Directories {
    @(Get-ChildItem $SignalRoot -Directory -Filter 'app-*' | ForEach-Object {
        $path = Join-Path $_.FullName 'Signal-x64'
        if (Test-Path "$path\SignalRgb.exe") { $path }
    })
}
if ($Action -eq 'Uninstall' -and !(Test-Path $SignalRoot)) { Log 'SignalRGB installation already removed.'; exit 0 }
if ($Action -ne 'Uninstall' -and !(Test-Path "$SignalRoot\SignalRgbLauncher.exe")) { throw "SignalRGB launcher not found at $SignalRoot" }
$names = @('DWrite.dll','force-proxy.dll','proxy.txt')
$directories = Directories
if (!$directories.Count) {
    if ($Action -eq 'Uninstall') { Log 'No remaining SignalRGB application folders to restore.'; exit 0 }
    throw 'No SignalRGB x64 installation found.'
}
if ($Action -eq 'Uninstall') {
    Stop-Signal
    foreach ($directory in $directories) {
        $backup = "$directory\signalrgb-proxy-backup"
        $manifest = "$backup\manifest.json"
        if (!(Test-Path $manifest)) { continue }
        $entries = Get-Content $manifest -Raw | ConvertFrom-Json
        foreach ($entry in $entries) {
            $target = "$directory\$($entry.Name)"
            if ((Test-Path $target) -and $entry.Name -ne 'proxy.txt' -and (Hash $target) -ne $entry.InstalledHash) {
                throw "File changed since installation: $target. Preserving it; uninstall stopped."
            }
            if ($entry.Existed -and !(Test-Path "$backup\$($entry.Name)")) { throw "Original backup missing: $($entry.Name)" }
        }
        # Preserve removed patch files as well as the original files.
        $removed = "$backup\removed-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        New-Item -ItemType Directory -Force $removed | Out-Null
        foreach ($entry in $entries) {
            $target = "$directory\$($entry.Name)"
            if (Test-Path $target) {
                Move-Item $target "$removed\$($entry.Name)"
            }
            if ($entry.Existed) { Copy-Item "$backup\$($entry.Name)" $target }
        }
        Move-Item $manifest "$removed\manifest.json"
        Move-Item $backup "$backup-restored-$(Get-Date -Format 'yyyyMMdd-HHmmss-fff')"
        Log "Restored original files in $directory"
    }
    exit 0
}
foreach ($name in $names) { if (!(Test-Path "$PSScriptRoot\$name")) { throw "Package file missing: $name" } }
if ($Action -eq 'Install') { Stop-Signal }
if ($Action -eq 'Start' -and (Get-Process SignalRgb -ErrorAction SilentlyContinue | Where-Object Path -like "$SignalRoot\*")) {
    Log 'SignalRGB is already running. Quit it before applying an updated package.'
    exit 0
}
foreach ($directory in $directories) {
    $backup = "$directory\signalrgb-proxy-backup"
    $manifest = "$backup\manifest.json"
    if (Test-Path $manifest) {
        $entries = Get-Content $manifest -Raw | ConvertFrom-Json
        foreach ($entry in $entries) {
            $target = "$directory\$($entry.Name)"
            if ((Test-Path $target) -and $entry.Name -ne 'proxy.txt' -and
                (Hash $target) -ne $entry.InstalledHash -and (Hash $target) -ne (Hash "$PSScriptRoot\$($entry.Name)")) {
                throw "Refusing to overwrite a changed file: $target"
            }
        }
    } else {
        if (Test-Path $backup) { throw "Untracked backup folder exists: $backup" }
        New-Item -ItemType Directory $backup | Out-Null
        $entries = @()
        foreach ($name in $names) {
            $exists = Test-Path "$directory\$name"
            if ($exists) { Copy-Item "$directory\$name" "$backup\$name" }
            $entries += [pscustomobject]@{Name=$name;Existed=$exists;InstalledHash=(Hash "$PSScriptRoot\$name")}
        }
        $entries | ConvertTo-Json | Set-Content $manifest -Encoding UTF8
    }
    foreach ($name in $names) {
        $target = "$directory\$name"
        $newHash = Hash "$PSScriptRoot\$name"
        if (!(Test-Path $target) -or (Hash $target) -ne $newHash) { Copy-Item "$PSScriptRoot\$name" $target -Force }
        ($entries | Where-Object Name -eq $name).InstalledHash = $newHash
    }
    $entries | ConvertTo-Json | Set-Content $manifest -Encoding UTF8
    Log "Proxy ready in $directory"
}
if ($Action -eq 'Install') { Log 'Installed. Run Start.cmd or use the scheduled task action in README.'; exit 0 }
$settings = @{}
Get-Content "$PSScriptRoot\proxy.txt" | ForEach-Object {
    if ($_ -match '^([A-Z0-9_]+)=(.*)$') { $settings[$matches[1]]=$matches[2] }
}
$proxyAddress = $settings.SOCKS5_PROXY_ADDRESS
$proxyPort = [int]$settings.SOCKS5_PROXY_PORT
$parsedIP = $null
if (![Net.IPAddress]::TryParse($proxyAddress,[ref]$parsedIP) -or
    $parsedIP.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork -or
    $proxyPort -lt 1 -or $proxyPort -gt 65535) { throw 'Proxy endpoint must be a numeric IPv4 address and valid port in proxy.txt.' }
function Proxy-Ready {
    $client = [Net.Sockets.TcpClient]::new()
    try {
        if (!$client.ConnectAsync($proxyAddress,$proxyPort).Wait(1500)) { return $false }
        $stream = $client.GetStream()
        $stream.ReadTimeout=1500; $stream.WriteTimeout=1500
        $hello = [byte[]](5,1,0)
        $stream.Write($hello,0,3)
        # Read exactly two bytes; TCP may split the SOCKS greeting response.
        $version=$stream.ReadByte(); $method=$stream.ReadByte()
        return $version -eq 5 -and $method -eq 0
    } catch { return $false } finally { $client.Dispose() }
}
$deadline = (Get-Date).AddSeconds($WaitSeconds)
while (!(Proxy-Ready)) {
    if ((Get-Date) -ge $deadline) { Log "SOCKS5 proxy $proxyAddress`:$proxyPort unavailable; SignalRGB was not started."; exit 2 }
    Start-Sleep -Milliseconds 1000
}
Log "SOCKS5 proxy $proxyAddress`:$proxyPort ready; starting SignalRGB."
Start-Process "$SignalRoot\SignalRgbLauncher.exe" -WorkingDirectory $SignalRoot
