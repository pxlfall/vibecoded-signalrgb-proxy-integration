param(
    [string]$ProbePath=(Join-Path $PSScriptRoot "..\build\Release\SignalProxyTransportProbe.exe"),
    [string]$ProxyDllPath=(Join-Path $PSScriptRoot "..\payload\force-proxy.dll")
)
$ErrorActionPreference='Stop'
$ready=Join-Path $env:TEMP ('SignalRGBProxy-probe-'+[guid]::NewGuid().ToString()+'.txt')
Remove-Item $ready -ErrorAction SilentlyContinue
$server=Start-Job -ArgumentList $ready -ScriptBlock {
    param($ready)
    $ErrorActionPreference='Stop'
    function Read-Exactly($stream,$count) {
        $bytes=New-Object byte[] $count
        $offset=0
        while ($offset -lt $count) { $n=$stream.Read($bytes,$offset,$count-$offset); if (!$n) { throw 'Unexpected EOF' }; $offset+=$n }
        return ,$bytes
    }
    function Write-Split($stream,[byte[]]$bytes) {
        foreach ($value in $bytes) { $stream.WriteByte($value); $stream.Flush(); Start-Sleep -Milliseconds 20 }
    }
    $listener=[Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback,17997)
    try {
        $listener.Start(); Set-Content $ready 'ready'
        for ($i=0;$i -lt 4;$i++) {
            $client=$listener.AcceptTcpClient(); $stream=$client.GetStream(); $stream.ReadTimeout=5000
            try {
                $hello=Read-Exactly $stream 3
                if ($hello[0] -ne 5) { throw 'Bad hello' }
                Write-Split $stream ([byte[]](5,0))
                $header=Read-Exactly $stream 4
                $body=Read-Exactly $stream $(if ($header[3] -eq 1) {6} elseif ($header[3] -eq 4) {18} else {throw 'Bad request'})
                Write-Split $stream ([byte[]](5,0,0,3,3,118,109,120,0,0))
                $request=Read-Exactly $stream 4
                if ([Text.Encoding]::ASCII.GetString($request) -ne 'PING') { throw 'Framing corrupted application data' }
                Write-Split $stream ([Text.Encoding]::ASCII.GetBytes('PONG'))
            } finally { $client.Dispose() }
        }
    } finally { $listener.Stop() }
}
try {
    $deadline=(Get-Date).AddSeconds(10)
    while (!(Test-Path $ready)) { if ((Get-Date) -gt $deadline) { throw 'Probe listener did not start.' }; Start-Sleep -Milliseconds 100 }
    & $ProbePath $ProxyDllPath
    if ($LASTEXITCODE) { throw "Transport probe failed: $LASTEXITCODE" }
    $null=Wait-Job $server -Timeout 10
    Receive-Job $server -ErrorAction Stop
    if ($server.State -ne 'Completed') { throw "Server state: $($server.State)" }
} finally { Stop-Job $server -ErrorAction SilentlyContinue; Remove-Job $server -Force }
