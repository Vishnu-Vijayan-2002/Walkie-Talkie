using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Collections.Concurrent;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;
using ConnectX.Server.Services;

namespace ConnectX.Server.Hubs;

public interface IPttClient
{
    Task OnFloorGranted(string roomId, string deviceId, string floorToken);
    Task OnFloorBusy(string roomId, string speakerDeviceId, string speakerCallsign);
    Task OnFloorReleased(string roomId);
    Task OnFloorDenied(string roomId, string reason);
    Task OnHandRaised(string roomId, string deviceId, string callsign, int position);
    Task OnHandCancelled(string roomId, string deviceId);
    Task OnMemberJoined(string roomId, string deviceId, string callsign);
    Task OnMemberLeft(string roomId, string deviceId);
    Task OnMemberMuted(string roomId, string deviceId, bool isMuted);
    Task OnMemberBanned(string roomId, string deviceId, string reason);
    Task OnEmergencyBroadcast(string roomId, string senderDeviceId, string details);

    // WebRTC Voice Signaling
    Task OnWebRtcOffer(string roomId, string senderDeviceId, string sdp);
    Task OnWebRtcAnswer(string roomId, string senderDeviceId, string sdp);
    Task OnIceCandidate(string roomId, string senderDeviceId, string candidate, string sdpMid, int sdpMLineIndex);

    // Room Join Request Flow
    Task OnRoomSearchResult(string roomId, string roomName, string creatorName, int memberCount, bool found);
    Task OnIncomingJoinRequest(string roomId, string requesterDeviceId, string requesterCallsign);
    Task OnJoinApproved(string roomId, string roomName, string creatorName, int memberCount);
    Task OnJoinDeclined(string roomId, string reason);
}

public class PttHub : Hub<IPttClient>
{
    // SignalR's default user identifier is not the device ID used by this app.
    // Keep the current connection for each device so targeted floor grants and
    // WebRTC signalling reach the intended peer.
    private static readonly ConcurrentDictionary<string, string> DeviceConnections = new();
    private readonly IRedisFloorService _floorService;
    private readonly ConnectXDbContext _db;
    private readonly ILogger<PttHub> _logger;

    public PttHub(IRedisFloorService floorService, ConnectXDbContext db, ILogger<PttHub> logger)
    {
        _floorService = floorService;
        _db = db;
        _logger = logger;
    }

    public async Task JoinRoom(string roomId, string deviceId, string callsign)
    {
        // Check if banned
        var isBanned = await _db.Bans.AnyAsync(b => b.RoomId == roomId && b.DeviceId == deviceId && (b.ExpiresAt == null || b.ExpiresAt > DateTime.UtcNow));
        if (isBanned)
        {
            await Clients.Caller.OnMemberBanned(roomId, deviceId, "You are banned from this channel");
            return;
        }

        await Groups.AddToGroupAsync(Context.ConnectionId, roomId);
        DeviceConnections[deviceId] = Context.ConnectionId;
        await _floorService.AddPresenceAsync(roomId, deviceId);

        // Notify others
        await Clients.OthersInGroup(roomId).OnMemberJoined(roomId, deviceId, callsign);

        // Check if floor is currently occupied
        var currentFloor = await _floorService.GetActiveFloorAsync(roomId);
        if (currentFloor != null)
        {
            await Clients.Caller.OnFloorBusy(roomId, currentFloor.DeviceId, currentFloor.Callsign);
        }
    }

    public async Task LeaveRoom(string roomId, string deviceId)
    {
        await Groups.RemoveFromGroupAsync(Context.ConnectionId, roomId);
        await _floorService.RemovePresenceAsync(roomId, deviceId);
        await Clients.OthersInGroup(roomId).OnMemberLeft(roomId, deviceId);
    }

    public async Task RequestFloor(string roomId, string deviceId, string callsign)
    {
        // Check if member is muted
        var member = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == deviceId);
        if (member != null && member.IsMuted)
        {
            await Clients.Caller.OnFloorDenied(roomId, "You are muted by the moderator");
            return;
        }

