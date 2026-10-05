using Koate.TickSubscriber;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

// A console host that runs two background services:
//   - TickSubscriber: connects to the kdb+ tickerplant and applies pushed updates
//   - StatusReporter: prints the rolling per-symbol aggregate
// Config comes from appsettings.json ("Kdb" section) / environment variables.

HostApplicationBuilder builder = Host.CreateApplicationBuilder(args);

builder.Services.Configure<KdbOptions>(builder.Configuration.GetSection("Kdb"));
builder.Services.AddSingleton<TradeAggregator>();
builder.Services.AddHostedService<TickSubscriber>();
builder.Services.AddHostedService<StatusReporter>();

await builder.Build().RunAsync();
