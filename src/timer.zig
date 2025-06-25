const std = @import("std");
const linux = std.os.linux;

bpm: u32,

const Self = @This();

pub fn init(alrm_handler: fn (i32) callconv(.C) void, bpm: u32) Self {
    const sa = linux.Sigaction{
        .handler = .{ .handler = alrm_handler },
        .mask = linux.empty_sigset,
        .flags = 0,
    };

    _ = linux.sigaction(linux.SIG.ALRM, &sa, null);

    const nsec = 60 * 1000_000 / bpm;
    const tv_sec = nsec / 1000_000;
    const tv_nsec = nsec % 1000_000;

    const timerspec = linux.itimerspec{
        .it_interval = .{
            .sec = tv_sec,
            .nsec = tv_nsec,
        },
        .it_value = .{
            .sec = tv_sec,
            .nsec = tv_nsec,
        },
    };

    _ = linux.setitimer(@intFromEnum(linux.ITIMER.REAL), &timerspec, null);

    return Self{ .bpm = bpm };
}

pub fn setBpm(self: *Self, bpm: u32) void {
    const nsec = 60 * 1000_000 / bpm;
    const tv_sec = nsec / 1000_000;
    const tv_nsec = nsec % 1000_000;

    const timerspec = linux.itimerspec{
        .it_interval = .{
            .sec = tv_sec,
            .nsec = tv_nsec,
        },
        .it_value = .{
            .sec = tv_sec,
            .nsec = tv_nsec,
        },
    };

    _ = linux.setitimer(@intFromEnum(linux.ITIMER.REAL), &timerspec, null);

    self.bpm = bpm;
}
