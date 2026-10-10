# Vibecoded SignalRGB Proxy Integration

A personal, experimental SignalRGB startup workaround for Clash/SOCKS5. Built on [runetfreedom/force-proxy](https://github.com/runetfreedom/force-proxy), [runetfreedom/discord-voice-proxy](https://github.com/runetfreedom/discord-voice-proxy), and the earlier [vibecoded Discord adaptation](https://github.com/pxlfall/vibecoded-discord-voice-proxy). **The original loader and proxy work belong to their upstream authors.** See [full credits and provenance](CREDITS.md).

Implemented and debugged with OpenAI Codex assistance, with project direction and VM testing by pxlfall. This is not an official SignalRGB or Clash product.

## Download and install

1. Download **SignalRGBProxyInstaller-v0.1.1-win-x64.exe** from [Release v0.1.1](https://github.com/pxlfall/vibecoded-signalrgb-proxy-integration/releases/tag/v0.1.1).
2. Start Clash with an unauthenticated SOCKS5/mixed listener at **127.0.0.1:7897**, or use your own numeric IPv4 address and port.
3. Run the installer as your normal Windows user and approve its administrator prompt. Select your **VortxEngine** folder; the default is `%LOCALAPPDATA%\VortxEngine`. The installer stops SignalRGB processes in that folder.
4. Select the proxy address/port and finish setup. You can launch the official **SignalRgbLauncher.exe** directly. The optional **Start SignalRGB** entry also checks proxy readiness and reapplies the package to existing app folders.

This release contains x64 DLLs. It was tested with SignalRGB 2.5.78 on Windows 11 ARM in Parallels running the x64 application under emulation. Native ARM64 SignalRGB binaries are unsupported. The installer is unsigned.

Setup defaults to `C:\Program Files\SignalRGBProxy`. `proxy.txt` in that folder is the configuration source; the wrapper copies it into SignalRGB on each launch. If you change settings, edit the file as administrator, quit SignalRGB, and launch the wrapper again.

## Launch SignalRGB directly

After installation, opening `VortxEngine\SignalRgbLauncher.exe` starts SignalRGB with the proxy already applied. Clash must already be ready. The launcher/updater itself is not proxied.

To change proxy settings, edit the installed package's `proxy.txt`, quit SignalRGB, and run **Start SignalRGB** once to apply them. After a SignalRGB update creates a new app folder, run **Start SignalRGB** again to reapply the patch.

## How to auto-run SignalRGB with administrator privileges

The installer does not create a scheduled task. To start SignalRGB automatically when you sign in:

1. Open **Task Scheduler** from the Windows Start menu and select **Create Task**.
2. On **General**, name it **SignalRGB Proxy Startup**, select your Windows account, choose **Run only when user is logged on**, and enable **Run with highest privileges**.
3. On **Triggers**, select **New**, choose **At log on** for your account, and leave the trigger enabled.
4. On **Actions**, select **New** and choose **Start a program**. Fill in the fields below.

**Program/script:**

```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

**Add arguments:**

```text
-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Program Files\SignalRGBProxy\SignalRGBProxy.ps1" -Action Start
```

**Start in:**

```text
C:\Program Files\SignalRGBProxy
```

If you installed the package elsewhere, use that folder in **Add arguments** and **Start in**. The installer also saves these details in `task-action.txt` in its installation folder.

5. On laptops, open **Conditions** and clear **Start the task only if the computer is on AC power** if you want it to start on battery too.
6. Save the task. Right-click it and choose **Run** to check that SignalRGB opens.

This task runs the wrapper, which reapplies the patch to existing app folders and starts the official launcher with administrator privileges. If Clash is ready, it proceeds immediately. Otherwise, it retries the local SOCKS5 check once per second for up to about 90 seconds. No fixed startup delay is needed. Clash should also start when you sign in.

If SignalRGB's separate automatic startup is enabled, disable it so this task controls startup.

## Uninstall and updates

Use Windows **Installed apps → SignalRGB Proxy Integration → Uninstall**. The uninstaller first restores the original SignalRGB files using the backup manifest. If a DLL changed independently, it stops instead of overwriting that change. Added files and original backups are archived in the SignalRGB app folder for recovery.

The patch backs up `DWrite.dll`, `force-proxy.dll`, and `proxy.txt` in `signalrgb-proxy-backup` within each `app-*\Signal-x64` folder. Next wrapper launch applies the package to existing app folders after an update. Updating while SignalRGB is running, newly created folders during the launcher's own update, and automatic update compatibility beyond 2.5.78 have not been verified; quit and rerun the wrapper if needed.

## What it does

- Intercepts native `connect`/ordinary `WSAConnect` TCP paths, including Qt dual-stack IPv4-mapped sockets, and sends them through SOCKS5.
- Supplies Qt WebEngine's own SOCKS setting by intercepting proxy queries from its module, using the application's Qt exports. Chromium NetworkService/Chrome IO threads bypass the native socket/DNS hooks to preserve their asynchronous behavior.
- Intercepted native DNS uses Cloudflare `https://1.1.1.1/dns-query` through SOCKS5, with TLS validation and a bounded TTL cache of IPv4 answers.
- Keeps loopback, private LAN traffic, and UDP device discovery direct.
- Checks proxy readiness and preserves original files for rollback.

Logs: `%LOCALAPPDATA%\SignalRGBProxy\launcher.log` and `dns.log`. Set `SOCKS5_DNS_LOG=0` in the installed package's `proxy.txt` to disable domain diagnostics. No global system proxy or global environment variables are changed.

## Validation and limits

v0.1 had a marketplace regression: catalog text loaded while artwork failed because the embedded browser still connected directly. **v0.1.1 fixes that path.** The VM now renders marketplace artwork, and Clash attributes `imagedelivery.net` SOCKS5 transfers to `SignalRgb.exe` with TUN disabled.

The VM showed process-attributed **SignalRgb.exe → Socks5 → 127.0.0.1:7897**, nonzero transfer counters, successful catalog downloads, and **Running** with Clash TUN disabled. The corrected native build stayed free of recorded crashes during an observation exceeding three minutes. See [validation notes](docs/VALIDATION.md).

An earlier unpatched run reached Booting after about 39 seconds with a cloud error. The first adapted run fetched fresh cloud configuration in about 10 seconds. Final cached network stage: about 6 seconds. Final total app startup: about 64 seconds including addons. These are different measurements; this is not a claim that the whole app starts in 6 seconds.

**This is not complete traffic enforcement.** Some public IPv6 traffic still went direct. UDP, unhooked Windows networking APIs, separate services, and dedicated IPv6-only sockets are outside full coverage. The browser hook depends on the Qt 6 MSVC x64 ABI and was tested against the bundled Qt 6.12.0. If its required modules or exports are absent, it does not attach; this does not guarantee browser proxy coverage on other versions. Proxy authentication is unsupported. Physical RGB hardware, physical-PC behavior, update survival, overhead, and long-term stability remain unverified. VM audio/GPU/driver warnings remain.

## Build, source, and credits

The repository contains the loader, native hooks, wrapper, installer source, tests, and original/dependency notices. Follow [BUILD.md](BUILD.md). The release includes a matching source archive and SHA-256 checksums. The combined project is **GPL-3.0**; dependency components retain their respective licenses. See [LICENSE](LICENSE), [CREDITS.md](CREDITS.md), and [licenses](licenses/).
