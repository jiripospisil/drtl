const std = @import("std");
const Allocator = std.mem.Allocator;

const VERSION = "0.0.21";

fn embedConfig(b: *std.Build, exe: *std.Build.Step.Compile) !void {
    var options = b.addOptions();
    options.addOption([]const u8, "version", try getVersion(b.allocator));
    exe.root_module.addOptions("config", options);
}

fn getVersion(allocator: Allocator) ![]const u8 {
    var file = try std.fs.cwd().openFile("pages/updated_on", .{});
    defer file.close();

    const updated_on = try file.readToEndAlloc(allocator, 11);
    return try std.fmt.allocPrint(allocator, "v{s}, database updated on {s}", .{ VERSION, updated_on });
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const tool = b.addExecutable(.{
        .name = "compile_pages",
        .root_source_file = b.path("src/compile_pages.zig"),
        .target = b.host,
        .optimize = optimize,
    });

    const tool_step = b.addRunArtifact(tool);
    tool_step.addFileInput(b.path("pages/updated_on"));
    const output = tool_step.addOutputFileArg("pages.zig");

    const exe = b.addExecutable(.{
        .name = "drtl",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    try embedConfig(b, exe);

    exe.root_module.addAnonymousImport("pages", .{
        .root_source_file = output,
    });

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
        try embedConfig(b, rel_exe);

        rel_exe.root_module.addAnonymousImport("pages", .{
            .root_source_file = output,
        });

        const install = b.addInstallArtifact(rel_exe, .{});
        install.dest_dir = .prefix;
        install.dest_sub_path = b.fmt("{s}-v{s}-{s}", .{ rel_exe.name, VERSION, target_string });

        release.dependOn(&install.step);
    }
}
