const std = @import("std");
const builtin = @import("builtin");
const List = std.ArrayList([]const u8);

const Flag = enum { NONE, R, HELP, DIR, RESTORE, RESTOREALL, EMPTY, CLEAR };

///Displays the help message
pub fn help() void {
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("-r: recursive delete (directories)\n", .{});
    std.debug.print("-d, --dir: print path of where the trash dir is located\n", .{});
    std.debug.print("-h, --help: display this help message\n", .{});
    std.debug.print("--restore: List files deleted at current directory that are not present and select which ones to restore\n", .{});
    std.debug.print("--restoreAll: restore all files from this directory that are not currently present\n", .{});
    std.debug.print("--empty: Delete all files in trash\n", .{});
    std.debug.print("--clear <days>: Delete files older than specified number of days\n", .{});
    std.debug.print("--------------------------------------------------------------------------------\n", .{});
    std.debug.print("INFO\n", .{});
    std.debug.print("We save copies of all files deleted at current dir. If you want an older copy you can examine the files in the trash directory\n", .{});
}

const Data = struct {
    flag: Flag,
    paths: List,
    arena: std.heap.ArenaAllocator,
    clear_days: ?u32,

    pub fn init(allocator: std.mem.Allocator) Data {
        return Data{
            .flag = Flag.NONE,
            .paths = List.empty,
            .arena = std.heap.ArenaAllocator.init(allocator),
            .clear_days = null,
        };
    }

    pub fn deinit(self: *Data) void {
        self.arena.deinit();
    }

    ///Does what it says it does gets and creates the trash path
    pub fn getOrCreateTrashPath(self: *Data) ![]const u8 {
        const home = try std.process.getEnvVarOwned(self.arena.allocator(), "HOME");
        const trash_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/.local/share/Trash/files", .{home});
        try std.fs.cwd().makePath(trash_path);
        return trash_path;
    }

    ///Splits arguments into paths and flags
    pub fn parse(self: *Data, args: *std.process.ArgIterator) !void {
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
    fn setFlag(self: *Data, arg: []const u8, args: *std.process.ArgIterator) !void {
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
    pub fn run(self: *Data) !void {
        switch (self.flag) {
            Flag.NONE, Flag.R => {
                try self.rm();
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
    fn printTrashDir(self: *Data) !void {
        const trash = try self.getOrCreateTrashPath();
        std.debug.print("Trash dir: {s}\n", .{trash});
    }

    ///deletes both files and Dirs
    fn rm(self: *Data) !void {
        const trash = try self.getOrCreateTrashPath();
        for (self.paths.items) |path| {
            try self.removeItem(path, trash);
        }
    }

    ///Removes an individual file or Dir
    fn removeItem(self: *Data, path: []const u8, trash: []const u8) !void {
        const stat = std.fs.cwd().statFile(path) catch |err| {
            std.debug.print("Error: '{s}' - {}\n", .{ path, err });
            return;
        };

        if (stat.kind == .directory) {
            if (self.flag == Flag.R) {
                try self.moveDirectory(path, trash);
            } else {
                std.debug.print("Error: '{s}' is a directory (use -r to delete directories)\n", .{path});
            }
        } else {
            try self.moveFile(path, trash);
        }
    }

    ///Moves specified DIR to the trash
    fn moveDirectory(self: *Data, path: []const u8, trash: []const u8) !void {
        const basename = std.fs.path.basename(path);

        // Get absolute path before moving
        const abs_path = try std.fs.cwd().realpathAlloc(self.arena.allocator(), path);

        // Find unique destination
        const final_path = try self.findUniquePath(trash, basename, abs_path);

        // Move the directory
        try std.fs.cwd().rename(path, final_path);

        // Write metadata
        try self.writeMetadata(basename, abs_path, final_path);

        std.debug.print("Moved directory '{s}' to trash\n", .{path});
    }

    ///Move specified file to the trash
    fn moveFile(self: *Data, path: []const u8, trash: []const u8) !void {
        const basename = std.fs.path.basename(path);

        const abs_path = try std.fs.cwd().realpathAlloc(self.arena.allocator(), path);

        const final_path = try self.findUniquePath(trash, basename, abs_path);

        try std.fs.cwd().rename(path, final_path);

        try self.writeMetadata(basename, abs_path, final_path);

        std.debug.print("Moved '{s}' to trash\n", .{path});
    }

    ///Get a unique path for our file
    fn findUniquePath(self: *Data, trash: []const u8, basename: []const u8, original_path: []const u8) ![]const u8 {
        const candidate = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ trash, basename });

        std.fs.cwd().access(candidate, .{}) catch {
            return candidate;
        };

        const metadata_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}.trashinfo", .{candidate});

        if (self.readOriginalPath(metadata_path)) |existing_original| {
            if (std.mem.eql(u8, existing_original, original_path)) {
                try self.removeOldVersion(candidate);
                return candidate;
            }
        } else |_| {}

        const timestamp = std.time.timestamp();
        return try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}.{d}", .{ trash, basename, timestamp });
    }

    ///Deletes old version of our data
    fn removeOldVersion(self: *Data, path: []const u8) !void {
        std.fs.cwd().deleteFile(path) catch |err| {
            if (err == error.IsDir) {
                try std.fs.cwd().deleteTree(path);
            } else {
                return err;
            }
        };

        const metadata_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}.trashinfo", .{path});
        std.fs.cwd().deleteFile(metadata_path) catch {};
    }

    ///get the original path of our file before it was deleted (stored in metaData)
    fn readOriginalPath(self: *Data, metadata_path: []const u8) ![]const u8 {
        const file = std.fs.cwd().openFile(metadata_path, .{}) catch {
            return error.CannotReadMetadata;
        };
        defer file.close();

        const content = try file.readToEndAlloc(self.arena.allocator(), 4096);

        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "Path=")) {
                return line[5..];
            }
        }

        return error.PathNotFoundInMetadata;
    }

    ///Each deleted file gets a meta data file to help with restores and name conflicts
    ///this is the function that creates these meta data files
    fn writeMetadata(self: *Data, original_path: []const u8, trash_path: []const u8) !void {
        const metadata_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}.trashinfo", .{trash_path});

        const file = try std.fs.cwd().createFile(metadata_path, .{});
        defer file.close();

        const timestamp = std.time.timestamp();
        const epoch_seconds: std.time.epoch.EpochSeconds = .{ .secs = @intCast(timestamp) };
        const epoch_day = epoch_seconds.getEpochDay();
        const year_day = epoch_day.calculateYearDay();
        const month_day = year_day.calculateMonthDay();

        var buf_writer = std.io.bufferedWriter(file.writer());
        const writer = buf_writer.writer();

        try writer.writeAll("[Trash Info]\n");
        try writer.print("Path={s}\n", .{original_path});
        try writer.print("DeletionDate={d:0>4}-{d:0>2}-{d:0>2}T", .{ year_day.year, month_day.month.numeric(), month_day.day_index + 1 });

        const day_seconds = epoch_seconds.getDaySeconds();
        try writer.print("{d:0>2}:{d:0>2}:{d:0>2}\n", .{
            day_seconds.getHoursIntoDay(),
            day_seconds.getMinutesIntoHour(),
            day_seconds.getSecondsIntoMinute(),
        });

        try buf_writer.flush();
    }

    ///Not implimented yet!
    ///will list all possible files to be restored and give user the option to select from them
    fn restore(self: *Data) !void {
        _ = self;
        std.debug.print("Function not set up yet\n", .{});
    }

    ///Not implimented yet!
    ///Restores all files associated with the current Dir
    fn restoreAll(self: *Data) !void {
        _ = self;
        std.debug.print("Function not set up yet\n", .{});
    }

    ///Clear trash
    fn empty(self: *Data) !void {
        const trash = try self.getOrCreateTrashPath();

        var dir = try std.fs.cwd().openDir(trash, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        var deleted_count: usize = 0;

        while (try iterator.next()) |entry| {
            // Skip .trashinfo files, we'll delete them with their corresponding files
            if (std.mem.endsWith(u8, entry.name, ".trashinfo")) {
                continue;
            }

            const item_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ trash, entry.name });
            const metadata_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}.trashinfo", .{item_path});

            // Delete the item (file or directory)
            if (entry.kind == .directory) {
                std.fs.cwd().deleteTree(item_path) catch |err| {
                    std.debug.print("Error deleting directory '{s}': {}\n", .{ entry.name, err });
                    continue;
                };
            } else {
                std.fs.cwd().deleteFile(item_path) catch |err| {
                    std.debug.print("Error deleting file '{s}': {}\n", .{ entry.name, err });
                    continue;
                };
            }

            // Delete metadata file
            std.fs.cwd().deleteFile(metadata_path) catch {};

            deleted_count += 1;
        }

        std.debug.print("Emptied trash: deleted {d} items\n", .{deleted_count});
    }

    ///Clear based on dats
    fn clear(self: *Data) !void {
        const days = self.clear_days orelse {
            std.debug.print("Error: --clear requires a number of days\n", .{});
            return error.MissingClearDays;
        };

        const trash = try self.getOrCreateTrashPath();
        const now = std.time.timestamp();
        const cutoff_time = now - (@as(i64, days) * 86400); // days * seconds_per_day

        var dir = try std.fs.cwd().openDir(trash, .{ .iterate = true });
        defer dir.close();

        var iterator = dir.iterate();
        var deleted_count: usize = 0;

        while (try iterator.next()) |entry| {
            // Skip .trashinfo files, we'll delete them with their corresponding files
            if (std.mem.endsWith(u8, entry.name, ".trashinfo")) {
                continue;
            }

            const item_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}/{s}", .{ trash, entry.name });
            const metadata_path = try std.fmt.allocPrint(self.arena.allocator(), "{s}.trashinfo", .{item_path});

            // Read deletion date from metadata
            const deletion_time = self.readDeletionTime(metadata_path) catch {
                // If we can't read metadata, skip this item
                continue;
            };

            if (deletion_time < cutoff_time) {
                // Delete the item (file or directory)
                if (entry.kind == .directory) {
                    std.fs.cwd().deleteTree(item_path) catch |err| {
                        std.debug.print("Error deleting directory '{s}': {}\n", .{ entry.name, err });
                        continue;
                    };
                } else {
                    std.fs.cwd().deleteFile(item_path) catch |err| {
                        std.debug.print("Error deleting file '{s}': {}\n", .{ entry.name, err });
                        continue;
                    };
                }

                // Delete metadata file
                std.fs.cwd().deleteFile(metadata_path) catch {};

                deleted_count += 1;
            }
        }

        std.debug.print("Cleared trash: deleted {d} items older than {d} days\n", .{ deleted_count, days });
    }

    ///Reads the time file was deleted (done in order to clear old files automatically)
    fn readDeletionTime(self: *Data, metadata_path: []const u8) !i64 {
        const file = try std.fs.cwd().openFile(metadata_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.arena.allocator(), 4096);

        // Parse deletion date from metadata
        // Format: DeletionDate=2025-10-16T15:30:45
        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            if (std.mem.startsWith(u8, line, "DeletionDate=")) {
                const date_str = line[13..]; // Skip "DeletionDate="

                // Parse ISO 8601 format: YYYY-MM-DDTHH:MM:SS
                if (date_str.len < 19) return error.InvalidDateFormat;

                const year = try std.fmt.parseInt(i32, date_str[0..4], 10);
                const month = try std.fmt.parseInt(u8, date_str[5..7], 10);
                const day = try std.fmt.parseInt(u8, date_str[8..10], 10);
                const hour = try std.fmt.parseInt(u8, date_str[11..13], 10);
                const minute = try std.fmt.parseInt(u8, date_str[14..16], 10);
                const second = try std.fmt.parseInt(u8, date_str[17..19], 10);

                var days_since_epoch: i64 = 0;

                var y: i32 = 1970;
                while (y < year) : (y += 1) {
                    if (std.time.epoch.isLeapYear(y)) {
                        days_since_epoch += 366;
                    } else {
                        days_since_epoch += 365;
                    }
                }

                const days_in_months = std.time.epoch.getDaysInMonths(std.time.epoch.isLeapYear(year));
                var m: u8 = 1;
                while (m < month) : (m += 1) {
                    days_since_epoch += days_in_months[m - 1];
                }

                days_since_epoch += day - 1;

                const timestamp = days_since_epoch * 86400 +
                    @as(i64, hour) * 3600 +
                    @as(i64, minute) * 60 +
                    @as(i64, second);

                return timestamp;
            }
        }

        return error.DeletionDateNotFound;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    var data = Data.init(allocator);
    defer data.deinit();

    data.parse(&args) catch |err| {
        switch (err) {
            error.NoArgs => {
                std.debug.print("No arguments provided\n", .{});
                help();
                return;
            },
            else => {
                std.debug.print("Error: {}\n", .{err});
                return;
            },
        }
    };

    try data.run();
}
