// ============================================================================
// qipc.hpp - a tiny, self-contained implementation of the kdb+ IPC wire
// protocol (outbound/async only), used by the C++ feed handler.
//
// Separating the serialization library from main() keeps it unit-testable:
// tests/test_ser.cpp includes this header and checks the bytes it produces
// against q's own `-8!` output. No KX library, no sockets needed here.
//
// Wire format (little-endian):
//   message = [0x01 arch][0x00 async][0x00 0x00 pad][int32 total length][payload]
//   payload = general list: 0x00 0x00 count → (`upd; `table; table)
//   symbol  = 0xf5 + chars + 0x00  (atom)
//   vector  = type + attr(0) + int32 count + data
//   table   = 0x62 0x00 0x63 + name-symbol-vector + general-list-of-columns
// ============================================================================
#ifndef QIPC_HPP
#define QIPC_HPP

#include <chrono>
#include <cstdint>
#include <cstring>
#include <random>
#include <string>
#include <vector>

// ---------------------------------------------------------------------------
// Little-endian byte buffer used to build serialized q objects
// ---------------------------------------------------------------------------
struct Buf {
    std::vector<uint8_t> d;

    void u8(uint8_t v) { d.push_back(v); }
    void i32(int32_t v) {
        for (int i = 0; i < 4; i++) d.push_back(static_cast<uint8_t>((v >> (8 * i)) & 0xff));
    }
    void i64(int64_t v) {
        for (int i = 0; i < 8; i++) d.push_back(static_cast<uint8_t>((v >> (8 * i)) & 0xff));
    }
    void f64(double v) {
        uint64_t u;
        std::memcpy(&u, &v, 8);
        i64(static_cast<int64_t>(u));
    }
    void raw(const char* s, size_t n) { d.insert(d.end(), s, s + n); }
    void raw(const std::string& s) { raw(s.data(), s.size()); }
    void raw(const std::vector<uint8_t>& v) { d.insert(d.end(), v.begin(), v.end()); }
};

// ---------------------------------------------------------------------------
// q serialization primitives
// ---------------------------------------------------------------------------

// symbol atom:  0xf5 + chars + 0x00
inline void qSymbolAtom(Buf& b, const std::string& s) {
    b.u8(0xf5);
    b.raw(s);
    b.u8(0x00);
}

// generic vector:  type + attr(0) + 4-byte count + payload
template <typename F>
void qVector(Buf& b, uint8_t type, int32_t count, F writePayload) {
    b.u8(type);
    b.u8(0x00);  // attributes: none
    b.i32(count);
    writePayload();
}

// symbol vector (a column of symbols): type 11
inline void qSymbolVector(Buf& b, const std::vector<std::string>& v) {
    qVector(b, 0x0b, static_cast<int32_t>(v.size()), [&] {
        for (const auto& s : v) { b.raw(s); b.u8(0x00); }  // null-terminated
    });
}

// timestamp column: type 12, int64 nanoseconds since 2000.01.01
inline void qTimestampColumn(Buf& b, const std::vector<int64_t>& v) {
    qVector(b, 0x0c, static_cast<int32_t>(v.size()), [&] {
        for (auto t : v) b.i64(t);
    });
}

// float column: type 9
inline void qFloatColumn(Buf& b, const std::vector<double>& v) {
    qVector(b, 0x09, static_cast<int32_t>(v.size()), [&] {
        for (auto x : v) b.f64(x);
    });
}

// long column: type 7
inline void qLongColumn(Buf& b, const std::vector<int64_t>& v) {
    qVector(b, 0x07, static_cast<int32_t>(v.size()), [&] {
        for (auto x : v) b.i64(x);
    });
}

// table:  0x62 0x00 0x63 + column-name symbol vector + general list of columns
inline void qTable(Buf& b, const std::vector<std::string>& cols,
                   const std::vector<Buf>& columns) {
    b.u8(0x62);  // table
    b.u8(0x00);  // attribute
    b.u8(0x63);  // dictionary (flipped)
    qSymbolVector(b, cols);  // keys: column names
    qVector(b, 0x00, static_cast<int32_t>(cols.size()), [&] {
        for (const auto& c : columns) b.raw(c.d);
    });
}

