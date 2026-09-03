using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Controllers;

[ApiController]
[Route("api/v1/rooms")]
public class RoomsController : ControllerBase
{
    private readonly ConnectXDbContext _db;

    public RoomsController(ConnectXDbContext db)
    {
        _db = db;
    }

    public record CreateRoomDto(
        string Name,
        RoomType Type,
        RoomVisibility Visibility,
        CommunicationMode CommunicationMode,
        string CreatorDeviceId,
        bool IsMeshFallback
    );

    [HttpGet]
    public async Task<IActionResult> GetRooms([FromQuery] string? deviceId)
    {
        var query = _db.Rooms
            .Include(r => r.Members)
            .AsQueryable();

        if (!string.IsNullOrEmpty(deviceId))
        {
            // Return public rooms + rooms where the device is an active member
            query = query.Where(r => r.Visibility == RoomVisibility.Public || r.Members.Any(m => m.DeviceId == deviceId && m.Status == MemberStatus.Active));
        }
        else
        {
            query = query.Where(r => r.Visibility == RoomVisibility.Public);
        }

        var rooms = await query
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.RoomId,
                r.Name,
                r.Type,
                r.Visibility,
                r.CommunicationMode,
                r.CreatorDeviceId,
                r.Status,
                r.IsMeshFallback,
                MemberCount = r.Members.Count(m => m.Status == MemberStatus.Active),
                r.CreatedAt
            })
            .ToListAsync();

        return Ok(rooms);
    }

    [HttpPost]
    public async Task<IActionResult> CreateRoom([FromBody] CreateRoomDto dto)
    {
        var random = new Random();
        var code = $"CX-{random.Next(10000, 99999)}";

        var room = new Room
        {
            RoomId = code,
            Name = dto.Name,
            Type = dto.Type,
            Visibility = dto.Visibility,
            CommunicationMode = dto.CommunicationMode,
            CreatorDeviceId = dto.CreatorDeviceId,
            Status = "ACTIVE",
            IsMeshFallback = dto.IsMeshFallback,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        var creatorMember = new RoomMember
        {
            RoomId = room.RoomId,
            DeviceId = dto.CreatorDeviceId,
            Role = MemberRole.Creator,
            Status = MemberStatus.Active,
            JoinedAt = DateTime.UtcNow
        };

        room.Members.Add(creatorMember);

        _db.Rooms.Add(room);
        _db.AuditLogs.Add(new AuditLog
        {
            Action = "CREATE_ROOM",
            ActorDeviceId = dto.CreatorDeviceId,
            RoomId = room.RoomId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetRoomById), new { roomId = room.RoomId }, new
        {
            room.RoomId,
            room.Name,
            room.Type,
            room.Visibility,
            room.CommunicationMode,
            room.CreatorDeviceId,
            room.Status,
            room.IsMeshFallback,
            MemberCount = 1,
            room.CreatedAt
        });
    }

    [HttpGet("{roomId}")]
    public async Task<IActionResult> GetRoomById(string roomId)
    {
        var room = await _db.Rooms
            .Include(r => r.Members)
                .ThenInclude(m => m.Device)
            .Include(r => r.RaisedHands.Where(rh => rh.Status == RaisedHandStatus.Waiting))
            .FirstOrDefaultAsync(r => r.RoomId == roomId);

        if (room == null) return NotFound();

        return Ok(new
        {
            room.RoomId,
            room.Name,
            room.Type,
            room.Visibility,
            room.CommunicationMode,
            room.CreatorDeviceId,
            room.Status,
            room.IsMeshFallback,
            Members = room.Members.Where(m => m.Status == MemberStatus.Active).Select(m => new
            {
                m.DeviceId,
                Callsign = m.Device.DisplayName,
                m.Role,
                m.IsMuted,
                m.JoinedAt
            }),
            RaisedHands = room.RaisedHands.OrderBy(rh => rh.QueuePosition).Select(rh => new
            {
                rh.Id,
                rh.DeviceId,
                rh.QueuePosition,
                rh.CreatedAt
            })
        });
    }

    [HttpDelete("{roomId}")]
    public async Task<IActionResult> CloseRoom(string roomId, [FromQuery] string actorDeviceId)
    {
        var room = await _db.Rooms.FirstOrDefaultAsync(r => r.RoomId == roomId);
        if (room == null) return NotFound();

        if (room.CreatorDeviceId != actorDeviceId)
        {
            return Forbid("Only the creator can close this room");
        }

        room.Status = "CLOSED";
        room.UpdatedAt = DateTime.UtcNow;

        _db.AuditLogs.Add(new AuditLog
        {
            Action = "CLOSE_ROOM",
            ActorDeviceId = actorDeviceId,
            RoomId = roomId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = "Room closed successfully" });
    }
}
