const std = @import("std");
const Alsa = @import("Alsa.zig");
const Timer = @import("Timer.zig");

const linux = std.os.linux;
const Wav = Alsa.Wav;

var counter: u8 = 0;
var signature: u8 = 1;

var alsa: Alsa = undefined;
var sound_A: Wav = undefined;
var sound_B: Wav = undefined;

fn alrm_handler(_: i32) callconv(.c) void {
    switch (counter) {
        0 => _ = alsa.play(sound_A),
        else => _ = alsa.play(sound_B),
    }

    counter = (counter + 1) % signature;
}

fn say_bye() void {
    std.debug.print("\nbye!\n\n", .{});
}

const Gpa: type = @import("allocator.zig").Gpa;

pub fn main() !u8 {
    defer if (comptime @hasDecl(Gpa, "deinit")) Gpa.deinit();
    const gpa = Gpa.allocator();

    alsa = try Alsa.init(44100, 2);
    defer alsa.deinit();

    std.debug.print("\n", .{});
    alsa.info();

    sound_A = try alsa.loadWav(gpa, "assets/tic.wav");
    defer sound_A.freeBuffer(gpa);

    sound_B = try alsa.loadWav(gpa, "assets/tac.wav");
    defer sound_B.freeBuffer(gpa);

    std.debug.print("\n - Sound A -\n", .{});
    sound_A.info();

    std.debug.print("\n - Sound B -\n", .{});
    sound_B.info();

    var timer = Timer.init(alrm_handler, 120);

    var stdin_buf: [256]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buf);
    const stdin: *std.Io.Reader = &stdin_reader.interface;

    std.debug.print("\nsig: {}\n", .{signature});
    std.debug.print("bpm: {}\n\n", .{timer.bpm});

    while (true) {
        std.debug.print("> ", .{});
        const bare_line = try stdin.takeDelimiter('\n') orelse {
            std.debug.print("\n", .{});
            say_bye();
            return 0;
        };

        const input = std.mem.trim(u8, bare_line, " \t\n");

        var it = std.mem.tokenizeScalar(u8, input, ' ');
        const first = it.next() orelse continue;

        if (std.mem.eql(u8, "q", first)) { // quit
            say_bye();
            return 0;
        }

        if (first[0] == '/') { // command
            const cmd = first[1..];

            if (std.mem.eql(u8, "sig", cmd)) { // change signature
                const sig = it.next() orelse {
                    std.debug.print("\nExpected value\n", .{});
                    std.debug.print("Try again...\n", .{});
                    continue;
                };

                const new_sig = std.fmt.parseInt(u8, sig, 10) catch |err| {
                    std.debug.print("\nHmm...\n", .{});
                    std.debug.print("error: {s}\n", .{@errorName(err)});
                    std.debug.print("Try again...\n\n", .{});
                    continue;
                };

                signature = new_sig;
                std.debug.print("\nsig: {}\n\n", .{signature});
                continue;
            }

            // unknown command
            std.debug.print("\nUnknown command: {s}\n\n", .{cmd});
            continue;
        } else { // new bpm
            const new_bpm = std.fmt.parseInt(u32, first, 10) catch |err| {
                std.debug.print("\nHmm...\n", .{});
                std.debug.print("error: {s}\n", .{@errorName(err)});
                std.debug.print("Try again...\n\n", .{});
                continue;
            };

            if (new_bpm <= 0 or new_bpm > 500) {
                std.debug.print("\nbpm should be between 0 and 500\n", .{});
                std.debug.print("Try again...\n\n", .{});
                continue;
            }

            timer.setBpm(new_bpm);
            std.debug.print("\nbpm: {}\n\n", .{timer.bpm});
            continue;
        }
    }
}
