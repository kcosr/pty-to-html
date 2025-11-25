const std = @import("std");
const ghostty_vt = @import("ghostty-vt");
const color = ghostty_vt.color;
const testing = std.testing;
const builtin = @import("builtin");

const usage =
    \\Usage: pty-to-html [OPTIONS] [FILE]
    \\
    \\Convert a raw PTY log file to HTML with styled terminal output.
    \\
    \\If FILE is not provided, reads from stdin.
    \\
    \\Options:
    \\  -c, --cols N         Terminal width in columns (default: 120)
    \\  -r, --rows N         Terminal height in rows (default: 40)
    \\  -o, --output FILE    Write output to FILE instead of stdout
    \\  --full               Output a full HTML document (with <html>, <head>, etc.)
    \\  --unwrap             Unwrap soft-wrapped lines
    \\  --no-trim            Don't trim trailing whitespace
    \\  --bg COLOR           Background color (hex, e.g., #1e1e1e)
    \\  --fg COLOR           Foreground color (hex, e.g., #d4d4d4)
    \\  --inline-colors      Emit colors as RGB instead of CSS variables
    \\  --no-palette         Don't emit CSS palette variables
    \\  -h, --help           Show this help message
    \\
;

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn parseColor(arg: []const u8) ?color.RGB {
    if (arg.len == 0) return null;

    var s = arg;
    if (s[0] == '#') {
        s = s[1..];
    }

    if (s.len == 6) {
        const r_hi = hexNibble(s[0]) orelse return null;
        const r_lo = hexNibble(s[1]) orelse return null;
        const g_hi = hexNibble(s[2]) orelse return null;
        const g_lo = hexNibble(s[3]) orelse return null;
        const b_hi = hexNibble(s[4]) orelse return null;
        const b_lo = hexNibble(s[5]) orelse return null;

        return .{
            .r = (r_hi << 4) | r_lo,
            .g = (g_hi << 4) | g_lo,
            .b = (b_hi << 4) | b_lo,
        };
    } else if (s.len == 3) {
        const r_n = hexNibble(s[0]) orelse return null;
        const g_n = hexNibble(s[1]) orelse return null;
        const b_n = hexNibble(s[2]) orelse return null;

        // Expand #RGB to #RRGGBB
        return .{
            .r = r_n * 17,
            .g = g_n * 17,
            .b = b_n * 17,
        };
    } else {
        return null;
    }
}

comptime {
    if (builtin.is_test) {
        _ = parseColor;
    }
}

pub fn main() !void {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    // Parse command line arguments
    var cols: u16 = 120;
    var rows: u16 = 40;
    var input_file: ?[]const u8 = null;
    var output_file: ?[]const u8 = null;
    var full_html: bool = false;
    var unwrap: bool = false;
    var trim_trailing: bool = true;
    var background_color: ?color.RGB = null;
    var foreground_color: ?color.RGB = null;
    var inline_colors: bool = false;
    var no_palette: bool = false;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var i: usize = 1; // Skip program name
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            var buf: [4096]u8 = undefined;
            var stdout_writer = std.fs.File.stdout().writer(&buf);
            const stdout = &stdout_writer.interface;
            try stdout.writeAll(usage);
            try stdout.flush();
            return;
        } else if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--cols")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --cols requires an argument\n", .{});
                std.process.exit(1);
            }
            cols = std.fmt.parseInt(u16, args[i], 10) catch {
                std.debug.print("Error: invalid column count: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-r") or std.mem.eql(u8, arg, "--rows")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --rows requires an argument\n", .{});
                std.process.exit(1);
            }
            rows = std.fmt.parseInt(u16, args[i], 10) catch {
                std.debug.print("Error: invalid row count: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --output requires an argument\n", .{});
                std.process.exit(1);
            }
            output_file = args[i];
        } else if (std.mem.eql(u8, arg, "--full")) {
            full_html = true;
        } else if (std.mem.eql(u8, arg, "--unwrap")) {
            unwrap = true;
        } else if (std.mem.eql(u8, arg, "--no-trim")) {
            trim_trailing = false;
        } else if (std.mem.eql(u8, arg, "--bg")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --bg requires an argument\n", .{});
                std.process.exit(1);
            }
            background_color = parseColor(args[i]) orelse {
                std.debug.print("Error: invalid background color: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--fg")) {
            i += 1;
            if (i >= args.len) {
                std.debug.print("Error: --fg requires an argument\n", .{});
                std.process.exit(1);
            }
            foreground_color = parseColor(args[i]) orelse {
                std.debug.print("Error: invalid foreground color: {s}\n", .{args[i]});
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "--inline-colors")) {
            inline_colors = true;
        } else if (std.mem.eql(u8, arg, "--no-palette")) {
            no_palette = true;
        } else if (arg[0] != '-') {
            input_file = arg;
        } else {
            std.debug.print("Error: unknown option: {s}\n", .{arg});
            std.process.exit(1);
        }
    }

    // Create a terminal
    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = cols, .rows = rows });
    defer t.deinit(alloc);

    // Create a read-only VT stream for parsing terminal sequences
    var stream = t.vtStream();
    defer stream.deinit();

    // Read input and process through VT stream using slices for performance
    var buf: [65536]u8 = undefined;
    if (input_file) |path| {
        const file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Error opening file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        };
        defer file.close();

        while (true) {
            const n = try file.readAll(&buf);
            if (n == 0) break;
            try stream.nextSlice(buf[0..n]);
        }
    } else {
        const stdin = std.fs.File.stdin();
        while (true) {
            const n = try stdin.readAll(&buf);
            if (n == 0) break;
            try stream.nextSlice(buf[0..n]);
        }
    }

    // Use TerminalFormatter to emit HTML
    const palette_ptr: *const color.Palette = &t.colors.palette.current;
    const palette_opt: ?*const color.Palette = if (inline_colors) palette_ptr else null;

    var formatter: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .html,
        .unwrap = unwrap,
        .trim = trim_trailing,
        .background = background_color,
        .foreground = foreground_color,
        .palette = palette_opt,
    });
    if (no_palette) {
        formatter.extra.palette = false;
    }

    // Open output file or use stdout
    const output: std.fs.File = if (output_file) |path|
        std.fs.cwd().createFile(path, .{}) catch |err| {
            std.debug.print("Error creating output file '{s}': {}\n", .{ path, err });
            std.process.exit(1);
        }
    else
        std.fs.File.stdout();
    defer if (output_file != null) output.close();

    var out_buf: [8192]u8 = undefined;
    var out_writer = output.writer(&out_buf);
    const writer = &out_writer.interface;

    // Write HTML output
    if (full_html) {
        try writer.writeAll(
            \\<!DOCTYPE html>
            \\<html>
            \\<head>
            \\<meta charset="UTF-8">
            \\<title>PTY Log</title>
            \\<style>
            \\body {
            \\  background-color: #1e1e1e;
            \\  color: #d4d4d4;
            \\  padding: 20px;
            \\}
            \\</style>
            \\
        );
    }

    try writer.print("{f}", .{formatter});

    if (full_html) {
        try writer.writeAll(
            \\</body>
            \\</html>
            \\
        );
    }

    try writer.flush();
}

