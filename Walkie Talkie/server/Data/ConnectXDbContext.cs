using Microsoft.EntityFrameworkCore;
using ConnectX.Server.Models.Entities;

namespace ConnectX.Server.Data;

public class ConnectXDbContext : DbContext
{
    public ConnectXDbContext(DbContextOptions<ConnectXDbContext> options) : base(options)
    {
    }

    public DbSet<Organization> Organizations => Set<Organization>();
    public DbSet<Workspace> Workspaces => Set<Workspace>();
    public DbSet<Device> Devices => Set<Device>();
    public DbSet<Room> Rooms => Set<Room>();
    public DbSet<RoomMember> RoomMembers => Set<RoomMember>();
    public DbSet<JoinRequest> JoinRequests => Set<JoinRequest>();
    public DbSet<Invitation> Invitations => Set<Invitation>();
    public DbSet<RaisedHand> RaisedHands => Set<RaisedHand>();
    public DbSet<SpeakingSession> SpeakingSessions => Set<SpeakingSession>();
    public DbSet<Ban> Bans => Set<Ban>();
    public DbSet<AuditLog> AuditLogs => Set<AuditLog>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // Room Member Unique constraint
        modelBuilder.Entity<RoomMember>()
            .HasIndex(rm => new { rm.RoomId, rm.DeviceId })
            .IsUnique();

        // Indices
        modelBuilder.Entity<Room>()
            .HasIndex(r => r.Visibility);

        modelBuilder.Entity<JoinRequest>()
            .HasIndex(jr => new { jr.RoomId, jr.Status });

        modelBuilder.Entity<RaisedHand>()
            .HasIndex(rh => new { rh.RoomId, rh.Status });

        modelBuilder.Entity<Ban>()
            .HasIndex(b => new { b.RoomId, b.DeviceId });

        modelBuilder.Entity<AuditLog>()
            .HasIndex(a => new { a.RoomId, a.CreatedAt });
    }
}
