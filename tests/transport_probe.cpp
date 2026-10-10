#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <cstdio>
#include <cstring>

int main(int argc, char** argv) {
    if (argc != 2) return 2;
    WSADATA data;
    if (WSAStartup(MAKEWORD(2,2), &data)) return 3;
    SetEnvironmentVariableA("SOCKS5_PROXY_ADDRESS", "127.0.0.1");
    SetEnvironmentVariableA("SOCKS5_PROXY_PORT", "17997");
    SetEnvironmentVariableA("SOCKS5_PROXY_TIMEOUT", "3");
    SetEnvironmentVariableA("SOCKS5_PROXY_DNS", "0");
    if (!LoadLibraryA(argv[1])) return 4;
    for (int kind = 0; kind < 4; ++kind) {
        SOCKET s = socket(kind < 2 ? AF_INET : AF_INET6, SOCK_STREAM, IPPROTO_TCP);
        DWORD zero = 0, timeout = 5000;
        setsockopt(s, SOL_SOCKET, SO_RCVTIMEO, reinterpret_cast<char*>(&timeout), sizeof(timeout));
        if (kind >= 2) setsockopt(s, IPPROTO_IPV6, IPV6_V6ONLY, reinterpret_cast<char*>(&zero), sizeof(zero));
        sockaddr_storage target = {};
        int length;
        if (kind < 2) {
            auto* ip = reinterpret_cast<sockaddr_in*>(&target);
            ip->sin_family = AF_INET; ip->sin_port = htons(443);
            InetPtonA(AF_INET, "8.8.8.8", &ip->sin_addr); length = sizeof(*ip);
        } else {
            auto* ip = reinterpret_cast<sockaddr_in6*>(&target);
            ip->sin6_family = AF_INET6; ip->sin6_port = htons(443);
            InetPtonA(AF_INET6, kind == 2 ? "::ffff:8.8.8.8" : "2001:db8::123", &ip->sin6_addr);
            length = sizeof(*ip);
        }
        u_long nonblocking = 1;
        if (kind != 0) ioctlsocket(s, FIONBIO, &nonblocking);
        int result = kind == 0 ? connect(s, reinterpret_cast<sockaddr*>(&target), length)
                               : WSAConnect(s, reinterpret_cast<sockaddr*>(&target), length, nullptr, nullptr, nullptr, nullptr);
        if (result) { std::printf("FAIL case %d connect error %d\n", kind, WSAGetLastError()); return 10+kind; }
        nonblocking = 0; ioctlsocket(s, FIONBIO, &nonblocking);
        send(s, "PING", 4, 0);
        char reply[4] = {}; int total = 0;
        while (total < 4) { int count = recv(s, reply+total, 4-total, 0); if (count <= 0) break; total += count; }
        closesocket(s);
        if (total != 4 || std::memcmp(reply, "PONG", 4)) { std::printf("FAIL case %d payload/framing\n", kind); return 20+kind; }
        std::printf("PASS case %d: split SOCKS frames and application data\n", kind);
    }
    WSACleanup(); return 0;
}
