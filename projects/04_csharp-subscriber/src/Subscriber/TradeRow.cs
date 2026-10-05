namespace Koate.TickSubscriber;

/// <summary>A single trade row extracted from a q table.</summary>
/// <param name="Symbol">Instrument symbol.</param>
/// <param name="Time">Trade timestamp (q timestamp -&gt; .NET DateTime).</param>
/// <param name="Price">Trade price.</param>
/// <param name="Size">Trade size.</param>
public readonly record struct TradeRow(string Symbol, DateTime Time, double Price, long Size);
