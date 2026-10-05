namespace Koate.TickSubscriber;

/// <summary>Connection settings for the kdb+ tickerplant, bound from the "Kdb" section.</summary>
public sealed class KdbOptions
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 5010;
    public string Credentials { get; set; } = string.Empty;

    /// <summary>Tables to subscribe to (the tickerplant broadcasts these).</summary>
    public string[] Tables { get; set; } = { "trade" };

    /// <summary>Milliseconds between status prints.</summary>
    public int ReportIntervalMs { get; set; } = 2000;

    /// <summary>Seconds to wait before reconnecting after a failure.</summary>
    public int ReconnectDelaySeconds { get; set; } = 2;
}
