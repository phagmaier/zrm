const std = @import("std");
const builtin = @import("builtin");
const help = @import("rm.zig").help;
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

    var rm = try Rm.init(allocator);
    defer rm.deinit();

    rm.parse(&args) catch |err| {
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

    try rm.run();
}
