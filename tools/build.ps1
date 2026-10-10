param(
    [string]$VcpkgRoot=$env:VCPKG_ROOT,
    [string]$CMake='cmake',
    [string]$InnoCompiler='C:\Program Files (x86)\Inno Setup 6\ISCC.exe',
    [switch]$InstallerOnly,
    [string]$InstalledDependencies=''
)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
if (!$InstallerOnly) {
    if (!(Test-Path "$VcpkgRoot\scripts\buildsystems\vcpkg.cmake")) { throw 'Set -VcpkgRoot to an initialized vcpkg checkout.' }
    $arguments=@('-S',$root,'-B',"$root\build",'-G','Visual Studio 17 2022','-A','x64',"-DCMAKE_TOOLCHAIN_FILE=$VcpkgRoot\scripts\buildsystems\vcpkg.cmake",'-DVCPKG_TARGET_TRIPLET=x64-windows-static','-DVCPKG_HOST_TRIPLET=x64-windows-static','-DSIGNAL_PROXY_BUILD_PROBE=ON')
    if ($InstalledDependencies) { $arguments+=@("-DVCPKG_INSTALLED_DIR=$InstalledDependencies",'-DVCPKG_MANIFEST_INSTALL=OFF',"-DCMAKE_PREFIX_PATH=$InstalledDependencies\x64-windows-static") }
    & $CMake @arguments
    if ($LASTEXITCODE) { throw 'CMake configure failed.' }
    & $CMake --build "$root\build" --config Release --parallel 4
    if ($LASTEXITCODE) { throw 'CMake build failed.' }
    New-Item -ItemType Directory -Force "$root\payload" | Out-Null
    Copy-Item "$root\build\payload\Release\DWrite.dll","$root\build\payload\Release\force-proxy.dll" "$root\payload" -Force
}
if (!(Test-Path $InnoCompiler)) { throw 'Pass -InnoCompiler with the path to ISCC.exe.' }
& $InnoCompiler "$root\installer\SignalRGBProxy.iss"
if ($LASTEXITCODE) { throw 'Installer compilation failed.' }
Get-FileHash "$root\release\SignalRGBProxyInstaller-v0.1-win-x64.exe" -Algorithm SHA256
