const std = @import("std");

pub fn main() !void {
    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    const args = try std.process.argsAlloc(arena);
    const output_file = try std.fs.cwd().createFile(args[1], .{});

    try writePages(arena, output_file);
}

fn writePages(allocator: std.mem.Allocator, output_file: std.fs.File) !void {
    try output_file.writeAll(
        \\ const std = @import("std");
        \\
        \\ pub const pages = std.StaticStringMap([]const u8).initComptime(.{
        \\
    );

    try traverseDir(allocator, output_file, "pages");

    try output_file.writeAll(
        \\ });
        \\
    );
}

fn traverseDir(allocator: std.mem.Allocator, output_file: std.fs.File, path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();

    while (try it.next()) |file| {
        const name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, file.name });

        switch (file.kind) {
            .file => {
                if (!std.mem.endsWith(u8, name, ".md")) {
                    continue;
                }

                var f = try std.fs.cwd().openFile(name, .{});
                defer f.close();
                const content = try f.readToEndAlloc(allocator, 4096);

                const writer = output_file.writer();
                try writer.writeAll(".{\"");
                try writer.writeAll(name[6..(name.len - 3)]);
                try writer.writeAll("\", \"");
                try std.zig.stringEscape(content, "", .{}, writer);
                try writer.writeAll("\"}, \n");
            },
            .directory => {
                try traverseDir(allocator, output_file, name);
            },
            else => |t| std.debug.panic("Unexpected type '{any}'", .{t}),
        }
    }
}
