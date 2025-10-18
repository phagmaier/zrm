const std = @import("std");
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";
const DIM = "\x1b[2m";
const CYAN = "\x1b[36m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const RED = "\x1b[31m";

fn printTableHeader() void {
    std.debug.print("{s}{s}", .{ BOLD, CYAN });
    std.debug.print("{s: <6}", .{"#"});
    std.debug.print("{s: <30}", .{"Name"});
    std.debug.print("{s: <50}", .{"Original Path"});
    std.debug.print("{s: <20}", .{"Deleted"});
    std.debug.print("{s}\n", .{RESET});
    std.debug.print("{s}\n", .{"─" ** 106}); // Separator line
}

fn printTableRow(index: usize, basename: []const u8, full_path: []const u8, date: []const u8) void {
    // Truncate long strings if needed
    const name_display = if (basename.len > 28) basename[0..25] ++ "..." else basename;
    const path_display = if (full_path.len > 48) "..." ++ full_path[full_path.len - 45 ..] else full_path;

    std.debug.print("{s}{d: <6}{s}", .{ YELLOW, index, RESET });
    std.debug.print("{s: <30}", .{name_display});
    std.debug.print("{s}{s: <50}{s}", .{ DIM, path_display, RESET });
    std.debug.print("{s: <20}\n", .{date});
}
