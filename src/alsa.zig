const std = @import("std");

const c = @cImport({
    @cInclude("alsa/asoundlib.h");
});

sample_rate: u32,
bits_per_sample: u8,
channels: u8,
playback_handle: ?*c.snd_pcm_t,

const Self = @This();

pub fn init(sample_rate: u32, channels: u8) !Self {
    var actual_sample_rate: c_uint = sample_rate;

    var hw_params: ?*c.snd_pcm_hw_params_t = undefined;
    var playback_handle: ?*c.snd_pcm_t = undefined;

    var rc: c_int = 0;

    rc = c.snd_pcm_open(&playback_handle, "default", c.SND_PCM_STREAM_PLAYBACK, 0);
    if (rc < 0) return error.OpenError;

    rc = c.snd_pcm_hw_params_malloc(&hw_params);
    if (rc < 0) return error.HwParamsMalloc;

    rc = c.snd_pcm_hw_params_any(playback_handle, hw_params);
    if (rc < 0) return error.HwParamsAny;

    rc = c.snd_pcm_hw_params_set_access(playback_handle, hw_params, c.SND_PCM_ACCESS_RW_INTERLEAVED);
    if (rc < 0) return error.HwSetAccess;

    rc = c.snd_pcm_hw_params_set_format(playback_handle, hw_params, c.SND_PCM_FORMAT_S16_LE);
    if (rc < 0) return error.HwSetFormat;

    rc = c.snd_pcm_hw_params_set_rate_near(playback_handle, hw_params, &actual_sample_rate, 0);
    if (rc < 0 or actual_sample_rate != sample_rate) return error.HwSetRateNear;

    rc = c.snd_pcm_hw_params_set_channels(playback_handle, hw_params, channels);
    if (rc < 0) return error.HwSetChannels;

    rc = c.snd_pcm_hw_params(playback_handle, hw_params);
    if (rc < 0) return error.HwParams;

    c.snd_pcm_hw_params_free(hw_params);

    return Self{
        .sample_rate = actual_sample_rate,
        .bits_per_sample = 16,
        .channels = channels,
        .playback_handle = playback_handle,
    };
}

pub fn deinit(self: Self) void {
    _ = c.snd_pcm_close(self.playback_handle);
}

pub fn info(self: Self) void {
    std.debug.print("ALSA PCM\n", .{});
    std.debug.print("sample rate: {d} Hz\n", .{self.sample_rate});
    std.debug.print("bits per sample: {d}\n", .{self.bits_per_sample});
    std.debug.print("channels: {d}\n", .{self.channels});
}

pub fn play(self: Self, wav: Wav) i8 {
    const rc: c_int = c.snd_pcm_prepare(self.playback_handle);
    if (rc < 0) {
        var str_buffer: [128]u8 = undefined;
        const str = std.fmt.bufPrint(&str_buffer, "snd_pcm_prepare: {s}\n", .{c.snd_strerror(rc)}) catch unreachable;
        _ = std.posix.write(1, str) catch {};
        return -1;
    }

    if (wav.frames != c.snd_pcm_writei(self.playback_handle, @as(?*const anyopaque, @ptrCast(wav.pcm_buffer)), wav.frames)) {
        _ = std.posix.write(1, "Write to audio interface failed\n") catch {};
        return -1;
    }

    return 0;
}

pub const Wav = struct {
    const HEADER_SIZE = 44;

    sample_rate: u32,
    bits_per_sample: u16,
    channels: u16,
    frames: usize,
    pcm_buffer: []u8,

    pub fn info(self: Wav) void {
        std.debug.print("sample_rate: {d}\n", .{self.sample_rate});
        std.debug.print("bits_per_sample: {d}\n", .{self.bits_per_sample});
        std.debug.print("channels: {d}\n", .{self.channels});
        std.debug.print("frames: {d}\n", .{self.frames});
    }
};

const FileBufferedReader = std.io.BufferedReader(4096, std.fs.File.Reader);

pub fn loadWav(self: Self, allocator: std.mem.Allocator, input_fp: []const u8) !Wav {
    const input_file: std.fs.File = std.fs.cwd().openFile(input_fp, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Error opening file: {s}\n", .{input_fp});
        return err;
    };

    var file_br: FileBufferedReader = std.io.bufferedReader(input_file.reader());
    const reader: FileBufferedReader.Reader = file_br.reader();

    var header: [Wav.HEADER_SIZE]u8 = undefined;

    var nread: usize = 0;

    nread = try reader.read(&header);
    if (nread != header.len) return error.ReadHeader;

    const sample_rate: u32 = read_u32(&header, 24);
    const bits_per_sample: u16 = read_u16(&header, 34);
    const channels: u16 = read_u16(&header, 22);

    if (sample_rate != self.sample_rate) return error.SampleRate;
    if (bits_per_sample != self.bits_per_sample) return error.BitsPerSample;
    if (channels != self.channels) return error.Channels;

    const buffer_size = (try input_file.getEndPos()) - Wav.HEADER_SIZE;

    const pcm_buffer = try allocator.alloc(u8, buffer_size);

    nread = try reader.readAll(pcm_buffer);
    if (nread != pcm_buffer.len) return error.BufferTooSmall;

    input_file.close();

    const frames = 8 * buffer_size / (channels * bits_per_sample);

    return Wav{
        .sample_rate = sample_rate,
        .bits_per_sample = bits_per_sample,
        .channels = channels,
        .frames = frames,
        .pcm_buffer = pcm_buffer,
    };
}

fn read_u32(buffer: []const u8, pos: comptime_int) u32 {
    return @as(u32, buffer[pos]) |
        (@as(u32, buffer[pos + 1]) << 8) |
        (@as(u32, buffer[pos + 2]) << 16) |
        (@as(u32, buffer[pos + 3]) << 24);
}

fn read_u16(buffer: []const u8, pos: comptime_int) u16 {
    return @as(u16, buffer[pos]) |
        (@as(u16, buffer[pos + 1]) << 8);
}
