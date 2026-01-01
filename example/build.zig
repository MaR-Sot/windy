const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const stbi_dep = b.dependency("stbi", .{ .target = target, .optimize = optimize });
    const windy_dep = b.dependency("windy", .{
        .target = target,
        .optimize = optimize,
        .vulkan_support = true,
    });
    const exe = b.addExecutable(.{
        .name = "Example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("example.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{
                .{ .name = "windy", .module = windy_dep.module("windy") },
                .{ .name = "stbi", .module = stbi_dep.module("root") },
            },
        }),
    });

    exe.linkLibrary(stbi_dep.artifact("stbi"));

    const run_step = b.addRunArtifact(exe);
    const run = b.step("run", "Run the example");
    run.dependOn(&run_step.step);

    b.installArtifact(exe);
}
