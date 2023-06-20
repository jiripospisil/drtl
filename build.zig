const std = @import("std");
const Allocator = std.mem.Allocator;

const VERSION = "0.0.1";

fn embedData(b: *std.Build, exe: *std.Build.Step.Compile) !void {
    var options = b.addOptions();

    const pages = try collectPages(b.allocator, exe, "pages");
    options.addOption([]const []const u8, "pages", pages.items);

    options.addOption([]const u8, "version", try getVersion(b.allocator));

    exe.addOptions("embedded", options);
}

fn collectPages(allocator: Allocator, exe: *std.Build.Step.Compile, path: []const u8) !std.ArrayList([]const u8) {
    var pages = std.ArrayList([]const u8).init(allocator);
    try traverseAndCollectPages(allocator, exe, &pages, path);
    return pages;
}

fn traverseAndCollectPages(allocator: Allocator, exe: *std.Build.Step.Compile, pages: *std.ArrayList([]const u8), path: []const u8) !void {
    var dir = try std.fs.cwd().openIterableDir(path, .{});
    var it = dir.iterate();

    while (try it.next()) |file| {
        const name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ path, file.name });

        switch (file.kind) {
            .file => {
                if (!std.mem.endsWith(u8, name, ".md")) {
                    continue;
                }

                std.debug.print("Embedding {s}\n", .{name});
                try pages.append(name);

                exe.addAnonymousModule(name, .{
                    .source_file = std.build.FileSource.relative(name),
                });
            },
            .directory => {
                try traverseAndCollectPages(allocator, exe, pages, name);
            },
            else => |t| std.debug.panic("Unexpected type '{any}'", .{t}),
        }
    }
}

fn getVersion(allocator: Allocator) ![]const u8 {
    var file = try std.fs.cwd().openFile("./pages/updated_on", .{});
    defer file.close();

    var updated_on = try file.readToEndAlloc(allocator, 11);
    return try std.fmt.allocPrint(allocator, "v{s}, database updated on {s}", .{ VERSION, updated_on });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "drtl",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    embedData(b, exe) catch |err| {
        std.debug.panic("{any}", .{err});
    };

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
