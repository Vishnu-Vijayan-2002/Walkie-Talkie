using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Controllers;

[ApiController]
[Route("api/v1")]
public class JoinRequestsController : ControllerBase
{
    private readonly ConnectXDbContext _db;

    public JoinRequestsController(ConnectXDbContext db)
    {
        _db = db;
    }

    public record SubmitJoinRequestDto(string DeviceId);

    [HttpPost("rooms/{roomId}/join-requests")]
    public async Task<IActionResult> SubmitJoinRequest(string roomId, [FromBody] SubmitJoinRequestDto dto)
    {
        var room = await _db.Rooms.FirstOrDefaultAsync(r => r.RoomId == roomId);
        if (room == null) return NotFound("Room not found");

        var isBanned = await _db.Bans.AnyAsync(b => b.RoomId == roomId && b.DeviceId == dto.DeviceId && (b.ExpiresAt == null || b.ExpiresAt > DateTime.UtcNow));
        if (isBanned) return Forbid("Device is banned from this room");

        var existingMember = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == dto.DeviceId);
        if (existingMember != null && existingMember.Status == MemberStatus.Active)
        {
            return BadRequest("Device is already an active member");
        }

        // If public, auto-approve
        if (room.Visibility == RoomVisibility.Public)
        {
            var member = new RoomMember
            {
                RoomId = roomId,
                DeviceId = dto.DeviceId,
                Role = MemberRole.Member,
                Status = MemberStatus.Active,
                JoinedAt = DateTime.UtcNow
            };
            _db.RoomMembers.Add(member);
            await _db.SaveChangesAsync();
            return Ok(new { status = "APPROVED", member });
        }

        var request = new JoinRequest
        {
            RoomId = roomId,
            DeviceId = dto.DeviceId,
            Status = JoinRequestStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };

        _db.JoinRequests.Add(request);
        await _db.SaveChangesAsync();

        return Ok(new { status = "PENDING", requestId = request.RequestId });
    }

    [HttpGet("rooms/{roomId}/join-requests")]
    public async Task<IActionResult> GetPendingRequests(string roomId, [FromQuery] string actorDeviceId)
    {
        // Check if actor is moderator or creator
        var member = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (member == null || (member.Role != MemberRole.Creator && member.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can view join requests");
        }

        var requests = await _db.JoinRequests
            .Include(jr => jr.Device)
            .Where(jr => jr.RoomId == roomId && jr.Status == JoinRequestStatus.Pending)
            .OrderBy(jr => jr.CreatedAt)
            .Select(jr => new
            {
                jr.RequestId,
                jr.DeviceId,
                Callsign = jr.Device.DisplayName,
                HardwareId = jr.Device.HardwareCallsign,
                jr.CreatedAt
            })
            .ToListAsync();

        return Ok(requests);
    }

    [HttpPut("join-requests/{requestId}/approve")]
    public async Task<IActionResult> ApproveRequest(Guid requestId, [FromQuery] string actorDeviceId)
    {
        var request = await _db.JoinRequests.Include(jr => jr.Room).FirstOrDefaultAsync(jr => jr.RequestId == requestId);
        if (request == null) return NotFound();

        var reviewer = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == request.RoomId && m.DeviceId == actorDeviceId);
        if (reviewer == null || (reviewer.Role != MemberRole.Creator && reviewer.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can approve join requests");
        }

        request.Status = JoinRequestStatus.Accepted;
        request.ReviewedByDeviceId = actorDeviceId;
        request.ResolvedAt = DateTime.UtcNow;

        var existingMember = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == request.RoomId && m.DeviceId == request.DeviceId);
        if (existingMember != null)
        {
            existingMember.Status = MemberStatus.Active;
        }
        else
        {
            _db.RoomMembers.Add(new RoomMember
            {
                RoomId = request.RoomId,
                DeviceId = request.DeviceId,
                Role = MemberRole.Member,
                Status = MemberStatus.Active,
                JoinedAt = DateTime.UtcNow
            });
        }

        _db.AuditLogs.Add(new AuditLog
        {
            Action = "APPROVE_MEMBER",
            ActorDeviceId = actorDeviceId,
            RoomId = request.RoomId,
            TargetDeviceId = request.DeviceId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = "Join request approved" });
    }

    [HttpPut("join-requests/{requestId}/reject")]
    public async Task<IActionResult> RejectRequest(Guid requestId, [FromQuery] string actorDeviceId)
    {
        var request = await _db.JoinRequests.FirstOrDefaultAsync(jr => jr.RequestId == requestId);
        if (request == null) return NotFound();

        var reviewer = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == request.RoomId && m.DeviceId == actorDeviceId);
        if (reviewer == null || (reviewer.Role != MemberRole.Creator && reviewer.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can reject join requests");
        }

        request.Status = JoinRequestStatus.Rejected;
        request.ReviewedByDeviceId = actorDeviceId;
        request.ResolvedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok(new { message = "Join request rejected" });
    }
}
