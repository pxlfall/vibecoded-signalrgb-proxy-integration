# v0.1.1 validation

Environment: Windows 11 ARM under Parallels; SignalRGB 2.5.78 x64 under emulation; Clash SOCKS5 at 127.0.0.1:7897, TUN off. Physical Windows PC and RGB hardware have not been tested for this integration.

## Marketplace regression and correction

The v0.1 startup/catalog checks missed broken marketplace artwork. The embedded browser reported `net::ERR_CONNECTION_RESET` for `imagedelivery.net`; the exact image returned HTTP 200 and 55,230 bytes through either Clash SOCKS5 or its HTTP listener, while a direct request reset. Chromium proxy flags alone did not cover Qt WebEngine's proxy configuration service.

v0.1.1 intercepts `QNetworkProxy::applicationProxy()` and `QNetworkProxyFactory::usesSystemConfiguration()` only when called from `Qt6WebEngineCore.dll`. Qt's own exports construct and mutate the returned SOCKS5 proxy. Native Qt callers retain their prior proxy configuration; Chromium's asynchronous network threads still bypass the native socket/DNS hooks. Required modules and exports must already be present. This was tested with the bundled Qt 6.12.0 MSVC x64 ABI.

The corrected VM run visibly rendered Discover marketplace cards and bundle artwork. Clash attributed a SOCKS5 connection for `imagedelivery.net` to `SignalRgb.exe`, inbound 127.0.0.1:7897, with 40,756 downloaded bytes in the captured sample. TUN was disabled. The four native transport probe cases passed after the change. No SignalRGB Windows crash event was recorded during an observation exceeding three minutes. Diagnostic remote debugging was temporary and restricted to VM loopback.

## Native payload

Clash's controller attributed SOCKS5 connections to SignalRgb.exe on port 7897, with recovered domains, the selected outbound chain, and nonzero byte counters. Examples included catalog.signalrgb.com, services.signalrgb.com, signalrgbmarketplace.pages.dev, and Cloudflare Insights. The final sample contained two catalog connections with approximately 21 KB and 42 KB downloaded.

SignalRGB fetched the effect catalog and entered Running. The final native build recorded no crash during a three-minute observation. Earlier builds exposed a Chromium NetworkService crash/restart; the supplied native build bypasses native socket/DNS handling on NetworkService and Chrome IO threads, which use the separate Qt WebEngine SOCKS setting in the corrected v0.1.1 build.

Timing from the native application logs: unpatched Booting after approximately 39 seconds with cloud failure; first adapted fresh cloud configuration success at approximately 10 seconds; final cached network stage approximately 6 seconds. Final total application startup was approximately 64 seconds including addon work. These comparisons do not establish full startup speed, long-term stability, or overhead.

A local fake SOCKS server sent greetings, domain-address CONNECT replies, and application data one byte at a time. Blocking IPv4 connect, nonblocking IPv4 WSAConnect, IPv4-mapped IPv6 WSAConnect, and dual-stack IPv6 WSAConnect passed framing and PING/PONG checks.

The PowerShell management script was tested for backup/restoration of an original DLL, removal of newly added patch files, reinstall, and refusal to launch when SOCKS5 was unavailable. An elevated interactive scheduled task returned 0 and SignalRGB recorded Admin Status: True. The temporary task was removed after testing.

## Executable installer

Inno Setup 6.7.3 compiled the installer. Isolated install/uninstall tests verified the embedded payload hashes, a custom SignalRGB root containing Unicode characters, the selected proxy port, generation of the exact task action, refusal to launch when SOCKS5 was absent, restoration of an existing original DLL, removal of newly added files, and successful reinstall/uninstall. The fixture contained dummy application files; those checks do not establish physical hardware behavior.

## Coverage

Some public IPv6 traffic remained direct. UDP, dedicated IPv6-only sockets to an IPv4 proxy, unhooked networking APIs, and separate service processes are not completely covered. Authentication, automatic update survival, physical-PC behavior, and long-term stability are unverified. VM GPU/audio/driver warnings remain.

The public repository and release source omit SignalRGB executables, private raw logs, subscriptions, and credentials.
