const std = @import("std");
const Allocator = std.mem.Allocator;

const VERSION = "0.0.8";

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

    const release = b.step("release", "create binaries for common targets");
    const release_targets = [_][]const u8{
        "aarch64-linux",
        "aarch64-macos",
        "x86_64-linux",
        "x86-linux",
        "x86_64-macos",
        "aarch64-windows",
        "x86_64-windows",
    };

    for (release_targets) |target_string| {
        const rel_exe = b.addExecutable(.{
            .name = "drtl",
            .root_source_file = .{ .path = "src/main.zig" },
            .target = std.zig.CrossTarget.parse(.{
                .arch_os_abi = target_string,
            }) catch unreachable,
            .optimize = .ReleaseSafe,
        });
        rel_exe.strip = true;

        embedData(b, rel_exe) catch |err| {
            std.debug.panic("{any}", .{err});
        };

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}-v{s}-{s}", .{ rel_exe.name, VERSION, target_string });

        release.dependOn(&install.step);
    }
}
