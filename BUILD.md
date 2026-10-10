# Build v0.1.1

Use Windows with Visual Studio 2022 C++/MASM tools, a Windows SDK, CMake 3.24+, Python 3, vcpkg, and Inno Setup 6.7.3. See the [official Inno Setup download](https://jrsoftware.org/isdl.php). The pinned vcpkg baseline installs Detours and libcurl with Windows SSL using the static x64 triplet.

```powershell
git clone https://github.com/pxlfall/vibecoded-signalrgb-proxy-integration.git
cd vibecoded-signalrgb-proxy-integration
.\tools\build.ps1 -VcpkgRoot C:\path\to\vcpkg
```

Run from a Visual Studio developer shell. Supply `-CMake` or `-InnoCompiler` if those tools are not at their default locations. Outputs:

- `build\payload\Release\DWrite.dll` and `force-proxy.dll`
- `payload\` copies for installer packaging (ignored by Git)
- `release\SignalRGBProxyInstaller-v0.1.1-win-x64.exe`

To compile the installer only from an already built payload:

```powershell
.\tools\build.ps1 -InstallerOnly -InnoCompiler 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'
```

No SignalRGB binaries, proxy credentials, or personal test logs are required for the source build. The release installer embeds the DLLs, scripts, docs, credits, and license notices. It requires administrator privileges to modify an installation that may be running elevated. The default package directory is Program Files; SignalRGB itself remains in the selected VortxEngine folder.

The DLL transport probe is built as `build\Release\SignalProxyTransportProbe.exe`. See `tests/transport_probe.cpp`. Run it with a local SOCKS test listener on port 17997; the test deliberately expects split greeting/CONNECT frames and PING/PONG payloads. `tools/test-transport.ps1` supplies that listener.

The release source archive is generated from the tagged repository with `git archive`, so the distributed source matches the release tag. `tools/release-assets.py` creates the portable archive and checksums from the local payload. Build tools are not redistributed; runtime dependency and installer-engine notices are retained in `licenses/dependencies/`.
