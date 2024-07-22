const std = @import("std");
const builtin = @import("builtin");
const config = @import("config");
const pages = @import("pages").pages;
const File = std.fs.File;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

fn writeHighlighted(allocator: Allocator, stdout: File, content: []const u8) !void {
    const tty_conf = std.io.tty.detectConfig(std.io.getStdErr());
    var stdout_bw = std.io.bufferedWriter(stdout.writer());
    const stdout_w = stdout_bw.writer();

    try stdout_w.writeAll("\n");

    var it = std.mem.tokenizeScalar(u8, content, '\n');

    while (it.next()) |s| {
        if (std.mem.eql(u8, s, "")) {
            try stdout_w.writeAll("\n");
        } else if (std.mem.startsWith(u8, s, "#")) {
            try tty_conf.setColor(stdout_w, .bold);
            try stdout_w.print("{s}\n\n", .{s[2..]});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, ">")) {
            try tty_conf.setColor(stdout_w, .dim);
            try stdout_w.print("{s}\n\n", .{s[2..]});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "-")) {
            try tty_conf.setColor(stdout_w, .green);
            try stdout_w.print("{s}\n", .{s});
            try tty_conf.setColor(stdout_w, .reset);
        } else if (std.mem.startsWith(u8, s, "`")) {
            const ss = s[1..(s.len - 1)];
            const output = try allocator.alloc(u8, ss.len);

            _ = std.mem.replace(u8, ss, "}}", "{{", output);

            try stdout_w.writeAll("    ");
            try tty_conf.setColor(stdout_w, .red);

            var itt = std.mem.tokenizeSequence(u8, output, "{{");
            var flip = false;
            while (itt.next()) |sss| {
                if (flip) {
                    try tty_conf.setColor(stdout_w, .blue);
                } else {
                    try tty_conf.setColor(stdout_w, .red);
                }
                flip = !flip;
                try stdout_w.writeAll(sss);
            }
            try stdout_w.writeAll("\n\n");
        }
    }

    try tty_conf.setColor(stdout_w, .reset);
    try stdout_bw.flush();
}

fn printPage(allocator: Allocator, stdout: File, name: []const u8) !void {
    const candidate_pages = candidate_pages: {
        var list = std.ArrayList([]const u8).init(allocator);

        // category/name -> [category/name]
        if (std.mem.containsAtLeast(u8, name, 1, "/")) {
            try list.append(name);
            break :candidate_pages list;
        }

        // name -> [current_os/name, common/name, categories../name]
        const current_os = switch (builtin.os.tag) {
            .linux => "linux",
            .windows => "windows",
            .macos => "osx",
            else => "linux",
        };
        try list.append(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ current_os, name }));
        try list.append(try std.fmt.allocPrint(allocator, "common/{s}", .{name}));

        const categories = [_][]const u8{
            "android",
            "linux",
            "osx",
            "sunos",
            "windows",
            "freebsd",
            "openbsd",
        };
        for (categories) |category| {
            if (!std.mem.eql(u8, current_os, category)) {
                try list.append(try std.fmt.allocPrint(allocator, "{s}/{s}", .{ category, name }));
            }
        }
        break :candidate_pages list;
    };

    for (candidate_pages.items) |page_name| {
        const content = pages.get(page_name);

        if (content) |c| {
            return try writeHighlighted(allocator, stdout, c);
        }
    }

    const joined = try std.mem.join(allocator, ", ", candidate_pages.items);
    std.debug.print("Unable to locate the page. The candidates were {s}.\n", .{joined});
    std.process.exit(1);
}

fn printPageList(stdout: File) !void {
    var stdout_bw = std.io.bufferedWriter(stdout.writer());
    const stdout_w = stdout_bw.writer();

    for (pages.keys()) |key| {
        try stdout_w.print("{s}\n", .{key});
    }

    try stdout_bw.flush();
}

pub fn main() !void {
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    var idx: usize = 1;

    const stdout = std.io.getStdOut();

    if (args.len == 1) {
        try stdout.writeAll(usage_text);
        return std.process.cleanExit();
    }

    while (idx < args.len) : (idx += 1) {
        const arg = args[idx];

        if (std.mem.startsWith(u8, arg, "-")) {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try stdout.writeAll(usage_text);
                return std.process.cleanExit();
            }

            if (std.mem.eql(u8, arg, "-v") or std.mem.eql(u8, arg, "--version")) {
                try stdout.writeAll(config.version);
                return std.process.cleanExit();
            }

            if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--list")) {
                return printPageList(stdout);
            }

            std.debug.print("Unknown option: '{s}'\n\n{s}", .{ arg, usage_text });
            std.process.exit(1);
        }

        return printPage(allocator, stdout, arg);
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
