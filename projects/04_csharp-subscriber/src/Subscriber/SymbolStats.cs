namespace Koate.TickSubscriber;

/// <summary>Rolling per-symbol statistics accumulated from the live feed.</summary>
/// <param name="Symbol">Instrument symbol.</param>
/// <param name="Count">Number of trades seen.</param>
/// <param name="LastPrice">Most recent trade price.</param>
/// <param name="Vwap">Volume-weighted average price.</param>
/// <param name="TotalSize">Total traded size.</param>
/// <param name="LastTime">Timestamp of the most recent trade.</param>
public sealed record SymbolStats(
        string Symbol,
        long Count,
        double LastPrice,
        double Vwap,
        long TotalSize,
        DateTime LastTime);
