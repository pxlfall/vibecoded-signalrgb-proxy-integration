#include "stdafx.h"

// Глобальные переменные g_ProxyAddress, g_ProxyPort, g_ProxyTimeout, g_ProxyLogin, g_ProxyPassword теперь в dllmain.cpp


bool WaitForWrite(SOCKET s, int timeoutSec)
{
    fd_set writeSet;
    FD_ZERO(&writeSet);
    FD_SET(s, &writeSet);

    timeval timeout = { timeoutSec, 0 };
    int result = select(0, NULL, &writeSet, NULL, &timeout);
    if (result > 0 && FD_ISSET(s, &writeSet)) {
        return true;
    }

    return false;
}

bool WaitForRead(SOCKET s, int timeoutSec)
{
    fd_set readSet;
    FD_ZERO(&readSet);
    FD_SET(s, &readSet);

    timeval timeout = { timeoutSec, 0 };
    int result = select(0, &readSet, NULL, NULL, &timeout);
    if (result > 0 && FD_ISSET(s, &readSet)) {
        return true;
    }

    return false;
}

bool SetNonBlockingMode(SOCKET s, bool nonBlocked)
{
    u_long mode = nonBlocked;
    return Real_ioctlsocket(s, FIONBIO, &mode) == NO_ERROR;
}

// SignalRGB adaptation: complete SOCKS frames before reporting connection success.
// TCP may split any greeting or response across reads.
static bool Transfer(SOCKET s, uint8_t* data, int length, bool write) {
    int offset = 0;
    while (offset < length) {
        if (!(write ? WaitForWrite(s, g_ProxyTimeout) : WaitForRead(s, g_ProxyTimeout))) {
            WSASetLastError(WSAETIMEDOUT); return false;
        }
        const int count = write ? send(s, reinterpret_cast<char*>(data + offset), length - offset, 0)
                                : recv(s, reinterpret_cast<char*>(data + offset), length - offset, 0);
        if (count == SOCKET_ERROR && WSAGetLastError() == WSAEWOULDBLOCK) continue;
        if (count <= 0) { if (!count) WSASetLastError(WSAECONNRESET); return false; }
        offset += count;
    }
    return true;
}
int ConnectToProxy(SOCKET s, bool nonBlocking) {
    WSAPROTOCOL_INFOW info = {};
    int infoSize = sizeof(info);
    if (getsockopt(s, SOL_SOCKET, SO_PROTOCOL_INFOW, reinterpret_cast<char*>(&info), &infoSize)) return SOCKET_ERROR;
    int result;
    if (info.iAddressFamily == AF_INET6) {
        sockaddr_in6 proxy = {};
        proxy.sin6_family = AF_INET6; proxy.sin6_port = g_ProxyPort;
        proxy.sin6_addr.u.Byte[10] = 0xff; proxy.sin6_addr.u.Byte[11] = 0xff;
        memcpy(proxy.sin6_addr.u.Byte + 12, &g_ProxyAddress, 4);
        result = Real_connect(s, reinterpret_cast<sockaddr*>(&proxy), sizeof(proxy));
    } else {
        sockaddr_in proxy = {};
        proxy.sin_family = AF_INET; proxy.sin_addr = g_ProxyAddress; proxy.sin_port = g_ProxyPort;
        result = Real_connect(s, reinterpret_cast<sockaddr*>(&proxy), sizeof(proxy));
    }
    if (result == SOCKET_ERROR) {
        if (WSAGetLastError() != WSAEWOULDBLOCK) return SOCKET_ERROR;
        if (!WaitForWrite(s, g_ProxyTimeout)) { WSASetLastError(WSAETIMEDOUT); return SOCKET_ERROR; }
        int error = 0, size = sizeof(error);
        if (getsockopt(s, SOL_SOCKET, SO_ERROR, reinterpret_cast<char*>(&error), &size)) return SOCKET_ERROR;
        if (error) { WSASetLastError(error); return SOCKET_ERROR; }
    }
    return ERROR_SUCCESS;
}
int SendSocks5Handshake(SOCKET s, bool) {
    uint8_t hello[] = {5, 1, 0}, response[2] = {};
    if (!Transfer(s, hello, 3, true) || !Transfer(s, response, 2, false)) return SOCKET_ERROR;
    if (response[0] != 5 || response[1] != 0) { WSASetLastError(WSAEACCES); return SOCKET_ERROR; }
    return ERROR_SUCCESS;
}
static int ConnectRequest(SOCKET s, uint8_t* request, int length, bool nonBlocking) {
    if (ConnectToProxy(s, nonBlocking) || SendSocks5Handshake(s, nonBlocking)) return SOCKET_ERROR;
    uint8_t header[4] = {}, bound[258] = {};
    if (!Transfer(s, request, length, true) || !Transfer(s, header, 4, false)) return SOCKET_ERROR;
    if (header[0] != 5 || header[1] != 0 || header[2] != 0) { WSASetLastError(WSAECONNREFUSED); return SOCKET_ERROR; }
    int remaining;
    if (header[3] == 1) remaining = 6;
    else if (header[3] == 4) remaining = 18;
    else if (header[3] == 3) {
        if (!Transfer(s, bound, 1, false)) return SOCKET_ERROR;
        remaining = bound[0] + 2;
    } else { WSASetLastError(WSAEINVAL); return SOCKET_ERROR; }
    if (!Transfer(s, bound, remaining, false)) return SOCKET_ERROR;
    // The handshake is complete, even if the application socket is nonblocking.
    return ERROR_SUCCESS;
}
int ConnectThroughSocks5(SOCKET s, const sockaddr_in* target, bool nonBlocking) {
    uint8_t request[10] = {5, 1, 0, 1};
    memcpy(request + 4, &target->sin_addr, 4); memcpy(request + 8, &target->sin_port, 2);
    return ConnectRequest(s, request, sizeof(request), nonBlocking);
}
int ConnectThroughSocks5IPv6(SOCKET s, const sockaddr_in6* target, bool nonBlocking) {
    uint8_t request[22] = {5, 1, 0, 4};
    memcpy(request + 4, &target->sin6_addr, 16); memcpy(request + 20, &target->sin6_port, 2);
    return ConnectRequest(s, request, sizeof(request), nonBlocking);
}

