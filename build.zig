const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const options = .{
        .use_wayland = false, // b.option(bool, "use_wayland", "Whether to use Wayland over X11 on Linux / BSDs") orelse false,
        .use_gtk = b.option(bool, "use_gtk",
            \\Whether to use GTK as the dialog provider on Linux / BSDs (requires GTK3 development headers).
            \\Zenity is used otherwise and assumed to exist on the computer running the program.
        ) orelse true,
        .vulkan_support = b.option(bool, "vulkan_support", "Whether to provide utility functions for use with Vulkan.") orelse false,
    };

    const opt_step = b.addOptions();
    inline for (@typeInfo(@TypeOf(options)).@"struct".fields) |field|
        opt_step.addOption(field.type, field.name, @field(options, field.name));

    const mod = b.addModule("windy", .{
        .root_source_file = b.path("src/windy.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .imports = &.{
            .{ .name = "options", .module = opt_step.createModule() },
        },
    });

    if (builtin.os.tag == .windows) if (b.lazyDependency("zigwin32", .{})) |dep|
        mod.addImport("win32", dep.module("win32"));

    if (builtin.os.tag == .linux or builtin.os.tag.isBSD()) {
        if (options.use_gtk) mod.linkSystemLibrary("gtk+-3.0", .{});

        if (options.use_wayland)
            mod.linkSystemLibrary("wayland-client", .{})
        else {
            mod.linkSystemLibrary("xcb", .{});
            mod.linkSystemLibrary("xcb-xkb", .{});
            mod.linkSystemLibrary("xcb-render", .{});
            mod.linkSystemLibrary("xcb-render-util", .{});
            mod.linkSystemLibrary("xkbcommon-x11", .{});
        }
    }
}
