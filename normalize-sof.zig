// Rewrite the build timestamps that Quartus embeds in SOF bitstreams, so that
// a derivation which keeps a bitstream can be reproducible.
//
// Every integer below is little endian.
//
// A SOF is a 12 byte header followed by a flat sequence of records that runs
// to the end of the file:
//
//     0        4        8       12                              EOF
//     +--------+--------+--------+---------- - - - --------------+
//     | "SOF\0"|  u32   |  u32   |            records            |
//     |        |   0    |   16   |                               |
//     +--------+--------+--------+---------- - - - --------------+
//
// Each record is a 6 byte header plus its payload:
//
//     0        2                 6
//     +--------+-----------------+-------- - - - ----------------+
//     |  u16   |       u32       |       payload[length]         |
//     |  tag   |     length      |                               |
//     +--------+-----------------+-------- - - - ----------------+
//
// For tag values of 0x0024 (undocumented as far as I can tell) is a nested
// payload structure:
//
//     0        4     6          10    12         16      16+n
//     +--------+-----+----------+-----+----------+-------+-------+
//     |  u32   | u16 |   u32    | u16 |   u32    | name  | data  |
//     | mtime  |     | name_len |     | data_len |  [n]  |  [d]  |
//     +--------+-----+----------+-----+----------+-------+-------+
//
// Some of the mtime entries are zero (which we don't touch), but the non-zero
// ones we replace with SOURCE_DATE_EPOCH.
//
// Reference:
//
// POF format: https://web.archive.org/web/2020/http://www.pldtool.com/pdf/fmt_pof.pdf
// POF disassembler: https://github.com/tomverbeure/aha363/blob/3b4c89a072dc8ce816c5ff3b90faca90aff7e599/tools/pof_tool.py
// CRC16 variant: https://github.com/trabucayre/openFPGALoader/issues/569

const std = @import("std");
const crc = std.hash.crc.Crc16IbmSdlc;

// nixpkgs' default
const default_source_date_epoch: u32 = 315532800;

const sof_header_len = 12;
const record_header_len = 6;
const archive_tag: u16 = 0x0024;
const entry_header_len = 16;

fn usage() noreturn {
    std.debug.print("usage: quartus-normalize-sof <file.sof>\n", .{});
    std.process.exit(2);
}

fn exit(path: []const u8, comptime msg: []const u8) noreturn {
    std.debug.print("quartus-normalize-sof: {s}: {s}\n", .{ path, msg });
    std.process.exit(0);
}

fn fail(path: []const u8, comptime msg: []const u8) noreturn {
    std.debug.print("quartus-normalize-sof: {s}: {s}\n", .{ path, msg });
    std.process.exit(1);
}

fn readInt(comptime T: anytype, data: []const u8, off: usize) T {
    return std.mem.readInt(T, data[off..][0..@sizeOf(T)], .little);
}

/// Rewrite the mtimes in one 0x0024 archive record, returning how many changed.
fn patchArchive(path: []const u8, data: []u8, start: usize, end: usize, epoch: u32) usize {
    var patched: usize = 0;
    var pos = start;

    while (pos < end) {
        if (end - pos < entry_header_len) fail(path, "truncated archive entry header");

        const mtime = readInt(u32, data, pos);
        const name_len = readInt(u32, data, pos + 6);
        const data_len = readInt(u32, data, pos + 12);

        // Widened so that a corrupt length cannot wrap the addition.
        const next = @as(u64, pos) + entry_header_len + name_len + data_len;
        if (next > end) fail(path, "archive entry runs past the end of its record");

        if (mtime != 0) {
            std.mem.writeInt(u32, data[pos..][0..4], epoch, .little);
            patched += 1;
        }
        pos = @intCast(next);
    }

    if (pos != end) fail(path, "archive entries do not fill their record");
    return patched;
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var args = init.minimal.args.iterate();
    if (!args.skip()) {
        usage();
    }

    const path = args.next() orelse {
        usage();
    };

    const epoch: u32 = b: {
        if (init.minimal.environ.getPosix("SOURCE_DATE_EPOCH")) |raw| {
            if (raw.len != 0) {
                const parsed = std.fmt.parseInt(u64, raw, 10) catch
                    fail(path, "SOURCE_DATE_EPOCH is not a number");
                break :b @intCast(std.math.clamp(parsed, 0, std.math.maxInt(u32)));
            }
        }
        break :b default_source_date_epoch;
    };

    const cwd = std.Io.Dir.cwd();
    const data = cwd.readFileAlloc(io, path, arena, .unlimited) catch fail(path, "failed to read input SOF");

    if (data.len < sof_header_len + 2 or !std.mem.eql(u8, data[0..4], "SOF\x00"))
        exit(path, "not a Quartus SOF file");

    // The trailing CRC record covers every byte before its own payload.
    const body = data.len - 2;
    if (crc.hash(data[0..body]) != readInt(u16, data, body))
        exit(path, "CRC mismatch, not touching file");

    var patched: usize = 0;
    var off: usize = sof_header_len;
    while (off < data.len) {
        if (data.len - off < record_header_len) fail(path, "truncated record header");
        const tag = readInt(u16, data, off);
        const rec_len = readInt(u32, data, off + 2);

        const next = @as(u64, off) + record_header_len + rec_len;
        if (next > data.len) fail(path, "record runs past the end of the file");

        if (tag == archive_tag)
            patched += patchArchive(path, data, off + record_header_len, @intCast(next), epoch);

        off = @intCast(next);
    }
    if (off != data.len) fail(path, "records do not fill the file");

    if (patched == 0) return;

    std.mem.writeInt(u16, data[body..][0..2], crc.hash(data[0..body]), .little);

    cwd.writeFile(io, .{ .sub_path = path, .data = data }) catch fail(path, "failed to write new SOF content");
}