bool InitializeSocks5UdpAssociation(udp_association_entry_t* entry) {
    //We need tmp socket to request udp association
    entry->proxySocket = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (entry->proxySocket == INVALID_SOCKET) {
        return false;
    }

    SetNonBlockingMode(entry->proxySocket, true);
    /*int iOptval = 1;
    setsockopt(s, SOL_SOCKET, SO_EXCLUSIVEADDRUSE,
        (char*)&iOptval, sizeof(iOptval));*/

    if (ConnectToProxy(entry->proxySocket, true) != ERROR_SUCCESS) {
        return false;
    }

    if (SendSocks5Handshake(entry->proxySocket, true) != ERROR_SUCCESS) {
        return false;
    }

    // Request UDP associate
    // We don't have to specify dst since proxies usually get it from encapsulating header
    uint8_t udpAssociateRequest[10] = { 0x05, 0x03, 0x00, 0x01, 0, 0, 0, 0, 0, 0 }; // SOCKS5, UDP ASSOCIATE, reserved, IPv4, dst addr, dst port
    WaitForWrite(entry->proxySocket, g_ProxyTimeout);
    send(entry->proxySocket, (const char*)udpAssociateRequest, sizeof(udpAssociateRequest), 0);

    uint8_t udpAssociateResponse[10];
    WaitForRead(entry->proxySocket, g_ProxyTimeout);
    recv(entry->proxySocket, (char*)udpAssociateResponse, sizeof(udpAssociateResponse), 0);

    if (udpAssociateResponse[1] != 0x00) {
        return false;
    }

    //Real_closesocket(s);

    // Get address and port to send UDP packets
    entry->udpProxyAddr.sin_family = AF_INET;
    memcpy(&entry->udpProxyAddr.sin_addr, udpAssociateResponse + 4, 4);
    memcpy(&entry->udpProxyAddr.sin_port, udpAssociateResponse + 8, 2);

    return true;
}

void EncapsulateUDPPacket(WSABUF* target, char *buf, int len, const sockaddr* lpTo)
{
    target->len = len + 10; // packet len + encasulated size
    target->buf = (char *)malloc(target->len);

    target->buf[0] = 0; // Reserved
    target->buf[1] = 0; // Reserved
    target->buf[2] = 0; // Fragmentation flag
    target->buf[3] = 1; // IPv4

    const struct sockaddr_in* addr = reinterpret_cast<const struct sockaddr_in*>(lpTo);
    memcpy(&target->buf[4], &addr->sin_addr.s_addr, sizeof(addr->sin_addr.s_addr)); //ip addr
    memcpy(&target->buf[8], &addr->sin_port, sizeof(addr->sin_port)); // port

    memcpy(&target->buf[10], buf, len); //copy whole packet
}

void ExtractSockAddr(char* buf, sockaddr* target)
{
    const struct sockaddr_in* addr = reinterpret_cast<const struct sockaddr_in*>(target);
    memcpy((void*)&addr->sin_addr.s_addr, &buf[4], sizeof(addr->sin_addr.s_addr)); //ip addr
    memcpy((void*)&addr->sin_port, &buf[8], sizeof(addr->sin_port)); // port
}