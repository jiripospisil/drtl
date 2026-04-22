const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const output_file = try std.Io.Dir.cwd().createFile(init.io, args[1], .{});

    var buffer: [4096]u8 = undefined;
    var writer = output_file.writer(init.io, &buffer);

    try writePages(init.io, init.arena.allocator(), &writer.interface);
    try writer.flush();
}

fn writePages(io: std.Io, allocator: std.mem.Allocator, writer: *std.Io.Writer) !void {
    try writer.writeAll(
        \\ const std = @import("std");
        \\
        \\ pub const pages = std.StaticStringMap([]const u8).initComptime(.{
        \\
    );

    try traverseDir(io, allocator, writer, "pages");

    try writer.writeAll(
        \\ });
        \\
    );
}

fn traverseDir(io: std.Io, allocator: std.mem.Allocator, writer: *std.Io.Writer, path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    var it = dir.iterate();

    while (try it.next(io)) |file| {
        const name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, file.name });

        switch (file.kind) {
            .file => {
                if (!std.mem.endsWith(u8, name, ".md")) {
                    continue;
                }

                const content = try std.Io.Dir.cwd().readFileAlloc(io, name, allocator, .unlimited);

                try writer.writeAll(".{\"");
                try writer.writeAll(name[6..(name.len - 3)]);
                try writer.writeAll("\", \"");
                try std.zig.stringEscape(content, writer);
                try writer.writeAll("\"}, \n");
            },
            .directory => {
                try traverseDir(io, allocator, writer, name);
            },
            else => |t| std.debug.panic("Unexpected type '{any}'", .{t}),
        }
    }
}
