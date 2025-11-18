const std = @import("std");
const print = std.debug.print;
const builtin = @import("builtin");
const Allocator = std.mem.Allocator;
const CARDS = "KQJ";

pub fn main() !void {
    var da = std.heap.DebugAllocator(.{}){};
    const mem = if (builtin.mode == .Debug)
        da.allocator()
    else
        std.heap.smp_allocator;
    defer _ = da.deinit();
}
