const std = @import("std");

const windy = @import("../windy.zig");
const Error = @import("errors.zig").ZenityError;

/// All of these are unreachable on Linux/BSDs, which are the only Zenity targets.
fn trimUnreachableErrors(e: anyerror) Error {
    return switch (e) {
        error.NoDevice,
        error.InvalidWtf8,
        error.CurrentWorkingDirectoryUnlinked,
        error.InvalidBatchScriptArg,
        error.InvalidUtf8,
        error.InvalidHandle,
        error.WaitAbandoned,
        error.WaitTimeOut,
        => unreachable,
        else => return @errorCast(e),
    };
}

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) Error![]const u8 {
    var proc: std.process.Child = .init(argv, allocator);
    errdefer _ = proc.wait() catch {};
    proc.stdout_behavior = .Pipe;

    proc.spawn() catch |e| return trimUnreachableErrors(e);

    var buf: [4096]u8 = undefined;
    var reader = proc.stdout.?.reader(&buf);
    const ret = try reader.interface.allocRemaining(allocator, .unlimited);

    const term = proc.wait() catch |e| return trimUnreachableErrors(e);
    if (term.Exited > 1) return Error.ExitCode;
    return ret;
}

fn appendFilterArgs(
    allocator: std.mem.Allocator,
    args: *std.ArrayList([]const u8),
    filters: []const windy.Filter,
) Error!void {
    for (filters) |filter| {
        var aw: std.Io.Writer.Allocating = .init(allocator);
        var w = &aw.writer;
        try w.print("--file-filter={s} |", .{filter.name});
        if (filter.exts) |exts| {
            for (exts) |ext|
                try w.print(" *.{s}", .{ext});
        } else try w.writeAll(" *");
        try args.append(allocator, aw.written());
    }
}

pub fn openDialog(
    comptime multiple_selection: bool,
    allocator: std.mem.Allocator,
    child_allocator: std.mem.Allocator,
    dialog_type: windy.DialogType,
    filters: []const windy.Filter,
    title: []const u8,
    default_path: ?[]const u8,
) Error!if (multiple_selection) []const []const u8 else []const u8 {
    var args: std.ArrayList([]const u8) = .{};

    const title_arg = try std.fmt.allocPrint(allocator, "--title={s}", .{title});
    try args.appendSlice(allocator, &.{ "zenity", "--file-selection", title_arg });
    if (dialog_type == .directory) try args.append(allocator, "--directory");
    if (multiple_selection) try args.append(allocator, "--multiple");
    try appendFilterArgs(allocator, &args, filters);
    if (default_path) |name|
        try args.append(allocator, try std.fmt.allocPrint(allocator, "--filename={s}", .{name}));

    const res = try runCommand(allocator, args.items);
    const output = std.mem.trimEnd(u8, res, "\n");
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
    filters: []const windy.Filter,
    title: []const u8,
    default_path: ?[]const u8,
) Error![]const u8 {
    var args: std.ArrayList([]const u8) = .{};

    const title_arg = try std.fmt.allocPrint(allocator, "--title={s}", .{title});
    try args.appendSlice(allocator, &.{ "zenity", "--file-selection", "--save", title_arg });
    try appendFilterArgs(allocator, &args, filters);
    if (default_path) |name|
        try args.append(allocator, try std.fmt.allocPrint(allocator, "--filename={s}", .{name}));

    const res = try runCommand(allocator, args.items);
    return try child_allocator.dupe(u8, std.mem.trimEnd(u8, res, "\n"));
}

pub fn message(
    allocator: std.mem.Allocator,
    level: windy.MessageLevel,
    buttons: windy.MessageButtons,
    text: []const u8,
    title: []const u8,
) Error!bool {
    var args: std.ArrayList([]const u8) = .{};

    try args.appendSlice(allocator, &.{
        "zenity",
        try std.fmt.allocPrint(allocator, "--title={s}", .{title}),
        try std.fmt.allocPrint(allocator, "--text={s}", .{text}),
    });
    const icon = switch (level) {
        .info => "--icon=info",
        .warn => "--icon=warning",
        .err => "--icon=error",
    };
    try args.appendSlice(allocator, switch (buttons) {
        .yes_no => &.{ icon, "--question", "--ok-label=Yes", "--cancel-label=No" },
        .ok_cancel => &.{ icon, "--question", "--ok-label=Ok", "--cancel-label=Cancel" },
        .ok => &.{},
    });
    if (buttons == .ok) try args.append(allocator, switch (level) {
        .info => "--info",
        .warn => "--warning",
        .err => "--error",
    });

    _ = try runCommand(allocator, args.items);
    return true;
}

pub fn colorChooser(
    allocator: std.mem.Allocator,
    color: windy.Rgba,
    use_alpha: bool,
    title: []const u8,
) Error!?windy.Rgba {
    var args: std.ArrayList([]const u8) = .{};

    try args.appendSlice(allocator, &.{
        "zenity",
        "--color-selection",
        try std.fmt.allocPrint(allocator, "--title={s}", .{title}),
        try std.fmt.allocPrint(allocator, "--color=rgba({},{},{},{}", .{
            color.r,
            color.g,
            color.b,
            @as(f64, @floatFromInt(color.a)) / 255.0,
        }),
    });

    const res = try runCommand(allocator, args.items);
    const values = std.mem.trimEnd(
        u8,
        std.mem.trimStart(
            u8,
            std.mem.trimStart(u8, res, "rgb("),
            "rgba(",
        ),
        ")\n",
    );
    if (values.len == 0) return null;

    var iter = std.mem.splitScalar(u8, values, ',');
    return .{
        .r = try std.fmt.parseInt(u8, iter.next() orelse return Error.ResultFormat, 10),
        .g = try std.fmt.parseInt(u8, iter.next() orelse return Error.ResultFormat, 10),
        .b = try std.fmt.parseInt(u8, iter.next() orelse return Error.ResultFormat, 10),
        .a = if (!use_alpha)
            255
        else
            @intFromFloat(try std.fmt.parseFloat(f64, iter.next() orelse "1.0") * 255.0),
    };
}
