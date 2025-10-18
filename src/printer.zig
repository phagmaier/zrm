const std = @import("std");

pub const Printer = struct {
    pub const RESET = "\x1b[0m";
    pub const BOLD = "\x1b[1m";
    pub const DIM = "\x1b[2m";
    pub const CYAN = "\x1b[36m";
    pub const GREEN = "\x1b[32m";
    pub const YELLOW = "\x1b[33m";
    pub const RED = "\x1b[31m";

    stdout: *std.Io.Writer,

    pub fn init(stdout: *std.Io.Writer) Printer {
        return Printer{ .stdout = stdout };
    }

    pub fn printTableHeader(self: *Printer) !void {
        try self.stdout.print("{s}{s}", .{ Printer.BOLD, Printer.CYAN });
        try self.stdout.print("{s: <6}", .{"#"});
        try self.stdout.print("{s: <30}", .{"Name"});
        try self.stdout.print("{s: <50}", .{"Original Path"});
        try self.stdout.print("{s: <20}", .{"Deleted"});
        try self.stdout.print("{s}\n", .{Printer.RESET});
        try self.stdout.print("{s}\n", .{"─" ** 106}); // Separator line
    }

    pub fn printTableRow(self: *Printer, basename: []const u8, full_path: []const u8, date: []const u8, index: usize) !void {
        try self.stdout.print("{s}{d: <6}{s}", .{ Printer.YELLOW, index, Printer.RESET });

        if (basename.len > 28) {
            try self.stdout.print("{s: <25}...", .{basename[0..25]});
        } else {
            try self.stdout.print("{s: <30}", .{basename});
        }

        try self.stdout.print("{s}", .{Printer.DIM});
        if (full_path.len > 48) {
            try self.stdout.print("...{s: <45}", .{full_path[full_path.len - 45 ..]});
        } else {
            try self.stdout.print("{s: <50}", .{full_path});
        }
        try self.stdout.print("{s}", .{Printer.RESET});

        try self.stdout.print("{s: <20}\n", .{date});
    }

    pub fn flush(self: *Printer) !void {
        try self.stdout.flush();
    }

    pub fn help(self: *Printer) !void {
        try self.stdout.writeAll("--------------------------------------------------------------------------------\n");
        try self.stdout.print("{s}FLAGS:{s}\n", .{ Printer.BOLD, Printer.RESET });
        try self.stdout.print("{s}-r:{s} recursive delete (directories)\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}-d, --dir:{s} print path of where the trash dir is located\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}-h, --help:{s} display this help message\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}-l, --list:{s} List all files in the trash\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}--restore:{s} List files deleted at current directory that are not present and select which ones to restore\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}--restoreAll:{s} restore all files from this directory that are not currently present\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}--empty:{s} Delete all files in trash\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.print("{s}--clear <days>:{s} Delete files older than specified number of days\n", .{ Printer.CYAN, Printer.RESET });
        try self.stdout.writeAll("--------------------------------------------------------------------------------\n");
    }

    pub fn print(self: *Printer, comptime str: []const u8, args: anytype) !void {
        try self.stdout.print(str, args);
    }

    pub fn write(self: *Printer, str: []const u8) !void {
        try self.stdout.writeAll(str);
    }
};
