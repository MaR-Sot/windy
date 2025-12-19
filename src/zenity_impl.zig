const std = @import("std");

const zd = @import("zd.zig");

fn runCommand(allocator: std.mem.Allocator, argv: []const []const u8) !struct {
    text: []const u8,
    term: u1,
} {
    var proc: std.process.Child = .init(argv, allocator);
    errdefer _ = proc.wait() catch {};
    proc.stdout_behavior = .Pipe;
    try proc.spawn();

    var buf: [4096]u8 = undefined;
    var reader = proc.stdout.?.reader(&buf);
    const ret = try reader.interface.allocRemaining(allocator, .unlimited);

    const term = try proc.wait();
    if (term.Exited > 1) return error.Fail;
    return .{
        .text = ret,
        .term = @intCast(term.Exited),
    };
}

fn appendFilterArgs(
    allocator: std.mem.Allocator,
    args: *std.ArrayList([]const u8),
    filters: []const zd.Filter,
) !void {
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

    const res = try runCommand(allocator, args.items);
    const output = std.mem.trimEnd(u8, res.text, "\n");
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

    const res = try runCommand(allocator, args.items);
    return try child_allocator.dupe(u8, std.mem.trimEnd(u8, res.text, "\n"));
}

pub fn message(
    allocator: std.mem.Allocator,
    level: zd.MessageLevel,
    buttons: zd.MessageButtons,
    text: []const u8,
    title: []const u8,
) !bool {
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

    const res = try runCommand(allocator, args.items);
    return res.term == 0;
}

pub fn colorChooser(
    allocator: std.mem.Allocator,
    color: zd.Rgba,
    use_alpha: bool,
    title: []const u8,
) !zd.Rgba {
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
            std.mem.trimStart(u8, res.text, "rgb("),
            "rgba(",
        ),
        ")\n",
    );
    var iter = std.mem.splitScalar(u8, values, ',');
    return .{
        .r = try std.fmt.parseInt(u8, iter.next() orelse return error.InvalidResult, 10),
        .g = try std.fmt.parseInt(u8, iter.next() orelse return error.InvalidResult, 10),
        .b = try std.fmt.parseInt(u8, iter.next() orelse return error.InvalidResult, 10),
        .a = if (!use_alpha)
            255
        else
            @intFromFloat(try std.fmt.parseFloat(f64, iter.next() orelse "1.0") * 255.0),
    };
}
