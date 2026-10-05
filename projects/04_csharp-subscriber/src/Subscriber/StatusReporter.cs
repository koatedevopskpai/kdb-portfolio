using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Koate.TickSubscriber;

/// <summary>Periodically prints the current per-symbol aggregate.</summary>
public sealed class StatusReporter : BackgroundService
{
    private readonly KdbOptions _options;
    private readonly TradeAggregator _aggregator;
    private readonly ILogger<StatusReporter> _logger;

    public StatusReporter(
            IOptions<KdbOptions> options,
            TradeAggregator aggregator,
            ILogger<StatusReporter> logger)
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
                await Task.Delay(_options.ReportIntervalMs, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            IReadOnlyList<SymbolStats> snapshot = _aggregator.Snapshot();
            _logger.LogInformation("total rows received: {Rows}", _aggregator.TotalRows);
            foreach (SymbolStats s in snapshot)
            {
                _logger.LogInformation(
                        "  {Symbol,-5} count={Count,-6} last={Last,8:F2} vwap={Vwap,8:F2} size={Size}",
                        s.Symbol, s.Count, s.LastPrice, s.Vwap, s.TotalSize);
            }
        }
    }
}
