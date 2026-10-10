#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <fstream>
#include <string>

// Adapted from runetfreedom/discord-voice-proxy (GPL-3.0).
// SignalRGB parses its own command line: Chromium flags belong in the Qt
// environment, not in GetCommandLineW. Paths are relative to this module.
extern "C" uintptr_t OrignalDWriteCreateFactory = 0;
namespace {
HMODULE original;
std::wstring Directory(HMODULE module) {
    wchar_t path[32768] = {};
    const DWORD size = GetModuleFileNameW(module, path, 32768);
    if (!size || size >= 32768) return {};
    std::wstring value(path, size);
    return value.substr(0, value.find_last_of(L'\\'));
}
void Configure(const std::wstring& directory) {
    std::ifstream file(directory + L"\\proxy.txt");
    std::string line;
    while (std::getline(file, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        auto equals = line.find('=');
        if (equals == std::string::npos) continue;
        const auto key = line.substr(0, equals), value = line.substr(equals + 1);
        if (key == "SOCKS5_PROXY_ADDRESS" || key == "SOCKS5_PROXY_PORT" ||
            key == "SOCKS5_PROXY_TIMEOUT" || key == "SOCKS5_PROXY_DNS" ||
            key == "SOCKS5_DNS_LOG") SetEnvironmentVariableA(key.c_str(), value.c_str());
    }
    char address[64] = {}, port[16] = {};
    GetEnvironmentVariableA("SOCKS5_PROXY_ADDRESS", address, sizeof(address));
    GetEnvironmentVariableA("SOCKS5_PROXY_PORT", port, sizeof(port));
    IN_ADDR ip;
    char* end = nullptr;
    const auto number = strtoul(port, &end, 10);
    if (InetPtonA(AF_INET, address, &ip) != 1 || !number || number > 65535 || !end || *end) return;
    const std::string endpoint = std::string(address) + ":" + port;
    const std::string flags = "--proxy-server=socks5://" + endpoint +
        " --proxy-bypass-list=localhost;127.0.0.1;[::1];10.0.0.0/8;172.16.0.0/12;192.168.0.0/16;*.local";
    SetEnvironmentVariableA("QTWEBENGINE_CHROMIUM_FLAGS", flags.c_str());
    LoadLibraryW((directory + L"\\force-proxy.dll").c_str());
}
}
BOOL WINAPI DllMain(HMODULE module, DWORD reason, LPVOID) {
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    DisableThreadLibraryCalls(module);
    wchar_t system[32768] = {};
    if (!GetSystemDirectoryW(system, 32768)) return FALSE;
    original = LoadLibraryW((std::wstring(system) + L"\\DWrite.dll").c_str());
    if (!original) return FALSE;
    OrignalDWriteCreateFactory = reinterpret_cast<uintptr_t>(GetProcAddress(original, "DWriteCreateFactory"));
    if (!OrignalDWriteCreateFactory) return FALSE;
    wchar_t exe[32768] = {};
    GetModuleFileNameW(nullptr, exe, 32768);
    const wchar_t* name = wcsrchr(exe, L'\\');
    if (name && _wcsicmp(name + 1, L"SignalRgb.exe") == 0) Configure(Directory(module));
    return TRUE;
}
