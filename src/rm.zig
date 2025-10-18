const std = @import("std");
const ztime = @import("ztime.zig");
const Printer = @import("printer.zig").Printer;
const List = std.ArrayList([]const u8);

///Displays the help message
fn is_sub_dir(parent: []const u8, path: []const u8) bool {
    if (parent.len >= path.len) {
        return false;
    }
    const pos_child = path[0..parent.len];
    return std.mem.eql(u8, parent, pos_child);
}

const Flag = enum { NONE, R, HELP, DIR, RESTORE, RESTOREALL, EMPTY, CLEAR, LIST };

const PathType = enum { FILE, DIR, NONE };

const PathAndDate = struct {
    path: []const u8,
    date: []const u8,
};

pub fn getPathType(path: []const u8) PathType {
    const stat = std.fs.cwd().statFile(path) catch {
        return .NONE;
    };

    return switch (stat.kind) {
        .file => .FILE,
        .directory => .DIR,
        else => .NONE,
    };
}

pub const Rm = struct {
    //size of string deletiondelete=
    const DATE_STR_SIZE: usize = 13;
    //Size of Path
    const PATH_STR_SIZE: usize = 4;
    flag: Flag,
    paths: List,
    arena: std.heap.ArenaAllocator,
    clear_days: ?u32,
    trash_path: []const u8,
    info_path: []const u8,
    printer: Printer,

    pub fn init(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !Rm {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const home = try std.process.getEnvVarOwned(arena.allocator(), "HOME");
        const trash_path = try std.fmt.allocPrint(arena.allocator(), "{s}/.local/share/Trash/files", .{home});
        const info_path = try std.fmt.allocPrint(arena.allocator(), "{s}/.local/share/Trash/info", .{home});

        // Create directories if they don't exist
        try std.fs.cwd().makePath(trash_path);
        try std.fs.cwd().makePath(info_path);

        return Rm{
            .flag = Flag.NONE,
            .paths = List.empty,
            .arena = arena,
            .clear_days = null,
            .trash_path = trash_path,
            .info_path = info_path,
            .printer = Printer.init(stdout),
        };
    }

    pub fn help(self: *Rm) !void {
        try self.printer.help();
        try self.printer.flush();
    }

    pub fn deinit(self: *Rm) void {
        self.arena.deinit();
    }

    ///Splits arguments into paths and flags
    pub fn parse(self: *Rm, args: *std.process.ArgIterator) !void {
        _ = args.next();

        if (args.next()) |arg| {
            try self.setFlag(arg, args);
        } else {
            return error.NoArgs;
        }

        while (args.next()) |arg| {
            try self.paths.append(self.arena.allocator(), arg);
        }

        if (self.paths.items.len == 0 and (self.flag == Flag.R or self.flag == Flag.NONE)) {
            return error.NoArgs;
        }
    }

    ///Assigns the flag
    fn setFlag(self: *Rm, arg: []const u8, args: *std.process.ArgIterator) !void {
        if (std.mem.eql(u8, arg, "-r")) {
            self.flag = Flag.R;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            self.flag = Flag.HELP;
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--dir")) {
            self.flag = Flag.DIR;
        } else if (std.mem.eql(u8, arg, "--restore")) {
            self.flag = Flag.RESTORE;
        } else if (std.mem.eql(u8, arg, "--restoreAll")) {
            self.flag = Flag.RESTOREALL;
        } else if (std.mem.eql(u8, arg, "-l") or std.mem.eql(u8, arg, "--list")) {
            self.flag = Flag.LIST;
        } else if (std.mem.eql(u8, arg, "--empty")) {
            self.flag = Flag.EMPTY;
        } else if (std.mem.eql(u8, arg, "--clear")) {
            self.flag = Flag.CLEAR;
            // Get the days parameter
            if (args.next()) |days_str| {
                self.clear_days = try std.fmt.parseInt(u32, days_str, 10);
            } else {
                try self.printer.write("Error: --clear requires a number of days\n");
                return error.MissingClearDays;
            }
        } else {
            try self.paths.append(self.arena.allocator(), arg);
        }
    }

    ///Actually runs the program after parse
    pub fn run(self: *Rm) !void {
        switch (self.flag) {
            Flag.NONE => {
                try self.rm();
            },
            Flag.R => {
                try self.rmr();
            },
            Flag.LIST => {
                try self.list();
            },
            Flag.RESTORE => {
                try self.restore();
            },
            Flag.RESTOREALL => {
                try self.restoreAll();
            },
            Flag.HELP => {
                try self.printer.help();
            },
            Flag.DIR => {
                try self.printTrashDir();
            },
            Flag.EMPTY => {
                try self.empty();
            },
            Flag.CLEAR => {
                try self.clear();
            },
        }
    }

    ///When you call -d it will display the path of the trash
    fn printTrashDir(self: *Rm) !void {
        try self.printer.print("Trash dir: {s}\n", .{self.trash_path});
    }

    ///deletes both files and Dirs
    fn rm(self: *Rm) !void {
        for (self.paths.items) |path| {
            const ptype = getPathType(path);
            switch (ptype) {
                PathType.FILE => {
                    try self.movePath(path);
                },
                PathType.DIR => {
                    try self.printer.print("{s}zrm: '{s}' is a directory use -r to delete directories\n{s}", .{ Printer.RED, path, Printer.RESET });
                },
                PathType.NONE => {
                    try self.printer.print("{s}zrm: No file or directory '{s}'\n{s}", .{ Printer.RED, path, Printer.RESET });
                },
            }
        }
    }

    fn rmr(self: *Rm) !void {
        for (self.paths.items) |path| {
            const ptype = getPathType(path);
            switch (ptype) {
                PathType.FILE, PathType.DIR => {
                    try self.movePath(path);
                },
                PathType.NONE => {
                    try self.printer.print("{s}zrm: No file or directory '{s}'\n{s}", .{ Printer.RED, path, Printer.RESET });
                },
            }
        }
    }

    fn movePath(self: *Rm, path: []const u8) !void {
        // Get absolute path of source BEFORE moving
        const absolute_src = try std.fs.cwd().realpathAlloc(self.arena.allocator(), path);

        // Get the basename for the trash
        const basename = std.fs.path.basename(path);
        const ptype = getPathType(path);
        const unique_name = try self.getUniqueName(basename, ptype);

        // Move to trash
        const new_path_trash = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.trash_path, unique_name });
        try std.fs.renameAbsolute(absolute_src, new_path_trash);

        // Write metadata with original absolute path
        try self.writeMetaData(unique_name, absolute_src);
    }

    fn writeMetaData(self: *Rm, trash_name: []const u8, original_path: []const u8) !void {
        const meta_data_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}.trashinfo", .{ self.info_path, trash_name });
        const deletion_date = try ztime.formatTimeStamp(&self.arena, std.time.timestamp());

        const file = try std.fs.cwd().createFile(meta_data_path, .{});
        defer file.close();

        var write_buffer: [1024]u8 = undefined;
        var file_writer = file.writer(&write_buffer);
        const writer: *std.Io.Writer = &file_writer.interface;
        try writer.print("[Trash Info]\nPath={s}\nDeletionDate={s}\n", .{ original_path, deletion_date });
        try writer.flush();
    }

    fn getUniqueName(self: *Rm, basename: []const u8, pathType: PathType) ![]const u8 {
        // Check if base name already exists in trash
        if (!try self.existsInTrash(basename, pathType)) {
            return basename;
        }

        // Generate unique name by appending counter
        var count: u32 = 1;
        while (count < 10000) : (count += 1) { // Safety limit
            const unique_name = try std.fmt.allocPrint(self.arena.allocator(), "{s}_{d}", .{ basename, count });
            if (!try self.existsInTrash(unique_name, pathType)) {
                return unique_name;
            }
        }

        return error.TooManyDuplicates;
    }

    fn existsInTrash(self: *Rm, name: []const u8, pathType: PathType) !bool {
        const full_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.trash_path, name });

        switch (pathType) {
            .FILE => {
                var file = std.fs.openFileAbsolute(full_path, .{}) catch {
                    return false;
                };
                file.close();
                return true;
            },
            .DIR => {
                var dir = std.fs.openDirAbsolute(full_path, .{}) catch {
                    return false;
                };
                dir.close();
                return true;
            },
            .NONE => return false,
        }
    }

    fn move_back(self: *Rm, info_file_name: []const u8, original_path: []const u8) !void {
        const trash_name = info_file_name[0 .. info_file_name.len - 10];

        const trash_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.trash_path, trash_name });
        const info_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, info_file_name });

        // Check for conflict
        if (getPathType(original_path) != .NONE) {
            try self.printer.print("{s}✗{s} Skipped: {s} (already exists)\n", .{ Printer.YELLOW, Printer.RESET, std.fs.path.basename(original_path) });
            return;
        }

        // Restore
        try std.fs.renameAbsolute(trash_file_path, original_path);
        try std.fs.cwd().deleteFile(info_file_path);

        try self.printer.print("{s}✓{s} Restored: {s}\n", .{ Printer.GREEN, Printer.RESET, std.fs.path.basename(original_path) });
    }

    fn restore_select(self: *Rm, arr: std.ArrayList(PathAndDate), fileNames: std.ArrayList([]const u8)) !void {

        // Header
        try self.printer.print("\n{s}Files available for restore:{s}\n\n", .{ Printer.BOLD, Printer.RESET });
        try self.printer.printTableHeader();

        // Print each row
        for (arr.items, 0..) |item, i| {
            try self.printer.printTableRow(std.fs.path.basename(item.path), item.path, item.date, i);
        }

        //try stdout.print("\n{s}Enter number to restore [0-{d}] or 'q' to quit:{s} ", .{ BOLD, arr.items.len - 1, RESET });
        try self.printer.print("\n{s}Enter number to restore [0-{d}] or 'q' to quit:{s} ", .{ Printer.BOLD, arr.items.len - 1, Printer.RESET });
        try self.printer.flush();

        // Read user input
        var stdin_buffer: [512]u8 = undefined;
        var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
        const reader = &stdin_reader.interface;

        const line = (try reader.takeDelimiter('\n')) orelse {
            try self.printer.print("{s}Cancelled{s}\n", .{ Printer.YELLOW, Printer.RESET });
            return;
        };

        // Check for quit
        if (std.mem.eql(u8, line, "q") or std.mem.eql(u8, line, "Q")) {
            try self.printer.print("{s}Cancelled{s}\n", .{ Printer.YELLOW, Printer.RESET });
            return;
        }

        const parsed_uint = std.fmt.parseInt(u32, line, 10) catch {
            try self.printer.print("{s}Invalid number{s}\n", .{ Printer.RED, Printer.RESET });
            return;
        };

        if (parsed_uint >= arr.items.len) {
            try self.printer.print("{s}Invalid selection{s}\n", .{ Printer.RED, Printer.RESET });
            return;
        }

        try self.move_back(fileNames.items[parsed_uint], arr.items[parsed_uint].path);
    }
    fn restore(self: *Rm) !void {
        var arr = std.ArrayList(PathAndDate).empty;
        var file_names = std.ArrayList([]const u8).empty;
        const cwd_path = try std.fs.cwd().realpathAlloc(self.arena.allocator(), ".");

        var info_dir = try std.fs.openDirAbsolute(self.info_path, .{ .iterate = true });
        defer info_dir.close();

        var iter = info_dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".trashinfo")) continue;

            const info_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });
            const result = try self.getFileContents(info_file_path);

            if (is_sub_dir(cwd_path, result.path)) {
                try arr.append(self.arena.allocator(), result);
                try file_names.append(self.arena.allocator(), entry.name);
            }
        }

        if (arr.items.len == 0) {
            try self.printer.write("No items to restore from current directory\n");
            return;
        }

        try self.restore_select(arr, file_names);
    }

    fn restoreAll(self: *Rm) !void {
        const cwd_path = try std.fs.cwd().realpathAlloc(self.arena.allocator(), ".");

        var info_dir = try std.fs.openDirAbsolute(self.info_path, .{ .iterate = true });
        defer info_dir.close();

        try self.printer.print("\n{s}Restoring files from current directory...{s}\n\n", .{ Printer.BOLD, Printer.RESET });

        var restored_count: u32 = 0;
        var skipped_count: u32 = 0;

        var iter = info_dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".trashinfo")) continue;

            const info_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });
            const result = try self.getFileContents(info_file_path);

            // Only restore files from current directory
            if (!is_sub_dir(cwd_path, result.path)) continue;

            // Check for conflict
            if (getPathType(result.path) != .NONE) {
                try self.printer.print("{s}✗{s} Skipped: {s} (already exists)\n", .{ Printer.YELLOW, Printer.RESET, std.fs.path.basename(result.path) });
                skipped_count += 1;
                continue;
            }

            // Restore this file
            const trash_name = entry.name[0 .. entry.name.len - 10];
            const trash_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.trash_path, trash_name });

            try std.fs.renameAbsolute(trash_file_path, result.path);

            const info_path_full = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });
            try std.fs.cwd().deleteFile(info_path_full);

            try self.printer.print("{s}✓{s} Restored: {s}\n", .{ Printer.GREEN, Printer.RESET, std.fs.path.basename(result.path) });
            restored_count += 1;
        }

        // Summary
        try self.printer.print("\n{s}Summary:{s}\n", .{ Printer.BOLD, Printer.RESET });
        try self.printer.print("  Restored: {s}{d}{s}\n", .{ Printer.GREEN, restored_count, Printer.RESET });
        if (skipped_count > 0) {
            try self.printer.print("  Skipped:  {s}{d}{s} (conflicts)\n", .{ Printer.YELLOW, skipped_count, Printer.RESET });
        }
    }

    fn empty(self: *Rm) !void {
        try self.printer.print("Emptying trash...\n", .{});

        // Delete all files in trash directory
        var trash_dir = try std.fs.openDirAbsolute(self.trash_path, .{ .iterate = true });
        defer trash_dir.close();

        var iter = trash_dir.iterate();
        while (try iter.next()) |entry| {
            try trash_dir.deleteTree(entry.name);
        }

        // Delete all .trashinfo files
        var info_dir = try std.fs.openDirAbsolute(self.info_path, .{ .iterate = true });
        defer info_dir.close();

        var info_iter = info_dir.iterate();
        while (try info_iter.next()) |entry| {
            try info_dir.deleteFile(entry.name);
        }

        try self.printer.print("Trash emptied successfully\n", .{});
    }

    // TODO: Implement clear old files functionality
    fn clear(self: *Rm) !void {
        const days = self.clear_days orelse return error.MissingClearDays;
        try self.printer.print("Clearing files older than {d} days...\n", .{days});

        var info_dir = try std.fs.openDirAbsolute(self.info_path, .{ .iterate = true });
        defer info_dir.close();

        var iter = info_dir.iterate();
        var deleted_count: u32 = 0;

        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".trashinfo")) continue;

            // Read the trashinfo file
            const info_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });
            const content = try std.fs.cwd().readFileAlloc(self.arena.allocator(), info_path, 4096);

            // Parse deletion date from content
            if (try self.parseDeletionDate(content)) |deletion_timestamp| {
                if (ztime.isOlderThanDays(deletion_timestamp, days)) {
                    // Delete the actual file/dir from trash
                    const trash_name = entry.name[0 .. entry.name.len - 10]; // Remove .trashinfo
                    const trash_item_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.trash_path, trash_name });

                    // Try to delete as file first, then as directory
                    std.fs.deleteFileAbsolute(trash_item_path) catch {
                        std.fs.deleteTreeAbsolute(trash_item_path) catch |err| {
                            try self.printer.print("{s}Failed to delete {s}: {}\n{s}", .{ Printer.RED, trash_name, err, Printer.RESET });

                            continue;
                        };
                    };

                    // Delete the trashinfo file
                    try info_dir.deleteFile(entry.name);
                    deleted_count += 1;
                }
            }
        }

        try self.printer.print("Deleted {d} old items from trash\n", .{deleted_count});
        try self.printer.flush();
    }

    fn parseDeletionDate(self: *Rm, content: []const u8) !?i64 {
        _ = self;

        // Find "DeletionDate=" line
        const needle = "DeletionDate=";
        const start_idx = std.mem.indexOf(u8, content, needle) orelse return null;
        const date_start = start_idx + needle.len;

        // Find end of line
        const date_end = std.mem.indexOfScalarPos(u8, content, date_start, '\n') orelse content.len;

        const date_str = content[date_start..date_end];
        return ztime.parseTimeStamp(date_str) catch null;
    }

    fn getFileContents(self: *Rm, full_path: []const u8) !PathAndDate {
        const file = try std.fs.cwd().openFile(full_path, .{ .mode = .read_only });
        defer file.close();

        const buffer = try file.readToEndAlloc(self.arena.allocator(), std.math.maxInt(usize));
        var iter = std.mem.splitScalar(u8, buffer, '\n');

        _ = iter.first(); // Skip "[Trash Info]" line
        const path_line = iter.next() orelse return error.InvalidFormat;
        const date_line = iter.next() orelse return error.InvalidFormat;

        // Strip "Path=" and "DeletionDate=" prefixes
        const path = if (std.mem.startsWith(u8, path_line, "Path="))
            path_line[5..]
        else
            return error.InvalidFormat;

        const date = if (std.mem.startsWith(u8, date_line, "DeletionDate="))
            date_line[13..]
        else
            return error.InvalidFormat;

        return .{ .path = path, .date = date };
    }

    fn list(self: *Rm) !void {
        var info_dir = try std.fs.openDirAbsolute(self.info_path, .{ .iterate = true });
        defer info_dir.close();

        try self.printer.print("\n{s}Trash Contents:{s}\n\n", .{ Printer.BOLD, Printer.RESET });
        try self.printer.printTableHeader();

        var count: usize = 0;
        var iter = info_dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".trashinfo")) continue;

            const info_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });
            const result = try self.getFileContents(info_file_path);

            try self.printer.printTableRow(std.fs.path.basename(result.path), result.path, result.date, count);
            count += 1;
        }

        if (count == 0) {
            try self.printer.print("\n{s}Trash is empty{s}\n", .{ Printer.DIM, Printer.RESET });
        } else {
            try self.printer.print("\n{s}Total: {d} items{s}\n", .{ Printer.DIM, count, Printer.RESET });
        }
    }
};
