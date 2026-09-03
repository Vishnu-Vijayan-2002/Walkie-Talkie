using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;
using System.Text.Json.Serialization;

namespace ConnectX.Server.Models.Entities;

public enum RoomType
{
    General,
    Event,
    Hospital,
    School,
    FieldTeam
}

public enum RoomVisibility
{
    Public,
    Private
}

public enum CommunicationMode
{
    Online,
    OfflineNearby,
    Auto
}

public enum MemberRole
{
    Creator,
    Moderator,
    Member,
    ListenOnly
}

public enum MemberStatus
{
    Active,
    Muted,
    Suspended
}

public enum JoinRequestStatus
{
    Pending,
    Accepted,
    Rejected,
    Expired
}

public enum RaisedHandStatus
{
    Waiting,
    Granted,
    Cancelled,
    Expired
}

[Table("organizations")]
public class Organization
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(20)]
    public string OrgCode { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Workspace> Workspaces { get; set; } = new List<Workspace>();
}

[Table("workspaces")]
public class Workspace
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid OrganizationId { get; set; }
    public Organization Organization { get; set; } = null!;

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    [Required]
    [MaxLength(30)]
    public string Type { get; set; } = "GENERAL";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<Room> Rooms { get; set; } = new List<Room>();
}

[Table("devices")]
public class Device
{
    [Key]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;

    [Required]
    [MaxLength(16)]
    public string HardwareCallsign { get; set; } = string.Empty;

    [Required]
    [MaxLength(64)]
    public string DisplayName { get; set; } = string.Empty;

    [Required]
    public string PublicKey { get; set; } = string.Empty;

    [MaxLength(64)]
    public string UnitTeam { get; set; } = "General Unit";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime LastSeenAt { get; set; } = DateTime.UtcNow;

    public ICollection<RoomMember> Memberships { get; set; } = new List<RoomMember>();
}

[Table("rooms")]
public class Room
{
    [Key]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;

    public Guid? WorkspaceId { get; set; }
    public Workspace? Workspace { get; set; }

    [Required]
    [MaxLength(100)]
    public string Name { get; set; } = string.Empty;

    public RoomType Type { get; set; } = RoomType.General;
    public RoomVisibility Visibility { get; set; } = RoomVisibility.Private;
    public CommunicationMode CommunicationMode { get; set; } = CommunicationMode.Auto;

    [Required]
    [MaxLength(64)]
    public string CreatorDeviceId { get; set; } = string.Empty;
    public Device CreatorDevice { get; set; } = null!;

    [MaxLength(20)]
    public string Status { get; set; } = "ACTIVE";

    public bool IsMeshFallback { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public ICollection<RoomMember> Members { get; set; } = new List<RoomMember>();
    public ICollection<JoinRequest> JoinRequests { get; set; } = new List<JoinRequest>();
    public ICollection<Invitation> Invitations { get; set; } = new List<Invitation>();
    public ICollection<RaisedHand> RaisedHands { get; set; } = new List<RaisedHand>();
    public ICollection<SpeakingSession> SpeakingSessions { get; set; } = new List<SpeakingSession>();
    public ICollection<Ban> Bans { get; set; } = new List<Ban>();
}

[Table("room_members")]
public class RoomMember
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;
    public Device Device { get; set; } = null!;

    public MemberRole Role { get; set; } = MemberRole.Member;
    public MemberStatus Status { get; set; } = MemberStatus.Active;
    public bool IsMuted { get; set; } = false;

    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
}

[Table("join_requests")]
public class JoinRequest
{
    [Key]
    public Guid RequestId { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;
    public Device Device { get; set; } = null!;

    public JoinRequestStatus Status { get; set; } = JoinRequestStatus.Pending;

    [MaxLength(64)]
    public string? ReviewedByDeviceId { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ResolvedAt { get; set; }
}

[Table("invitations")]
public class Invitation
{
    [Key]
    [MaxLength(32)]
    public string Code { get; set; } = string.Empty;

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string CreatedByDeviceId { get; set; } = string.Empty;

    public int MaxUses { get; set; } = 0;
    public int UsedCount { get; set; } = 0;
    public DateTime? ExpiresAt { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

[Table("raised_hands")]
public class RaisedHand
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;
    public Device Device { get; set; } = null!;

    public int QueuePosition { get; set; } = 1;
    public RaisedHandStatus Status { get; set; } = RaisedHandStatus.Waiting;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ResolvedAt { get; set; }
}

[Table("speaking_sessions")]
public class SpeakingSession
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;
    public Device Device { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string FloorToken { get; set; } = string.Empty;

    [MaxLength(20)]
    public string Transport { get; set; } = "WEBRTC_WAN";

    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? EndedAt { get; set; }
    public int DurationMs { get; set; } = 0;
}

[Table("bans")]
public class Ban
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    [MaxLength(32)]
    public string RoomId { get; set; } = string.Empty;
    [JsonIgnore]
    public Room Room { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string DeviceId { get; set; } = string.Empty;
    public Device Device { get; set; } = null!;

    [Required]
    [MaxLength(64)]
    public string BannedByDeviceId { get; set; } = string.Empty;

    [MaxLength(255)]
    public string? Reason { get; set; }

    public DateTime BannedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ExpiresAt { get; set; }
}

[Table("audit_logs")]
public class AuditLog
{
    [Key]
    public long Id { get; set; }

    [Required]
    [MaxLength(50)]
    public string Action { get; set; } = string.Empty;

    [Required]
    [MaxLength(64)]
    public string ActorDeviceId { get; set; } = string.Empty;

    [MaxLength(32)]
    public string? RoomId { get; set; }

    [MaxLength(64)]
    public string? TargetDeviceId { get; set; }

    [Column(TypeName = "jsonb")]
    public string MetadataJson { get; set; } = "{}";

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
