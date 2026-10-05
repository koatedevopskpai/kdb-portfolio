using System;
using System.Linq;
using Koate.TickSubscriber;
using Xunit;

namespace Koate.TickSubscriber.Tests;

public class TradeAggregatorTests
{
    private static readonly DateTime T0 = new(2026, 10, 5, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void AggregatesCountsSizeLastPriceAndVwap()
    {
        var agg = new TradeAggregator();
        agg.Apply(new TradeRow("AAPL", T0, 100.0, 10));
        agg.Apply(new TradeRow("AAPL", T0.AddSeconds(1), 102.0, 30));
        agg.Apply(new TradeRow("MSFT", T0, 50.0, 5));

        Assert.Equal(3, agg.TotalRows);

        SymbolStats aapl = agg.Snapshot().Single(s => s.Symbol == "AAPL");
        Assert.Equal(2, aapl.Count);
        Assert.Equal(40, aapl.TotalSize);
        Assert.Equal(102.0, aapl.LastPrice);
        Assert.Equal((100.0 * 10 + 102.0 * 30) / 40.0, aapl.Vwap, 10);
        Assert.Equal(T0.AddSeconds(1), aapl.LastTime);
    }

    [Fact]
    public void SnapshotIsOrderedBySymbol()
    {
        var agg = new TradeAggregator();
        agg.Apply(new TradeRow("TSLA", T0, 1, 1));
        agg.Apply(new TradeRow("AAPL", T0, 1, 1));
        agg.Apply(new TradeRow("MSFT", T0, 1, 1));

        Assert.Equal(new[] { "AAPL", "MSFT", "TSLA" }, agg.Snapshot().Select(s => s.Symbol));
    }

    [Fact]
    public void ResetClearsState()
    {
        var agg = new TradeAggregator();
        agg.Apply(new TradeRow("AAPL", T0, 100.0, 10));
        agg.Reset();

        Assert.Equal(0, agg.TotalRows);
        Assert.Empty(agg.Snapshot());
    }
}
