const std = @import("std");
const Alsa = @import("alsa.zig");
const Timer = @import("timer.zig");

const linux = std.os.linux;
const Wav = Alsa.Wav;

var counter: u8 = 0;

var alsa: Alsa = undefined;
var sound_A: Wav = undefined;
var sound_B: Wav = undefined;

fn alrm_handler(_: i32) callconv(.C) void {
    switch (counter) {
        0 => {
            _ = alsa.play(sound_A);
        },

        1, 2, 3 => {
            _ = alsa.play(sound_B);
        },

        else => unreachable,
    }

    counter = (counter + 1) % 4;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    alsa = try Alsa.init(44100, 1);
    defer alsa.deinit();

    alsa.info();

    sound_A = try alsa.loadWav(allocator, "assets/sound-A.wav");
    defer allocator.free(sound_A.pcm_buffer);

    sound_B = try alsa.loadWav(allocator, "assets/sound-B.wav");
    defer allocator.free(sound_B.pcm_buffer);

    std.debug.print("\n - Sound A -\n", .{});
    sound_A.info();

    std.debug.print("\n - Sound B -\n", .{});
    sound_B.info();

    var timer = Timer.init(alrm_handler, 120);

    const stdin = std.io.getStdIn().reader();

    var input: [128]u8 = undefined;

    std.debug.print("\nEnter a number between 0 and 500 to set bpm,\nor q to exit.\n\n> {d}\n", .{timer.bpm});

    while (true) {
        std.debug.print("> ", .{});
        const bytes_read = try stdin.readUntilDelimiter(&input, '\n');

        if (std.mem.eql(u8, "q", bytes_read)) {
            std.debug.print("\nbye!\n\n", .{});
            break;
        }

        const new_bpm = std.fmt.parseInt(u32, bytes_read, 10) catch continue;

        if (new_bpm > 500) {
            std.debug.print("too big\n", .{});
            continue;
        }

        timer.setBpm(new_bpm);
    }
}