        var lockInfo = await _floorService.TryAcquireFloorAsync(roomId, deviceId, callsign, timeoutSeconds: 60);
        if (lockInfo != null)
        {
            // Floor granted to caller
            await Clients.Caller.OnFloorGranted(roomId, deviceId, lockInfo.FloorToken);
            // Notify other room members that floor is busy
            await Clients.OthersInGroup(roomId).OnFloorBusy(roomId, deviceId, callsign);

            // Record session
            _db.SpeakingSessions.Add(new SpeakingSession
            {
                RoomId = roomId,
                DeviceId = deviceId,
                FloorToken = lockInfo.FloorToken,
                Transport = "WEBRTC_WAN",
                StartedAt = DateTime.UtcNow
            });
            await _db.SaveChangesAsync();
        }
        else
        {
            await Clients.Caller.OnFloorDenied(roomId, "Floor is currently occupied");
        }
    }

    public async Task ReleaseFloor(string roomId, string deviceId, string floorToken)
    {
        var released = await _floorService.ReleaseFloorAsync(roomId, deviceId, floorToken);
        if (released)
        {
            await Clients.Group(roomId).OnFloorReleased(roomId);

            var session = await _db.SpeakingSessions
                .Where(s => s.RoomId == roomId && s.DeviceId == deviceId && s.FloorToken == floorToken && s.EndedAt == null)
                .OrderByDescending(s => s.StartedAt)
                .FirstOrDefaultAsync();

            if (session != null)
            {
                session.EndedAt = DateTime.UtcNow;
                session.DurationMs = (int)(session.EndedAt.Value - session.StartedAt).TotalMilliseconds;
                await _db.SaveChangesAsync();
            }
        }
    }

    public async Task RaiseHand(string roomId, string deviceId, string callsign)
    {
        var count = await _db.RaisedHands.CountAsync(rh => rh.RoomId == roomId && rh.Status == RaisedHandStatus.Waiting);
        var hand = new RaisedHand
        {
            RoomId = roomId,
            DeviceId = deviceId,
            QueuePosition = count + 1,
            Status = RaisedHandStatus.Waiting,
            CreatedAt = DateTime.UtcNow
        };
        _db.RaisedHands.Add(hand);
        await _db.SaveChangesAsync();

        await Clients.Group(roomId).OnHandRaised(roomId, deviceId, callsign, hand.QueuePosition);
    }

    public async Task CancelRaiseHand(string roomId, string deviceId)
    {
        var existing = await _db.RaisedHands.FirstOrDefaultAsync(rh => rh.RoomId == roomId && rh.DeviceId == deviceId && rh.Status == RaisedHandStatus.Waiting);
        if (existing != null)
        {
            existing.Status = RaisedHandStatus.Cancelled;
            existing.ResolvedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        await Clients.Group(roomId).OnHandCancelled(roomId, deviceId);
    }

    public async Task GiveFloor(string roomId, string targetDeviceId, string targetCallsign)
    {
        // Cancel active floor if any
        var active = await _floorService.GetActiveFloorAsync(roomId);
        if (active != null)
        {
            await _floorService.ReleaseFloorAsync(roomId, active.DeviceId, active.FloorToken);
        }

        var lockInfo = await _floorService.TryAcquireFloorAsync(roomId, targetDeviceId, targetCallsign, timeoutSeconds: 60);
        if (lockInfo != null)
        {
            // Resolve hand request
            var hand = await _db.RaisedHands.FirstOrDefaultAsync(rh => rh.RoomId == roomId && rh.DeviceId == targetDeviceId && rh.Status == RaisedHandStatus.Waiting);
            if (hand != null)
            {
                hand.Status = RaisedHandStatus.Granted;
                hand.ResolvedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }

            await Clients.Group(roomId).OnFloorBusy(roomId, targetDeviceId, targetCallsign);
            await SendToDevice(targetDeviceId, client => client.OnFloorGranted(roomId, targetDeviceId, lockInfo.FloorToken));
        }
    }

    public async Task EmergencyAlert(string roomId, string deviceId, string details)
    {
        await Clients.Group(roomId).OnEmergencyBroadcast(roomId, deviceId, details);
        _db.AuditLogs.Add(new AuditLog
        {
            Action = "EMERGENCY_ALERT",
            ActorDeviceId = deviceId,
            RoomId = roomId,
            MetadataJson = $"{{\"details\": \"{details}\"}}",
            CreatedAt = DateTime.UtcNow
        });
        await _db.SaveChangesAsync();
    }

    // ─────────────────────────────────────────────────────────────────
    // WebRTC Online Voice Signaling Relay
    // ─────────────────────────────────────────────────────────────────

    public async Task SendWebRtcOffer(string roomId, string senderDeviceId, string targetDeviceId, string sdp)
    {
        if (string.IsNullOrEmpty(targetDeviceId))
        {
            await Clients.OthersInGroup(roomId).OnWebRtcOffer(roomId, senderDeviceId, sdp);
        }
        else
        {
            await SendToDevice(targetDeviceId, client => client.OnWebRtcOffer(roomId, senderDeviceId, sdp));
        }
    }

    public async Task SendWebRtcAnswer(string roomId, string senderDeviceId, string targetDeviceId, string sdp)
    {
        if (string.IsNullOrEmpty(targetDeviceId))
        {
            await Clients.OthersInGroup(roomId).OnWebRtcAnswer(roomId, senderDeviceId, sdp);
        }
        else
        {
            await SendToDevice(targetDeviceId, client => client.OnWebRtcAnswer(roomId, senderDeviceId, sdp));
        }
    }

    public async Task SendIceCandidate(string roomId, string senderDeviceId, string targetDeviceId, string candidate, string sdpMid, int sdpMLineIndex)
    {
        if (string.IsNullOrEmpty(targetDeviceId))
        {
            await Clients.OthersInGroup(roomId).OnIceCandidate(roomId, senderDeviceId, candidate, sdpMid, sdpMLineIndex);
        }
        else
        {
            await SendToDevice(targetDeviceId, client => client.OnIceCandidate(roomId, senderDeviceId, candidate, sdpMid, sdpMLineIndex));
        }
    }

    // ─────────────────────────────────────────────────────────────────
    // Room Join Request Flow
    // ─────────────────────────────────────────────────────────────────

    // In-memory pending join requests: key = "roomId:requesterDeviceId", value = requester connectionId
    private static readonly ConcurrentDictionary<string, string> PendingJoinRequests = new();
    // Track room creators: key = roomId, value = creatorDeviceId
    private static readonly ConcurrentDictionary<string, string> RoomCreators = new();
    // Track room info: key = roomId, value = (name, creatorName, memberCount)
    private static readonly ConcurrentDictionary<string, (string Name, string CreatorName, int MemberCount)> RoomInfoCache = new();

    public async Task RegisterRoomCreator(string roomId, string creatorDeviceId, string roomName, string creatorName)
    {
        var memberCount = 1;
        try
        {
            var room = await _db.Rooms.FirstOrDefaultAsync(r => r.RoomId == roomId);
            if (room != null)
            {
                memberCount = await _db.RoomMembers.CountAsync(member =>
                    member.RoomId == roomId && member.Status == MemberStatus.Active);
                if (memberCount == 0) memberCount = 1;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("RegisterRoomCreator DB lookup failed: {Message}", ex.Message);
        }

        RoomCreators[roomId] = creatorDeviceId;
        RoomInfoCache[roomId] = (string.IsNullOrWhiteSpace(roomName) ? "Tactical Room" : roomName, creatorName, memberCount);
        DeviceConnections[creatorDeviceId] = Context.ConnectionId;
        _logger.LogInformation("Room {RoomId} registered by {DeviceId} (Name: {Name})", roomId, creatorDeviceId, roomName);
        await Task.CompletedTask;
    }

    public async Task SearchRoom(string roomId, string requesterDeviceId)
    {
        // Store requester connection for later targeting
        DeviceConnections[requesterDeviceId] = Context.ConnectionId;

        // 1. Try memory cache first
        if (RoomInfoCache.TryGetValue(roomId, out var info))
        {
            await Clients.Caller.OnRoomSearchResult(roomId, info.Name, info.CreatorName, info.MemberCount, true);
            return;
        }

        // 2. Try looking up from DB
        try
        {
            var room = await _db.Rooms.Include(r => r.CreatorDevice).FirstOrDefaultAsync(r => r.RoomId == roomId);
            if (room != null)
            {
                var memberCount = await _db.RoomMembers.CountAsync(m => m.RoomId == roomId && m.Status == MemberStatus.Active);
                if (memberCount == 0) memberCount = 1;
                var creatorName = room.CreatorDevice?.DisplayName ?? "Commander";
                RoomInfoCache[roomId] = (room.Name, creatorName, memberCount);
                if (!string.IsNullOrEmpty(room.CreatorDeviceId))
                {
                    RoomCreators[roomId] = room.CreatorDeviceId;
                }
                await Clients.Caller.OnRoomSearchResult(roomId, room.Name, creatorName, memberCount, true);
                return;
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("SearchRoom DB query failed: {Message}", ex.Message);
        }

        await Clients.Caller.OnRoomSearchResult(roomId, "", "", 0, false);
    }

    public async Task RequestJoin(string roomId, string requesterDeviceId, string requesterCallsign)
    {
        // Save requester connection for targeted approval/decline
        DeviceConnections[requesterDeviceId] = Context.ConnectionId;
        var requestKey = $"{roomId}:{requesterDeviceId}";
        PendingJoinRequests[requestKey] = Context.ConnectionId;

        // Find creator device ID
        string? creatorDeviceId = null;
        if (RoomCreators.TryGetValue(roomId, out var registeredCreator))
        {
            creatorDeviceId = registeredCreator;
        }
        else
        {
            try
            {
                var dbRoom = await _db.Rooms.FirstOrDefaultAsync(r => r.RoomId == roomId);
                if (dbRoom != null)
                {
                    creatorDeviceId = dbRoom.CreatorDeviceId;
                    RoomCreators[roomId] = creatorDeviceId;
                }
            }
            catch { }
        }

        if (string.IsNullOrEmpty(creatorDeviceId))
        {
            await Clients.Caller.OnJoinDeclined(roomId, "Room creator not found or offline");
            return;
        }

        if (creatorDeviceId == requesterDeviceId)
        {
            await Clients.Caller.OnJoinDeclined(roomId, "You are already the creator of this room");
            return;
        }

        // Persist join request if DB is reachable
        try
        {
            var persistedRequest = await _db.JoinRequests.FirstOrDefaultAsync(request =>
                request.RoomId == roomId && request.DeviceId == requesterDeviceId && request.Status == JoinRequestStatus.Pending);
            if (persistedRequest == null)
            {
                _db.JoinRequests.Add(new JoinRequest
                {
                    RoomId = roomId,
                    DeviceId = requesterDeviceId,
                    Status = JoinRequestStatus.Pending,
                    CreatedAt = DateTime.UtcNow
                });
                await _db.SaveChangesAsync();
            }
        }
        catch (Exception ex)
        {
            _logger.LogWarning("RequestJoin DB save note: {Message}", ex.Message);
        }

        // Notify room creator if connected
        if (DeviceConnections.ContainsKey(creatorDeviceId))
        {
            await SendToDevice(creatorDeviceId, client =>
                client.OnIncomingJoinRequest(roomId, requesterDeviceId, requesterCallsign));
        }
        else
        {
            await Clients.Caller.OnJoinDeclined(roomId, "Room creator is currently offline");
        }
    }

    public async Task ApproveJoin(string roomId, string approverDeviceId, string requesterDeviceId)
    {
        var requestKey = $"{roomId}:{requesterDeviceId}";
        PendingJoinRequests.TryRemove(requestKey, out _);

        // Verify approver is creator (either via memory cache or DB)
        var isCreator = false;
        if (RoomCreators.TryGetValue(roomId, out var registeredCreator) && registeredCreator == approverDeviceId)
        {
            isCreator = true;
        }

        try
        {
            var room = await _db.Rooms.FirstOrDefaultAsync(r => r.RoomId == roomId);
            if (room != null && room.CreatorDeviceId == approverDeviceId)
            {
                isCreator = true;
            }

            var request = await _db.JoinRequests.FirstOrDefaultAsync(joinRequest =>
                joinRequest.RoomId == roomId && joinRequest.DeviceId == requesterDeviceId && joinRequest.Status == JoinRequestStatus.Pending);
            if (request != null)
            {
                request.Status = JoinRequestStatus.Accepted;
                request.ReviewedByDeviceId = approverDeviceId;
                request.ResolvedAt = DateTime.UtcNow;
            }
            if (!await _db.RoomMembers.AnyAsync(member => member.RoomId == roomId && member.DeviceId == requesterDeviceId))
            {
                _db.RoomMembers.Add(new RoomMember
                {
                    RoomId = roomId,
                    DeviceId = requesterDeviceId,
                    Role = MemberRole.Member,
                    Status = MemberStatus.Active,
                    JoinedAt = DateTime.UtcNow
                });
            }
            await _db.SaveChangesAsync();
        }
        catch (Exception ex)
        {
            _logger.LogWarning("ApproveJoin DB update note: {Message}", ex.Message);
        }

        if (!isCreator && RoomCreators.ContainsKey(roomId))
        {
            _logger.LogWarning("ApproveJoin: Approver {Approver} is not creator of {RoomId}", approverDeviceId, roomId);
            return;
        }

        // Get room info to send back to requester
        if (RoomInfoCache.TryGetValue(roomId, out var info))
        {
            // Bump member count
            RoomInfoCache[roomId] = (info.Name, info.CreatorName, info.MemberCount + 1);
            await SendToDevice(requesterDeviceId, client =>
                client.OnJoinApproved(roomId, info.Name, info.CreatorName, info.MemberCount + 1));
        }
        else
        {
            await SendToDevice(requesterDeviceId, client =>
                client.OnJoinApproved(roomId, "Tactical Room", "", 2));
        }
    }

    public async Task DeclineJoin(string roomId, string declinerDeviceId, string requesterDeviceId)
    {
        var requestKey = $"{roomId}:{requesterDeviceId}";
        PendingJoinRequests.TryRemove(requestKey, out _);

        try
        {
            var request = await _db.JoinRequests.FirstOrDefaultAsync(joinRequest =>
                joinRequest.RoomId == roomId && joinRequest.DeviceId == requesterDeviceId && joinRequest.Status == JoinRequestStatus.Pending);
            if (request != null)
            {
                request.Status = JoinRequestStatus.Rejected;
                request.ReviewedByDeviceId = declinerDeviceId;
                request.ResolvedAt = DateTime.UtcNow;
                await _db.SaveChangesAsync();
            }
        }
        catch { }

        await SendToDevice(requesterDeviceId, client =>
            client.OnJoinDeclined(roomId, "Your join request was declined by the room creator"));
    }

    public override Task OnDisconnectedAsync(Exception? exception)
    {
        foreach (var entry in DeviceConnections.Where(entry => entry.Value == Context.ConnectionId))
        {
            DeviceConnections.TryRemove(entry.Key, out _);
        }

        return base.OnDisconnectedAsync(exception);
    }

    private Task SendToDevice(string deviceId, Func<IPttClient, Task> send)
    {
        return DeviceConnections.TryGetValue(deviceId, out var connectionId)
            ? send(Clients.Client(connectionId))
            : Task.CompletedTask;
    }
}
