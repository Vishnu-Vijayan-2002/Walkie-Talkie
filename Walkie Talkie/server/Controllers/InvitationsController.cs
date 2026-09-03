using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Controllers;

[ApiController]
[Route("api/v1")]
public class InvitationsController : ControllerBase
{
    private readonly ConnectXDbContext _db;

    public InvitationsController(ConnectXDbContext db)
    {
        _db = db;
    }

    public record CreateInvitationDto(int MaxUses = 0, int ValidHours = 48);

    [HttpPost("rooms/{roomId}/invitations")]
    public async Task<IActionResult> CreateInvitation(string roomId, [FromBody] CreateInvitationDto dto, [FromQuery] string actorDeviceId)
    {
        var member = await _db.RoomMembers.FirstOrDefaultAsync(m => m.RoomId == roomId && m.DeviceId == actorDeviceId);
        if (member == null || (member.Role != MemberRole.Creator && member.Role != MemberRole.Moderator))
        {
            return Forbid("Only moderators or creators can generate invitations");
        }

        var random = new Random();
        var code = $"INV-{roomId}-{random.Next(1000, 9999)}";

        var invitation = new Invitation
        {
            Code = code,
            RoomId = roomId,
            CreatedByDeviceId = actorDeviceId,
            MaxUses = dto.MaxUses,
            UsedCount = 0,
            ExpiresAt = dto.ValidHours > 0 ? DateTime.UtcNow.AddHours(dto.ValidHours) : null,
            IsActive = true,
            CreatedAt = DateTime.UtcNow
        };

        _db.Invitations.Add(invitation);
        await _db.SaveChangesAsync();

        return Ok(invitation);
    }

    [HttpGet("invitations/{code}")]
    public async Task<IActionResult> ResolveInvitation(string code)
    {
        var invite = await _db.Invitations
            .Include(i => i.Room)
                .ThenInclude(r => r.CreatorDevice)
            .FirstOrDefaultAsync(i => i.Code == code && i.IsActive);

        if (invite == null) return NotFound("Invalid or inactive invitation");

        if (invite.ExpiresAt != null && invite.ExpiresAt < DateTime.UtcNow)
        {
            return BadRequest("Invitation code has expired");
        }

        if (invite.MaxUses > 0 && invite.UsedCount >= invite.MaxUses)
        {
            return BadRequest("Invitation code max uses exceeded");
        }

        return Ok(new
        {
            invite.Code,
            invite.RoomId,
            RoomName = invite.Room.Name,
            invite.Room.Type,
            CreatorCallsign = invite.Room.CreatorDevice.DisplayName,
            MemberCount = await _db.RoomMembers.CountAsync(m => m.RoomId == invite.RoomId && m.Status == MemberStatus.Active)
        });
    }
}
