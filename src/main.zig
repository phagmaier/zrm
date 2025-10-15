const std = @import("std");

fn delete_file(path: []const u8) !void {
    try std.fs.cwd().deleteFile(path);
}

fn delete_dir(path: []const u8) !void {
    try std.fs.cwd().deleteDir(path);
}

fn rm_r(args: *std.process.ArgIterator) void {
    if (args.next()) |arg| {
        delete_dir(arg) catch {
            delete_file(arg) catch {
                std.debug.print("Error: Could not delete file or directory '{s}'\n", .{arg});
                return;
            };
        };
    } else {
        std.debug.print("Missing argument for rm -r\n", .{});
    }
}

fn rm(arg: []const u8) void {
    delete_file(arg) catch {
        std.debug.print("Error: Could not delete file '{s}'\n", .{arg});
        return;
    };
}

pub fn main() !void {
    var args = std.process.args();
    _ = args.next(); // Skip program name

    if (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-r")) {
            rm_r(&args);
        } else if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            std.debug.print("Help message not yet implimented\n", .{});
        } else {
            rm(arg);
        }
    } else {
        std.debug.print("Error a path needed to be provided\n", .{});
    }
}
