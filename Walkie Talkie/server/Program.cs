using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Hubs;
using ConnectX.Server.Services;

var builder = WebApplication.CreateBuilder(args);

// 1. Database Configuration (PostgreSQL with InMemory fallback for unit/integration tests)
var connectionString = builder.Configuration.GetConnectionString("DefaultConnection");
if (!string.IsNullOrEmpty(connectionString))
{
    builder.Services.AddDbContext<ConnectXDbContext>(options =>
        options.UseNpgsql(connectionString));
}
else
{
    // Local In-Memory fallback for fast dev scaffolding without external DB
    builder.Services.AddDbContext<ConnectXDbContext>(options =>
        options.UseInMemoryDatabase("ConnectX_Dev"));
}

// 2. Redis Realtime Floor Lock & Presence Service
builder.Services.AddSingleton<IRedisFloorService, RedisFloorService>();

// 3. SignalR Realtime Hub
builder.Services.AddSignalR();

// 4. Controllers & OpenAPI / Swagger
builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.ReferenceHandler = System.Text.Json.Serialization.ReferenceHandler.IgnoreCycles;
    });
builder.Services.AddEndpointsApiExplorer();

// 5. Permissive CORS for Flutter Web / Mobile Dev
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyHeader()
              .AllowAnyMethod()
              .SetIsOriginAllowed(_ => true)
              .AllowCredentials();
    });
});

var app = builder.Build();

// Ensure Database Created
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ConnectXDbContext>();
    db.Database.EnsureCreated();
}

app.UseCors("AllowAll");

app.MapControllers();
app.MapHub<PttHub>("/hubs/ptt");

app.MapGet("/", () => new
{
    Service = "ConnectX Tactical Communication Core API",
    Status = "ONLINE",
    Version = "1.0.0-PRO",
    Timestamp = DateTime.UtcNow
});

app.Run();
