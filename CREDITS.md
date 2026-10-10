# Credits and provenance

This project is an adaptation of existing open-source work. The original loader and SOCKS wrapper were not created here.

## Code this project builds on

- **[runetfreedom/force-proxy](https://github.com/runetfreedom/force-proxy)** — original Winsock hooks, SOCKS5 transport, nonblocking socket tracking, and UDP code. Base snapshot: [`00ba992fc150f4ada7c4dccf7d2c49c9eab6ff83`](https://github.com/runetfreedom/force-proxy/tree/00ba992fc150f4ada7c4dccf7d2c49c9eab6ff83), GPL-3.0. Credit to **runetfreedom** for the original project and **m0nstrum** for the timeout/thread-safety contribution ([commit 1519e12](https://github.com/runetfreedom/force-proxy/commit/1519e12)).
- **[runetfreedom/discord-voice-proxy](https://github.com/runetfreedom/discord-voice-proxy)** — the DWrite forwarding/loader approach and assembly export stub. Base snapshot: [`ad909a68a5bc2691622b1ef9ec9b687ba9a65c04`](https://github.com/runetfreedom/discord-voice-proxy/tree/ad909a68a5bc2691622b1ef9ec9b687ba9a65c04), GPL-3.0. Credit to **runetfreedom**, **[Behnam Banaei / behnawwm](https://github.com/behnawwm)**, and the upstream contributors. The upstream Discord installer is not shipped in this project.
- **[pxlfall/vibecoded-discord-voice-proxy](https://github.com/pxlfall/vibecoded-discord-voice-proxy)** — the earlier local DNS-over-HTTPS adaptation, parser/cache, and experiments reused for this project. This project retains that adaptation's upstream provenance; it does not replace the upstream projects' authorship.

See the upstream [force-proxy contributors](https://github.com/runetfreedom/force-proxy/graphs/contributors) and [discord-voice-proxy contributors](https://github.com/runetfreedom/discord-voice-proxy/graphs/contributors). Original license texts remain in `licenses/`.

## Work added here

**pxlfall** provided project direction, the Clash/SignalRGB use case, and the Windows/Parallels test environment. **OpenAI Codex** assisted with implementation and debugging. This is explicitly a vibecoded personal experiment.

SignalRGB-specific changes include a loader without Discord command-line/update hooks; Qt WebEngine proxy settings; native WSAConnect and dual-stack handling; complete SOCKS response framing; Chromium network-thread isolation; direct LAN/device discovery; the readiness/backup/restore wrapper; and this Inno Setup installer. Neither physical-PC compatibility nor long-term stability is established by the VM tests.

## Dependencies and build tools

- **[Microsoft Detours](https://github.com/microsoft/Detours)** and its contributors — function interception; MIT license in `licenses/dependencies/detours.txt`.
- **[curl / libcurl](https://curl.se/)**, **Daniel Stenberg**, and the curl contributors — DoH HTTPS transport; curl license in `licenses/dependencies/curl.txt`.
- **[zlib](https://zlib.net/)**, **Jean-loup Gailly**, **Mark Adler**, and contributors — libcurl dependency; license in `licenses/dependencies/zlib.txt`.
- **[vcpkg](https://github.com/microsoft/vcpkg)**, Microsoft, and contributors — dependency builds; retained vcpkg helper notices in `licenses/dependencies/`.
- **[Inno Setup](https://jrsoftware.org/)**, **Jordan Russell**, **Martijn Laan**, and contributors — executable installer and uninstaller; its distribution license is included in `licenses/dependencies/inno-setup.txt`.
- **[CMake](https://cmake.org/)**, Kitware, and contributors; **Microsoft Visual Studio / Windows SDK / PowerShell** — build and Windows platform tools. These products are not redistributed as part of the release.
- **Free Software Foundation** — GNU GPL version 3 license text. The combined project is distributed under GPL-3.0.

## Ecosystem acknowledgments

**SignalRGB / Whirlwind FX**, **Qt / Qt WebEngine / Chromium**, **Clash Verge Rev**, **Mihomo / MetaCubeX**, and **Cloudflare DNS-over-HTTPS** provide the application, networking ecosystem, or services used in testing. Their products and branding are not owned by this project. This project is unaffiliated with and not endorsed by any of them.

The source tree and release archives contain our adaptation and required notices, not SignalRGB executables, proxy subscriptions, credentials, or private test logs.