// ---------------------------------------------------------------------------
// clock helper: nanoseconds since 2000.01.01 (the q timestamp epoch)
// ---------------------------------------------------------------------------
inline int64_t nowNanos() {
    using namespace std::chrono;
    auto ns = duration_cast<nanoseconds>(system_clock::now().time_since_epoch()).count();
    return ns - 946684800LL * 1000000000LL;  // 1970 -> 2000
}

// ---------------------------------------------------------------------------
// feed generation
// ---------------------------------------------------------------------------
static const char* SYMS[] = {"AAPL", "AMZN", "GOOG", "MSFT", "NFLX", "TSLA"};

// a generated row batch: timestamp/symbol columns plus named serialized columns
struct Batch {
    std::vector<std::string> sym;
    std::vector<int64_t> ts;
    std::vector<std::string> names;  // column names in order
    std::vector<Buf> cols;           // matching serialized column vectors
};

inline Buf tsCol(const std::vector<int64_t>& v) { Buf b; qTimestampColumn(b, v); return b; }
inline Buf symCol(const std::vector<std::string>& v) { Buf b; qSymbolVector(b, v); return b; }
inline Buf floatCol(const std::vector<double>& v) { Buf b; qFloatColumn(b, v); return b; }
inline Buf longCol(const std::vector<int64_t>& v) { Buf b; qLongColumn(b, v); return b; }

inline Batch makeTrades(std::mt19937& rng, int n) {
    Batch x;
    std::uniform_int_distribution<int> si(0, 5);
    std::uniform_real_distribution<double> pd(100.0, 150.0);
    std::uniform_int_distribution<int> sd(1, 1000);
    std::vector<double> price;
    std::vector<int64_t> size;
    auto base = nowNanos();
    for (int i = 0; i < n; i++) {
        x.sym.push_back(SYMS[si(rng)]);
        price.push_back(pd(rng));
        size.push_back(sd(rng));
        x.ts.push_back(base + i * 100000);  // 0.1ms apart, time-ordered
    }
    x.names = {"time", "sym", "price", "size"};
    x.cols = {tsCol(x.ts), symCol(x.sym), floatCol(price), longCol(size)};
    return x;
}

inline Batch makeQuotes(std::mt19937& rng, int n) {
    Batch x;
    std::uniform_int_distribution<int> si(0, 5);
    std::uniform_real_distribution<double> pd(99.0, 150.0);
    std::uniform_int_distribution<int> sd(1, 100);
    std::vector<double> bid, ask;
    std::vector<int64_t> bsize, asize;
    auto base = nowNanos();
    for (int i = 0; i < n; i++) {
        x.sym.push_back(SYMS[si(rng)]);
        bid.push_back(pd(rng));
        ask.push_back(pd(rng));
        bsize.push_back(sd(rng));
        asize.push_back(sd(rng));
        x.ts.push_back(base + i * 100000);
    }
    x.names = {"time", "sym", "bid", "ask", "bsize", "asize"};
    x.cols = {tsCol(x.ts), symCol(x.sym), floatCol(bid), floatCol(ask),
              longCol(bsize), longCol(asize)};
    return x;
}

// ---------------------------------------------------------------------------
// build the full async "upd" message bytes:  (`upd; `tableName; table)
// (pure - no I/O, so it can be unit tested)
// ---------------------------------------------------------------------------
inline std::vector<uint8_t> buildUpd(const std::string& tableName, const Batch& x) {
    Buf payload;
    payload.u8(0x00);  // general list
    payload.u8(0x00);  // attributes
    payload.i32(3);    // count
    qSymbolAtom(payload, "upd");
    qSymbolAtom(payload, tableName);
    qTable(payload, x.names, x.cols);

    std::vector<uint8_t> msg;
    msg.reserve(8 + payload.d.size());
    // 8-byte header: arch(1) + type(0=async) + pad + total length
    int32_t total = 8 + static_cast<int32_t>(payload.d.size());
    uint8_t hdr[8] = {0x01, 0x00, 0x00, 0x00};
    std::memcpy(hdr + 4, &total, 4);
    msg.insert(msg.end(), hdr, hdr + 8);
    msg.insert(msg.end(), payload.d.begin(), payload.d.end());
    return msg;
}

#endif  // QIPC_HPP