using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Controllers;

[ApiController]
[Route("api/v1/rooms/{roomId}")]
public class MembersController : ControllerBase
{
    private readonly ConnectXDbContext _db;

    public MembersController(ConnectXDbContext db)
    {
        _db = db;
    }

    [HttpGet("members")]
    public async Task<IActionResult> GetMembers(string roomId)
    {
        var members = await _db.RoomMembers
            .Include(m => m.Device)
            .Where(m => m.RoomId == roomId && m.Status == MemberStatus.Active)
            .OrderBy(m => m.Role == MemberRole.Creator ? 0 : (m.Role == MemberRole.Moderator ? 1 : 2))
            .ThenBy(m => m.Device.DisplayName)
            .Select(m => new
            {
                m.DeviceId,
                Callsign = m.Device.DisplayName,
                HardwareId = m.Device.HardwareCallsign,
                m.Role,
                m.Status,
                m.IsMuted,
                m.JoinedAt,
                LastSeenAt = m.Device.LastSeenAt
            })
            .ToListAsync();

        return Ok(members);
    }

    public record UpdateRoleDto(MemberRole NewRole);

    [HttpPut("members/{targetDeviceId}/role")]
    public async Task<IActionResult> UpdateRole(string roomId, string targetDeviceId, [FromBody] UpdateRoleDto dto, [FromQuery] string actorDeviceId)
    {
        var actor = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (actor == null || actor.Role != MemberRole.Creator)
        {
            return Forbid("Only the room creator can change member roles");
        }

        var target = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == targetDeviceId);
        if (target == null) return NotFound("Target member not found");

        target.Role = dto.NewRole;

        _db.AuditLogs.Add(new AuditLog
        {
            Action = "UPDATE_ROLE",
            ActorDeviceId = actorDeviceId,
            RoomId = roomId,
            TargetDeviceId = targetDeviceId,
            MetadataJson = $"{{\"newRole\": \"{dto.NewRole}\"}}",
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = $"Member role updated to {dto.NewRole}" });
    }

    public record ToggleMuteDto(bool IsMuted);

    [HttpPut("members/{targetDeviceId}/mute")]
    public async Task<IActionResult> ToggleMute(string roomId, string targetDeviceId, [FromBody] ToggleMuteDto dto, [FromQuery] string actorDeviceId)
    {
        var actor = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (actor == null || (actor.Role != MemberRole.Creator && actor.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can mute members");
        }

        var target = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == targetDeviceId);
        if (target == null) return NotFound("Target member not found");

        target.IsMuted = dto.IsMuted;

        _db.AuditLogs.Add(new AuditLog
        {
            Action = dto.IsMuted ? "MUTE_MEMBER" : "UNMUTE_MEMBER",
            ActorDeviceId = actorDeviceId,
            RoomId = roomId,
            TargetDeviceId = targetDeviceId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = $"Member mute state set to {dto.IsMuted}" });
    }

    [HttpDelete("members/{targetDeviceId}")]
    public async Task<IActionResult> RemoveMember(string roomId, string targetDeviceId, [FromQuery] string actorDeviceId)
    {
        var actor = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (actor == null || (actor.Role != MemberRole.Creator && actor.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can remove members");
        }

        var target = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == targetDeviceId);
        if (target == null) return NotFound();

        _db.RoomMembers.Remove(target);

        _db.AuditLogs.Add(new AuditLog
        {
            Action = "REMOVE_MEMBER",
            ActorDeviceId = actorDeviceId,
            RoomId = roomId,
            TargetDeviceId = targetDeviceId,
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = "Member removed from room" });
    }

    public record BanMemberDto(string? Reason, int BanDurationHours = 0);

    [HttpPost("bans")]
    public async Task<IActionResult> BanMember(string roomId, [FromBody] BanMemberDto dto, [FromQuery] string targetDeviceId, [FromQuery] string actorDeviceId)
    {
        var actor = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (actor == null || (actor.Role != MemberRole.Creator && actor.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can ban members");
        }

        var target = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == targetDeviceId);
        if (target != null)
        {
            _db.RoomMembers.Remove(target);
        }

        var ban = new Ban
        {
            RoomId = roomId,
            DeviceId = targetDeviceId,
            BannedByDeviceId = actorDeviceId,
            Reason = dto.Reason,
            BannedAt = DateTime.UtcNow,
            ExpiresAt = dto.BanDurationHours > 0 ? DateTime.UtcNow.AddHours(dto.BanDurationHours) : null
        };

        _db.Bans.Add(ban);
        _db.AuditLogs.Add(new AuditLog
        {
            Action = "BAN_MEMBER",
            ActorDeviceId = actorDeviceId,
            RoomId = roomId,
            TargetDeviceId = targetDeviceId,
            MetadataJson = $"{{\"reason\": \"{dto.Reason}\"}}",
            CreatedAt = DateTime.UtcNow
        });

        await _db.SaveChangesAsync();
        return Ok(new { message = "Member banned successfully" });
    }
}
