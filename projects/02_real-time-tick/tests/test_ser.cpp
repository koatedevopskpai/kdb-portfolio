// ============================================================================
// test_ser.cpp - byte-exact unit test for the q IPC serialization.
//
// Builds a deterministic table and checks the serialized message against the
// bytes q itself produces for the same object via `-8!`. If this passes, the
// C++ feed speaks the wire protocol correctly.
//
// Expected bytes captured from q:
//   tab:([] time:2000.01.01D00:00:00.000000001 2000.01.01D00:00:00.000000002;
//           sym:`AAPL`MSFT; price:100.5 101.25; size:1000 2000)
//   -8! (`upd;`trade;tab)
//
// Build/run: see tests/run_tests.sh, or:
//   g++ -std=c++17 -I.. test_ser.cpp -o test_ser && ./test_ser
// ============================================================================

#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>

#include "../qipc.hpp"

static std::string toHex(const std::vector<uint8_t>& v) {
    static const char* h = "0123456789abcdef";
    std::string s;
    s.reserve(v.size() * 2);
    for (uint8_t b : v) { s.push_back(h[b >> 4]); s.push_back(h[b & 0xf]); }
    return s;
}

int main() {
    // deterministic batch: timestamp raw longs are 1 and 2
    Batch x;
    x.ts = {1, 2};
    x.sym = {"AAPL", "MSFT"};
    std::vector<double> price = {100.5, 101.25};
    std::vector<int64_t> size = {1000, 2000};
    x.names = {"time", "sym", "price", "size"};
    x.cols = {tsCol(x.ts), symCol(x.sym), floatCol(price), longCol(size)};

    std::vector<uint8_t> got = buildUpd("trade", x);

    // exact bytes produced by q's `-8!` for the same message
    const std::string expected =
        "010000008f000000000003000000f575706400f57472616465006200630b000400000074696d"
        "650073796d0070726963650073697a65000000040000000c0002000000010000000000000002"
        "000000000000000b00020000004141504c004d5346540009000200000000000000002059400000"
        "000000505940070002000000e803000000000000d007000000000000";

    std::string gotHex = toHex(got);
    if (gotHex == expected) {
        std::printf("PASS test_ser: serialized %zu bytes match q's -8! byte-for-byte\n",
                    got.size());
        return 0;
    }
    std::printf("FAIL test_ser\n  expected %s\n  got      %s\n", expected.c_str(), gotHex.c_str());
    return 1;
}