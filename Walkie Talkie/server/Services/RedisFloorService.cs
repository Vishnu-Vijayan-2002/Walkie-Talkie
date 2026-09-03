using System.Collections.Concurrent;
using System.Text.Json;
using StackExchange.Redis;

namespace ConnectX.Server.Services;

public class FloorLockInfo
{
    public string RoomId { get; set; } = string.Empty;
    public string DeviceId { get; set; } = string.Empty;
    public string Callsign { get; set; } = string.Empty;
    public string FloorToken { get; set; } = string.Empty;
    public long GrantedAtEpochMs { get; set; }
}

public interface IRedisFloorService
{
    Task<FloorLockInfo?> TryAcquireFloorAsync(string roomId, string deviceId, string callsign, int timeoutSeconds = 60);
    Task<bool> ReleaseFloorAsync(string roomId, string deviceId, string floorToken);
    Task<FloorLockInfo?> GetActiveFloorAsync(string roomId);
    Task AddPresenceAsync(string roomId, string deviceId);
    Task RemovePresenceAsync(string roomId, string deviceId);
    Task<List<string>> GetRoomPresenceAsync(string roomId);
}

public class RedisFloorService : IRedisFloorService
{
    private readonly IConnectionMultiplexer? _redis;
    private readonly IDatabase? _db;
    
    // In-Memory fallback if Redis server is not running locally during development
    private readonly ConcurrentDictionary<string, FloorLockInfo> _inMemoryLocks = new();
    private readonly ConcurrentDictionary<string, ConcurrentDictionary<string, byte>> _inMemoryPresence = new();

    public RedisFloorService(IConfiguration configuration)
    {
        var redisConn = configuration.GetConnectionString("Redis");
        if (!string.IsNullOrEmpty(redisConn))
        {
            try
            {
                _redis = ConnectionMultiplexer.Connect(redisConn);
                _db = _redis.GetDatabase();
            }
            catch
            {
                _redis = null;
                _db = null;
            }
        }
    }

    public async Task<FloorLockInfo?> TryAcquireFloorAsync(string roomId, string deviceId, string callsign, int timeoutSeconds = 60)
    {
        var token = $"fl_{Guid.NewGuid():N}";
        var info = new FloorLockInfo
        {
            RoomId = roomId,
            DeviceId = deviceId,
            Callsign = callsign,
            FloorToken = token,
            GrantedAtEpochMs = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
        };

        var key = $"room:{roomId}:floor_lock";
        var json = JsonSerializer.Serialize(info);

        if (_db != null)
        {
            var acquired = await _db.StringSetAsync(key, json, TimeSpan.FromSeconds(timeoutSeconds), When.NotExists);
            if (acquired)
            {
                return info;
            }

            var existing = await _db.StringGetAsync(key);
            if (existing.HasValue)
            {
                return null;
            }
        }

        // In-memory fallback
        if (_inMemoryLocks.TryAdd(roomId, info))
        {
            return info;
        }

        return null;
    }

    public async Task<bool> ReleaseFloorAsync(string roomId, string deviceId, string floorToken)
    {
        var key = $"room:{roomId}:floor_lock";

        if (_db != null)
        {
            var existing = await _db.StringGetAsync(key);
            if (existing.HasValue)
            {
                var lockInfo = JsonSerializer.Deserialize<FloorLockInfo>((string)existing!);
                if (lockInfo != null && lockInfo.DeviceId == deviceId && lockInfo.FloorToken == floorToken)
                {
                    await _db.KeyDeleteAsync(key);
                    return true;
                }
            }
        }

        if (_inMemoryLocks.TryGetValue(roomId, out var memInfo))
        {
            if (memInfo.DeviceId == deviceId && memInfo.FloorToken == floorToken)
            {
                _inMemoryLocks.TryRemove(roomId, out _);
                return true;
            }
        }

        return false;
    }

    public async Task<FloorLockInfo?> GetActiveFloorAsync(string roomId)
    {
        var key = $"room:{roomId}:floor_lock";

        if (_db != null)
        {
            var existing = await _db.StringGetAsync(key);
            if (existing.HasValue)
            {
                return JsonSerializer.Deserialize<FloorLockInfo>((string)existing!);
            }
            return null;
        }

        if (_inMemoryLocks.TryGetValue(roomId, out var memInfo))
        {
            var expiresAt = DateTimeOffset.FromUnixTimeMilliseconds(memInfo.GrantedAtEpochMs)
                .AddSeconds(60);
            if (expiresAt > DateTimeOffset.UtcNow)
            {
                return memInfo;
            }

            _inMemoryLocks.TryRemove(roomId, out _);
        }

        return null;
    }

    public async Task AddPresenceAsync(string roomId, string deviceId)
    {
        var key = $"room:{roomId}:presence";
        if (_db != null)
        {
            await _db.SetAddAsync(key, deviceId);
        }
        else
        {
            var set = _inMemoryPresence.GetOrAdd(roomId, _ => new ConcurrentDictionary<string, byte>());
            set[deviceId] = 1;
        }
    }

    public async Task RemovePresenceAsync(string roomId, string deviceId)
    {
        var key = $"room:{roomId}:presence";
        if (_db != null)
        {
            await _db.SetRemoveAsync(key, deviceId);
        }
        else
        {
            if (_inMemoryPresence.TryGetValue(roomId, out var set))
            {
                set.TryRemove(deviceId, out _);
            }
        }
    }

    public async Task<List<string>> GetRoomPresenceAsync(string roomId)
    {
        var key = $"room:{roomId}:presence";
        if (_db != null)
        {
            var members = await _db.SetMembersAsync(key);
            return members.Select(m => m.ToString()).ToList();
        }

        if (_inMemoryPresence.TryGetValue(roomId, out var set))
        {
            return set.Keys.ToList();
        }

        return new List<string>();
    }
}
