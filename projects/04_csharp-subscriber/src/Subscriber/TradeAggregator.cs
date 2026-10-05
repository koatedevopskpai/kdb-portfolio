namespace Koate.TickSubscriber;

/// <summary>
/// Thread-safe, side-effect-free aggregation of a stream of trades into per-symbol stats
/// (count, last price, VWAP, total size). The feed thread calls <see cref="Apply"/>;
/// the reporting thread calls <see cref="Snapshot"/>.
/// </summary>
public sealed class TradeAggregator
{
    private readonly object _gate = new();
    private readonly Dictionary<string, Accumulator> _bySymbol = new(StringComparer.Ordinal);
    private long _totalRows;

    /// <summary>Total number of trade rows applied since the last reset.</summary>
    public long TotalRows
    {
        get { lock (_gate) { return _totalRows; } }
    }

    /// <summary>Fold a single trade into the running aggregates.</summary>
    public void Apply(TradeRow row)
    {
        lock (_gate)
        {
            if (!_bySymbol.TryGetValue(row.Symbol, out Accumulator? acc))
            {
                acc = new Accumulator();
                _bySymbol[row.Symbol] = acc;
            }
            acc.Count++;
            acc.TotalSize += row.Size;
            acc.Notional += row.Price * row.Size;
            acc.LastPrice = row.Price;
            acc.LastTime = row.Time;
            _totalRows++;
        }
    }

    /// <summary>An immutable, alphabetically-ordered snapshot of the current stats.</summary>
    public IReadOnlyList<SymbolStats> Snapshot()
    {
        lock (_gate)
        {
            return _bySymbol
                    .OrderBy(kv => kv.Key, StringComparer.Ordinal)
                    .Select(kv => new SymbolStats(
                            kv.Key,
                            kv.Value.Count,
                            kv.Value.LastPrice,
                            kv.Value.TotalSize == 0 ? 0d : kv.Value.Notional / kv.Value.TotalSize,
                            kv.Value.TotalSize,
                            kv.Value.LastTime))
                    .ToList();
        }
    }

    public void Reset()
    {
        lock (_gate)
        {
            _bySymbol.Clear();
            _totalRows = 0;
        }
    }

    private sealed class Accumulator
    {
        public long Count;
        public long TotalSize;
        public double Notional;
        public double LastPrice;
        public DateTime LastTime;
    }
}
