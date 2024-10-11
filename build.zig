const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const metro_exe = b.addExecutable(.{
        .name = "metronome",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    metro_exe.linkSystemLibrary("asound");

    b.installArtifact(metro_exe);

    const timer_run_cmd = b.addRunArtifact(metro_exe);
    timer_run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        timer_run_cmd.addArgs(args);
    }

    const timer_run_step = b.step("metro", "Run the metronome");
    timer_run_step.dependOn(&timer_run_cmd.step);
}
