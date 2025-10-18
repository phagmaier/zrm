const std = @import("std");
const builtin = @import("builtin");
const Rm = @import("rm.zig").Rm;

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const allocator = if (builtin.mode == .Debug)
        da.allocator()
    else
        std.heap.smp_allocator;

    defer _ = da.deinit();
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Create stdout writer
    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var rm = try Rm.init(allocator, stdout);
    defer rm.deinit();

    rm.parse(&args) catch |err| {
        switch (err) {
            error.NoArgs => {
                try rm.printer.write("No arguments provided\n");
                try rm.help();
                try rm.printer.flush();
                return;
            },
            else => {
                try rm.printer.print("Error: {}\n", .{err});
                try rm.printer.flush();
                return;
            },
        }
    };

    try rm.run();
    try rm.printer.flush();
}

