const std = @import("std");

const zd = @import("zd");

pub fn main() !void {
    var dbg_alloc: std.heap.DebugAllocator(.{ .stack_trace_frames = 10 }) = .init;
    defer _ = dbg_alloc.deinit();
    const allocator = dbg_alloc.allocator();

    const save_path = try zd.saveDialog(allocator, &.{
        .{ .name = "Zig", .exts = &.{ "zig", "zon" } },
        .{ .name = "Text", .exts = &.{ "txt", "pdf" } },
    }, "Hello World", null);
    defer zd.freeResult(allocator, save_path);
    std.log.err("Save dialog path: {s}", .{save_path});

    const open_path = try zd.openDialog(false, allocator, .file, &.{
        .{ .name = "Zig", .exts = &.{ "zig", "zon" } },
        .{ .name = "Text", .exts = &.{ "txt", "pdf" } },
    }, "Hello World", null);
    defer zd.freeResult(allocator, open_path);
    std.log.err("Open dialog path: {s}", .{open_path});

    const multi_path = try zd.openDialog(true, allocator, .file, &.{
        .{ .name = "Zig", .exts = &.{ "zig", "zon" } },
        .{ .name = "Text", .exts = &.{ "txt", "pdf" } },
    }, "Hello World", null);
    defer zd.freeResult(allocator, multi_path);
    std.log.err("Multi open dialog paths: [", .{});
    for (multi_path) |path| std.log.err("  {s}", .{path});
    std.log.err("];", .{});
}
