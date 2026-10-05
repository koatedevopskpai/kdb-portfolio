using System.Text;
using kx;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Koate.TickSubscriber;

/// <summary>
/// Connects to the kdb+ tickerplant, subscribes to the configured tables and applies every
/// pushed update to the <see cref="TradeAggregator"/>. Reconnects automatically on failure.
/// </summary>
public sealed class TickSubscriber : BackgroundService
{
    private readonly KdbOptions _options;
    private readonly TradeAggregator _aggregator;
    private readonly ILogger<TickSubscriber> _logger;

    public TickSubscriber(
            IOptions<KdbOptions> options,
            TradeAggregator aggregator,
            ILogger<TickSubscriber> logger)
    {
        _options = options.Value;
        _aggregator = aggregator;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RunSubscriptionAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "kdb+ subscription failed; reconnecting in {Delay}s",
                        _options.ReconnectDelaySeconds);
                try
                {
                    await Task.Delay(TimeSpan.FromSeconds(_options.ReconnectDelaySeconds), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
    }

    private async Task RunSubscriptionAsync(CancellationToken stoppingToken)
    {
        c.e = Encoding.UTF8;
        using c connection = new(_options.Host, _options.Port, _options.Credentials);

        // closing the socket on shutdown unblocks a pending kAsync()
        using CancellationTokenRegistration registration =
                stoppingToken.Register(() => { try { connection.Close(); } catch { /* shutting down */ } });

        _logger.LogInformation("connected to tickerplant {Host}:{Port}", _options.Host, _options.Port);

        // One subscription registers this handle with the tickerplant; it then broadcasts
        // every update (the mini tickerplant does not filter per subscriber - see README).
        connection.ks(".u.sub", _options.Tables[0]);
        _logger.LogInformation("subscribed to '{Table}'", _options.Tables[0]);

        while (!stoppingToken.IsCancellationRequested)
        {
            object message = await connection.kAsync();
            Handle(message);
        }
    }

    private void Handle(object? message)
    {
        if (message is not object[] parts || parts.Length < 4)
        {
            return;
        }
        if (parts[0]?.ToString() != ".u.upd")
        {
            return;
        }

        object? data = parts[3];
        c.Flip? flip = data as c.Flip ?? (data is null ? null : c.td(data));
        if (flip is not null && FlipMapper.TryToTrades(flip, out List<TradeRow> rows))
        {
            foreach (TradeRow row in rows)
            {
                _aggregator.Apply(row);
            }
        }
    }
}
