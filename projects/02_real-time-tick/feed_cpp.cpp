// ============================================================================
// feed_cpp.cpp - C++ FEED HANDLER for the KDB-X tick system
//
// This is the "bank-standard" market data architecture in C++:
//
//     [C++ feed handler] --IPC (raw kdb+ wire protocol)--> [q tickerplant]
//
// In a real investment bank the feed handler is the process that connects to
// an exchange (FIX/OUCH or a proprietary binary protocol) and normalises the
// raw bytes into tables before pushing them into the kdb+ tickerplant.
//
// The wire protocol implementation lives in qipc.hpp (so it can be unit
// tested); this file is only the network loop.
//
// Build:  bash build.sh        (needs g++; see README for the one-time setup)
// Run:    ./feed_cpp [host] [port] [interval-ms] [rows-per-batch]
// ============================================================================

#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <random>
#include <string>
#include <thread>

#include "qipc.hpp"

int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IOLBF, 0);  // flush each line to the log

    const char* host = argc > 1 ? argv[1] : "127.0.0.1";
    int port = argc > 2 ? std::atoi(argv[2]) : 5010;
    int intervalMs = argc > 3 ? std::atoi(argv[3]) : 100;
    int rows = argc > 4 ? std::atoi(argv[4]) : 10;

    int fd = ::socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) { std::perror("socket"); return 1; }

    sockaddr_in addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(static_cast<uint16_t>(port));
    if (inet_pton(AF_INET, host, &addr.sin_addr) <= 0) {
        std::fprintf(stderr, "bad host %s\n", host);
        return 1;
    }
    if (::connect(fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) < 0) {
        std::perror("connect");
        return 1;
    }

    // handshake: "username" + capability byte + null terminator, then read the
    // server's capability byte (captured from what q itself sends)
    const char* user = std::getenv("USER");
    if (!user || !*user) user = "anonymous";
    std::string hs(user);
    hs.push_back(static_cast<char>(0x06));
    hs.push_back(0x00);
    if (::send(fd, hs.data(), hs.size(), 0) < 0) { std::perror("handshake"); return 1; }
    char cap = 0;
    ::recv(fd, &cap, 1, 0);
    std::printf("feed_cpp connected to %s:%d (capability 0x%02x)\n", host, port, cap & 0xff);

    std::random_device rd;
    std::mt19937 rng(rd());
    unsigned long long ticks = 0;

    for (;;) {
        auto send = [&](const std::string& table, const Batch& b) {
            auto bytes = buildUpd(table, b);
            ::send(fd, bytes.data(), bytes.size(), 0);
        };
        send("trade", makeTrades(rng, rows));
        send("quote", makeQuotes(rng, rows));
        ticks++;
        if (ticks % 10 == 0) std::printf("feed_cpp pushed %llu batches\n", ticks);
        std::this_thread::sleep_for(std::chrono::milliseconds(intervalMs));
    }
    return 0;
}