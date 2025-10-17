const std = @import("std");
const ztime = @import("ztime.zig");
const List = std.ArrayList([]const u8);

///Displays the help message
pub fn help() void {
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("-r: recursive delete (directories)\n", .{});
    std.debug.print("-d, --dir: print path of where the trash dir is located\n", .{});
    std.debug.print("-h, --help: display this help message\n", .{});
    std.debug.print("-l, --list: List all files in the trash\n", .{});
    std.debug.print("--restore: List files deleted at current directory that are not present and select which ones to restore\n", .{});
    std.debug.print("--restoreAll: restore all files from this directory that are not currently present\n", .{});
    std.debug.print("--empty: Delete all files in trash\n", .{});
    std.debug.print("--clear <days>: Delete files older than specified number of days\n", .{});
    std.debug.print("--------------------------------------------------------------------------------\n", .{});
    std.debug.print("INFO\n", .{});
    std.debug.print("We save copies of all files deleted at current dir. If you want an older copy you can examine the files in the trash directory\n", .{});
}

const Flag = enum { NONE, R, HELP, DIR, RESTORE, RESTOREALL, EMPTY, CLEAR, LIST };

const PathType = enum { FILE, DIR, NONE };

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

    pub fn init(allocator: std.mem.Allocator) !Rm {
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
        };
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
                std.debug.print("Error: --clear requires a number of days\n", .{});
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
                help();
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
        std.debug.print("Trash dir: {s}\n", .{self.trash_path});
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
                    std.debug.print("zrm: '{s}' is a directory use -r to delete directories\n", .{path});
                },
                PathType.NONE => {
                    std.debug.print("zrm: No file or directory '{s}'\n", .{path});
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
                    std.debug.print("zrm: No file or directory '{s}'\n", .{path});
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

    // TODO: Implement restore functionality
    fn restore(self: *Rm) !void {
        _ = self;
        std.debug.print("TODO: Implement restore functionality\n", .{});
        std.debug.print("This should:\n", .{});
        std.debug.print("1. Read .trashinfo files in the info directory\n", .{});
        std.debug.print("2. Filter for files originally from current directory\n", .{});
        std.debug.print("3. Show interactive menu to select files to restore\n", .{});
        std.debug.print("4. Move selected files back to original locations\n", .{});
    }

    // TODO: Implement restoreAll functionality
    fn restoreAll(self: *Rm) !void {
        _ = self;
        std.debug.print("TODO: Implement restoreAll functionality\n", .{});
        std.debug.print("This should:\n", .{});
        std.debug.print("1. Read .trashinfo files in the info directory\n", .{});
        std.debug.print("2. Filter for files originally from current directory\n", .{});
        std.debug.print("3. Check if files don't exist at original location\n", .{});
        std.debug.print("4. Restore all matching files automatically\n", .{});
    }

    // TODO: Implement empty trash functionality
    fn empty(self: *Rm) !void {
        std.debug.print("Emptying trash...\n", .{});

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

        std.debug.print("Trash emptied successfully\n", .{});
    }

    // TODO: Implement clear old files functionality
    fn clear(self: *Rm) !void {
        const days = self.clear_days orelse return error.MissingClearDays;
        std.debug.print("Clearing files older than {d} days...\n", .{days});

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
                            std.debug.print("Failed to delete {s}: {}\n", .{ trash_name, err });
                            continue;
                        };
                    };

                    // Delete the trashinfo file
                    try info_dir.deleteFile(entry.name);
                    deleted_count += 1;
                }
            }
        }

        std.debug.print("Deleted {d} old items from trash\n", .{deleted_count});
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

    fn getFileContents(self: *Rm, full_path: []const u8) !struct { path: []const u8, date: []const u8 } {
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

        var iter = info_dir.iterate();
        while (try iter.next()) |entry| {
            if (!std.mem.endsWith(u8, entry.name, ".trashinfo")) continue;

            const info_file_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ self.info_path, entry.name });

            //const path, const date = try self.getFileContents(info_file_path);
            const result = try self.getFileContents(info_file_path);

            std.debug.print("{s}\t{s}\t{s}\n", .{ std.fs.path.basename(result.path), result.path, result.date });
        }
    }
};