test "parseColor parses 6-digit hex with and without hash" {
    const c1 = parseColor("#1e1e1e") orelse return testing.expect(false);
    try testing.expectEqual(@as(u8, 0x1e), c1.r);
    try testing.expectEqual(@as(u8, 0x1e), c1.g);
    try testing.expectEqual(@as(u8, 0x1e), c1.b);

    const c2 = parseColor("ff00aa") orelse return testing.expect(false);
    try testing.expectEqual(@as(u8, 0xff), c2.r);
    try testing.expectEqual(@as(u8, 0x00), c2.g);
    try testing.expectEqual(@as(u8, 0xaa), c2.b);
}

test "parseColor parses 3-digit hex with and without hash" {
    const c1 = parseColor("#abc") orelse return testing.expect(false);
    try testing.expectEqual(@as(u8, 0xaa), c1.r);
    try testing.expectEqual(@as(u8, 0xbb), c1.g);
    try testing.expectEqual(@as(u8, 0xcc), c1.b);

    const c2 = parseColor("0f3") orelse return testing.expect(false);
    try testing.expectEqual(@as(u8, 0x00), c2.r);
    try testing.expectEqual(@as(u8, 0xff), c2.g);
    try testing.expectEqual(@as(u8, 0x33), c2.b);
}

test "parseColor rejects invalid input" {
    try testing.expect(parseColor("") == null);
    try testing.expect(parseColor("1") == null);
    try testing.expect(parseColor("#12") == null);
    try testing.expect(parseColor("zzzzzz") == null);
    try testing.expect(parseColor("#ggg") == null);
}

