const std = @import("std");
const builtin = @import("builtin");
const List = std.ArrayList([]const u8);

const Flag = enum { NONE, R, HELP, DIR, RESTORE, RESTOREALL };

pub fn help() void {
    std.debug.print("FLAGS:\n", .{});
    std.debug.print("-r: recursive delete (directories)\n", .{});
    std.debug.print("-d, --dir: print path of where the trash dir is located\n", .{});
    std.debug.print("-h, --help: display this help message\n", .{});
    std.debug.print("--restore: List files deleted at current directory that are not present and select which ones to restore\n", .{});
    std.debug.print("--restoreAll: restore all files from this directory that are not currently present\n", .{});
    std.debug.print("--------------------------------------------------------------------------------", .{});
    std.debug.print("INFO\n", .{});
    std.debug.print("We save copies of all files deleted at current dir. If you want an older copy you can examine the files in the trash directory", .{});
}

const Data = struct {
    flag: Flag,
    paths: List,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Data {
        return Data{ .allocator = allocator, .paths = List.empty, .flag = Flag.NONE };
    }

    pub fn deinit(self: *Data) void {
        self.paths.deinit(self.allocator);
    }

    pub fn parse(self: *Data, args: *std.process.ArgIterator) !void {
        _ = args.next();

        if (args.next()) |arg| {
            try self.setFlag(arg);
        } else {
            return error.NoArgs;
        }

        while (args.next()) |arg| {
            try self.paths.append(self.allocator, arg);
        }

        if (self.paths.items.len == 0 and (self.flag == Flag.R or self.flag == Flag.NONE)) {
            return error.NoArgs;
        }
    }

    fn setFlag(self: *Data, arg: []const u8) !void {
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
        } else {
            // No flag recognized, treat as path
            try self.paths.append(self.allocator, arg);
        }
    }

    pub fn run(self: *Data) !void {
        switch (self.flag) {
            Flag.NONE => {
                self.rm();
            },
            Flag.R => {
                self.rmR();
            },
            Flag.RESTORE => {
                self.restore();
            },
            Flag.RESTOREALL => {
                self.restoreAll();
            },
            Flag.HELP => {
                help();
            },
            Flag.DIR => {
                try self.dir();
            },
        }
    }

    fn ensureTrashExists(self: *Data) !void {
        const trash_path = try self.getTrashPath();
        defer self.allocator.free(trash_path);

        const files_path = try std.fmt.allocPrint(self.allocator, "{s}/files", .{trash_path});
        defer self.allocator.free(files_path);

        const info_path = try std.fmt.allocPrint(self.allocator, "{s}/info", .{trash_path});
        defer self.allocator.free(info_path);

        std.fs.cwd().makePath(files_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        std.fs.cwd().makePath(info_path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
    }

    fn dir(self: *Data) !void {
        const path = try self.getTrashPath();
        defer self.allocator.free(path);
        std.debug.print("{s}\n", .{path});
    }

    fn getTrashPath(self: *Data) ![]u8 {
        const home = std.posix.getenv("HOME") orelse return error.NoHomeDir;
        return std.fmt.allocPrint(self.allocator, "{s}/.local/share/Trash", .{home});
    }

    fn rmR(self: *Data) void {
        for (self.paths.items) |path| {
            std.fs.cwd().deleteTree(path) catch {
                std.fs.cwd().deleteFile(path) catch {
                    std.debug.print("Could not find file/dir {s}\n", .{path});
                    continue;
                };
            };
        }
    }

    fn rm(self: *Data) void {
        for (self.paths.items) |path| {
            std.fs.cwd().deleteFile(path) catch {
                std.debug.print("Could not find file {s}\n", .{path});
                continue;
            };
        }
    }

    fn restore(self: *Data) void {
        _ = self;
        std.debug.print("Function not set up yet\n", .{});
    }

    fn restoreAll(self: *Data) void {
        _ = self;
        std.debug.print("Function not set up yet\n", .{});
    }
};

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug)
        da.allocator()
    else
        std.heap.smp_allocator;

    var args = std.process.args();
    var data = Data.init(allocator);
    defer data.deinit();

    data.parse(&args) catch |err| {
        switch (err) {
            error.NoArgs => {
                std.debug.print("No arguments provided\n", .{});
                return;
            },
            else => {
                std.debug.print("An unknown error occurred\n", .{});
                return;
            },
        }
    };

    try data.run();
}
