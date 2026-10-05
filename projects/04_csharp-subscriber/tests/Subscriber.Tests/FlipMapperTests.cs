using System;
using kx;
using Koate.TickSubscriber;
using Xunit;

namespace Koate.TickSubscriber.Tests;

public class FlipMapperTests
{
    private static c.Flip Flip(string[] columns, object[] values) =>
            new(new c.Dict(columns, values));

    private static c.Flip TradeFlip() =>
            Flip(
                    new[] { "time", "sym", "price", "size" },
                    new object[]
                    {
                        new[] { new DateTime(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc) },
                        new[] { "AAPL" },
                        new[] { 101.5 },
                        new[] { 250L },
                    });

    [Fact]
    public void MapsAValidTradeTable()
    {
        bool ok = FlipMapper.TryToTrades(TradeFlip(), out var rows);

        Assert.True(ok);
        TradeRow row = Assert.Single(rows);
        Assert.Equal("AAPL", row.Symbol);
        Assert.Equal(101.5, row.Price);
        Assert.Equal(250, row.Size);
        Assert.Equal(new DateTime(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc), row.Time);
    }

    [Fact]
    public void RejectsTableWithMissingColumns()
    {
        var quoteLike = Flip(
                new[] { "time", "sym", "bid", "ask" },
                new object[] { new[] { DateTime.UtcNow }, new[] { "AAPL" }, new[] { 1.0 }, new[] { 2.0 } });

        Assert.False(FlipMapper.TryToTrades(quoteLike, out var rows));
        Assert.Empty(rows);
    }

    [Fact]
    public void HandlesEmptyTable()
    {
        var empty = Flip(
                new[] { "time", "sym", "price", "size" },
                new object[] { Array.Empty<DateTime>(), Array.Empty<string>(), Array.Empty<double>(), Array.Empty<long>() });

        Assert.True(FlipMapper.TryToTrades(empty, out var rows));
        Assert.Empty(rows);
    }
}
