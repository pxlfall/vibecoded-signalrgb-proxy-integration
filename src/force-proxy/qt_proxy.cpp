#include "stdafx.h"
#include "qt_proxy.h"
#include <intrin.h>

// Qt WebEngine's ProxyConfigServiceQt asks Qt Network for its own proxy config.
// Chromium command-line flags alone do not override that service. Intercept
// only queries originating in Qt6WebEngineCore; native Qt/LAN users keep their
// original settings. Call the application's own exported Qt functions, rather
// than embedding or modifying Qt private data or setting a global system proxy.
namespace {
using ApplicationProxy = void* (*)(void* result);
using UsesSystemConfiguration = bool (*)();
using FromLatin1 = void* (*)(void* result, const char* text, int64_t length);
using DestroyString = void (*)(void* string);
using SetType = void (*)(void* proxy, int type);
using SetHost = void (*)(void* proxy, const void* string);
using SetPort = void (*)(void* proxy, uint16_t port);
ApplicationProxy realApplicationProxy;
UsesSystemConfiguration realUsesSystemConfiguration;
FromLatin1 fromLatin1;
DestroyString destroyString;
SetType setType;
SetHost setHost;
SetPort setPort;
HMODULE webEngine;
bool attached;

bool IsWebEngineCaller(void* address) {
    HMODULE owner = nullptr;
    return webEngine && GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, reinterpret_cast<LPCWSTR>(address), &owner) &&
        owner == webEngine;
}
void* ApplicationProxyForWebEngine(void* result) {
    const bool browser = IsWebEngineCaller(_ReturnAddress());
    realApplicationProxy(result);
    if (!browser) return result;
    char address[INET_ADDRSTRLEN] = {};
    InetNtopA(AF_INET, &g_ProxyAddress, address, sizeof(address));
    // Qt 6 x64 QString uses three pointer-sized words. The export constructs
    // it into caller-owned storage, and Qt's export destroys it afterwards.
    alignas(void*) unsigned char string[3 * sizeof(void*)] = {};
    fromLatin1(string, address, -1);
    setType(result, 1); // QNetworkProxy::Socks5Proxy
    setHost(result, string);
    setPort(result, ntohs(g_ProxyPort));
    destroyString(string);
    return result;
}
bool SystemConfigurationForWebEngine() {
    if (IsWebEngineCaller(_ReturnAddress())) return false;
    return realUsesSystemConfiguration();
}
}

void AttachQtProxyHooks() {
    const auto network = GetModuleHandleW(L"Qt6Network.dll");
    const auto core = GetModuleHandleW(L"Qt6Core.dll");
    webEngine = GetModuleHandleW(L"Qt6WebEngineCore.dll");
    if (!network || !core || !webEngine) return;
    realApplicationProxy = reinterpret_cast<ApplicationProxy>(GetProcAddress(network, "?applicationProxy@QNetworkProxy@@SA?AV1@XZ"));
    realUsesSystemConfiguration = reinterpret_cast<UsesSystemConfiguration>(GetProcAddress(network, "?usesSystemConfiguration@QNetworkProxyFactory@@SA_NXZ"));
    fromLatin1 = reinterpret_cast<FromLatin1>(GetProcAddress(core, "?fromLatin1@QString@@SA?AV1@PEBD_J@Z"));
    destroyString = reinterpret_cast<DestroyString>(GetProcAddress(core, "??1QString@@QEAA@XZ"));
    setType = reinterpret_cast<SetType>(GetProcAddress(network, "?setType@QNetworkProxy@@QEAAXW4ProxyType@1@@Z"));
    setHost = reinterpret_cast<SetHost>(GetProcAddress(network, "?setHostName@QNetworkProxy@@QEAAXAEBVQString@@@Z"));
    setPort = reinterpret_cast<SetPort>(GetProcAddress(network, "?setPort@QNetworkProxy@@QEAAXG@Z"));
    if (!realApplicationProxy || !realUsesSystemConfiguration || !fromLatin1 || !destroyString ||
        !setType || !setHost || !setPort) return;
    DetourAttach(reinterpret_cast<PVOID*>(&realApplicationProxy), ApplicationProxyForWebEngine);
    DetourAttach(reinterpret_cast<PVOID*>(&realUsesSystemConfiguration), SystemConfigurationForWebEngine);
    attached = true;
}
void DetachQtProxyHooks() {
    if (!attached) return;
    DetourDetach(reinterpret_cast<PVOID*>(&realApplicationProxy), ApplicationProxyForWebEngine);
    DetourDetach(reinterpret_cast<PVOID*>(&realUsesSystemConfiguration), SystemConfigurationForWebEngine);
    attached = false;
}
