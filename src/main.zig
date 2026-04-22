const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const pages = @import("pages").pages;
const Allocator = std.mem.Allocator;

fn writeHighlighted(io: std.Io, allocator: Allocator, writer: *std.Io.Writer, content: []const u8) !void {
    const mode: std.Io.Terminal.Mode = try .detect(io, std.Io.File.stdout(), false, false);
    var terminal: std.Io.Terminal = .{
        .writer = writer,
        .mode = mode,
    };
    try writer.writeAll("\n");

    var it = std.mem.tokenizeScalar(u8, content, '\n');

    while (it.next()) |s| {
        if (std.mem.eql(u8, s, "")) {
            try writer.writeAll("\n");
        } else if (std.mem.startsWith(u8, s, "#")) {
            try terminal.setColor(.bold);
            try writer.print("{s}\n\n", .{s[2..]});
            try terminal.setColor(.reset);
        } else if (std.mem.startsWith(u8, s, ">")) {
            try terminal.setColor(.dim);
            try writer.print("{s}\n\n", .{s[2..]});
            try terminal.setColor(.reset);
        } else if (std.mem.startsWith(u8, s, "-")) {
            try terminal.setColor(.green);
            try writer.print("{s}\n", .{s});
            try terminal.setColor(.reset);
        } else if (std.mem.startsWith(u8, s, "`")) {
            const ss = s[1..(s.len - 1)];
            const output = try allocator.alloc(u8, ss.len);

            _ = std.mem.replace(u8, ss, "}}", "{{", output);

            try writer.writeAll("    ");
            try terminal.setColor(.red);

            var itt = std.mem.tokenizeSequence(u8, output, "{{");
            var flip = false;
            while (itt.next()) |sss| {
                if (flip) {
                    try terminal.setColor(.blue);
                } else {
                    try terminal.setColor(.red);
                }
                flip = !flip;
                try writer.writeAll(sss);
            }
            try writer.writeAll("\n\n");
        }
    }

    try terminal.setColor(.reset);
}

fn printPage(io: std.Io, allocator: Allocator, writer: *std.Io.Writer, name: []const u8) !void {
    const candidate_pages = candidate_pages: {
        var list: std.ArrayList([]const u8) = .empty;

        // category/name -> [category/name]
        if (std.mem.containsAtLeast(u8, name, 1, "/")) {
            try list.append(allocator, name);
            break :candidate_pages list;
        }

        // name -> [current_os/name, common/name, categories../name]
        const current_os = switch (builtin.os.tag) {
            .linux => "linux",
            .windows => "windows",
            .macos => "osx",
            else => "linux",
        };
        try list.append(allocator, try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_os, name }));
        try list.append(allocator, try std.fmt.allocPrint(allocator, "common/{s}", .{name}));

        const categories = [_][]const u8{
            "android",
            "linux",
            "osx",
            "sunos",
            "windows",
            "freebsd",
            "netbsd",
            "openbsd",
        };
        for (categories) |category| {
            if (!std.mem.eql(u8, current_os, category)) {
                try list.append(allocator, try std.fmt.allocPrint(allocator, "{s}/{s}", .{ category, name }));
            }
        }
        break :candidate_pages list;
    };

    for (candidate_pages.items) |page_name| {
        const content = pages.get(page_name);

        if (content) |c| {
            return try writeHighlighted(io, allocator, writer, c);
        }
    }

    const joined = try std.mem.join(allocator, ", ", candidate_pages.items);
    std.debug.print("Unable to locate the page. The candidates were {s}.\n", .{joined});
    std.process.exit(1);
}

fn printPageList(io: std.Io, stdout: std.Io.File) !void {
    var buffer: [4096]u8 = undefined;
    var writer = stdout.writer(io, &buffer);

    for (pages.keys()) |key| {
        try writer.interface.print("{s}\n", .{key});
    }

    try writer.flush();
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const stdout = std.Io.File.stdout();

    var buffer: [4096]u8 = undefined;
    var w = stdout.writer(init.io, &buffer);
    var writer = &w.interface;
    defer writer.flush() catch {};

    if (args.len == 1) {
        try writer.writeAll(usage_text);
        return std.process.cleanExit(init.io);
    }

    for (1..args.len) |idx| {
        const arg = args[idx];

        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try writer.writeAll(usage_text);
                return std.process.cleanExit(init.io);
            }

            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try writer.writeAll(config.version);
                return std.process.cleanExit(init.io);
            }

            if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--list")) {
                return printPageList(init.io, stdout);
            }

            std.debug.print("Unknown option: '{s}'\n\n{s}", .{ arg, usage_text });
            std.process.exit(1);
        }

        try printPage(init.io, init.arena.allocator(), writer, arg);
    }
}

const usage_text =
    \\Usage: drtl <name>
    \\
    \\Prints tldr page for the given name.
    \\
    \\Pages are split into several categories (android, common, linux, osx, sunos, and windows). If
    \\you want a page for a specific category, use "category/name".
    \\
    \\Options:
    \\ -h, --help        print this help
    \\ -v, --version     print version
    \\ -l, --list        list all pages
    \\
;