test "background and foreground colors appear in HTML output" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = 80, .rows = 24 });
    defer t.deinit(alloc);

    var stream = t.vtStream();
    defer stream.deinit();

    const input = "hello";
    try stream.nextSlice(input);

    var formatter: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .html,
        .background = .{ .r = 0x12, .g = 0x34, .b = 0x56 },
        .foreground = .{ .r = 0xab, .g = 0xcd, .b = 0xef },
    });

    var buf: [16384]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try formatter.format(&writer);
    const html = std.Io.Writer.buffered(&writer);

    try testing.expect(std.mem.indexOf(u8, html, "background-color: #123456;") != null);
    try testing.expect(std.mem.indexOf(u8, html, "color: #abcdef;") != null);
}

test "no-palette disables palette style block in HTML output" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = 80, .rows = 24 });
    defer t.deinit(alloc);

    var stream = t.vtStream();
    defer stream.deinit();

    const input = "hello";
    try stream.nextSlice(input);

    var formatter: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .html,
        .palette = &t.colors.palette.current,
    });
    formatter.extra.palette = false;

    var buf: [16384]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buf);
    try formatter.format(&writer);
    const html = std.Io.Writer.buffered(&writer);

    try testing.expect(std.mem.indexOf(u8, html, "<style>:root{") == null);
}

test "session.log can be formatted to HTML without error" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = 120, .rows = 40 });
    defer t.deinit(alloc);

    var stream = t.vtStream();
    defer stream.deinit();

    const file = try std.fs.cwd().openFile("testdata/session.log", .{});
    defer file.close();

    var buf: [65536]u8 = undefined;
    while (true) {
        const n = try file.readAll(&buf);
        if (n == 0) break;
        try stream.nextSlice(buf[0..n]);
    }

    var formatter: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .html,
        .palette = &t.colors.palette.current,
    });
    formatter.extra.palette = true;

    var discarding: std.Io.Writer.Discarding = .init(&.{});
    try formatter.format(&discarding.writer);
    try testing.expect(discarding.count > 0);
}

test "unwrap reduces newline count for soft-wrapped lines" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = 5, .rows = 4 });
    defer t.deinit(alloc);

    var stream = t.vtStream();
    defer stream.deinit();

    const input = "abcdefghij";
    try stream.nextSlice(input);

    var formatter_no_unwrap: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .plain,
        .unwrap = false,
    });
    var buf1: [256]u8 = undefined;
    var writer1 = std.Io.Writer.fixed(&buf1);
    try formatter_no_unwrap.format(&writer1);
    const out1 = std.Io.Writer.buffered(&writer1);

    var formatter_unwrap: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .plain,
        .unwrap = true,
    });
    var buf2: [256]u8 = undefined;
    var writer2 = std.Io.Writer.fixed(&buf2);
    try formatter_unwrap.format(&writer2);
    const out2 = std.Io.Writer.buffered(&writer2);

    const nl1 = std.mem.count(u8, out1, "\n");
    const nl2 = std.mem.count(u8, out2, "\n");
    try testing.expect(nl2 < nl1);
}

fn countTrailingSpaces(s: []const u8) usize {
    var count: usize = 0;
    var i: usize = s.len;
    while (i > 0) : (i -= 1) {
        if (s[i - 1] == ' ') {
            count += 1;
        } else {
            break;
        }
    }
    return count;
}

test "trim controls trailing spaces in plain output" {
    var gpa: std.heap.DebugAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var t: ghostty_vt.Terminal = try .init(alloc, .{ .cols = 20, .rows = 4 });
    defer t.deinit(alloc);

    var stream = t.vtStream();
    defer stream.deinit();

    const input = "abc   ";
    try stream.nextSlice(input);

    var formatter_trim: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .plain,
        .trim = true,
    });
    var buf1: [256]u8 = undefined;
    var writer1 = std.Io.Writer.fixed(&buf1);
    try formatter_trim.format(&writer1);
    const out1 = std.Io.Writer.buffered(&writer1);
    const nl_pos1 = std.mem.indexOfScalar(u8, out1, '\n') orelse out1.len;
    const before_nl1 = out1[0..nl_pos1];

    var formatter_no_trim: ghostty_vt.formatter.TerminalFormatter = .init(&t, .{
        .emit = .plain,
        .trim = false,
    });
    var buf2: [256]u8 = undefined;
    var writer2 = std.Io.Writer.fixed(&buf2);
    try formatter_no_trim.format(&writer2);
    const out2 = std.Io.Writer.buffered(&writer2);
    const nl_pos2 = std.mem.indexOfScalar(u8, out2, '\n') orelse out2.len;
    const before_nl2 = out2[0..nl_pos2];

    try testing.expect(countTrailingSpaces(before_nl1) == 0);
    try testing.expect(countTrailingSpaces(before_nl2) >= 3);
}
