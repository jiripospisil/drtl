const std = @import("std");
const Allocator = std.mem.Allocator;

const VERSION = "0.0.21";

fn embedConfig(b: *std.Build, exe: *std.Build.Step.Compile, page_paths: std.ArrayList([]const u8)) !void {
    var options = b.addOptions();
    options.addOption([]const []const u8, "page_paths", page_paths.items);
    options.addOption([]const u8, "version", try getVersion(b.allocator));
    exe.root_module.addOptions("config", options);

    for (page_paths.items) |page_path| {
        exe.root_module.addAnonymousImport(page_path, .{
            .root_source_file = b.path(page_path),
        });
    }
}

fn collectPagePaths(b: *std.Build) !std.ArrayList([]const u8) {
    var page_paths = std.ArrayList([]const u8).init(b.allocator);
    try traverseAndCollectPagePaths(b, &page_paths, "pages");
    return page_paths;
}

fn traverseAndCollectPagePaths(b: *std.Build, pages: *std.ArrayList([]const u8), path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{ .iterate = true });
    var it = dir.iterate();

    while (try it.next()) |file| {
        const name = try std.fmt.allocPrint(b.allocator, "{s}/{s}", .{ path, file.name });

        switch (file.kind) {
            .file => {
                if (!std.mem.endsWith(u8, name, ".md")) {
                    continue;
                }

                std.debug.print("Found {s}\n", .{name});
                try pages.append(name);
            },
            .directory => {
                try traverseAndCollectPagePaths(b, pages, name);
            },
            else => |t| std.debug.panic("Unexpected type '{any}'", .{t}),
        }
    }
}

fn getVersion(allocator: Allocator) ![]const u8 {
    var file = try std.fs.cwd().openFile("./pages/updated_on", .{});
    defer file.close();

    const updated_on = try file.readToEndAlloc(allocator, 11);
    return try std.fmt.allocPrint(allocator, "v{s}, database updated on {s}", .{ VERSION, updated_on });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const page_paths = collectPagePaths(b) catch |err| {
        std.debug.panic("{any}", .{err});
    };

    const exe = b.addExecutable(.{
        .name = "drtl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    embedConfig(b, exe, page_paths) catch |err| {
        std.debug.panic("{any}", .{err});
    };

    b.installArtifact(exe);

    const release = b.step("release", "create binaries for common targets");
    const release_targets = [_][]const u8{
        "x86-linux",

        "x86_64-linux",
        "x86_64-macos",
        "x86_64-windows",

        "aarch64-linux",
        "aarch64-macos",
        "aarch64-windows",

        "riscv64-linux",
    };

    for (release_targets) |target_string| {
        const query = std.zig.CrossTarget.parse(.{
            .arch_os_abi = target_string,
        }) catch unreachable;

        const rel_exe = b.addExecutable(.{
            .name = "drtl",
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(query),
            .optimize = .ReleaseSafe,
            .strip = true,
        });

        embedConfig(b, rel_exe, page_paths) catch |err| {
            std.debug.panic("{any}", .{err});
        };

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}-v{s}-{s}", .{ rel_exe.name, VERSION, target_string });

        release.dependOn(&install.step);
    }
}
