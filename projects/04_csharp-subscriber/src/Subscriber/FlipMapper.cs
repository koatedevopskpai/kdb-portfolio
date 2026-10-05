using System;
using System.Collections.Generic;
using kx;

namespace Koate.TickSubscriber;

/// <summary>
/// Maps a deserialized q table (<see cref="c.Flip"/>) into <see cref="TradeRow"/>s.
/// Isolating this keeps the aggregator free of any kdb+ client types.
/// </summary>
public static class FlipMapper
{
    private static readonly string[] RequiredColumns = { "time", "sym", "price", "size" };

    /// <summary>
    /// Try to read a trade table. Returns false (and an empty list) if the flip does not
    /// have the expected schema, so an unexpected table is ignored rather than crashing.
    /// </summary>
    public static bool TryToTrades(c.Flip? flip, out List<TradeRow> rows)
    {
        rows = new List<TradeRow>();
        if (flip?.x is null || flip.y is null)
        {
            return false;
        }

        var column = new Dictionary<string, int>(StringComparer.Ordinal);
        for (int j = 0; j < flip.x.Length; j++)
        {
            column[flip.x[j]] = j;
        }
        foreach (string name in RequiredColumns)
        {
            if (!column.ContainsKey(name))
            {
                return false;
            }
        }

        int rowCount = flip.y.Length == 0 ? 0 : ((Array)flip.y[0]).Length;
        for (int i = 0; i < rowCount; i++)
        {
            rows.Add(new TradeRow(
                    Symbol: AsString(flip.y[column["sym"]], i),
                    Time: AsDateTime(flip.y[column["time"]], i),
                    Price: AsDouble(flip.y[column["price"]], i),
                    Size: AsLong(flip.y[column["size"]], i)));
        }
        return true;
    }

    private static object? At(object column, int index) =>
            column is Array array ? array.GetValue(index) : null;

    private static string AsString(object column, int index) =>
            At(column, index) as string ?? Convert.ToString(At(column, index)) ?? string.Empty;

    private static DateTime AsDateTime(object column, int index) =>
            At(column, index) is DateTime dt ? dt : default;

    private static double AsDouble(object column, int index)
    {
        object? value = At(column, index);
        return value is null ? 0d : Convert.ToDouble(value);
    }

    private static long AsLong(object column, int index)
    {
        object? value = At(column, index);
        return value is null ? 0L : Convert.ToInt64(value);
    }
}
