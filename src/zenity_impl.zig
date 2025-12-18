const std = @import("std");

const zd = @import("zd.zig");

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
    var process: std.process.Child = .init(argv, allocator);
    errdefer _ = process.wait() catch {};
    process.stdout_behavior = .Pipe;
    try process.spawn();

    const stdout = process.stdout.?;
    var stdout_buf: [4096]u8 = undefined;
    var stdout_reader = stdout.reader(&stdout_buf);
    const ret = try stdout_reader.interface.allocRemaining(allocator, .unlimited);

    const term = try process.wait();
    return switch (term.Exited) {
        0 => ret,
        1 => &.{},
        else => error.Fail,
    };
}

pub fn openDialog(
    comptime multiple_selection: bool,
    allocator: std.mem.Allocator,
    child_allocator: std.mem.Allocator,
    dialog_type: zd.DialogType,
    filters: []const zd.Filter,
    title: []const u8,
    default_path: ?[]const u8,
) !if (multiple_selection) []const []const u8 else []const u8 {
    var args: std.ArrayList([]const u8) = .{};

    const title_arg = try std.fmt.allocPrint(allocator, "--title={s}", .{title});
    try args.appendSlice(allocator, &.{ "zenity", "--file-selection", title_arg });
    if (dialog_type == .directory) try args.append(allocator, "--directory");
    if (multiple_selection) try args.append(allocator, "--multiple");
    try appendFilterArgs(allocator, &args, filters);
    if (default_path) |name|
        try args.append(allocator, try std.fmt.allocPrint(allocator, "--filename={s}", .{name}));

    const output = std.mem.trimEnd(u8, try runCommand(allocator, args.items), "\n");
    if (!multiple_selection) return try child_allocator.dupe(u8, output);

    var result: std.ArrayList([]const u8) = .{};
    var iter = std.mem.splitScalar(u8, output, '|');
    while (iter.next()) |path|
        try result.append(child_allocator, try child_allocator.dupe(u8, path));
    return try result.toOwnedSlice(child_allocator);
}

pub fn saveDialog(
    allocator: std.mem.Allocator,
    child_allocator: std.mem.Allocator,
    filters: []const zd.Filter,
    title: []const u8,
    default_path: ?[]const u8,
) ![]const u8 {
    var args: std.ArrayList([]const u8) = .{};

    const title_arg = try std.fmt.allocPrint(allocator, "--title={s}", .{title});
    try args.appendSlice(allocator, &.{ "zenity", "--file-selection", "--save", title_arg });
    try appendFilterArgs(allocator, &args, filters);
    if (default_path) |name|
        try args.append(allocator, try std.fmt.allocPrint(allocator, "--filename={s}", .{name}));

    return try child_allocator.dupe(u8, std.mem.trimEnd(u8, try runCommand(allocator, args.items), "\n"));
}

fn appendFilterArgs(
    allocator: std.mem.Allocator,
    args: *std.ArrayList([]const u8),
    filters: []const zd.Filter,
) !void {
    for (filters) |filter| {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        var w = &aw.writer;
        try w.writeAll("--file-filter=");
        try w.writeAll(filter.name);
        try w.writeAll(" |");
        if (filter.exts) |exts| {
            for (exts) |ext| {
                try w.writeAll(" *.");
                try w.writeAll(ext);
            }
        } else try w.writeAll(" *");
        try args.append(allocator, aw.written());
    }
}
