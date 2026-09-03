using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Data;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Controllers;

[ApiController]
[Route("api/v1/devices")]
public class DevicesController : ControllerBase
{
    private readonly ConnectXDbContext _db;

    public DevicesController(ConnectXDbContext db)
    {
        _db = db;
    }

    public record ProvisionDeviceDto(
        string DeviceId,
        string HardwareCallsign,
        string DisplayName,
        string PublicKey,
        string UnitTeam
    );

    [HttpPost("provision")]
    public async Task<IActionResult> ProvisionDevice([FromBody] ProvisionDeviceDto dto)
    {
        var existing = await _db.Devices.FirstOrDefaultAsync(d => d.DeviceId == dto.DeviceId);
        if (existing != null)
        {
            existing.DisplayName = dto.DisplayName;
            existing.UnitTeam = dto.UnitTeam;
            existing.LastSeenAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
            return Ok(existing);
        }

        var newDevice = new Device
        {
            DeviceId = dto.DeviceId,
            HardwareCallsign = dto.HardwareCallsign,
            DisplayName = dto.DisplayName,
            PublicKey = dto.PublicKey,
            UnitTeam = dto.UnitTeam,
            CreatedAt = DateTime.UtcNow,
            LastSeenAt = DateTime.UtcNow
        };

        _db.Devices.Add(newDevice);
        await _db.SaveChangesAsync();

        return CreatedAtAction(nameof(GetDevice), new { deviceId = newDevice.DeviceId }, newDevice);
    }

    [HttpGet("{deviceId}")]
    public async Task<IActionResult> GetDevice(string deviceId)
    {
        var device = await _db.Devices.FirstOrDefaultAsync(d => d.DeviceId == deviceId);
        if (device == null) return NotFound();
        return Ok(device);
    }

    [HttpPut("{deviceId}/profile")]
    public async Task<IActionResult> UpdateProfile(string deviceId, [FromBody] UpdateProfileDto dto)
    {
        var device = await _db.Devices.FirstOrDefaultAsync(d => d.DeviceId == deviceId);
        if (device == null) return NotFound();

        device.DisplayName = dto.DisplayName;
        device.UnitTeam = dto.UnitTeam;
        device.LastSeenAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok(device);
    }

    public record UpdateProfileDto(string DisplayName, string UnitTeam);
}
