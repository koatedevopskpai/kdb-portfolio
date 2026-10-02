// ============================================================================
// bench_ser.cpp - serialization throughput benchmark.
// Measures how fast the C++ feed can build wire messages for a market-data
// table (the per-message cost a real feed handler is judged on).
//
// Build/run: g++ -O2 -std=c++17 bench/bench_ser.cpp -o bench/bench_ser && ./bench/bench_ser
// ============================================================================

#include <chrono>
#include <cstdint>
#include <cstdio>
#include <random>

#include "../qipc.hpp"

int main() {
    std::mt19937 rng(42);
    const int N = 1000000;   // messages
    const int rows = 10;     // rows per message

    std::uint64_t bytes = 0;
    auto t0 = std::chrono::steady_clock::now();
    for (int i = 0; i < N; i++) {
        auto msg = buildUpd("trade", makeTrades(rng, rows));
        bytes += msg.size();
    }
    auto t1 = std::chrono::steady_clock::now();

    double sec = std::chrono::duration<double>(t1 - t0).count();
    std::printf("serialization benchmark: %d messages x %d rows (%.1f MB total)\n",
                N, rows, bytes / 1e6);
    std::printf("  %.0f msg/s | %.0f rows/s | %.1f MB/s | %.2f us/msg | %llu bytes/msg\n",
                N / sec, N * rows / sec, bytes / 1e6 / sec, sec / N * 1e6,
                (unsigned long long)(bytes / N));
    return 0;
}